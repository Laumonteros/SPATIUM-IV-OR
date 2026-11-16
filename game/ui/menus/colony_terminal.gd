class_name ColonyTerminal
extends CanvasLayer
## Pantalla de las terminales de la colonia. Un modo por función:
##   rocks        fichas técnicas de rocas (composición, utilidad, rareza, fuente)
##   telescope_N  observatorio N: elegir objetivo y calibrar el seguimiento (minijuego)
##   fabrication  Taller: kits, equipamiento y mejoras
##   save         Comando: guardar la partida
##   supplies     Comando: pedidos a la Tierra
##   storage      almacén refrigerado del domo
##   status / command_status  estado real de toda la colonia
## Pausa el juego mientras está abierta; Esc o "Cerrar" la cierran.

var colony: Colony
var module: Node
var player: Player
var mode: StringName = &""

var _root: Control
var _title: Label
var _subtitle: Label
var _list: VBoxContainer
var _detail: VBoxContainer
var _actions: HBoxContainer
var _selected: String = ""
var _refresh_acc := 0.0
var _tracker: TelescopeTracker


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SpatiumTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(SpatiumTheme.CYAN, Color(0.02, 0.05, 0.08, 0.94)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1040, 620)
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -310
	panel.offset_bottom = 310
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	_title = SpatiumTheme.label("", 26, &"title", 700, SpatiumTheme.CYAN)
	vb.add_child(_title)
	_subtitle = SpatiumTheme.label("", 15, &"body", 450, SpatiumTheme.TEXT_DIM)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_subtitle)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(330, 0)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(ls)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	ls.add_child(_list)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(ds)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	ds.add_child(_detail)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	_actions.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(_actions)


func open(m: StringName, c: Colony, mod: Node, p: Player) -> void:
	mode = m
	colony = c
	module = mod
	player = p
	_selected = ""
	visible = true
	get_tree().paused = true
	if m == &"power":
		EventBus.player_action.emit(&"power_panel")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_render()


func close() -> void:
	if not visible:
		return
	visible = false
	if _tracker:
		_tracker.queue_free()
		_tracker = null
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _tracker:
			_tracker.queue_free()
			_tracker = null
			_render()
		else:
			close()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_acc -= delta
	if _refresh_acc <= 0.0 and mode in [&"status", &"command_status", &"fabrication", &"supplies", &"storage", &"power"] and _tracker == null:
		_refresh_acc = 1.0
		_render()


func _es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _clear() -> void:
	for n in [_list, _detail, _actions]:
		for c in (n as Node).get_children():
			c.queue_free()


func _button(text: String, cb: Callable, parent: Node, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _text(t: String, size := 16, color := SpatiumTheme.TEXT, parent: Node = null) -> Label:
	var l := SpatiumTheme.label(t, size, &"body", 450, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	(parent if parent else _detail).add_child(l)
	return l


func _science_tag(kind: String, source: String) -> void:
	var key: String = {"real": "SCIENCE_KIND_REAL", "adapted": "SCIENCE_KIND_ADAPTED"}.get(kind, "SCIENCE_KIND_GAMEPLAY")
	_text("%s · %s" % [tr(key), source], 13, SpatiumTheme.AMBER)


func _render() -> void:
	_clear()
	_button(tr("UI_CLOSE"), close, _actions)
	var research := tr("COLONY_RESEARCH_UNITS") % colony.research_points
	match mode:
		&"rocks":
			_title.text = tr("COLONY_ROCK_SHEETS")
			_subtitle.text = tr("COLONY_ROCKS_HELP") + "  ·  " + research
			_render_rocks()
		&"fabrication":
			_title.text = tr("COLONY_FAB_TERMINAL")
			_subtitle.text = tr("COLONY_FAB_HELP") + "  ·  " + research
			_render_fabrication()
		&"supplies":
			_title.text = tr("COLONY_CMD_SUPPLIES")
			_subtitle.text = tr("COLONY_SUPPLY_HELP") + "  ·  " + research
			_render_supplies()
		&"save":
			_title.text = tr("COLONY_CMD_SAVE")
			_subtitle.text = tr("COLONY_SAVE_HELP")
			_render_save()
		&"storage":
			_title.text = tr("COLONY_STORAGE_NAME")
			_subtitle.text = tr("COLONY_STORAGE_HELP")
			_render_storage()
		&"power":
			_title.text = tr("POWER_TITLE")
			_subtitle.text = tr("POWER_HELP")
			_render_power()
		&"status", &"command_status":
			_title.text = tr("COLONY_TERMINAL_STATUS")
			_subtitle.text = research
			_button(tr("POWER_TITLE"), func() -> void:
				mode = &"power"
				EventBus.player_action.emit(&"power_panel")
				_render(), _actions)
			_text(colony.colony_status_text(false), 17)
			_text(colony.cable_status_line(), 15, SpatiumTheme.TEXT_DIM)
		_:
			if String(mode).begins_with("telescope_"):
				_render_telescope(int(String(mode).get_slice("_", 1)))


# --- Reparto de energía -------------------------------------------------------------

const POWER_GROUPS := [
	["life", "POWER_LIFE", "POWER_LIFE_EFFECT", Color(0.62, 0.9, 1.0)],
	["food", "POWER_FOOD", "POWER_FOOD_EFFECT", Color(0.45, 0.86, 0.42)],
	["science", "POWER_SCIENCE", "POWER_SCIENCE_EFFECT", Color(0.36, 0.84, 0.86)],
	["comms", "POWER_COMMS", "POWER_COMMS_EFFECT", Color(1.0, 0.4, 0.38)],
]


func _render_power() -> void:
	var net := colony.network
	var demand := net.group_demand()
	var total := 0.0
	for k: String in demand:
		total += float(demand[k])
	var prod := net.production_kw
	# balance y autonomía de las baterías
	var bal := prod - total
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	_list.add_child(head)
	head.add_child(SpatiumTheme.label(tr("POWER_PROD") % prod, 18, &"mono", 700, Color(1.0, 0.84, 0.26)))
	head.add_child(SpatiumTheme.label(tr("POWER_USE") % total, 18, &"mono", 700, SpatiumTheme.TEXT))
	var hours := net.stored_kwh / maxf(-bal, 0.001) if bal < 0.0 else INF
	var verdict := tr("POWER_CHARGING") % bal if bal >= 0.0 else tr("POWER_DRAINING") % [-bal, hours]
	_text(verdict, 17, Color(0.55, 1.0, 0.6) if bal >= 0.0 else (SpatiumTheme.AMBER if hours > 6.0 else SpatiumTheme.RED))
	# barra apilada: cuánto usa cada grupo frente a lo que se produce
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(760, 26)
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		var px := w / maxf(maxf(prod, total), 0.1)
		bar.draw_rect(Rect2(0, 0, w, 26), Color(1, 1, 1, 0.06))
		var x := 0.0
		for g: Array in POWER_GROUPS:
			var v := float(demand.get(g[0], 0.0)) * px
			bar.draw_rect(Rect2(x, 4, v, 18), g[3])
			x += v
		bar.draw_line(Vector2(prod * px, 0), Vector2(prod * px, 26), Color(1.0, 0.84, 0.26), 3.0))
	_list.add_child(bar)
	# un renglón por grupo: 100 % / 50 % / apagado
	for g: Array in POWER_GROUPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var dot := ColorRect.new()
		dot.color = g[3]
		dot.custom_minimum_size = Vector2(10, 34)
		row.add_child(dot)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(SpatiumTheme.label("%s  ·  %.1f kW" % [tr(g[1]), float(demand.get(g[0], 0.0))], 17, &"title", 600, g[3]))
		var eff := SpatiumTheme.label(tr(g[2]), 13, &"body", 450, SpatiumTheme.TEXT_DIM)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.custom_minimum_size.x = 420
		info.add_child(eff)
		var cur := float(net.throttles.get(g[0], 1.0))
		for opt: Array in [[1.0, "POWER_FULL"], [0.5, "POWER_HALF"], [0.0, "POWER_OFF"]]:
			var b := _button(tr(opt[1]), func() -> void:
				net.set_throttle(String(g[0]), float(opt[0]))
				_render(), row, g[0] == "life" and float(opt[0]) == 0.0)
			if is_equal_approx(cur, float(opt[0])):
				b.add_theme_color_override("font_color", SpatiumTheme.ORANGE)
				b.text = "● " + b.text
	_science_tag("adapted", tr("POWER_SOURCE"))


# --- Fichas de rocas --------------------------------------------------------------

func _render_rocks() -> void:
	for s: Dictionary in colony.rock_sheets:
		var id := String(s.id)
		var open_ := colony.unlocked_sheets.has(id)
		var nm := colony._loc(s, "name") if open_ else "?????"
		var b := _button(("■ " if open_ else "□ ") + nm, func() -> void:
			_selected = id
			_render(), _list)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if _selected == "" and open_:
			_selected = id
	if _selected == "":
		_text(tr("COLONY_ROCKS_EMPTY"), 17, SpatiumTheme.TEXT_DIM)
		return
	var s := colony.get_sheet(_selected)
	_text(colony._loc(s, "name"), 24, SpatiumTheme.CYAN)
	_text(tr("COLONY_RARITY") + " " + "★".repeat(int(s.get("rarity", 1))) + "☆".repeat(5 - int(s.get("rarity", 1))), 16, SpatiumTheme.AMBER)
	_text(tr("COLONY_COMPOSITION"), 17, SpatiumTheme.TEXT)
	for comp: Array in s.get("composition", []):
		var row := HBoxContainer.new()
		var l := SpatiumTheme.label("%s" % comp[0], 15)
		l.custom_minimum_size.x = 210
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.value = float(comp[1])
		bar.custom_minimum_size = Vector2(260, 16)
		bar.show_percentage = false
		row.add_child(bar)
		row.add_child(SpatiumTheme.label(" %.1f %%" % float(comp[1]), 15, &"mono"))
		_detail.add_child(row)
	_text(tr("COLONY_UTILITY"), 17)
	_text(colony._loc(s, "utility"), 15, SpatiumTheme.TEXT_DIM)
	_text(tr("COLONY_FACTS"), 17)
	_text(colony._loc(s, "facts"), 15, SpatiumTheme.TEXT_DIM)
	var sci: Dictionary = s.get("science", {})
	_science_tag(String(sci.get("kind", "gameplay")), String(sci.get("source", "")))


# --- Observatorios -------------------------------------------------------------------

func _render_telescope(k: int) -> void:
	var obs: Dictionary = colony.telescopes[k] if k < colony.telescopes.size() else {}
	_title.text = tr("COLONY_OBSERVATORY") % (k + 1) + " · " + tr(String(obs.get("name_key", "")))
	_subtitle.text = tr("COLONY_TELESCOPE_HELP")
	for t: Dictionary in obs.get("targets", []):
		var done := colony.observations.has(String(t.id))
		var tid := String(t.id)
		_button(("✓ " if done else "· ") + colony._loc(t, "name"), func() -> void:
			_selected = tid
			_render(), _list).alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _selected == "":
		_text(tr("COLONY_TELESCOPE_PICK"), 17, SpatiumTheme.TEXT_DIM)
		return
	var target: Dictionary = {}
	for t: Dictionary in obs.get("targets", []):
		if String(t.id) == _selected:
			target = t
	_text(colony._loc(target, "name"), 22, SpatiumTheme.CYAN)
	_text("az %d° · el %d° · %s %.1f s" % [int(target.az_deg), int(target.el_deg), tr("COLONY_TRACK_HOLD"), float(target.hold_s)], 15, SpatiumTheme.TEXT_DIM)
	if colony.observations.has(_selected):
		_text(colony._loc(target, "fact"), 16)
		_science_tag(String(target.get("kind", "real")), String(target.get("source", "")))
	_button(tr("COLONY_TRACK_START"), func() -> void: _start_tracking(k, target), _actions)


func _start_tracking(k: int, target: Dictionary) -> void:
	_clear()
	_button(tr("UI_CLOSE"), close, _actions)
	_tracker = TelescopeTracker.new()
	_tracker.setup(target, Color(String(target.get("color", "#FFFFFF"))))
	_tracker.custom_minimum_size = Vector2(620, 360)
	_detail.add_child(_tracker)
	var status := _text(tr("COLONY_TRACK_RUNNING"), 15, SpatiumTheme.TEXT_DIM)
	_tracker.progress.connect(func(hold: float, total: float, time_left: float) -> void:
		status.text = tr("COLONY_TRACK_STATUS") % [hold, total, time_left])
	_tracker.finished.connect(func(ok: bool) -> void:
		_tracker = null
		if ok:
			colony.complete_observation(k, target)
		EventBus.notification_requested.emit(tr("COLONY_TRACK_OK") if ok else tr("COLONY_TRACK_FAIL"), &"info" if ok else &"warning")
		_selected = String(target.id)
		_render())


# --- Taller -----------------------------------------------------------------------

func _render_fabrication() -> void:
	var kinds := [["kit", "COLONY_FAB_KITS"], ["equipment", "COLONY_FAB_EQUIPMENT"], ["upgrade", "COLONY_FAB_UPGRADES"], ["energy", "FAB_ENERGY"], ["propellant", "FAB_PROPELLANT"]]
	for kd: Array in kinds:
		_list.add_child(SpatiumTheme.label(tr(String(kd[1])), 15, &"title", 600, SpatiumTheme.AMBER))
		for r: Dictionary in colony.recipes:
			if String(r.kind) != String(kd[0]):
				continue
			var rid := String(r.id)
			var done := String(r.kind) in ["upgrade", "equipment"] and colony.upgrades.has(rid)
			_button(("✓ " if done else "") + colony._loc(r, "name"), func() -> void:
				_selected = rid
				_render(), _list).alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text(colony.fabrication_screen(), 15, SpatiumTheme.TEXT_DIM)
	if _selected == "":
		return
	var r := colony.get_recipe(_selected)
	_text(colony._loc(r, "name"), 22, SpatiumTheme.CYAN)
	_text(colony._loc(r, "desc"), 16)
	_text(tr("COLONY_FAB_COST") % [colony.cost_text(r), int(r.seconds)], 15, SpatiumTheme.TEXT_DIM)
	_science_tag("gameplay", tr("COLONY_FAB_SOURCE"))
	var why := colony.fabrication_blocker(r, player.inventory)
	if why != "":
		_text(why, 15, SpatiumTheme.AMBER)
	var rid := _selected
	_button(tr("COLONY_FAB_START"), func() -> void:
		colony.start_fabrication(rid, player.inventory)
		_render(), _actions, why != "")


# --- Comando --------------------------------------------------------------------------

func _render_supplies() -> void:
	# nave de regreso: tanques del módulo Ariel
	_text(tr("ROCKET_TITLE"), 20, SpatiumTheme.ORANGE)
	var tanks := Control.new()
	tanks.custom_minimum_size = Vector2(420, 34)
	var filled := colony.propellant
	tanks.draw.connect(func() -> void:
		for k in Colony.PROPELLANT_NEEDED:
			var r := Rect2(k * 82, 2, 74, 30)
			tanks.draw_rect(r, Color(0.45, 0.85, 1.0, 0.85) if k < filled else Color(1, 1, 1, 0.08))
			tanks.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0))
	_list.add_child(tanks)
	_text(tr("ROCKET_STATUS") % [filled, Colony.PROPELLANT_NEEDED], 14, SpatiumTheme.TEXT_DIM)
	_button(tr("ROCKET_LAUNCH"), func() -> void:
		close()
		var s := get_tree().get_first_node_in_group(&"game_session") as GameSession
		if s:
			ReturnLaunch.start(s), _list, filled < Colony.PROPELLANT_NEEDED)
	_text(tr("COLONY_CMD_SUPPLIES"), 20, SpatiumTheme.CYAN)
	for p: Dictionary in colony.supplies.get("packages", []):
		var pid := String(p.id)
		_button(colony._loc(p, "name"), func() -> void:
			_selected = pid
			_render(), _list).alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text(colony.supply_screen(), 16, SpatiumTheme.TEXT_DIM)
	if _selected == "":
		return
	var p := colony.get_package(_selected)
	_text(colony._loc(p, "name"), 22, SpatiumTheme.CYAN)
	_text(colony._loc(p, "desc"), 16)
	_text(tr("COLONY_SUPPLY_COST") % [int(p.research), int(p.delivery_s)], 15, SpatiumTheme.TEXT_DIM)
	var why := colony.order_blocker(p)
	if why != "":
		_text(why, 15, SpatiumTheme.AMBER)
	var pid := _selected
	_button(tr("COLONY_SUPPLY_ORDER"), func() -> void:
		colony.order_supply(pid)
		_render(), _actions, why != "")


func _render_save() -> void:
	_text(colony.save_screen(), 17)
	for s: Dictionary in SaveManager.list_slots():
		_list.add_child(SpatiumTheme.label("%s · %s" % [String(s.slot), String(s.saved_at).replace("T", " ").left(16)], 14, &"mono", 400, SpatiumTheme.TEXT_DIM))
	_button(tr("COLONY_SAVE_NOW"), func() -> void:
		var err := SaveManager.save_slot("comando")
		EventBus.notification_requested.emit(tr("COLONY_SAVED") if err == OK else tr("COLONY_SAVE_FAILED"), &"info" if err == OK else &"warning")
		_render(), _actions)


func _render_storage() -> void:
	var dome := colony.get_biodome()
	if dome == null:
		return
	_text(tr("COLONY_STORAGE_STATE") % [dome.storage, Biodome.STORAGE_CAPACITY, dome.harvested_total, colony.network.rations], 17)
	for i in dome.beds.size():
		_list.add_child(SpatiumTheme.label(dome.bed_report(i), 13, &"body", 400, SpatiumTheme.TEXT_DIM))
		(_list.get_child(_list.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var crop_sci: Dictionary = (dome.crops.values()[0] as Dictionary).get("science", {}) if not dome.crops.is_empty() else {}
	if not crop_sci.is_empty():
		_text(String(crop_sci.get("es" if _es() else "en", "")), 14, SpatiumTheme.TEXT_DIM)
		_science_tag("adapted", String(crop_sci.get("source", "")))
	_button(tr("COLONY_STORAGE_TAKE5"), func() -> void:
		dome.transfer_to_base(5)
		_render(), _actions, dome.storage <= 0)
	_button(tr("COLONY_STORAGE_TAKEALL"), func() -> void:
		dome.transfer_to_base(dome.storage)
		_render(), _actions, dome.storage <= 0)
