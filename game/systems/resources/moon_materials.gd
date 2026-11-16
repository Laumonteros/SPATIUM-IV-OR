class_name MoonMaterials
extends RefCounted
## Materiales compartidos de superficie lunar para rocas y depósitos.
## Las rocas no tienen UV: se texturizan con proyección triplanar (sin costuras).

const ROCK_ALBEDO := "res://assets/textures/terrain/moon_rocky_alb_h.png"
const ROCK_NORMAL := "res://assets/textures/terrain/moon_rocky_nrm_r.png"
const FINE_ALBEDO := "res://assets/textures/terrain/moon_regolith_alb_h.png"
const FINE_NORMAL := "res://assets/textures/terrain/moon_regolith_nrm_r.png"

## Nombres de material del GLB que se reemplazan por la versión triplanar.
const OVERRIDES := {
	"MoonRock": {"fine": false, "tint": Color(0.82, 0.8, 0.77), "scale": 0.9},
	"IlmeniteBasalt": {"fine": false, "tint": Color(0.46, 0.46, 0.49), "scale": 1.3},
	"BrecciaSample": {"fine": false, "tint": Color(0.9, 0.85, 0.78), "scale": 2.6},
	"RegolithFine": {"fine": true, "tint": Color(0.86, 0.84, 0.8), "scale": 0.8},
}

static var _cache: Dictionary = {}


static func get_material(gltf_name: String) -> Material:
	if not OVERRIDES.has(gltf_name):
		return null
	if _cache.has(gltf_name):
		return _cache[gltf_name]
	var cfg: Dictionary = OVERRIDES[gltf_name]
	var m := StandardMaterial3D.new()
	m.resource_name = gltf_name + "_Triplanar"
	m.albedo_texture = load(FINE_ALBEDO if cfg.fine else ROCK_ALBEDO)
	m.albedo_color = cfg.tint
	m.normal_enabled = true
	m.normal_texture = load(FINE_NORMAL if cfg.fine else ROCK_NORMAL)
	m.normal_scale = 1.2
	m.roughness_texture = m.normal_texture
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * float(cfg.scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[gltf_name] = m
	return m


## Reemplaza los materiales de roca de todas las mallas bajo `root`.
static func apply(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var repl := get_material(src.resource_name)
			if repl:
				mi.set_surface_override_material(i, repl)


## Primera malla encontrada dentro de una escena importada (para MultiMesh y colisiones).
static func first_mesh(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() > 0 else null
	inst.free()
	return mesh
