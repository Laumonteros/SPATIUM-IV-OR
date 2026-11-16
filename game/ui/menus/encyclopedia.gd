class_name Encyclopedia
extends CanvasLayer
## Enciclopedia espacial (J): conceptos científicos + fichas de recursos y estructuras.
## Cada ficha muestra su tipo de dato (real / adaptado / valor de juego) y su fuente.

const CONCEPTS := "res://data/encyclopedia/concepts.json"

var _session: GameSession
var _list: VBoxContainer
var _title: Label
var _kind: Label
var _body: Label
var _source: Label
var _entries: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(&"session_ui")
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func bind_session(session: GameSession) -> void:
	_session = session
	_load_entries()
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null:
		return
	if event.is_action_pressed(&"encyclopedia"):
		get_viewport().set_input_as_handled()
		_toggle(not visible)
	elif visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_toggle(false)


func _toggle(on: bool) -> void:
	if on == visible:
		return
	if on and get_tree().paused:
		return # no abrir encima del menú de pausa
	visible = on
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _load_entries() -> void:
	_entries.clear()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONCEPTS))
	if data is Dictionary:
		for e: Dictionary in data.get("entries", []):
			var loc := "es" if _es() else "en"
			_entries.append({"title": e.title.get(loc, e.title.es), "text": e.text.get(loc, e.text.es),
				"kind": String(e.kind), "source": String(e.source)})
	for d: GameDef in DataRegistry.get_all_of(ItemDef):
		var it := d as ItemDef
		var txt := "%s\n\n%s: %s\n%s: %s" % [it.get_description(),
			"Utilidad" if _es() else "Use", tr(it.utility_key), "Dónde" if _es() else "Where", tr(it.location_key)]
		if it.science:
			txt += "\n\n" + it.science.notes
		_entries.append({"title": it.get_display_name(), "text": txt,
			"kind": ["REAL_DATA", "ADAPTED", "GAMEPLAY_VALUE"][it.science.kind] if it.science else "GAMEPLAY_VALUE",
			"source": it.science.source_name + ("  " + it.science.url if it.science.url != "" else "") if it.science else ""})
	for d: GameDef in DataRegistry.get_all_of(BuildableDef):
		var b := d as BuildableDef
		var txt := "%s\n\n%s" % [b.get_description(), tr(b.function_key)]
		if b.cost.size() > 0:
			txt += "\n%s: %s" % ["Costo" if _es() else "Cost", b.cost_text()]
		_entries.append({"title": b.get_display_name(), "text": txt, "kind": "GAMEPLAY_VALUE",
			"source": "Diseño de juego inspirado en conceptos de hábitats lunares" if _es() else "Game design inspired by lunar habitat concepts"})


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = SpatiumTheme.get_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.01, 0.03, 0.82)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 80
	panel.offset_bottom = -80
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var head := SpatiumTheme.label(("ENCICLOPEDIA ESPACIAL" if _es() else "SPACE ENCYCLOPEDIA") + "   ·   J / Esc", 26, &"title", 700, SpatiumTheme.ORANGE)
	vb.add_child(head)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	hb.add_child(right)
	_title = SpatiumTheme.label("", 30, &"title", 700)
	right.add_child(_title)
	_kind = SpatiumTheme.label("", 15, &"mono", 600, SpatiumTheme.CYAN)
	right.add_child(_kind)
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(body_scroll)
	_body = SpatiumTheme.label("", 19, &"body", 450)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size.x = 600
	body_scroll.add_child(_body)
	_source = SpatiumTheme.label("", 14, &"mono", 450, SpatiumTheme.TEXT_DIM)
	_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_source)
	for i in _entries.size():
		var b := Button.new()
		b.text = _entries[i].title
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.tooltip_text = _entries[i].title
		b.pressed.connect(_show.bind(i))
		_list.add_child(b)
	if _entries.size() > 0:
		_show(0)


func _show(i: int) -> void:
	var e := _entries[i]
	_title.text = e.title
	var kinds := {"REAL_DATA": "SCIENCE_KIND_REAL", "ADAPTED": "SCIENCE_KIND_ADAPTED", "GAMEPLAY_VALUE": "SCIENCE_KIND_GAMEPLAY"}
	_kind.text = "■ " + tr(kinds.get(e.kind, "SCIENCE_KIND_GAMEPLAY")).to_upper()
	_kind.add_theme_color_override("font_color", SpatiumTheme.CYAN if e.kind == "REAL_DATA" else (SpatiumTheme.AMBER if e.kind == "ADAPTED" else SpatiumTheme.TEXT_DIM))
	_body.text = e.text
	_source.text = ("%s: %s" % [tr("SCIENCE_SOURCE"), e.source]) if e.source != "" else ""
