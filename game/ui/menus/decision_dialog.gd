class_name DecisionDialog
extends CanvasLayer
## Decisión de misión: el juego se pausa y se elige entre opciones que SIEMPRE
## tienen un costo (energía, oxígeno, materiales, tiempo o riesgo). Cada opción
## muestra qué se gana y qué se pierde; abajo, el dato real que lo explica.
##
## DecisionDialog.ask(titulo, cuerpo, [{"label":..., "cost":..., "gain":..., "call": Callable, "enabled": bool}], fuente)

var _root: Control
var _header := ""


static func ask(title: String, body: String, options: Array, source := "", header := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var d := DecisionDialog.new()
	tree.root.add_child(d)
	d._header = header
	d._show(title, body, options, source)


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS


func _show(title: String, body: String, options: Array, source: String) -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SpatiumTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.01, 0.03, 0.7)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(SpatiumTheme.AMBER, Color(0.03, 0.05, 0.08, 0.95)))
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(SpatiumTheme.label(_header if _header != "" else tr("DECISION_HEADER"), 13, &"mono", 600, SpatiumTheme.AMBER))
	vb.add_child(SpatiumTheme.label(title, 26, &"title", 700))
	var b := SpatiumTheme.label(body, 16)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 720
	vb.add_child(b)
	var hb := GridContainer.new()
	hb.columns = 2 if options.size() <= 2 or options.size() == 4 else 3
	hb.add_theme_constant_override("h_separation", 14)
	hb.add_theme_constant_override("v_separation", 14)
	vb.add_child(hb)
	var first: Button = null
	for o: Dictionary in options:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 6)
		hb.add_child(card)
		var btn := Button.new()
		btn.text = String(o.get("label", ""))
		btn.disabled = not bool(o.get("enabled", true))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(340 if hb.columns == 2 else 228, 0)
		var cb: Callable = o.get("call", Callable())
		btn.pressed.connect(func() -> void:
			_close()
			if cb.is_valid():
				cb.call())
		card.add_child(btn)
		if first == null and not btn.disabled:
			first = btn
		if o.has("gain"):
			var g := SpatiumTheme.label("▲ " + String(o.gain), 14, &"body", 500, Color(0.55, 1.0, 0.6))
			g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(g)
		if o.has("cost"):
			var c := SpatiumTheme.label("▼ " + String(o.cost), 14, &"body", 500, Color(1.0, 0.6, 0.45))
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(c)
	if source != "":
		var s := SpatiumTheme.label(source, 12, &"mono", 500, SpatiumTheme.TEXT_DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(s)
	if first:
		first.grab_focus.call_deferred()


func _close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
