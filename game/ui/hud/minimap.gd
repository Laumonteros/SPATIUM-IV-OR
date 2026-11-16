class_name Minimap
extends CanvasLayer
## Minimapa circular (arriba a la izquierda) y mapa completo de la región (M).
##
## Fondo: relieve sombreado de la región (tools/generate_map_texture.py).
## Muestra: estructuras, vehículo, rocas, recursos detectados por el escáner,
## puntos de interés descubiertos y la posición/orientación del astronauta.

const MAP_TEX := "res://assets/textures/ui/moon_region_01_map.png"
const WORLD_SIZE := 2048.0
const RADIUS_PX := 118.0
const VIEW_RADIUS_M := 140.0
var _player: Player
var _mini: Control
var _full: Control
var _tex: Texture2D
var _mini_mat: ShaderMaterial
var _full_map: TextureRect
var _full_icons: Control
var _acc := 0.0


func _ready() -> void:
	add_to_group(&"session_ui")
	add_to_group(&"minimap")
	layer = 12
	_tex = load(MAP_TEX)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SpatiumTheme.get_theme()
	add_child(root)
	_build_mini(root)
	_build_full(root)
	EventBus.pause_changed.connect(func(p: bool) -> void: visible = not p)


func bind_session(session: GameSession) -> void:
	_player = session.player


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or get_tree().paused:
		return
	if event.is_action_pressed(&"map"):
		_full.visible = not _full.visible
		if _full.visible:
			EventBus.player_action.emit(&"open_map")
			# el mapa entra en pantalla con la leyenda a la derecha
			var vs := get_viewport().get_visible_rect().size
			var half := minf(380.0, (vs.y - 140.0) * 0.5)
			_full_map.offset_left = -half - 110.0
			_full_map.offset_right = half - 110.0
			_full_map.offset_top = -half
			_full_map.offset_bottom = half
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _player == null:
		return
	var p := _player.global_position
	var uv := Vector2((p.x + WORLD_SIZE * 0.5) / WORLD_SIZE, (p.z + WORLD_SIZE * 0.5) / WORLD_SIZE)
	_mini_mat.set_shader_parameter("center_uv", uv)
	_mini_mat.set_shader_parameter("zoom", VIEW_RADIUS_M / WORLD_SIZE)
	_acc += delta
	if _acc > 0.1:
		_acc = 0.0
		_mini.get_node("Icons").queue_redraw()
		if _full.visible:
			_full_icons.queue_redraw()


# --- Construcción ---------------------------------------------------------------

func _build_mini(root: Control) -> void:
	_mini = Control.new()
	_mini.position = Vector2(28, 28)
	_mini.size = Vector2(RADIUS_PX * 2, RADIUS_PX * 2)
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_mini)
	var map := ColorRect.new() # tamaño fijo; la textura se muestrea en el shader
	map.position = Vector2.ZERO
	map.size = _mini.size
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear_mipmap;
uniform vec2 center_uv = vec2(0.5);
uniform float zoom = 0.07;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec2 uv = center_uv + d * 2.0 * zoom;
	vec4 c = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) c = vec4(0.02, 0.03, 0.05, 1.0);
	float edge = smoothstep(0.5, 0.485, r);
	float ring = smoothstep(0.47, 0.49, r) * smoothstep(0.5, 0.49, r);
	vec3 col = mix(c.rgb * 0.95, vec3(0.31, 0.82, 0.91), ring * 0.9);
	COLOR = vec4(col, edge * 0.94);
}
"""
	_mini_mat = ShaderMaterial.new()
	_mini_mat.shader = sh
	_mini_mat.set_shader_parameter("map_tex", _tex)
	map.material = _mini_mat
	_mini.add_child(map)
	var icons := Control.new()
	icons.name = "Icons"
	icons.size = _mini.size
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.draw.connect(_draw_mini_icons.bind(icons))
	_mini.add_child(icons)
	var n := SpatiumTheme.label("N", 14, &"title", 700, SpatiumTheme.ORANGE)
	n.position = Vector2(RADIUS_PX - 5, -2)
	_mini.add_child(n)
	var hint := SpatiumTheme.label("M · mapa" if TranslationServer.get_locale().begins_with("es") else "M · map", 12, &"mono", 500, SpatiumTheme.TEXT_DIM)
	hint.position = Vector2(RADIUS_PX * 2 - 54, RADIUS_PX * 2 - 14)
	_mini.add_child(hint)


func _build_full(root: Control) -> void:
	_full = Control.new()
	_full.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.visible = false
	root.add_child(_full)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0.01, 0.03, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.add_child(dim)
	_full_map = TextureRect.new()
	_full_map.texture = _tex
	_full_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_full_map.stretch_mode = TextureRect.STRETCH_SCALE
	_full_map.set_anchors_preset(Control.PRESET_CENTER)
	_full_map.offset_left = -380
	_full_map.offset_top = -380
	_full_map.offset_right = 380
	_full_map.offset_bottom = 380
	_full_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.add_child(_full_map)
	_full_icons = Control.new()
	_full_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_icons.draw.connect(_draw_full_icons)
	_full.add_child(_full_icons)
	var es := TranslationServer.get_locale().begins_with("es")
	var title := SpatiumTheme.label("REGIÓN LUNAR 01 · SITIO ALBOR   (M para cerrar)" if es else "LUNAR REGION 01 · ALBOR SITE   (M to close)", 20, &"title", 700, SpatiumTheme.ORANGE)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 40
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_full.add_child(title)


# --- Dibujo de íconos -------------------------------------------------------------

func _to_mini(world: Vector3) -> Vector2:
	var d := Vector2(world.x - _player.global_position.x, world.z - _player.global_position.z)
	return Vector2(RADIUS_PX, RADIUS_PX) + d / VIEW_RADIUS_M * RADIUS_PX


func _in_circle(p: Vector2, margin: float = 4.0) -> bool:
	return p.distance_to(Vector2(RADIUS_PX, RADIUS_PX)) <= RADIUS_PX - margin


func _draw_mini_icons(c: Control) -> void:
	if _player == null:
		return
	_draw_icons(c, _to_mini, func(p: Vector2) -> bool: return _in_circle(p), 1.0)
	# Astronauta: flecha según la orientación de la cámara
	var center := Vector2(RADIUS_PX, RADIUS_PX)
	var yaw := _player.camera_rig.yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	_draw_arrow(c, center, fwd, 9.0)


func _draw_full_icons() -> void:
	if _player == null:
		return
	var rect := Rect2(_full_map.global_position - _full_icons.global_position, _full_map.size)
	var to_full := func(w: Vector3) -> Vector2:
		return rect.position + Vector2((w.x + WORLD_SIZE * 0.5) / WORLD_SIZE, (w.z + WORLD_SIZE * 0.5) / WORLD_SIZE) * rect.size
	_draw_icons(_full_icons, to_full, func(p: Vector2) -> bool: return rect.has_point(p), 1.15)
	_draw_legend(_full_icons, Vector2(rect.end.x + 40, rect.position.y + 24))
	var yaw := _player.camera_rig.yaw
	_draw_arrow(_full_icons, to_full.call(_player.global_position), Vector2(-sin(yaw), -cos(yaw)), 11.0)


## Categorías de instalaciones: color y forma del ícono (y nombre para la leyenda).
const KINDS := {
	&"home": [Color(1.0, 0.54, 0.24), "MAP_HOME"],
	&"dome": [Color(0.45, 0.86, 0.42), "MAP_DOME"],
	&"lab": [Color(0.36, 0.84, 0.86), "MAP_LAB"],
	&"workshop": [Color(0.82, 0.84, 0.88), "MAP_WORKSHOP"],
	&"energy": [Color(1.0, 0.84, 0.26), "MAP_ENERGY"],
	&"solar": [Color(0.4, 0.6, 1.0), "MAP_SOLAR"],
	&"command": [Color(1.0, 0.4, 0.38), "MAP_COMMAND"],
	&"life": [Color(0.62, 0.9, 1.0), "MAP_LIFE"],
}
const KIND_OF := {
	&"spatium_habitat": &"home", &"monoblock": &"home", &"habitat": &"home",
	&"biodome": &"dome", &"research_lab": &"lab", &"workshop": &"workshop",
	&"battery_bank": &"energy", &"battery": &"energy", &"solar_panel": &"solar",
	&"command_center": &"command", &"lander": &"command",
	&"oxygen_generator": &"life", &"water_extractor": &"life",
}
const CREW_COLOR := Color(0.55, 1.0, 0.6)
const ROVER_COLOR := Color(0.31, 0.82, 0.91)


func _draw_icons(c: Control, project: Callable, visible_fn: Callable, s: float) -> void:
	# Rocas: sin escanear, un punto gris; escaneadas, el ícono del recurso que dan
	for node in get_tree().get_nodes_in_group(&"resource_deposit"):
		var dep := node as ResourceDeposit
		if dep == null or dep.is_depleted():
			continue
		var p: Vector2 = project.call(dep.global_position)
		if not visible_fn.call(p):
			continue
		if dep.discovered:
			ResourceColors.draw_icon(c, p, (4.2 if dep.scannable else 2.8) * s, dep.item_id)
			if dep.bonus_item != &"":
				c.draw_arc(p, 5.0 * s, 0.0, TAU, 12, ResourceColors.of(dep.bonus_item), 1.4, true)
		else:
			c.draw_circle(p, 1.4 * s, Color(0.75, 0.74, 0.72, 0.5))
	for node in get_tree().get_nodes_in_group(&"poi"):
		var poi := node as Node3D
		if poi.get("discovered") != true:
			continue
		var p: Vector2 = project.call(poi.global_position)
		if visible_fn.call(p):
			_star(c, p, 6.0 * s, SpatiumTheme.AMBER)
	for node in get_tree().get_nodes_in_group(&"structure"):
		var st := node as Structure
		if st.def == null:
			continue
		var p: Vector2 = project.call(st.global_position)
		if visible_fn.call(p):
			var kind: StringName = KIND_OF.get(st.def.id, &"workshop")
			var big := st.def.role == BuildableDef.Role.SHELTER or kind in [&"dome", &"lab", &"command", &"workshop"]
			_kind_icon(c, p, (6.5 if big else 4.6) * s, kind)
	for node in get_tree().get_nodes_in_group(&"colony_walker"):
		var w := node as Node3D
		var p: Vector2 = project.call(w.global_position)
		if visible_fn.call(p):
			var crew := w is CrewMember
			c.draw_circle(p, (3.6 if crew else 2.6) * s, Color(0.02, 0.04, 0.06, 0.8))
			c.draw_circle(p, (2.6 if crew else 1.8) * s, CREW_COLOR if crew else Color(0.92, 0.92, 0.95))
	for node in get_tree().get_nodes_in_group(&"vehicle"):
		var v := node as Node3D
		var p: Vector2 = project.call(v.global_position)
		if visible_fn.call(p):
			_rover_icon(c, p, 5.0 * s)


## Ícono de instalación: placa oscura con la forma de su categoría.
func _kind_icon(c: CanvasItem, p: Vector2, r: float, kind: StringName) -> void:
	var col: Color = KINDS[kind][0]
	c.draw_circle(p, r + 2.2, Color(0.02, 0.04, 0.07, 0.82))
	var pts := PackedVector2Array()
	match kind:
		&"home": # casa
			pts = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, -r * 0.1), p + Vector2(r * 0.75, r * 0.8), p + Vector2(-r * 0.75, r * 0.8), p + Vector2(-r, -r * 0.1)])
		&"dome": # cúpula
			for i in 9:
				var a := PI + i * PI / 8.0
				pts.append(p + Vector2(cos(a), sin(a)) * r + Vector2(0, r * 0.35))
		&"lab": # matraz
			pts = PackedVector2Array([p + Vector2(-r * 0.3, -r), p + Vector2(r * 0.3, -r), p + Vector2(r * 0.3, -r * 0.2), p + Vector2(r, r * 0.8), p + Vector2(-r, r * 0.8), p + Vector2(-r * 0.3, -r * 0.2)])
		&"workshop": # engranaje (octógono)
			for i in 8:
				var a := PI / 8.0 + i * TAU / 8.0
				pts.append(p + Vector2(cos(a), sin(a)) * r)
		&"energy": # rayo
			pts = PackedVector2Array([p + Vector2(r * 0.2, -r), p + Vector2(-r * 0.7, r * 0.15), p + Vector2(-r * 0.05, r * 0.15), p + Vector2(-r * 0.25, r), p + Vector2(r * 0.7, -r * 0.2), p + Vector2(r * 0.05, -r * 0.2)])
		&"solar": # panel
			pts = PackedVector2Array([p + Vector2(-r, -r * 0.6), p + Vector2(r, -r * 0.6), p + Vector2(r, r * 0.6), p + Vector2(-r, r * 0.6)])
		&"command": # cohete
			pts = PackedVector2Array([p + Vector2(0, -r * 1.15), p + Vector2(r * 0.45, -r * 0.2), p + Vector2(r * 0.45, r * 0.6), p + Vector2(r * 0.8, r), p + Vector2(-r * 0.8, r), p + Vector2(-r * 0.45, r * 0.6), p + Vector2(-r * 0.45, -r * 0.2)])
		_: # soporte vital
			c.draw_circle(p, r, col)
			c.draw_circle(p, r * 0.45, Color(0.02, 0.04, 0.07, 0.9))
			return
	c.draw_colored_polygon(pts, col)
	if kind == &"solar":
		c.draw_line(p + Vector2(0, -r * 0.6), p + Vector2(0, r * 0.6), Color(0.02, 0.04, 0.07), 1.0)
		c.draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), Color(0.02, 0.04, 0.07), 1.0)


func _rover_icon(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_circle(p, r + 2.0, Color(0.02, 0.04, 0.07, 0.82))
	c.draw_rect(Rect2(p - Vector2(r, r * 0.55), Vector2(r * 2.0, r * 1.1)), ROVER_COLOR)
	for sx: float in [-0.6, 0.6]:
		c.draw_circle(p + Vector2(r * sx, r * 0.6), r * 0.32, Color(0.02, 0.04, 0.07))


## Leyenda del mapa completo con los mismos íconos.
func _draw_legend(c: Control, origin: Vector2) -> void:
	var font := SpatiumTheme.font(&"body", 500)
	var x := origin.x
	var y := origin.y
	var entries: Array = []
	for k: StringName in KINDS:
		entries.append([&"kind", k, tr(String(KINDS[k][1]))])
	entries.append([&"crew", &"", tr("MAP_CREW")])
	entries.append([&"rover", &"", tr("MAP_ROVER")])
	for id: StringName in ResourceColors.COLORS:
		entries.append([&"res", id, ResourceColors.item_name(id)])
	entries.append([&"poi", &"", tr("MAP_POI")])
	var col_w := 190.0
	var per_col := entries.size()
	var sb := SpatiumTheme.panel_style()
	var rows := per_col
	var cols := int(ceil(entries.size() / float(per_col)))
	c.draw_style_box(sb, Rect2(origin - Vector2(14, 16), Vector2(cols * col_w + 16, rows * 24 + 14)))
	for i in entries.size():
		var e: Array = entries[i]
		var p := Vector2(x + (i / per_col) * col_w, y + (i % per_col) * 24)
		match e[0]:
			&"kind":
				_kind_icon(c, p, 6.0, e[1])
			&"crew":
				c.draw_circle(p, 3.6, Color(0.02, 0.04, 0.06))
				c.draw_circle(p, 2.8, CREW_COLOR)
			&"rover":
				_rover_icon(c, p, 5.0)
			&"res":
				ResourceColors.draw_icon(c, p, 5.0, e[1])
			&"poi":
				_star(c, p, 6.0, SpatiumTheme.AMBER)
		c.draw_string(font, p + Vector2(14, 5), String(e[2]), HORIZONTAL_ALIGNMENT_LEFT, col_w - 24, 14, SpatiumTheme.TEXT)


func _diamond(c: Control, p: Vector2, r: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)


func _star(c: Control, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)


func _draw_arrow(c: Control, p: Vector2, fwd: Vector2, size: float) -> void:
	var right := Vector2(-fwd.y, fwd.x)
	c.draw_colored_polygon(PackedVector2Array([p + fwd * size, p - fwd * size * 0.6 + right * size * 0.6, p - fwd * size * 0.25, p - fwd * size * 0.6 - right * size * 0.6]), Color.WHITE)
