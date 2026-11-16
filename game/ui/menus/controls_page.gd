class_name ControlsPage
extends VBoxContainer
## Página "Teclado y mouse": teclado visual con la función de cada tecla,
## diagrama del mouse y lista de acciones reasignables ("Cambiar").

signal back_requested

const ACTIONS := [
	[&"move_forward", "Avanzar", "Forward"], [&"move_back", "Retroceder", "Back"],
	[&"move_left", "Izquierda", "Left"], [&"move_right", "Derecha", "Right"],
	[&"jump", "Saltar", "Jump"], [&"sprint", "Correr", "Run"], [&"crouch", "Agacharse", "Crouch"],
	[&"interact", "Usar / recolectar", "Use / collect"], [&"scan", "Escáner", "Scanner"],
	[&"flashlight", "Luces del casco", "Helmet lights"],
	[&"build_mode", "Construir", "Build"], [&"build_rotate_left", "Rotar (izq.)", "Rotate (left)"],
	[&"build_rotate_right", "Rotar (der.)", "Rotate (right)"], [&"map", "Mapa", "Map"],
	[&"encyclopedia", "Enciclopedia", "Encyclopedia"], [&"inventory", "Inventario", "Inventory"],
	[&"ui_quick_save", "Guardado rápido", "Quick save"], [&"ui_quick_load", "Carga rápida", "Quick load"],
]
const ROWS := [
	["Escape", "", "1", "2", "3", "4", "5", "", "F5", "F9"],
	["Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["", "A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["Shift", "Z", "X", "C", "V", "B", "N", "M"],
	["", "", "", "Space", "", "", "", "Up"],
	["", "", "", "", "", "", "Left", "Down", "Right"],
]

var _waiting_for: StringName = &""
var _keyboard: Control
var _list: VBoxContainer
var _status: Label


func _es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var title := SpatiumTheme.label("TECLADO Y MOUSE" if _es() else "KEYBOARD & MOUSE", 26, &"title", 700, SpatiumTheme.ORANGE)
	add_child(title)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	add_child(hb)
	_keyboard = Control.new()
	_keyboard.custom_minimum_size = Vector2(900, 400)
	_keyboard.draw.connect(_draw_keyboard)
	hb.add_child(_keyboard)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 420
	hb.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_status = SpatiumTheme.label("", 15, &"body", 600, SpatiumTheme.AMBER)
	right.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	var reset := Button.new()
	reset.text = "Restablecer" if _es() else "Reset"
	reset.pressed.connect(func() -> void:
		InputConfig.reset_to_defaults()
		_refresh())
	buttons.add_child(reset)
	var back := Button.new()
	back.text = tr("PAUSE_BACK")
	back.pressed.connect(func() -> void: back_requested.emit())
	buttons.add_child(back)
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for a: Array in ACTIONS:
		var row := HBoxContainer.new()
		var name_l := SpatiumTheme.label(a[1] if _es() else a[2], 15)
		name_l.custom_minimum_size.x = 170
		row.add_child(name_l)
		var key_l := SpatiumTheme.label(InputConfig.get_key_label(a[0]), 15, &"mono", 700, SpatiumTheme.CYAN)
		key_l.custom_minimum_size.x = 110
		row.add_child(key_l)
		var b := Button.new()
		b.text = "Cambiar" if _es() else "Change"
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_begin_rebind.bind(a[0], a[1] if _es() else a[2]))
		row.add_child(b)
		_list.add_child(row)
	_keyboard.queue_redraw()


func _begin_rebind(action: StringName, label: String) -> void:
	_waiting_for = action
	_status.text = ("Presioná la nueva tecla para «%s» (Esc cancela)" if _es() else "Press the new key for “%s” (Esc cancels)") % label


func _input(event: InputEvent) -> void:
	if _waiting_for == &"" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var k := (event as InputEventKey).physical_keycode
		if k != KEY_ESCAPE:
			InputConfig.rebind_key(_waiting_for, k)
		_waiting_for = &""
		_status.text = ""
		_refresh()


## Mapa tecla -> acciones (texto corto) para dibujar en las teclas.
func _key_actions() -> Dictionary:
	var out := {}
	for a: Array in ACTIONS:
		for ev in InputMap.action_get_events(a[0]):
			if ev is InputEventKey:
				var name := OS.get_keycode_string((ev as InputEventKey).physical_keycode)
				var short: String = (a[1] if _es() else a[2]).split(" ")[0]
				out[name] = (out.get(name, "") + ("/" if out.has(name) else "") + short)
	return out


func _draw_keyboard() -> void:
	var c := _keyboard
	var acts := _key_actions()
	var font := SpatiumTheme.font(&"mono", 600)
	var font_b := SpatiumTheme.font(&"body", 500)
	var unit := 58.0
	var gap := 6.0
	for r in ROWS.size():
		var x := (r % 3) * 14.0
		for key: String in ROWS[r]:
			var w := unit * (2.6 if key == "Space" else (1.5 if key in ["Shift", "Tab", "Escape"] else 1.0))
			if key == "":
				x += unit * 0.5 + gap
				continue
			var rect := Rect2(x, r * (unit + gap), w, unit)
			var bound := acts.has(key)
			c.draw_rect(rect, Color(1, 0.54, 0.24, 0.85) if bound else Color(1, 1, 1, 0.08))
			c.draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.0)
			var label: String = {"Escape": "Esc", "Space": "Espacio" if _es() else "Space", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→"}.get(key, key)
			c.draw_string(font, rect.position + Vector2(6, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.05, 0.06) if bound else SpatiumTheme.TEXT)
			if bound:
				c.draw_string(font_b, rect.position + Vector2(4, unit - 8), String(acts[key]), HORIZONTAL_ALIGNMENT_LEFT, w - 6, 10, Color(0.05, 0.05, 0.06))
			x += w + gap
	# Mouse
	var m := Rect2(770, 20, 96, 150)
	c.draw_rect(m, Color(1, 1, 1, 0.08))
	c.draw_rect(m, Color(1, 1, 1, 0.3), false, 1.5)
	c.draw_line(Vector2(m.position.x + 48, m.position.y), Vector2(m.position.x + 48, m.position.y + 60), Color(1, 1, 1, 0.3), 1.5)
	c.draw_line(Vector2(m.position.x, m.position.y + 60), Vector2(m.end.x, m.position.y + 60), Color(1, 1, 1, 0.3), 1.5)
	c.draw_rect(Rect2(m.position + Vector2(2, 2), Vector2(44, 56)), Color(1, 0.54, 0.24, 0.85))
	c.draw_rect(Rect2(m.position + Vector2(50, 2), Vector2(44, 56)), Color(0.31, 0.82, 0.91, 0.6))
	var es := _es()
	c.draw_string(font_b, Vector2(740, 200), "Clic izq.: usar / colocar" if es else "Left: use / place", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpatiumTheme.TEXT)
	c.draw_string(font_b, Vector2(740, 218), "Clic der.: cancelar" if es else "Right: cancel", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpatiumTheme.TEXT)
	c.draw_string(font_b, Vector2(740, 236), "Rueda: elegir estructura" if es else "Wheel: pick structure", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpatiumTheme.TEXT)
	c.draw_string(font_b, Vector2(740, 254), "Mover: cámara" if es else "Move: camera", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpatiumTheme.TEXT)
