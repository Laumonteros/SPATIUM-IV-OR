class_name ToolBar
extends Control
## Barra de herramientas del traje, abajo al centro (ranuras cuadradas).
##
##   1 Mano        clic izquierdo = agarrar/usar lo que está enfrente (como E)
##   2 Escáner     clic izquierdo = pulso de escaneo (también Q)
##   3 Binoculares mantener clic izquierdo o derecho = mirar lejos (sin mira ni bordes)
## Se cambia con 1-3 o con la rueda del mouse (cruceta izquierda/derecha en mando).
## En modo construcción la barra se atenúa: los números y la rueda eligen estructuras.

signal tool_changed(index: int)

const SLOT := 78.0
const GAP := 12.0
const TOOLS := [&"hand", &"scanner", &"binoculars"]
const NAME_KEYS := ["TOOL_HAND", "TOOL_SCANNER", "TOOL_BINOCULARS"]

var selected := 0
var _player: Player
var _distance_text := ""
var _dist_acc := 0.0
var _name_label: Label
var _show_name_t := 0.0


func bind(p: Player) -> void:
	_player = p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var w := SLOT * TOOLS.size() + GAP * (TOOLS.size() - 1)
	custom_minimum_size = Vector2(w, SLOT + 40)
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -(SLOT + 58)
	offset_bottom = -18
	_name_label = SpatiumTheme.label("", 16, &"title", 600, SpatiumTheme.TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, -6)
	_name_label.size = Vector2(w, 24)
	add_child(_name_label)
	_flash_name()


func current_tool() -> StringName:
	return TOOLS[selected]


func select(i: int) -> void:
	i = clampi(i, 0, TOOLS.size() - 1)
	if i == selected:
		return
	selected = i
	if _player:
		_player.binoculars_active = false
	_flash_name()
	tool_changed.emit(selected)
	queue_redraw()


func _flash_name() -> void:
	if _name_label:
		_name_label.text = tr(NAME_KEYS[selected])
		_name_label.modulate.a = 1.0
		_show_name_t = 1.6


func _building() -> bool:
	if _player == null:
		return false
	var bs := _player.get_node_or_null("BuildSystem")
	return bs != null and bool(bs.get("active"))


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not _player.input_enabled or get_tree().paused or _building():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k < KEY_1 + TOOLS.size():
			select(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		var mb := (event as InputEventMouseButton).button_index
		if mb == MOUSE_BUTTON_WHEEL_UP:
			select((selected - 1 + TOOLS.size()) % TOOLS.size())
		elif mb == MOUSE_BUTTON_WHEEL_DOWN:
			select((selected + 1) % TOOLS.size())
	if event is InputEventJoypadButton and event.pressed:
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_DPAD_LEFT:
			select((selected - 1 + TOOLS.size()) % TOOLS.size())
		elif jb == JOY_BUTTON_DPAD_RIGHT:
			select((selected + 1) % TOOLS.size())
	var tool := current_tool()
	if event.is_action_pressed(&"tool_primary"):
		match tool:
			&"hand":
				if _player.is_on_floor() and not _player.is_busy():
					_player.interactor.try_interact(_player)
			&"scanner":
				(_player.get_node("Scanner") as Scanner).try_scan()
			&"binoculars":
				_player.binoculars_active = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"tool_secondary") and tool == &"binoculars":
		_player.binoculars_active = true
		get_viewport().set_input_as_handled()
	elif (event.is_action_released(&"tool_primary") or event.is_action_released(&"tool_secondary")) and tool == &"binoculars":
		_player.binoculars_active = false
	elif event.is_action_pressed(&"scan"):
		select(1) # Q también usa el escáner: la barra lo muestra


func _process(delta: float) -> void:
	if _show_name_t > 0.0:
		_show_name_t -= delta
		_name_label.modulate.a = clampf(_show_name_t / 0.5, 0.0, 1.0)
	if _player and _player.binoculars_active:
		_dist_acc -= delta
		if _dist_acc <= 0.0:
			_dist_acc = 0.2
			_distance_text = _measure_distance()
	modulate.a = 0.35 if _building() else 1.0
	queue_redraw()


## Distancia a lo que se mira con los binoculares (terreno lejano por mapa de alturas).
func _measure_distance() -> String:
	var cam := _player.camera_rig.get_camera()
	var from := cam.global_position
	var fwd := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 600.0, 1 | (1 << 2) | (1 << 3) | (1 << 5))
	q.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return "%d m" % int(from.distance_to(hit.position))
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	if region:
		var t := 20.0
		var step := 5.0
		while t < 3000.0:
			var pt := from + fwd * t
			var h := region.get_height(pt)
			if is_finite(h) and h >= pt.y:
				return "%d m" % int(t)
			t += step
			step = minf(step * 1.05, 40.0)
	return "∞"


func _draw() -> void:
	var font := SpatiumTheme.font(&"mono", 600)
	var scanner := _player.get_node_or_null("Scanner") as Scanner if _player else null
	for i in TOOLS.size():
		var r := Rect2(Vector2(i * (SLOT + GAP), 22), Vector2(SLOT, SLOT))
		var sel := i == selected
		# ranura cuadrada con esquinas redondeadas (fondo oscuro translúcido)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.1, 0.72 if sel else 0.5)
		sb.set_corner_radius_all(12)
		sb.border_color = Color(0.95, 0.93, 0.88, 0.95) if sel else Color(1, 1, 1, 0.18)
		sb.set_border_width_all(3 if sel else 1)
		draw_style_box(sb, r)
		var c := r.get_center()
		var col := Color(0.95, 0.93, 0.88) if sel else Color(0.8, 0.82, 0.85, 0.75)
		match TOOLS[i]:
			&"hand":
				_draw_hand(c, col)
			&"scanner":
				_draw_scanner(c, col)
				if scanner and scanner.get_cooldown_left() > 0.0:
					var f := scanner.get_cooldown_left() / maxf(scanner.cooldown, 0.01)
					draw_rect(Rect2(r.position + Vector2(4, r.size.y * (1.0 - f)), Vector2(r.size.x - 8, r.size.y * f - 4)), Color(0, 0, 0, 0.45))
			&"binoculars":
				_draw_binoculars(c, col)
		draw_string(font, r.position + Vector2(7, 18), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
	if _player and _player.binoculars_active and _distance_text != "":
		draw_string(font, Vector2(0, 14), _distance_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.95, 0.93, 0.88, 0.9))


func _draw_hand(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-13, -2), Vector2(26, 20)), col, false, 3.0)
	for k in 4:
		draw_line(c + Vector2(-10 + k * 7, -2), c + Vector2(-10 + k * 7, -16 + absf(k - 1.5) * 3.0), col, 4.0)
	draw_line(c + Vector2(-13, 6), c + Vector2(-20, -2), col, 4.0)


func _draw_scanner(c: Vector2, col: Color) -> void:
	draw_arc(c + Vector2(0, 8), 8, PI, TAU, 16, col, 3.0)
	draw_arc(c + Vector2(0, 8), 16, PI * 1.1, TAU - PI * 0.1, 20, col, 3.0)
	draw_arc(c + Vector2(0, 8), 24, PI * 1.2, TAU - PI * 0.2, 24, Color(col, col.a * 0.6), 3.0)
	draw_circle(c + Vector2(0, 8), 3.5, col)


func _draw_binoculars(c: Vector2, col: Color) -> void:
	for s: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(s * 11, 6), 9, Color(col, 0.0))
		draw_arc(c + Vector2(s * 11, 6), 9, 0, TAU, 20, col, 3.0)
		draw_rect(Rect2(c + Vector2(s * 11 - 6, -14), Vector2(12, 14)), col, false, 3.0)
	draw_line(c + Vector2(-4, -4), c + Vector2(4, -4), col, 3.0)
