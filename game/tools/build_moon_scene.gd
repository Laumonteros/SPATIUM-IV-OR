extends SceneTree
## Genera (una sola vez) la escena base de la Región Lunar 01 y su Environment.
## Después de generada, la escena se edita normalmente en el editor de Godot.
##   Godot_console.exe --headless --path . -s res://tools/build_moon_scene.gd [-- --force]

const SCENE_PATH := "res://worlds/moon/moon_region_01.tscn"
const ENV_PATH := "res://worlds/moon/moon_environment.tres"
const SKY_SHADER := "res://worlds/common/sky/space_sky.gdshader"

## Sol bajo (14° de elevación) desde el este: sombras largas, típico de latitudes altas.
const SUN_ELEVATION_DEG := 14.0
const SUN_AZIMUTH_DEG := 75.0   # 0 = norte (-Z), 90 = este (+X)
## Tierra alta en el cielo hacia el suroeste.
const EARTH_ELEVATION_DEG := 32.0
const EARTH_AZIMUTH_DEG := 215.0


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	if ResourceLoader.exists(SCENE_PATH) and not force:
		print("La escena ya existe; usar -- --force para regenerarla.")
		quit()
		return

	var env := _make_environment()
	ResourceSaver.save(env, ENV_PATH)
	env = load(ENV_PATH)

	var root := Node3D.new()
	root.name = "MoonRegion01"
	root.set_script(load("res://worlds/moon/moon_region.gd"))

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.set_script(load("res://worlds/common/environment_controller.gd"))
	we.environment = env
	_add(root, we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.light_energy = 2.4
	sun.light_angular_distance = 0.53 # tamaño angular real del Sol: sombras con penumbra correcta
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 350.0
	sun.directional_shadow_blend_splits = true
	sun.basis = _basis_looking(_dir_from(SUN_ELEVATION_DEG, SUN_AZIMUTH_DEG) * -1.0)
	_add(root, sun)

	var terrain: Terrain3D = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.data_directory = "res://worlds/moon/terrain_data"
	terrain.assets = load("res://worlds/moon/moon_terrain_assets.tres")
	terrain.material = load("res://worlds/moon/moon_terrain_material.tres")
	terrain.collision_mask = 0
	terrain.collision_layer = 1
	_add(root, terrain)

	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0.0, 1.2, 0.0)
	_add(root, spawn)

	root.set("terrain", terrain)
	root.set("player_spawn", spawn)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, SCENE_PATH)
	print(("Escena guardada: " if err == OK else "ERROR: ") + SCENE_PATH)
	root.free()
	quit()


func _make_environment() -> Environment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER)
	sky_mat.set_shader_parameter("star_map", load("res://assets/textures/sky/nasa_starmap_2020_4k.png"))
	sky_mat.set_shader_parameter("planet_day", load("res://assets/textures/sky/earth_daymap_2k.jpg"))
	sky_mat.set_shader_parameter("planet_clouds", load("res://assets/textures/sky/earth_clouds_2k.jpg"))
	sky_mat.set_shader_parameter("planet_direction", _dir_from(EARTH_ELEVATION_DEG, EARTH_AZIMUTH_DEG))
	sky_mat.set_shader_parameter("star_rotation", Vector3(0.4, 0.0, 0.25))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_64

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Sin atmósfera: la luz ambiente es casi nula (solo reflejo de la Tierra y del suelo).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.12
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = false
	return env


func _dir_from(elev_deg: float, az_deg: float) -> Vector3:
	var e := deg_to_rad(elev_deg)
	var a := deg_to_rad(az_deg)
	# az 0 = norte (-Z), 90 = este (+X)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e)).normalized()


func _basis_looking(forward: Vector3) -> Basis:
	return Basis.looking_at(forward, Vector3.UP)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = parent
