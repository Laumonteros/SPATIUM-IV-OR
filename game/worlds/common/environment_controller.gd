class_name EnvironmentController
extends WorldEnvironment
## Aplica al Environment de la escena los efectos que dependen del preset gráfico
## (SSAO, reflejos SSR, brillo, niebla volumétrica) y lo actualiza en caliente.

## Si es false, este escenario nunca usa niebla volumétrica (p. ej. la Luna, sin atmósfera).
@export var allow_volumetric_fog: bool = false


var _sky: ShaderMaterial
var _last_pixel_angle := -1.0


func _ready() -> void:
	_apply(Settings.get_preset())
	EventBus.graphics_preset_changed.connect(_apply)
	if environment and environment.sky:
		_sky = environment.sky.sky_material as ShaderMaterial
		if _sky:
			CelestialCatalog.apply_to_sky(_sky)


## Las estrellas puntuales del cielo necesitan el ángulo de un píxel: cambia con el
## FOV (binoculares, cinemáticas) y con la resolución.
func _process(_delta: float) -> void:
	if _sky == null:
		return
	var cam := get_viewport().get_camera_3d()
	var h := float(get_viewport().get_visible_rect().size.y)
	if cam == null or h <= 0.0:
		return
	var pa := deg_to_rad(cam.fov) / (h * clampf(get_viewport().scaling_3d_scale, 0.25, 2.0))
	if absf(pa - _last_pixel_angle) > _last_pixel_angle * 0.01:
		_last_pixel_angle = pa
		_sky.set_shader_parameter("pixel_angle", pa)


func _apply(_preset: int) -> void:
	if environment == null:
		return
	var p := Settings.get_environment_profile()
	environment.ssao_enabled = p["ssao"]
	environment.ssr_enabled = p["ssr"]
	environment.glow_enabled = p["glow"]
	environment.volumetric_fog_enabled = allow_volumetric_fog and p["volumetric_fog"]
	# Cascadas y distancia de sombra del sol (cada cascada vuelve a dibujar el terreno)
	for light: DirectionalLight3D in get_parent().find_children("*", "DirectionalLight3D", false, false):
		var four := int(p["shadow_splits"]) >= 4
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if four else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = p["shadow_distance"]
	# Densidad de la malla del terreno (clipmap): menos triángulos en presets bajos
	for t: Node in get_parent().find_children("*", "Terrain3D", false, false):
		if int(t.get("mesh_size")) != int(p["terrain_mesh"]):
			t.set("mesh_size", int(p["terrain_mesh"]))
