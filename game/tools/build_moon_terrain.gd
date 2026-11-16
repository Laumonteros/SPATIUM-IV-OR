extends SceneTree
## Construye los datos de Terrain3D de la Región Lunar 01 a partir del heightmap.
##
## Uso (desde game/):
##   Godot_console.exe --headless --path . -s res://tools/build_moon_terrain.gd -- <ruta_al_exr>
## El heightmap se genera con tools/generate_moon_region.py (Blender).
## Salidas: res://worlds/moon/terrain_data/ (regiones), *_assets.tres y *_material.tres.

const OUT_DIR := "res://worlds/moon/terrain_data"
const ASSETS_PATH := "res://worlds/moon/moon_terrain_assets.tres"
const MATERIAL_PATH := "res://worlds/moon/moon_terrain_material.tres"
const MAP_SIZE := 2048
const TEXTURES := [
	{"name": "Regolito", "base": "res://assets/textures/terrain/moon_regolith", "uv_scale": 0.22},
	{"name": "Roca y eyecta", "base": "res://assets/textures/terrain/moon_rocky", "uv_scale": 0.12},
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Falta la ruta del heightmap .exr")
		quit(1)
		return
	_build.call_deferred(args[0])


func _build(exr_path: String) -> void:
	var img := Image.load_from_file(exr_path)
	if img == null or img.is_empty():
		push_error("No se pudo leer %s" % exr_path)
		quit(1)
		return
	img.convert(Image.FORMAT_RF)
	print("Heightmap: %dx%d" % [img.get_width(), img.get_height()])

	var terrain: Terrain3D = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = 1024
	terrain.vertex_spacing = 1.0
	get_root().add_child(terrain)

	var assets := Terrain3DAssets.new()
	for i in TEXTURES.size():
		var t: Dictionary = TEXTURES[i]
		var ta := Terrain3DTextureAsset.new()
		ta.name = t.name
		ta.albedo_texture = load(t.base + "_alb_h.png")
		ta.normal_texture = load(t.base + "_nrm_r.png")
		ta.uv_scale = t.uv_scale
		ta.detiling_rotation = 0.35
		ta.detiling_shift = 0.25
		assets.set_texture_asset(i, ta)
	terrain.assets = assets

	var mat := terrain.material
	mat.auto_shader_enabled = true
	mat.world_background = 0  # NONE: fuera del mapa no hay terreno
	mat.set_shader_param("auto_base_texture", 0)
	mat.set_shader_param("auto_overlay_texture", 1)
	mat.set_shader_param("auto_slope", 2.2)
	mat.set_shader_param("auto_height_reduction", 0.0)
	mat.set_shader_param("blend_sharpness", 0.75)
	mat.set_shader_param("macro_variation1", Color(0.93, 0.92, 0.9))
	mat.set_shader_param("macro_variation2", Color(1.0, 0.98, 0.95))

	var half := MAP_SIZE / 2.0
	var images: Array[Image] = [img, null, null]
	terrain.data.import_images(images, Vector3(-half, 0.0, -half), 0.0, 1.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	terrain.data.save_directory(OUT_DIR)
	_check(ResourceSaver.save(assets, ASSETS_PATH), ASSETS_PATH)
	_check(ResourceSaver.save(mat, MATERIAL_PATH), MATERIAL_PATH)
	print("Regiones: %d · altura en el centro: %.2f m" % [terrain.data.get_region_count(), terrain.data.get_height(Vector3.ZERO)])
	quit()


func _check(err: Error, path: String) -> void:
	print(("Guardado " if err == OK else "ERROR al guardar ") + path)
