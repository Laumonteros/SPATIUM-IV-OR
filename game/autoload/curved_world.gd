extends Node
## Curvatura de planeta pequeño (estilo Astroneer) por deformación de vértices.
##
## Todo lo que se dibuja baja según su distancia horizontal a la cámara:
##   caída = d² / (2·R)
## así el suelo "se aleja" hacia el horizonte y se ve la curvatura del cuerpo
## celeste. Es solo visual: la física y las colisiones siguen planas (cerca del
## astronauta la diferencia es de centímetros), como en otros juegos de mundo
## curvo. R es un VALOR DE JUEGO: la Luna real tiene 1.737 km de radio y con ese
## valor la curvatura no se notaría a escala humana.
##
## Cómo funciona: cada StandardMaterial3D se convierte, una vez, en un
## ShaderMaterial equivalente (systems/visual/curved_standard.gdshaderinc) que
## incluye la caída en vertex(). El terreno (Terrain3D) recibe la misma caída en
## su shader. Los nodos del grupo `flat`, las partículas y los textos 3D no se tocan.

const PLANET_RADIUS_M := 1000.0
const GLOBAL_PARAM := &"planet_curvature"

var enabled := false
var _converted: Dictionary = {} # instance_id del material original -> ShaderMaterial
var _shaders: Dictionary = {} # variante -> Shader
var _supported := false


func _ready() -> void:
	# Sin renderizador real (tests headless) no se convierte nada.
	_supported = DisplayServer.get_name() != "headless"
	RenderingServer.global_shader_parameter_set(GLOBAL_PARAM, 0.0)


## Activa la curvatura (al empezar a jugar; la intro se ve plana).
func set_enabled(on: bool) -> void:
	if not _supported:
		return
	enabled = on
	RenderingServer.global_shader_parameter_set(GLOBAL_PARAM, 1.0 / (2.0 * PLANET_RADIUS_M) if on else 0.0)
	if on:
		_convert_tree(get_tree().root)
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)


## Caída visual (m) a una distancia horizontal dada.
static func drop_at(distance_m: float) -> float:
	return distance_m * distance_m / (2.0 * PLANET_RADIUS_M)


func _on_node_added(n: Node) -> void:
	if n is Label3D:
		_register_label.call_deferred(n)
	elif n is GeometryInstance3D:
		_convert_node.call_deferred(n)


# Los textos 3D no pasan por el shader: se bajan cada cuadro con la misma caída.
var _labels: Dictionary = {} # Label3D -> posición local original


func _register_label(l: Label3D) -> void:
	if is_instance_valid(l) and l.is_inside_tree() and not _labels.has(l) and not _is_flat(l):
		_labels[l] = l.position


func _process(_delta: float) -> void:
	if not enabled or _labels.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var k := 1.0 / (2.0 * PLANET_RADIUS_M)
	for l: Label3D in _labels.keys():
		if not is_instance_valid(l):
			_labels.erase(l)
			continue
		if not l.is_visible_in_tree():
			continue
		var base: Vector3 = _labels[l]
		var parent := l.get_parent() as Node3D
		var world := parent.global_transform * base if parent else base
		var d := Vector2(world.x - c.x, world.z - c.z)
		var drop := d.length_squared() * k
		l.position = base + (parent.global_basis.inverse() * Vector3(0, -drop, 0) if parent else Vector3(0, -drop, 0))


func _convert_tree(root: Node) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		if n is Label3D:
			_register_label(n)
		else:
			_convert_node(n)


func _is_flat(n: Node) -> bool:
	while n:
		if n.is_in_group(&"flat"):
			return true
		n = n.get_parent()
	return false


func _convert_node(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	if n is Label3D or n is SpriteBase3D or n is GPUParticles3D or n is CPUParticles3D or _is_flat(n):
		return
	var gi := n as GeometryInstance3D
	if gi.material_override:
		gi.material_override = convert_material(gi.material_override)
		return
	if gi is MeshInstance3D:
		var mi := gi as MeshInstance3D
		if mi.mesh == null:
			return
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m:
				mi.set_surface_override_material(i, convert_material(m))
	elif gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		if mm and mm.mesh and mm.mesh.get_surface_count() == 1 and mm.mesh.surface_get_material(0):
			gi.material_override = convert_material(mm.mesh.surface_get_material(0))


## Devuelve una versión curvada del material (cacheada). Si no corresponde, el original.
func convert_material(m: Material) -> Material:
	if not _supported or m == null or not (m is BaseMaterial3D):
		return m
	var key := m.get_instance_id()
	if _converted.has(key):
		return _converted[key]
	var b := m as BaseMaterial3D
	if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return m # partículas y carteles: sin curvatura
	var tri := b.uv1_triplanar
	var transparent := b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and b.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var unshaded := b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	var variant := "%d_%d_%d_%d_%d" % [int(tri), int(transparent), int(unshaded), b.cull_mode, b.transparency]
	var shader: Shader = _shaders.get(variant)
	if shader == null:
		shader = _make_shader(tri, transparent, unshaded, b.cull_mode, b.transparency)
		_shaders[variant] = shader
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.resource_name = b.resource_name
	sm.render_priority = b.render_priority
	sm.set_shader_parameter("albedo", b.albedo_color)
	sm.set_shader_parameter("use_albedo_texture", b.albedo_texture != null)
	if b.albedo_texture:
		sm.set_shader_parameter("texture_albedo", b.albedo_texture)
	sm.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
	sm.set_shader_parameter("roughness", b.roughness)
	sm.set_shader_parameter("use_roughness_texture", b.roughness_texture != null)
	if b.roughness_texture:
		sm.set_shader_parameter("texture_roughness", b.roughness_texture)
		var ch: Array[Vector4] = [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0.333, 0.333, 0.333, 0)]
		sm.set_shader_parameter("roughness_channel", ch[clampi(b.roughness_texture_channel, 0, 4)])
	sm.set_shader_parameter("metallic", b.metallic)
	sm.set_shader_parameter("specular", b.metallic_specular)
	var has_normal := b.normal_enabled and b.normal_texture != null
	sm.set_shader_parameter("use_normal", has_normal)
	if has_normal:
		sm.set_shader_parameter("texture_normal", b.normal_texture)
		sm.set_shader_parameter("normal_scale", b.normal_scale)
	if b.emission_enabled:
		sm.set_shader_parameter("emission", Color(b.emission.r, b.emission.g, b.emission.b))
		sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	sm.set_shader_parameter("uv1_scale", b.uv1_scale)
	sm.set_shader_parameter("uv1_offset", b.uv1_offset)
	sm.set_shader_parameter("triplanar_sharpness", b.uv1_triplanar_sharpness)
	_converted[key] = sm
	return sm


func _make_shader(tri: bool, transparent: bool, unshaded: bool, cull: int, transparency: int) -> Shader:
	var culls: Array[String] = ["cull_back", "cull_front", "cull_disabled"]
	var modes: PackedStringArray = ["blend_mix", culls[clampi(cull, 0, 2)]]
	if unshaded:
		modes.append("unshaded")
	if transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		modes.append("depth_prepass_alpha")
	var code := "shader_type spatial;\nrender_mode %s;\n" % ", ".join(modes)
	if tri:
		code += "#define TRIPLANAR\n"
	if transparent:
		code += "#define TRANSPARENT\n"
	if unshaded:
		code += "#define UNSHADED\n"
	code += "#include \"res://systems/visual/curved_standard.gdshaderinc\"\n"
	var sh := Shader.new()
	sh.code = code
	return sh


## Curvatura del terreno Terrain3D: misma caída, aplicada en coordenadas de mundo
## antes de pasar a espacio de vista (su shader usa skip_vertex_transform).
func curve_terrain(terrain: Node) -> void:
	if not _supported or terrain == null:
		return
	var mat: Object = terrain.get("material")
	if mat == null:
		return
	var code := RenderingServer.shader_get_code(mat.call("get_shader_rid"))
	var target := "VERTEX = (VIEW_MATRIX * vec4(v_vertex + displacement, 1.0)).xyz;"
	if code == "" or not (target in code):
		push_warning("CurvedWorld: no se pudo adaptar el shader del terreno.")
		return
	if not ("planet_curvature" in code):
		var nl := code.find("\n", code.find("shader_type"))
		code = code.substr(0, nl + 1) + "global uniform float planet_curvature;\n" + code.substr(nl + 1)
		code = code.replace(target, "{ vec2 _cw_d = v_vertex.xz - v_camera_pos.xz; displacement.y -= dot(_cw_d, _cw_d) * planet_curvature; }\n " + target)
	var sh := Shader.new()
	sh.code = code
	mat.set("shader_override", sh)
	mat.set("shader_override_enabled", true)
	# el terreno se deforma hacia abajo: margen de culling para que no desaparezca
	if "cull_margin" in terrain:
		terrain.set("cull_margin", 300.0)
