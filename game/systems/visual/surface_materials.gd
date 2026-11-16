class_name SurfaceMaterials
extends RefCounted
## Materiales con detalle de superficie para el astronauta y las estructuras.
## Realismo liviano: solo mapas de normales y rugosidad de 1K (CC0, Poly Haven)
## sobre los colores del modelo, más ruido procedural para la lámina térmica.

const FABRIC_N := "res://assets/textures/detail/denim_fabric_04_nor_gl_1k.jpg"
const FABRIC_R := "res://assets/textures/detail/denim_fabric_04_rough_1k.jpg"

static var _cache: Dictionary = {}
static var _foil_normal: Texture2D
static var _hull_normal: Texture2D
static var _hull_rough: Texture2D


## Reemplaza materiales del GLB según su nombre (los de Blender).
static func apply(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var m := _variant(src)
			if m:
				mi.set_surface_override_material(i, m)


static func _variant(src: BaseMaterial3D) -> Material:
	var key := src.resource_name
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D = null
	match key:
		"SuitBeta", "SuitJoint", "Glove":
			# Tela beta del traje: trama fina (UV de los modelos)
			m = _copy(src)
			m.normal_enabled = true
			m.normal_texture = load(FABRIC_N)
			m.normal_scale = 0.55
			m.roughness_texture = load(FABRIC_R)
			m.roughness = 1.0
			m.uv1_scale = Vector3(7, 7, 7)
		"HullWhite", "HullGrey", "SuitHardShell":
			# Casco compuesto: imperfecciones suaves y rugosidad variable (triplanar)
			m = _copy(src)
			m.normal_enabled = true
			m.normal_texture = _hull()
			m.normal_scale = 0.5
			m.roughness_texture = _hull_rough_tex()
			m.roughness = clampf(src.roughness * 1.3, 0.3, 0.9)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.6, 0.6, 0.6) if key != "SuitHardShell" else Vector3(2.0, 2.0, 2.0)
		"GoldFoil":
			# Lámina térmica (Kapton/MLI): arrugas procedurales
			m = _copy(src)
			m.normal_enabled = true
			m.normal_texture = _foil()
			m.normal_scale = 1.4
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.7, 0.7, 0.7)
			m.metallic = 0.7
			m.roughness = 0.32
	if m:
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cache[key] = m
	return m


static func _copy(src: BaseMaterial3D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = src.resource_name + "_Detail"
	m.albedo_color = src.albedo_color
	m.albedo_texture = src.albedo_texture
	m.metallic = src.metallic
	m.roughness = src.roughness
	m.emission_enabled = src.emission_enabled
	m.emission = src.emission
	m.emission_energy_multiplier = src.emission_energy_multiplier
	return m


static func _foil() -> Texture2D:
	if _foil_normal:
		return _foil_normal
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.035
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	t.noise = n
	_foil_normal = t
	return t


static func _noise_tex(freq: float, octaves: int, normal: bool, strength: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = normal
	t.bump_strength = strength
	t.noise = n
	return t


static func _hull() -> Texture2D:
	if _hull_normal == null:
		_hull_normal = _noise_tex(0.02, 4, true, 2.5)
	return _hull_normal


static func _hull_rough_tex() -> Texture2D:
	if _hull_rough == null:
		_hull_rough = _noise_tex(0.008, 3, false, 0.0)
	return _hull_rough
