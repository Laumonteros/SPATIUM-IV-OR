class_name ModuleBuilder
extends RefCounted
## Kit de construcción de los módulos procedurales de la colonia.
##
## Escala: 1 unidad = 1 metro. Todo cuelga de `root`; las colisiones se agrupan en
## dos cuerpos estáticos: `shell` (muros, pisos, techos: bloquean al astronauta y a
## la cámara) y `furniture` (muebles: capa 9, bloquean al astronauta pero no a la
## cámara, para que no salte en los interiores). Los materiales son compartidos
## (una instancia por tipo) y los props interiores tienen distancia de visibilidad.
##
## Código de color de la biblia de arte: cian = información, ámbar = advertencia y
## energía, magenta = iluminación de cultivo.

const LAYER_SHELL := 1 | (1 << 2) # terreno + estructuras (la cámara choca)
const LAYER_FURNITURE := 1 << 8 # mobiliario (solo el astronauta)
## Más allá de esta distancia no se dibujan los props interiores (HLOD simple).
const DETAIL_RANGE := 24.0
const SHELL_RANGE := 900.0

static var _mats: Dictionary = {}

var root: Node3D
var shell: StaticBody3D
var furniture: StaticBody3D
## Mientras está activo, las piezas nuevas se consideran props interiores.
var detail := false


func _init(parent: Node3D) -> void:
	root = parent
	shell = StaticBody3D.new()
	shell.name = "Shell"
	shell.collision_layer = LAYER_SHELL
	shell.collision_mask = 0
	root.add_child(shell)
	furniture = StaticBody3D.new()
	furniture.name = "Furniture"
	furniture.collision_layer = LAYER_FURNITURE
	furniture.collision_mask = 0
	root.add_child(furniture)


# --- Materiales compartidos ----------------------------------------------------

static func mat(key: StringName) -> Material:
	if _mats.has(key):
		var cached: Material = _mats[key]
		# piezas que cambian de material en juego: devolver la versión curvada
		return CurvedWorld.convert_material(cached) if CurvedWorld.enabled else cached
	var m := StandardMaterial3D.new()
	m.resource_name = String(key)
	match key:
		&"hull": # revestimiento claro
			m.albedo_color = Color(0.86, 0.87, 0.85)
			m.roughness = 0.55
			m.metallic = 0.1
		&"hull_panel":
			m.albedo_color = Color(0.74, 0.76, 0.76)
			m.roughness = 0.6
		&"frame": # estructura oscura
			m.albedo_color = Color(0.16, 0.17, 0.19)
			m.roughness = 0.45
			m.metallic = 0.7
		&"metal":
			m.albedo_color = Color(0.55, 0.57, 0.6)
			m.roughness = 0.35
			m.metallic = 0.85
		&"armor": # blindaje
			m.albedo_color = Color(0.36, 0.37, 0.36)
			m.roughness = 0.8
			m.metallic = 0.3
		&"regolith_bag":
			m.albedo_color = Color(0.5, 0.48, 0.44)
			m.roughness = 1.0
		&"floor":
			m.albedo_color = Color(0.3, 0.31, 0.33)
			m.roughness = 0.7
			m.metallic = 0.5
		&"interior_wall":
			m.albedo_color = Color(0.9, 0.91, 0.92)
			m.roughness = 0.75
		&"interior_trim":
			m.albedo_color = Color(0.42, 0.45, 0.5)
			m.roughness = 0.5
			m.metallic = 0.4
		&"fabric_blue":
			m.albedo_color = Color(0.22, 0.32, 0.48)
			m.roughness = 0.95
		&"fabric_gray":
			m.albedo_color = Color(0.5, 0.52, 0.55)
			m.roughness = 0.95
		&"fabric_orange":
			m.albedo_color = Color(0.85, 0.42, 0.18)
			m.roughness = 0.9
		&"plastic":
			m.albedo_color = Color(0.82, 0.83, 0.8)
			m.roughness = 0.4
		&"plastic_dark":
			m.albedo_color = Color(0.1, 0.11, 0.12)
			m.roughness = 0.4
		&"copper":
			m.albedo_color = Color(0.72, 0.45, 0.28)
			m.roughness = 0.35
			m.metallic = 0.9
		&"pipe_white":
			m.albedo_color = Color(0.92, 0.92, 0.9)
			m.roughness = 0.3
			m.metallic = 0.2
		&"pipe_blue":
			m.albedo_color = Color(0.2, 0.45, 0.75)
			m.roughness = 0.35
		&"cable":
			m.albedo_color = Color(0.08, 0.08, 0.09)
			m.roughness = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"power_cable": # funda de cable de potencia (ámbar = energía)
			m.albedo_color = Color(0.95, 0.55, 0.12)
			m.roughness = 0.55
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"soil":
			m.albedo_color = Color(0.22, 0.16, 0.11)
			m.roughness = 1.0
		&"leaf":
			m.albedo_color = Color(0.25, 0.6, 0.22)
			m.roughness = 0.7
		&"leaf_dark":
			m.albedo_color = Color(0.16, 0.42, 0.18)
			m.roughness = 0.7
		&"fruit_red":
			m.albedo_color = Color(0.85, 0.15, 0.1)
			m.roughness = 0.3
		&"wheat":
			m.albedo_color = Color(0.82, 0.7, 0.35)
			m.roughness = 0.8
		&"glass":
			m.albedo_color = Color(0.55, 0.7, 0.8, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"glass_gold": # visor/ventana con lámina dorada (reduce IR)
			m.albedo_color = Color(0.85, 0.65, 0.3, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"screen_cyan":
			_emissive(m, Color(0.45, 0.7, 0.76), 0.3)
		&"screen_dark":
			m.albedo_color = Color(0.02, 0.05, 0.07)
			m.roughness = 0.15
			m.emission_enabled = true
			m.emission = Color(0.05, 0.16, 0.19)
			m.emission_energy_multiplier = 0.4
		&"light_warm":
			_emissive(m, Color(1.0, 0.94, 0.86), 0.55)
		&"light_cyan":
			_emissive(m, Color(0.55, 0.75, 0.8), 0.3)
		&"light_amber":
			_emissive(m, Color(0.95, 0.75, 0.42), 0.35)
		&"light_red":
			_emissive(m, Color(0.85, 0.35, 0.3), 0.35)
		&"light_green":
			_emissive(m, Color(0.5, 0.8, 0.55), 0.3)
		&"light_magenta":
			_emissive(m, Color(1.0, 0.9, 0.94), 0.4) # LED de cultivo: blanco rosado suave, sin neón
		&"hull_2s": # revestimiento de túneles (se ve por dentro y por fuera)
			m.albedo_color = Color(0.86, 0.87, 0.85)
			m.roughness = 0.55
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"floor_light":
			m.albedo_color = Color(0.56, 0.58, 0.6)
			m.roughness = 0.6
			m.metallic = 0.3
		&"paint_orange": # franjas del Hábitat Spatium (pintura, no luz)
			m.albedo_color = Color(0.86, 0.47, 0.16)
			m.roughness = 0.6
		&"paint_blue":
			m.albedo_color = Color(0.22, 0.36, 0.6)
			m.roughness = 0.6
		&"solar_cell":
			m.albedo_color = Color(0.1, 0.16, 0.3)
			m.roughness = 0.25
			m.metallic = 0.5
		&"holo": # globo holográfico: tenue, sin neón
			m.albedo_color = Color(0.6, 0.8, 0.9, 0.3)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color(0.45, 0.65, 0.75)
			m.emission_energy_multiplier = 0.2
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"paint_teal": # pintura mate de señalización (sector informativo)
			m.albedo_color = Color(0.32, 0.56, 0.6)
			m.roughness = 0.75
		&"paint_rose": # pintura mate (sector cultivos)
			m.albedo_color = Color(0.7, 0.45, 0.55)
			m.roughness = 0.75
		&"paint_ochre": # pintura mate (sector energía/industria)
			m.albedo_color = Color(0.78, 0.6, 0.3)
			m.roughness = 0.75
		&"reflector": # captafaro de los postes de camino: refleja, no brilla
			m.albedo_color = Color(0.9, 0.88, 0.8)
			m.roughness = 0.2
			m.metallic = 0.6
		&"sign_board":
			m.albedo_color = Color(0.13, 0.14, 0.16)
			m.roughness = 0.6
		&"stripe_amber": # señalización de advertencia
			m.albedo_color = Color(0.86, 0.66, 0.26)
			m.roughness = 0.7
		&"frost":
			m.albedo_color = Color(0.8, 0.92, 1.0)
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(0.6, 0.78, 0.9)
			m.emission_energy_multiplier = 0.15
		&"rock_sample":
			m.albedo_color = Color(0.45, 0.43, 0.4)
			m.roughness = 0.95
		&"photo":
			m.albedo_color = Color(0.25, 0.4, 0.7)
			m.roughness = 0.3
		&"book_red":
			m.albedo_color = Color(0.6, 0.15, 0.12)
		&"book_green":
			m.albedo_color = Color(0.15, 0.4, 0.25)
		&"concrete": # losa de regolito sinterizado
			m.albedo_color = Color(0.45, 0.44, 0.42)
			m.roughness = 0.95
		_:
			m.albedo_color = Color.MAGENTA
	_apply_textures(m, key)
	_mats[key] = m
	return CurvedWorld.convert_material(m) if CurvedWorld.enabled else m


const TEX_DIR := "res://assets/textures/modules/"
const FABRIC_NRM := "res://assets/textures/detail/denim_fabric_04_nor_gl_1k.jpg"


## Texturas de detalle (proyección triplanar en coordenadas del módulo, así las
## piezas fusionadas siguen la misma grilla de paneles): revestimiento con juntas y
## remaches, chapa antideslizante en pisos, losas de regolito y trama de tela.
static func _apply_textures(m: StandardMaterial3D, key: StringName) -> void:
	var set_name := ""
	var scale := 0.5
	var nscale := 1.0
	match key:
		&"hull", &"hull_2s", &"hull_panel", &"armor":
			set_name = "hull"
			scale = 0.25 # paneles de 2 x 1 m
		&"interior_wall":
			set_name = "hull"
			scale = 0.25
			nscale = 0.35
		&"floor", &"floor_light":
			set_name = "floor"
		&"concrete", &"regolith_bag":
			set_name = "slab"
			scale = 0.25
		&"fabric_blue", &"fabric_gray", &"fabric_orange":
			if ResourceLoader.exists(FABRIC_NRM):
				m.normal_enabled = true
				m.normal_texture = load(FABRIC_NRM)
				m.normal_scale = 0.6
				m.uv1_triplanar = true
				m.uv1_scale = Vector3.ONE * 3.0
			return
	if set_name == "" or not ResourceLoader.exists(TEX_DIR + set_name + "_alb.png"):
		return
	m.albedo_texture = load(TEX_DIR + set_name + "_alb.png")
	m.normal_enabled = true
	m.normal_texture = load(TEX_DIR + set_name + "_nrm.png")
	m.normal_scale = nscale
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


static func _emissive(m: StandardMaterial3D, c: Color, e: float) -> void:
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.roughness = 0.4
	# sin "unshaded": las luces se ven como lámparas reales, no como neón


# --- Primitivas ------------------------------------------------------------------

func _mesh(mesh: Mesh, pos: Vector3, m: Material, rot: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if detail:
		mi.visibility_range_end = DETAIL_RANGE
		mi.visibility_range_end_margin = 4.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mi.visibility_range_end = SHELL_RANGE
	(parent if parent else root).add_child(mi)
	return mi


## Caja. `collide`: &"" (sin colisión), &"shell" o &"furniture".
func box(size: Vector3, pos: Vector3, m: StringName, rot := Vector3.ZERO, collide: StringName = &"", parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(bm, pos, mat(m), rot, parent)
	if collide != &"":
		var shape := BoxShape3D.new()
		shape.size = size
		_add_shape(shape, mi, collide)
	return mi


func cyl(radius: float, height: float, pos: Vector3, m: StringName, rot := Vector3.ZERO, collide: StringName = &"", sides := 16, top_radius := -1.0, parent: Node3D = null) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	var mi := _mesh(cm, pos, mat(m), rot, parent)
	if collide != &"":
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, cm.top_radius)
		shape.height = height
		_add_shape(shape, mi, collide)
	return mi


func sphere(radius: float, pos: Vector3, m: StringName, scale := Vector3.ONE, parent: Node3D = null, segments := 12) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(segments / 2, 4)
	var mi := _mesh(sm, pos, mat(m), Vector3.ZERO, parent)
	mi.scale = scale
	return mi


## Tubo recto entre dos puntos (cañerías, barandas, puntales).
func pipe(a: Vector3, b: Vector3, radius: float, m: StringName, parent: Node3D = null, sides := 8) -> MeshInstance3D:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return null
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = len
	cm.radial_segments = sides
	cm.rings = 1
	var mi := _mesh(cm, (a + b) * 0.5, mat(m), Vector3.ZERO, parent)
	var up := d / len
	var basis := Basis(Quaternion(Vector3.UP, up)) if absf(up.dot(Vector3.UP)) < 0.9999 else (Basis() if up.y > 0 else Basis(Vector3.RIGHT, PI))
	mi.basis = basis
	return mi


func _add_shape(shape: Shape3D, mi: MeshInstance3D, collide: StringName) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var body := furniture if collide == &"furniture" else shell
	# Transformación relativa al cuerpo (los cuerpos cuelgan de root en el origen)
	var t := mi.transform
	var p := mi.get_parent()
	while p and p != root:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	cs.transform = t
	body.add_child(cs)


## Colisión invisible (para volúmenes ya dibujados por otras piezas).
func collider(size: Vector3, pos: Vector3, collide: StringName = &"shell", rot := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	cs.rotation = rot
	(furniture if collide == &"furniture" else shell).add_child(cs)


func omni(pos: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 30.0
	l.distance_fade_length = 10.0
	root.add_child(l)
	return l


## Texto en el mundo (pantallas, carteles). Devuelve el Label3D para actualizarlo.
func label(text: String, pos: Vector3, rot: Vector3, size := 0.012, color := Color(0.6, 0.95, 1.0), width := 600.0, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation = rot
	l.pixel_size = size
	l.modulate = color
	l.outline_size = 0
	l.font_size = 32
	l.width = width
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.shaded = false
	l.double_sided = false
	l.visibility_range_end = DETAIL_RANGE if detail else 120.0
	var f := load(SpatiumTheme.FONT_MONO) as Font
	if f:
		l.font = f
	(parent if parent else root).add_child(l)
	return l


# --- Muros con aberturas reales ----------------------------------------------------

## Muro recto de `a` a `b` (a nivel del piso, en coordenadas de root) con aberturas.
## Cada abertura: Vector4(distancia desde a, ancho, altura del borde inferior, alto).
## Las ventanas (borde inferior > 0) llevan vidrio y marco con colisión.
func wall(a: Vector3, b: Vector3, height: float, thickness: float, openings: Array[Vector4], m: StringName, inner: StringName = &"") -> void:
	var dir := (b - a)
	var length := dir.length()
	dir /= length
	var yaw := atan2(-dir.z, dir.x)
	var normal := Vector3(-dir.z, 0, dir.x) # hacia el interior si el contorno es antihorario
	# Tramos horizontales entre todos los bordes de aberturas; en cada tramo se
	# rellena en vertical solo lo que no ocupa ninguna abertura. Así una ventana
	# alta y una puerta en el mismo tramo conviven (antes la ventana tapaba la puerta).
	var cuts: Array[float] = [0.0, length]
	for o: Vector4 in openings:
		cuts.append(clampf(o.x, 0.0, length))
		cuts.append(clampf(o.x + o.y, 0.0, length))
	cuts.sort()
	for i in cuts.size() - 1:
		var s0 := cuts[i]
		var s1 := cuts[i + 1]
		if s1 - s0 <= 0.001:
			continue
		var mid := (s0 + s1) * 0.5
		var gaps: Array[Vector2] = []
		for o: Vector4 in openings:
			if mid > o.x and mid < o.x + o.y:
				gaps.append(Vector2(o.z, o.z + o.w))
		gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var y := 0.0
		for g: Vector2 in gaps:
			if g.x > y:
				_wall_piece(a, dir, normal, yaw, s0, s1, y, g.x, thickness, m, inner)
			y = maxf(y, g.y)
		if y < height:
			_wall_piece(a, dir, normal, yaw, s0, s1, y, height, thickness, m, inner)
	for o: Vector4 in openings:
		if o.z > 0.0: # ventana: vidrio y marco
			_window(a + dir * (o.x + o.y * 0.5) + Vector3(0, o.z + o.w * 0.5, 0), yaw, o.y, o.w, thickness)


func _wall_piece(a: Vector3, dir: Vector3, normal: Vector3, yaw: float, s0: float, s1: float, y0: float, y1: float, t: float, m: StringName, inner: StringName) -> void:
	var w := s1 - s0
	if w <= 0.001 or y1 - y0 <= 0.001:
		return
	var c := a + dir * ((s0 + s1) * 0.5) + Vector3(0, (y0 + y1) * 0.5, 0)
	box(Vector3(w, y1 - y0, t), c, m, Vector3(0, yaw, 0), &"shell")
	if inner != &"": # revestimiento interior (paneles claros)
		var was := detail
		detail = true
		box(Vector3(w - 0.02, y1 - y0 - 0.02, 0.02), c + normal * (t * 0.5 + 0.03), inner, Vector3(0, yaw, 0))
		detail = was


func _window(center: Vector3, yaw: float, w: float, h: float, t: float) -> void:
	box(Vector3(w, h, 0.03), center, &"glass_gold", Vector3(0, yaw, 0), &"shell")
	var r := Basis(Vector3.UP, yaw)
	for s: float in [-1.0, 1.0]:
		box(Vector3(0.08, h + 0.08, t + 0.06), center + r * Vector3(s * w * 0.5, 0, 0), &"frame", Vector3(0, yaw, 0))
		box(Vector3(w + 0.08, 0.08, t + 0.06), center + Vector3(0, s * h * 0.5, 0), &"frame", Vector3(0, yaw, 0))


## Piso + techo rectangular (centrado en `center`, a nivel del piso).
func slab(size: Vector3, center: Vector3, m: StringName, collide: StringName = &"shell") -> MeshInstance3D:
	return box(size, center + Vector3(0, -size.y * 0.5, 0), m, Vector3.ZERO, collide)


# --- Props reutilizables (interiores) ---------------------------------------------

## Panel de luz de techo + luz real.
func ceiling_light(pos: Vector3, color := Color(1.0, 0.93, 0.82), energy := 1.4, range_m := 6.0, with_light := true) -> OmniLight3D:
	var was := detail
	detail = true
	box(Vector3(1.0, 0.04, 0.35), pos, &"light_warm")
	box(Vector3(1.1, 0.03, 0.45), pos + Vector3(0, 0.03, 0), &"interior_trim")
	detail = was
	return omni(pos - Vector3(0, 0.25, 0), color, energy, range_m) if with_light else null


## Tendido de cañerías y bandeja de cables por el techo.
func ceiling_services(a: Vector3, b: Vector3) -> void:
	var was := detail
	detail = true
	var side := (b - a).normalized().cross(Vector3.UP) * 0.18
	pipe(a, b, 0.05, &"pipe_white")
	pipe(a + side, b + side, 0.035, &"pipe_blue")
	pipe(a - side, b - side, 0.03, &"copper")
	box(Vector3((b - a).length(), 0.03, 0.22), (a + b) * 0.5 - side * 2.2 + Vector3(0, -0.04, 0), &"frame", Vector3(0, atan2(-(b - a).z, (b - a).x), 0))
	var n := int((b - a).length() / 1.2)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		box(Vector3(0.04, 0.16, 0.6), p + Vector3(0, 0.06, 0), &"frame", Vector3(0, atan2(-(b - a).z, (b - a).x), 0))
		if i % 2 == 0: # cables sueltos en la bandeja
			pipe(p - side * 2.2 + Vector3(0, -0.02, 0), a.lerp(b, float(i + 1) / maxf(n, 1)) - side * 2.2 + Vector3(0, -0.01, 0), 0.012, &"cable")
	detail = was


## Litera/cama con colchón, almohada, manta y luz de lectura. Devuelve su centro.
func bed(pos: Vector3, yaw: float) -> Node3D:
	var n := _group(pos, yaw, "Bed")
	box(Vector3(0.95, 0.35, 2.05), Vector3(0, 0.25, 0), &"frame", Vector3.ZERO, &"furniture", n)
	box(Vector3(0.9, 0.16, 1.95), Vector3(0, 0.5, 0), &"fabric_gray", Vector3.ZERO, &"", n)
	box(Vector3(0.88, 0.06, 1.3), Vector3(0, 0.6, 0.3), &"fabric_blue", Vector3(0.02, 0, 0), &"", n)
	box(Vector3(0.6, 0.1, 0.35), Vector3(0, 0.62, -0.75), &"plastic", Vector3.ZERO, &"", n)
	box(Vector3(0.95, 1.0, 0.06), Vector3(0, 0.75, -1.02), &"interior_trim", Vector3.ZERO, &"furniture", n)
	# correas de sujeción (sin gravedad terrestre la ropa de cama se fija)
	for z: float in [-0.2, 0.6]:
		box(Vector3(0.96, 0.02, 0.05), Vector3(0, 0.64, z), &"fabric_orange", Vector3.ZERO, &"", n)
	box(Vector3(0.12, 0.05, 0.12), Vector3(0.38, 1.15, -0.98), &"light_warm", Vector3.ZERO, &"", n)
	# cajón bajo la cama
	box(Vector3(0.85, 0.18, 0.6), Vector3(0, 0.14, 0.55), &"plastic_dark", Vector3.ZERO, &"", n)
	return n


func desk(pos: Vector3, yaw: float, width := 1.4) -> Node3D:
	var n := _group(pos, yaw, "Desk")
	box(Vector3(width, 0.05, 0.7), Vector3(0, 0.76, 0), &"plastic", Vector3.ZERO, &"furniture", n)
	for x in [-width * 0.5 + 0.05, width * 0.5 - 0.05]:
		box(Vector3(0.05, 0.74, 0.65), Vector3(x, 0.37, 0), &"frame", Vector3.ZERO, &"", n)
	box(Vector3(0.45, 0.5, 0.6), Vector3(width * 0.5 - 0.3, 0.27, 0), &"interior_trim", Vector3.ZERO, &"", n)
	# teclado y tablet
	box(Vector3(0.45, 0.02, 0.15), Vector3(-0.1, 0.795, 0.12), &"plastic_dark", Vector3.ZERO, &"", n)
	box(Vector3(0.22, 0.015, 0.3), Vector3(0.4, 0.795, 0.1), &"screen_dark", Vector3(0, 0.3, 0), &"", n)
	return n


func chair(pos: Vector3, yaw: float) -> Node3D:
	var n := _group(pos, yaw, "Chair")
	cyl(0.04, 0.45, Vector3(0, 0.23, 0), &"metal", Vector3.ZERO, &"", 8, -1.0, n)
	cyl(0.28, 0.04, Vector3(0, 0.02, 0), &"frame", Vector3.ZERO, &"", 5, -1.0, n)
	box(Vector3(0.46, 0.08, 0.46), Vector3(0, 0.48, 0), &"fabric_blue", Vector3.ZERO, &"furniture", n)
	box(Vector3(0.44, 0.5, 0.06), Vector3(0, 0.78, 0.22), &"fabric_blue", Vector3(0.1, 0, 0), &"furniture", n)
	return n


## Casillero/armario con puertas, rejillas y etiqueta.
func locker(pos: Vector3, yaw: float, doors := 2) -> Node3D:
	var n := _group(pos, yaw, "Locker")
	var w := 0.5 * doors
	box(Vector3(w, 2.0, 0.55), Vector3(0, 1.0, 0), &"interior_trim", Vector3.ZERO, &"furniture", n)
	for i in doors:
		var x := -w * 0.5 + 0.25 + i * 0.5
		box(Vector3(0.46, 1.9, 0.02), Vector3(x, 1.0, 0.285), &"hull_panel", Vector3.ZERO, &"", n)
		for k in 3:
			box(Vector3(0.3, 0.015, 0.01), Vector3(x, 1.6 + k * 0.05, 0.3), &"frame", Vector3.ZERO, &"", n)
		box(Vector3(0.03, 0.18, 0.03), Vector3(x + 0.17, 1.0, 0.3), &"metal", Vector3.ZERO, &"", n)
		box(Vector3(0.05, 0.05, 0.01), Vector3(x - 0.15, 1.85, 0.3), &"light_cyan" if i % 2 == 0 else &"light_green", Vector3.ZERO, &"", n)
	return n


## Estante con objetos personales (libros, foto, planta, contenedores).
func shelf(pos: Vector3, yaw: float, width := 1.2, levels := 3, personal := true) -> Node3D:
	var n := _group(pos, yaw, "Shelf")
	for l in levels:
		box(Vector3(width, 0.03, 0.35), Vector3(0, 0.4 + l * 0.45, 0), &"metal", Vector3.ZERO, &"", n)
	for x in [-width * 0.5, width * 0.5]:
		box(Vector3(0.03, 0.45 * levels + 0.1, 0.35), Vector3(x, 0.4 + 0.45 * levels * 0.5 - 0.2, 0), &"frame", Vector3.ZERO, &"", n)
	box(Vector3(width, 0.45 * levels + 0.1, 0.35), Vector3(0, 0.4 + 0.45 * levels * 0.5 - 0.2, 0), &"frame", Vector3.ZERO, &"furniture", n).visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 131.0 + pos.z * 71.0)
	for l in levels:
		var y := 0.42 + l * 0.45
		var x := -width * 0.5 + 0.1
		while x < width * 0.5 - 0.15:
			var kind := rng.randi() % (5 if personal else 3)
			match kind:
				0, 1: # libros / manuales
					for b in rng.randi_range(3, 6):
						var bw := rng.randf_range(0.03, 0.05)
						box(Vector3(bw, rng.randf_range(0.22, 0.3), 0.18), Vector3(x, y + 0.13, 0), [&"book_red", &"book_green", &"pipe_blue", &"plastic"][rng.randi() % 4], Vector3(0, 0, rng.randf_range(-0.05, 0.05)), &"", n)
						x += bw + 0.005
				2: # contenedores rotulados
					box(Vector3(0.25, 0.16, 0.25), Vector3(x + 0.12, y + 0.09, 0), &"plastic", Vector3.ZERO, &"", n)
					box(Vector3(0.1, 0.04, 0.005), Vector3(x + 0.12, y + 0.12, 0.13), &"stripe_amber", Vector3.ZERO, &"", n)
					x += 0.3
				3: # foto familiar
					box(Vector3(0.18, 0.14, 0.02), Vector3(x + 0.09, y + 0.08, 0.05), &"frame", Vector3(-0.2, 0, 0), &"", n)
					box(Vector3(0.15, 0.11, 0.005), Vector3(x + 0.09, y + 0.08, 0.065), &"photo", Vector3(-0.2, 0, 0), &"", n)
					x += 0.22
				4: # planta en maceta
					cyl(0.07, 0.12, Vector3(x + 0.08, y + 0.07, 0), &"plastic", Vector3.ZERO, &"", 10, 0.09, n)
					sphere(0.1, Vector3(x + 0.08, y + 0.2, 0), &"leaf", Vector3(1, 0.8, 1), n, 8)
					x += 0.2
			x += 0.06
	return n


## Cocina compacta: mesada, dispensador de agua, calentador de raciones, alacena.
func kitchenette(pos: Vector3, yaw: float) -> Node3D:
	var n := _group(pos, yaw, "Galley")
	box(Vector3(1.8, 0.9, 0.6), Vector3(0, 0.45, 0), &"interior_trim", Vector3.ZERO, &"furniture", n)
	box(Vector3(1.85, 0.04, 0.64), Vector3(0, 0.92, 0), &"metal", Vector3.ZERO, &"", n)
	box(Vector3(0.5, 0.35, 0.4), Vector3(-0.55, 1.12, -0.05), &"plastic", Vector3.ZERO, &"", n) # calentador
	box(Vector3(0.36, 0.2, 0.01), Vector3(-0.55, 1.14, 0.155), &"screen_dark", Vector3.ZERO, &"", n)
	box(Vector3(0.05, 0.05, 0.01), Vector3(-0.38, 1.2, 0.156), &"light_amber", Vector3.ZERO, &"", n)
	cyl(0.12, 0.5, Vector3(0.6, 1.19, -0.1), &"pipe_blue", Vector3.ZERO, &"", 12, -1.0, n) # depósito de agua
	box(Vector3(0.2, 0.08, 0.15), Vector3(0.6, 1.0, 0.1), &"metal", Vector3.ZERO, &"", n)
	box(Vector3(1.8, 0.55, 0.35), Vector3(0, 1.9, -0.12), &"hull_panel", Vector3.ZERO, &"furniture", n) # alacena
	for x: float in [-0.6, 0.0, 0.6]:
		box(Vector3(0.56, 0.5, 0.01), Vector3(x, 1.9, 0.055), &"plastic", Vector3.ZERO, &"", n)
	# bolsas de raciones sujetas con velcro
	for i in 4:
		box(Vector3(0.12, 0.18, 0.04), Vector3(-0.1 + i * 0.14, 1.06, 0.18), [&"fabric_orange", &"plastic", &"pipe_blue"][i % 3], Vector3(0.1, 0, 0), &"", n)
	return n


func table(pos: Vector3, yaw: float, size := Vector2(1.2, 0.8), stools := 2) -> Node3D:
	var n := _group(pos, yaw, "Table")
	box(Vector3(size.x, 0.05, size.y), Vector3(0, 0.74, 0), &"plastic", Vector3.ZERO, &"furniture", n)
	cyl(0.06, 0.72, Vector3(0, 0.36, 0), &"metal", Vector3.ZERO, &"", 10, -1.0, n)
	cyl(0.3, 0.03, Vector3(0, 0.015, 0), &"frame", Vector3.ZERO, &"", 12, -1.0, n)
	for i in stools:
		var a := PI * i
		var sp := Vector3(sin(a), 0, cos(a)) * (size.y * 0.5 + 0.35)
		cyl(0.2, 0.06, sp + Vector3(0, 0.46, 0), &"fabric_blue", Vector3.ZERO, &"furniture", 12, -1.0, n)
		collider(Vector3(0.36, 0.45, 0.36), n.position + Basis(Vector3.UP, yaw) * (sp + Vector3(0, 0.23, 0)), &"furniture")
		cyl(0.035, 0.45, sp + Vector3(0, 0.22, 0), &"metal", Vector3.ZERO, &"", 8, -1.0, n)
	# taza y tablet olvidadas sobre la mesa
	cyl(0.04, 0.09, Vector3(0.3, 0.81, 0.1), &"fabric_orange", Vector3.ZERO, &"", 10, -1.0, n)
	box(Vector3(0.24, 0.012, 0.17), Vector3(-0.2, 0.775, -0.05), &"screen_dark", Vector3(0, 0.4, 0), &"", n)
	return n


## Terminal de pared o pie con pantalla de telemetría. Devuelve el Label3D de la pantalla.
func terminal(pos: Vector3, yaw: float, text := "", accent: StringName = &"screen_cyan", standing := true) -> Label3D:
	var n := _group(pos, yaw, "Terminal")
	if standing:
		box(Vector3(0.7, 1.0, 0.45), Vector3(0, 0.5, 0), &"interior_trim", Vector3.ZERO, &"furniture", n)
		box(Vector3(0.72, 0.06, 0.4), Vector3(0, 1.02, 0.05), &"frame", Vector3(-0.3, 0, 0), &"", n)
		box(Vector3(0.5, 0.02, 0.18), Vector3(0, 1.06, 0.1), &"plastic_dark", Vector3(-0.3, 0, 0), &"", n)
	box(Vector3(0.82, 0.55, 0.06), Vector3(0, 1.45 if standing else 0.0, -0.12), &"frame", Vector3.ZERO, &"", n)
	box(Vector3(0.76, 0.49, 0.01), Vector3(0, 1.45 if standing else 0.0, -0.085), &"screen_dark", Vector3.ZERO, &"", n)
	box(Vector3(0.76, 0.03, 0.012), Vector3(0, (1.45 if standing else 0.0) + 0.23, -0.075), accent, Vector3.ZERO, &"", n)
	var l := label(text, Vector3(-0.36, (1.45 if standing else 0.0) + 0.21, -0.07), Vector3.ZERO, 0.0030, Color(0.65, 0.95, 1.0), 240.0, n)
	l.font_size = 20
	return l


## Pantalla de pared grande (telemetría).
func wall_screen(pos: Vector3, yaw: float, size := Vector2(1.4, 0.8), text := "") -> Label3D:
	var n := _group(pos, yaw, "Screen")
	box(Vector3(size.x + 0.08, size.y + 0.08, 0.05), Vector3.ZERO, &"frame", Vector3.ZERO, &"", n)
	box(Vector3(size.x, size.y, 0.01), Vector3(0, 0, 0.03), &"screen_dark", Vector3.ZERO, &"", n)
	box(Vector3(size.x, 0.03, 0.012), Vector3(0, size.y * 0.5 - 0.03, 0.042), &"screen_cyan", Vector3.ZERO, &"", n)
	var l := label(text, Vector3(-size.x * 0.47, size.y * 0.42, 0.05), Vector3.ZERO, 0.0032, Color(0.65, 0.95, 1.0), size.x / 0.0032 * 0.94, n)
	l.font_size = 22
	return l


func crate(pos: Vector3, yaw: float, size := Vector3(0.6, 0.45, 0.6), m: StringName = &"plastic") -> Node3D:
	var n := _group(pos, yaw, "Crate")
	box(size, Vector3(0, size.y * 0.5, 0), m, Vector3.ZERO, &"furniture", n)
	for s: float in [-1.0, 1.0]:
		box(Vector3(size.x + 0.02, 0.04, 0.04), Vector3(0, size.y * 0.5, s * size.z * 0.5), &"frame", Vector3.ZERO, &"", n)
	box(Vector3(size.x * 0.4, 0.06, 0.005), Vector3(0, size.y * 0.7, size.z * 0.5 + 0.003), &"stripe_amber", Vector3.ZERO, &"", n)
	return n


func gas_cylinder(pos: Vector3, m: StringName = &"pipe_white") -> void:
	cyl(0.12, 1.2, pos + Vector3(0, 0.6, 0), m, Vector3.ZERO, &"furniture", 12)
	cyl(0.04, 0.12, pos + Vector3(0, 1.26, 0), &"metal", Vector3.ZERO, &"", 8)


## Tablero de herramientas con siluetas pintadas.
func tool_wall(pos: Vector3, yaw: float, width := 2.0) -> Node3D:
	var n := _group(pos, yaw, "ToolWall")
	box(Vector3(width, 1.1, 0.04), Vector3(0, 1.5, 0), &"interior_trim", Vector3.ZERO, &"", n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 17.0 + pos.z * 3.0)
	for i in int(width / 0.22):
		var x := -width * 0.5 + 0.15 + i * 0.22
		var h := rng.randf_range(0.25, 0.5)
		box(Vector3(0.04, h, 0.03), Vector3(x, 1.5 + rng.randf_range(-0.2, 0.2), 0.04), [&"metal", &"fabric_orange", &"frame", &"stripe_amber"][i % 4], Vector3(0, 0, rng.randf_range(-0.3, 0.3)), &"", n)
	return n


func workbench(pos: Vector3, yaw: float, width := 2.0) -> Node3D:
	var n := _group(pos, yaw, "Workbench")
	box(Vector3(width, 0.08, 0.9), Vector3(0, 0.9, 0), &"metal", Vector3.ZERO, &"furniture", n)
	box(Vector3(width - 0.1, 0.7, 0.8), Vector3(0, 0.45, 0), &"interior_trim", Vector3.ZERO, &"", n)
	for i in 3:
		box(Vector3(width / 3.0 - 0.06, 0.2, 0.02), Vector3(-width / 3.0 + i * width / 3.0, 0.65, 0.41), &"hull_panel", Vector3.ZERO, &"", n)
	# tornillo de banco, soldador y pieza a medio armar
	box(Vector3(0.2, 0.15, 0.25), Vector3(-width * 0.35, 1.02, 0.1), &"frame", Vector3.ZERO, &"", n)
	cyl(0.05, 0.3, Vector3(width * 0.3, 1.0, -0.1), &"stripe_amber", Vector3(0, 0, PI * 0.5), &"", 8, -1.0, n)
	box(Vector3(0.4, 0.1, 0.3), Vector3(0, 0.99, 0), &"metal", Vector3(0, 0.3, 0), &"", n)
	box(Vector3(0.06, 0.4, 0.06), Vector3(width * 0.48, 1.15, -0.4), &"frame", Vector3.ZERO, &"", n)
	box(Vector3(0.3, 0.05, 0.2), Vector3(width * 0.4, 1.35, -0.35), &"light_warm", Vector3.ZERO, &"", n)
	return n


## Rack de equipos con luces de estado.
func rack(pos: Vector3, yaw: float, height := 1.9) -> Node3D:
	var n := _group(pos, yaw, "Rack")
	box(Vector3(0.6, height, 0.7), Vector3(0, height * 0.5, 0), &"frame", Vector3.ZERO, &"furniture", n)
	for i in int(height / 0.18):
		var y := 0.15 + i * 0.18
		box(Vector3(0.54, 0.14, 0.01), Vector3(0, y, 0.355), &"plastic_dark", Vector3.ZERO, &"", n)
		box(Vector3(0.03, 0.03, 0.01), Vector3(0.22, y, 0.362), [&"light_green", &"light_cyan", &"light_amber"][i % 3], Vector3.ZERO, &"", n)
	return n


## Grupo de piezas con su propia transformación (pivote nombrado: piezas móviles separadas).
func _group(pos: Vector3, yaw: float, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	g.position = pos
	g.rotation.y = yaw
	root.add_child(g)
	return g


func group(pos: Vector3, yaw: float, n: String, parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.name = n
	g.position = pos
	g.rotation.y = yaw
	(parent if parent else root).add_child(g)
	return g


## Interactuable (Area3D con esfera) ubicado en `pos`.
func interactable(pos: Vector3, action_key: String, display_name: String, radius := 0.6, max_dist := 2.3) -> Interactable:
	var it := Interactable.new()
	it.action_key = action_key
	it.display_name = display_name
	it.max_distance = max_dist
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = radius
	cs.shape = sp
	it.add_child(cs)
	it.position = pos
	root.add_child(it)
	return it


# --- Optimización: fusión de mallas estáticas -------------------------------------

## Marca un nodo como móvil/interactivo: sus mallas no se fusionan.
static func mark_dynamic(n: Node) -> Node:
	n.set_meta(&"dynamic", true)
	return n


## Fusiona todas las piezas fijas en una malla por material (y por rango de detalle),
## dejando aparte las marcadas como dinámicas. Reduce cientos de llamadas de dibujo
## por módulo a unas pocas decenas. Se llama al terminar de armar el módulo.
func finalize() -> void:
	_sharpen_labels()
	if Array(OS.get_cmdline_user_args()).has("audit_float"):
		_audit_floating()
	var groups := {}
	var to_free: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or _is_dynamic(mi):
			continue
		if not mi.visible:
			to_free.append(mi)
			continue
		var m := mi.material_override
		var is_detail := mi.visibility_range_end > 0.0 and mi.visibility_range_end <= DETAIL_RANGE + 0.1
		var key := "%d_%s_%d" % [m.get_instance_id() if m else 0, is_detail, mi.cast_shadow]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"st": st, "mat": m, "detail": is_detail, "shadow": mi.cast_shadow, "range": mi.visibility_range_end}
		(groups[key].st as SurfaceTool).append_from(mi.mesh, 0, _relative(mi))
		to_free.append(mi)
	for k: String in groups:
		var g: Dictionary = groups[k]
		var out := MeshInstance3D.new()
		out.name = "Merged_%s" % (g.mat.resource_name if g.mat else "none")
		out.mesh = (g.st as SurfaceTool).commit()
		out.material_override = g.mat
		out.cast_shadow = g.shadow
		out.visibility_range_end = g.range
		out.visibility_range_end_margin = 4.0 if g.detail else 30.0
		root.add_child(out)
	for mi in to_free:
		mi.get_parent().remove_child(mi)
		mi.free()


## Textos 3D nítidos: misma medida en el mundo, pero la fuente se rasteriza al doble
## de resolución, con un contorno oscuro fino y recorte alfa (sin bordes borrosos).
func _sharpen_labels() -> void:
	for n in root.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l.has_meta(&"sharp"):
			continue
		l.set_meta(&"sharp", true)
		l.font_size *= 2
		l.pixel_size *= 0.5
		l.width *= 2.0
		l.outline_size = maxi(4, l.font_size / 12)
		l.outline_modulate = Color(0.0, 0.0, 0.0, 0.6)
		l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Revisión (solo con `-- audit_float`): lista las piezas que no tocan ninguna otra
## pieza ni el suelo, es decir, que quedaron flotando.
func _audit_floating() -> void:
	var boxes: Array[AABB] = []
	var names: Array[String] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		boxes.append(_relative(mi) * mi.mesh.get_aabb())
		names.append("%s/%s" % [mi.get_parent().name, mi.material_override.resource_name if mi.material_override else "?"])
	for cs in root.find_children("*", "CollisionShape3D", true, false):
		var b := cs as CollisionShape3D
		if b.shape is BoxShape3D:
			var sz := (b.shape as BoxShape3D).size
			boxes.append(b.transform * AABB(-sz * 0.5, sz))
			names.append("")
	var region := root.get_tree().get_first_node_in_group(&"world_region") as MoonRegion if root.is_inside_tree() else null
	for i in boxes.size():
		if names[i] == "":
			continue
		var a := boxes[i].grow(0.04)
		var touching := false
		for j in boxes.size():
			if j != i and a.intersects(boxes[j]):
				touching = true
				break
		if touching:
			continue
		var bottom_w := root.global_transform * Vector3(a.get_center().x, a.position.y, a.get_center().z) if root.is_inside_tree() else Vector3.ZERO
		if region:
			var h := region.get_height(bottom_w)
			if is_finite(h) and bottom_w.y <= h + 0.08:
				continue
		print("FLOAT %s %s center=%s size=%s" % [root.name, names[i], boxes[i].get_center(), boxes[i].size])


func _is_dynamic(n: Node) -> bool:
	while n and n != root:
		if n.has_meta(&"dynamic"):
			return true
		n = n.get_parent()
	return false


func _relative(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
