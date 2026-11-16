class_name MissionManager
extends Node
## Campaña de misiones encadenadas (datos en res://data/missions/campaign_moon.json).
##
## Cada objetivo avanza con eventos del juego (EventBus) o por verificación
## periódica (distancia, zonas, reservas de la base). Al completar una misión se
## muestra el cierre educativo, se desbloquea un logro y empieza la siguiente.

signal mission_started(index: int)
signal objectives_changed
signal mission_completed(index: int)
signal achievement_unlocked(id: String, title: String)
signal briefing(title: String, text: String)

const DATA_PATH := "res://data/missions/campaign_moon.json"
const SAVE_ID := "missions"
const TUTORIAL_PATH := "res://data/missions/tutorial_moon.json"
var has_tutorial := false

var missions: Array = []
var achievement_titles: Dictionary = {}
var current: int = 0
var progress: Array[int] = []
var achievements: Array[String] = []
var finished: bool = false
## Entre misiones (mostrando el cierre): no se cuentan objetivos.
var between: bool = false

var _session: GameSession
var _poll := 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(&"mission_manager")
	add_to_group(&"session_ui")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if data is Dictionary:
		missions = data.get("missions", [])
		achievement_titles = data.get("achievements", {})
	EventBus.resource_collected.connect(_on_collected)
	EventBus.structure_built.connect(func(_s: Node) -> void: _recount_builds())
	EventBus.structure_loaded.connect(_on_loaded)
	EventBus.scan_completed.connect(func(_f: Array) -> void: _on_action(&"scan"))
	EventBus.player_action.connect(_on_action)


func bind_session(session: GameSession) -> void:
	_session = session
	if GameState.tutorial:
		_add_tutorial()
	_session.player.jumped.connect(func() -> void: _on_action(&"jump"))
	_start.call_deferred(current, true) # diferido: que el HUD de misiones ya esté conectado


## Antepone los pasos del tutorial a la campaña.
func _add_tutorial() -> void:
	if has_tutorial:
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUTORIAL_PATH))
	if d is Dictionary:
		missions = (d as Dictionary).get("missions", []) + missions
		has_tutorial = true


func current_mission() -> Dictionary:
	return missions[current] if current < missions.size() else {}


func text(d: Variant) -> String:
	if d is Dictionary:
		var loc := TranslationServer.get_locale().left(2)
		return str(d.get(loc, d.get("es", "")))
	return str(d)


func objective_target(o: Dictionary) -> int:
	return int(o.get("count", o.get("target", 1))) if o.type in ["action", "collect", "build", "load"] else 1


func is_objective_done(i: int) -> bool:
	var objs: Array = current_mission().get("objectives", [])
	if between:
		return true
	return i < objs.size() and i < progress.size() and progress[i] >= objective_target(objs[i])


func _start(index: int, show_briefing: bool) -> void:
	between = false
	current = index
	if current >= missions.size():
		finished = true
		objectives_changed.emit()
		return
	var objs: Array = current_mission().get("objectives", [])
	if progress.size() != objs.size():
		progress.clear()
		progress.resize(objs.size())
		progress.fill(0)
	mission_started.emit(current)
	if show_briefing:
		briefing.emit(text(current_mission().title), text(current_mission().briefing))
		var ev := String(current_mission().get("event", ""))
		if ev != "":
			get_tree().create_timer(20.0, false).timeout.connect(func() -> void:
				var ed := get_tree().get_first_node_in_group(&"event_director") as EventDirector
				if ed:
					ed.trigger(StringName(ev)))
	_recount_builds()
	objectives_changed.emit()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.5 or finished or between or _session == null:
		return
	_poll = 0.0
	var objs: Array = current_mission().get("objectives", [])
	var changed := false
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	for i in objs.size():
		if is_objective_done(i):
			continue
		var o: Dictionary = objs[i]
		match String(o.type):
			"distance":
				var colony := get_tree().get_first_node_in_group(&"colony") as Colony
				var home: Node3D = colony.get_player_home() if colony else null
				var origin: Node3D = home if home else (net.get_lander() if net else null)
				if origin and origin.global_position.distance_to(_session.player.global_position) >= float(o.target):
					progress[i] = 1
					changed = true
			"visit":
				var c := _crater(String(o.zone))
				if not c.is_empty():
					var d := Vector2(_session.player.global_position.x - float(c.x), _session.player.global_position.z - float(c.z)).length()
					if d <= float(c.diameter_m) * 0.42:
						progress[i] = 1
						changed = true
			"self_sufficient":
				if net and net.is_self_sufficient():
					progress[i] = 1
					changed = true
			"oxygen_reserve":
				if net and net.oxygen_kg >= float(o.target):
					progress[i] = 1
					changed = true
			"upgrade":
				var col := get_tree().get_first_node_in_group(&"colony") as Colony
				if col and col.upgrades.has(String(o.id)):
					progress[i] = 1
					changed = true
	if changed:
		objectives_changed.emit()
		_check_complete()


func _on_action(action: StringName) -> void:
	_bump(func(o: Dictionary) -> bool: return o.type == "action" and StringName(o.action) == action, 1)


func _on_collected(item_id: StringName, amount: int) -> void:
	_bump(func(o: Dictionary) -> bool: return o.type == "collect" and StringName(o.item) == item_id, amount)


func _on_loaded(_s: Node, item_id: StringName, amount: int) -> void:
	_bump(func(o: Dictionary) -> bool: return o.type == "load" and StringName(o.item) == item_id, amount)


func _bump(match_fn: Callable, amount: int) -> void:
	if finished or between:
		return
	var objs: Array = current_mission().get("objectives", [])
	var changed := false
	for i in objs.size():
		if not is_objective_done(i) and match_fn.call(objs[i]):
			progress[i] = mini(progress[i] + amount, objective_target(objs[i]))
			changed = true
	if changed:
		objectives_changed.emit()
		_check_complete()


## Las construcciones se cuentan por estado actual de la base (no por eventos).
func _recount_builds() -> void:
	if finished or between or missions.is_empty():
		return
	var counts := {}
	for s in get_tree().get_nodes_in_group(&"structure"):
		var st := s as Structure
		if st.is_built():
			counts[String(st.def.id)] = counts.get(String(st.def.id), 0) + 1
	var objs: Array = current_mission().get("objectives", [])
	var changed := false
	for i in objs.size():
		var o: Dictionary = objs[i]
		if o.type == "build":
			var v := mini(int(counts.get(String(o.structure), 0)), objective_target(o))
			if v != progress[i]:
				progress[i] = v
				changed = true
	if changed:
		objectives_changed.emit()
		_check_complete()


func _check_complete() -> void:
	var objs: Array = current_mission().get("objectives", [])
	for i in objs.size():
		if not is_objective_done(i):
			return
	var m := current_mission()
	mission_completed.emit(current)
	briefing.emit(text(m.title) + " ✓", text(m.debrief))
	_unlock(String(m.get("achievement", "")))
	between = true
	progress.clear()
	get_tree().create_timer(9.0, false).timeout.connect(func() -> void: _start(current + 1, true))


func _unlock(id: String) -> void:
	if id == "" or id in achievements:
		return
	achievements.append(id)
	var title := text(achievement_titles.get(id, id))
	achievement_unlocked.emit(id, title)
	GameState.unlock(StringName("achievement_" + id))


func _crater(id: String) -> Dictionary:
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	if region:
		for c: Dictionary in region.features.get("craters", []):
			if c.get("id") == id:
				return c
	return {}


# --- Saveable ---------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var idx := current + 1 if between else current
	return {"current": idx, "progress": [] if between else Array(progress), "achievements": achievements, "finished": finished, "tutorial": has_tutorial}


func load_state(data: Dictionary) -> void:
	if bool(data.get("tutorial", false)):
		_add_tutorial()
	achievements.assign(data.get("achievements", []))
	finished = bool(data.get("finished", false))
	progress.clear()
	for v: Variant in data.get("progress", []):
		progress.append(int(v))
	_start(int(data.get("current", 0)), false)
