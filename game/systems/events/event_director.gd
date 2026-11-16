class_name EventDirector
extends Node
## Sucesos aleatorios de la colonia, anunciados por radio (voz en el idioma elegido).
## Cada partida los sortea distinto: así cada vuelta se juega diferente.
##
##   flare     Fulguración solar real (DONKI, archivada). Decisión: reforzar el
##             blindaje gastando batería, o ahorrar energía y arriesgar dosis.
##   dust      Polvo electrostático en los paneles (problema real de Apollo): rinden
##             menos hasta que alguien va a limpiarlos.
##   leak      Micrometeorito perfora un módulo: se escapa aire. Decisión: gastar
##             hierro y parchar ya, o ir en persona mientras se pierde oxígeno.
##   blackout  Corte de comunicaciones con la Tierra: no se pueden pedir suministros.
##   impact    Destello de impacto (NASA vigila estos destellos en la Luna): cráter
##             nuevo con muestras frescas, marcado en el mapa.
##   quake     Sismo lunar superficial (registrados por los sismómetros de Apollo):
##             puede abrir una fuga en un módulo.
##   science   La Tierra pide una muestra geológica a cambio de datos científicos.
## Intensidades, costos y tiempos son VALORES DE JUEGO; los fenómenos son reales.

const SAVE_ID := "event_director"
const EVENTS := {
	&"flare": {"weight": 2.0, "cooldown": 600.0},
	&"dust": {"weight": 3.0, "cooldown": 300.0},
	&"leak": {"weight": 2.0, "cooldown": 420.0},
	&"blackout": {"weight": 2.0, "cooldown": 420.0},
	&"impact": {"weight": 2.0, "cooldown": 360.0},
	&"quake": {"weight": 1.2, "cooldown": 600.0},
	&"science": {"weight": 2.0, "cooldown": 300.0},
}
const LEAK_O2_PER_S := 0.01 # kg de O₂ por segundo real (valor de juego)
const FLARE_SHIELD_KWH := 4.0
const BLACKOUT_S := 150.0

var next_in: float = 270.0
var cooldowns: Dictionary = {}
var leak_module: String = ""
var blackout_left: float = 0.0
var science_active: bool = false
var impacts: Array = [] # [[x, y, z], ...]

var _session: GameSession
var _rng := RandomNumberGenerator.new()
var _flares: Array = []
var _dusty: Array[Structure] = []
var _repair_point: Interactable
var _shake_left := 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(&"session_ui")
	add_to_group(&"event_director")
	_rng.randomize()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/science/donki_flares.json"))
	if d is Dictionary:
		_flares = (d as Dictionary).get("flares", [])
	EventBus.resource_collected.connect(_on_collected)


func bind_session(session: GameSession) -> void:
	_session = session
	next_in = _rng.randf_range(240.0, 330.0)
	if GameState.is_unlocked(&"evaluator_mode"):
		next_in = 90.0


func _process(delta: float) -> void:
	if _session == null or get_tree().paused or not _session.player.input_enabled:
		return
	for k: StringName in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - delta
	if leak_module != "":
		var net := _net()
		if net:
			net.take_oxygen(LEAK_O2_PER_S * delta)
	if blackout_left > 0.0:
		blackout_left -= delta
		if blackout_left <= 0.0:
			RadioPanel.say("blackout_end")
	if _shake_left > 0.0:
		_shake_left -= delta
		var cam := _session.player.camera_rig.get_camera()
		var amp := 0.08 * clampf(_shake_left / 2.0, 0.0, 1.0)
		cam.h_offset = _rng.randf_range(-amp, amp)
		cam.v_offset = _rng.randf_range(-amp, amp)
		if _shake_left <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
	next_in -= delta
	if next_in <= 0.0:
		next_in = _rng.randf_range(150.0, 300.0)
		_trigger_random()


func _trigger_random() -> void:
	var rad := get_tree().get_first_node_in_group(&"radiation_system") as RadiationSystem
	var busy_rad := rad != null and rad.phase in [&"warning", &"storm"]
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	for k: StringName in EVENTS:
		if float(cooldowns.get(k, 0.0)) > 0.0:
			continue
		if (k == &"flare" and busy_rad) or (k == &"leak" and leak_module != "") or (k == &"blackout" and blackout_left > 0.0) \
				or (k == &"science" and science_active) or (k == &"dust" and not _dusty.is_empty()):
			continue
		pool.append(k)
		weights.append(float(EVENTS[k].weight))
	if pool.is_empty():
		return
	var total := 0.0
	for w in weights:
		total += w
	var r := _rng.randf() * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			trigger(pool[i])
			return


## Dispara un suceso concreto (también lo usan las misiones y los tests).
func trigger(kind: StringName) -> void:
	cooldowns[kind] = float(EVENTS.get(kind, {}).get("cooldown", 300.0))
	match kind:
		&"flare", &"flare_forecast": _forecast()
		&"dust": _dust()
		&"leak": _leak()
		&"blackout": _blackout()
		&"impact": _impact()
		&"quake": _quake()
		&"science": _science()


# --- Sucesos ----------------------------------------------------------------------

func _es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _net() -> BaseNetwork:
	return get_tree().get_first_node_in_group(&"base_network") as BaseNetwork


func _colony() -> Colony:
	return get_tree().get_first_node_in_group(&"colony") as Colony


## Preaviso: los satélites que vigilan el Sol avisan antes de la fulguración.
func _forecast() -> void:
	RadioPanel.say("flare_forecast")
	EventBus.notification_requested.emit(tr("EV_FORECAST_NOTE"), &"warning")
	get_tree().create_timer(45.0, false).timeout.connect(_flare)


func _flare() -> void:
	var rad := get_tree().get_first_node_in_group(&"radiation_system") as RadiationSystem
	if rad == null:
		return
	var f: Dictionary = _flares[_rng.randi() % _flares.size()] if not _flares.is_empty() else {}
	RadioPanel.say("flare_alert")
	var net := _net()
	var can_pay := net != null and net.stored_kwh >= FLARE_SHIELD_KWH
	var src := "NASA DONKI (%s): %s %s" % [tr("SCI_ARCHIVED"), String(f.get("class", "X")), String(f.get("date", ""))]
	var note := String(f.get("note_es" if _es() else "note_en", ""))
	DecisionDialog.ask(tr("EV_FLARE_TITLE") % String(f.get("class", "X")), tr("EV_FLARE_BODY") + "\n" + note, [
		{"label": tr("EV_FLARE_A"), "gain": tr("EV_FLARE_A_GAIN"), "cost": tr("EV_FLARE_A_COST") % FLARE_SHIELD_KWH, "enabled": can_pay,
			"call": func() -> void:
				net.stored_kwh -= FLARE_SHIELD_KWH
				rad.shield_boost = 0.5
				rad.start_event(true, f)},
		{"label": tr("EV_FLARE_B"), "gain": tr("EV_FLARE_B_GAIN"), "cost": tr("EV_FLARE_B_COST"),
			"call": func() -> void:
				rad.shield_boost = 1.0
				rad.start_event(true, f)},
	], src)


func _dust() -> void:
	var panels: Array[Structure] = []
	for s in get_tree().get_nodes_in_group(&"structure"):
		var st := s as Structure
		if st.def and st.def.role == BuildableDef.Role.SOLAR:
			panels.append(st)
	if panels.is_empty():
		return
	panels.shuffle()
	for i in mini(2, panels.size()):
		panels[i].set_dusty(true)
		_dusty.append(panels[i])
		panels[i].dust_cleaned.connect(_on_panel_clean.bind(panels[i]), CONNECT_ONE_SHOT)
	RadioPanel.say("dust")
	EventBus.notification_requested.emit(tr("EV_DUST_NOTE"), &"warning")


func _on_panel_clean(p: Structure) -> void:
	_dusty.erase(p)
	if _dusty.is_empty():
		RadioPanel.say("dust_clean")


func _leak() -> void:
	var colony := _colony()
	if colony == null:
		return
	var mods: Array = colony.modules.keys().filter(func(k: String) -> bool:
		return colony.modules[k] is ColonyModule and not (colony.modules[k] as ColonyModule).interior_volumes.is_empty())
	if mods.is_empty():
		return
	var key: String = mods[_rng.randi() % mods.size()]
	var m := colony.modules[key] as ColonyModule
	leak_module = key
	RadioPanel.say("leak")
	var inv := _session.player.inventory
	DecisionDialog.ask(tr("EV_LEAK_TITLE") % m.def.get_display_name(), tr("EV_LEAK_BODY"), [
		{"label": tr("EV_LEAK_A"), "gain": tr("EV_LEAK_A_GAIN"), "cost": tr("EV_LEAK_A_COST"), "enabled": inv.has(&"iron", 2),
			"call": func() -> void:
				inv.remove(&"iron", 2)
				_fix_leak()},
		{"label": tr("EV_LEAK_B"), "gain": tr("EV_LEAK_B_GAIN"), "cost": tr("EV_LEAK_B_COST") % (LEAK_O2_PER_S * 60.0),
			"call": func() -> void: _place_repair_point(m)},
	], tr("EV_LEAK_SOURCE"))


func _place_repair_point(m: ColonyModule) -> void:
	if is_instance_valid(_repair_point):
		_repair_point.queue_free()
	var it := Interactable.new()
	it.action_key = "ACTION_REPAIR"
	it.display_name = tr("EV_LEAK_POINT")
	it.max_distance = 2.6
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.8
	cs.shape = sp
	it.add_child(cs)
	m.add_child(it)
	it.global_position = m.spawn_point() + Vector3(0, 1.0, 0)
	_repair_point = it
	it.interacted.connect(func(by: Node) -> void:
		var p := by as Player
		if p == null:
			return
		if not p.inventory.has(&"iron", 1):
			EventBus.notification_requested.emit(tr("EV_LEAK_NEED_IRON"), &"warning")
			return
		p.perform_action(&"Interact", func() -> void:
			p.inventory.remove(&"iron", 1)
			_fix_leak(), 0.8))


func _fix_leak() -> void:
	leak_module = ""
	EventBus.player_action.emit(&"repair")
	if is_instance_valid(_repair_point):
		_repair_point.queue_free()
	RadioPanel.say("leak_fixed")


func _blackout() -> void:
	blackout_left = BLACKOUT_S
	RadioPanel.say("blackout")


func is_comms_down() -> bool:
	return blackout_left > 0.0


func _impact() -> void:
	var field := get_tree().get_first_node_in_group(&"resource_field") as ResourceField
	var region := _session.region as MoonRegion
	if field == null or region == null:
		return
	var center := Vector3.INF
	for _try in 40:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(110.0, 260.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if field.is_free_spot(p):
			center = p
			break
	if center == Vector3.INF:
		return
	center = region.snap_to_ground(center)
	_spawn_impact(center, true)
	impacts.append([center.x, center.y, center.z])
	for i in 3:
		var a := TAU * i / 3.0 + _rng.randf()
		field.spawn_extra(&"geo_sample", center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 6.0))
	RadioPanel.say("impact")


func _spawn_impact(center: Vector3, flash: bool) -> void:
	var site := ImpactSite.new()
	_session.region.add_child(site)
	site.global_position = center
	if flash:
		site.flash()


func _quake() -> void:
	_shake_left = 6.0
	RadioPanel.say("quake")
	if leak_module == "" and _rng.randf() < 0.4:
		get_tree().create_timer(9.0).timeout.connect(func() -> void:
			if leak_module == "":
				_leak())


func _science() -> void:
	science_active = true
	RadioPanel.say("science")
	EventBus.notification_requested.emit(tr("EV_SCIENCE_NOTE"), &"info")


func _on_collected(id: StringName, _amount: int) -> void:
	if science_active and id == &"geo_sample":
		science_active = false
		var c := _colony()
		if c:
			c.add_research(6)
		RadioPanel.say("science_done")


# --- Saveable ---------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"next_in": next_in, "cooldowns": cooldowns.duplicate(), "leak": leak_module,
		"blackout": blackout_left, "science": science_active, "impacts": impacts.duplicate(true)}


func load_state(d: Dictionary) -> void:
	next_in = float(d.get("next_in", next_in))
	cooldowns = (d.get("cooldowns", {}) as Dictionary).duplicate()
	blackout_left = float(d.get("blackout", 0.0))
	science_active = bool(d.get("science", false))
	impacts = (d.get("impacts", []) as Array).duplicate(true)
	for p: Array in impacts:
		_spawn_impact(Vector3(float(p[0]), float(p[1]), float(p[2])), false)
	leak_module = String(d.get("leak", ""))
	var colony := _colony()
	if leak_module != "" and colony and colony.modules.has(leak_module):
		_place_repair_point(colony.modules[leak_module] as ColonyModule)
