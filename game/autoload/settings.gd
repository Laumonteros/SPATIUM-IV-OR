extends Node
## Configuración persistente del jugador (gráficos, audio, controles, idioma).
##
## Se guarda en `user://settings.cfg`, separado de las partidas. Los valores de
## entorno que dependen de la escena (SSAO, reflejos, niebla) no se aplican acá:
## cada `WorldEnvironment` consulta `get_environment_profile()` y escucha
## `EventBus.graphics_preset_changed`.

enum GraphicsPreset { LOW, MEDIUM, HIGH }

const DEFAULT_PATH := "user://settings.cfg"

const DEFAULTS := {
	"graphics": {
		"preset": GraphicsPreset.MEDIUM,
		"fullscreen": false,
		"vsync": true,
		"max_fps": 0,
	},
	"audio": {
		"Master": 1.0,
		"Music": 0.7,
		"SFX": 0.9,
		"Suit": 0.9,
		"Ambient": 0.8,
		"UI": 0.8,
	},
	"controls": {
		"mouse_sensitivity": 0.25,
		"gamepad_sensitivity": 3.0,
		"invert_y": false,
	},
	"game": {
		"locale": "es",
		"autosave_minutes": 5,
		"evaluator_mode": false,
	},
}

## Parámetros por preset. Referencia mínima: Ryzen 3 5300G (Radeon integrada).
const PRESET_PROFILES := {
	GraphicsPreset.LOW: {
		"render_scale": 0.6, "scaling_mode": Viewport.SCALING_3D_MODE_FSR,
		"msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"terrain_mesh": 24, "shadow_size": 2048, "shadow_splits": 2, "shadow_distance": 160.0, "soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"ssao": false, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "ssr": false, "glow": true, "volumetric_fog": false,
		"particle_scale": 0.5, "lod_threshold": 2.0,
	},
	GraphicsPreset.MEDIUM: {
		"render_scale": 0.7, "scaling_mode": Viewport.SCALING_3D_MODE_FSR,
		"msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"terrain_mesh": 32, "shadow_size": 4096, "shadow_splits": 2, "shadow_distance": 220.0, "soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": false, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "ssr": false, "glow": true, "volumetric_fog": false,
		"particle_scale": 0.8, "lod_threshold": 1.0,
	},
	GraphicsPreset.HIGH: {
		"render_scale": 1.0, "scaling_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"msaa": Viewport.MSAA_2X, "fxaa": false,
		"terrain_mesh": 48, "shadow_size": 8192, "shadow_splits": 4, "shadow_distance": 400.0, "soft_shadow_quality": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"ssao": true, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssr": true, "glow": true, "volumetric_fog": true,
		"particle_scale": 1.0, "lod_threshold": 0.75,
	},
}

var _config := ConfigFile.new()
var _path := DEFAULT_PATH


func _ready() -> void:
	load_settings()
	_auto_detect_preset()
	apply_all()


## Primera ejecución: GPU integrada -> Bajo (~70 fps a 1080p en el equipo de
## referencia); GPU dedicada -> Medio. Si el jugador ya eligió, se respeta.
func _auto_detect_preset() -> void:
	if _config.has_section_key("graphics", "preset") or DisplayServer.get_name() == "headless":
		return
	var integrated := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	_config.set_value("graphics", "preset", GraphicsPreset.LOW if integrated else GraphicsPreset.MEDIUM)


## Carga la configuración; si no existe, quedan los valores por defecto.
func load_settings(path: String = DEFAULT_PATH) -> void:
	_path = path
	_config = ConfigFile.new()
	var err := _config.load(_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: no se pudo leer %s (error %d); se usan valores por defecto." % [_path, err])
		_config = ConfigFile.new()


func save_settings() -> Error:
	return _config.save(_path)


func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = (DEFAULTS.get(section, {}) as Dictionary).get(key)
	return _config.get_value(section, key, fallback)


## Cambia un valor, lo aplica en caliente si corresponde y lo persiste.
func set_value(section: String, key: String, value: Variant, persist: bool = true) -> void:
	_config.set_value(section, key, value)
	_apply_one(section, key)
	EventBus.settings_changed.emit(section, key, value)
	if persist:
		save_settings()


## Acceso directo al ConfigFile para módulos con secciones propias (p. ej. InputConfig).
func get_config() -> ConfigFile:
	return _config


func get_preset() -> int:
	return int(get_value("graphics", "preset"))


func get_environment_profile() -> Dictionary:
	return PRESET_PROFILES.get(get_preset(), PRESET_PROFILES[GraphicsPreset.MEDIUM])


func apply_all() -> void:
	_apply_graphics()
	_apply_window()
	for bus_name: String in (DEFAULTS["audio"] as Dictionary):
		_apply_audio(bus_name)
	TranslationServer.set_locale(str(get_value("game", "locale")))


func _apply_one(section: String, key: String) -> void:
	match section:
		"graphics":
			if key == "preset":
				_apply_graphics()
			else:
				_apply_window()
		"audio":
			_apply_audio(key)
		"game":
			if key == "locale":
				TranslationServer.set_locale(str(get_value("game", "locale")))


func _apply_graphics() -> void:
	var p := get_environment_profile()
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = p["scaling_mode"]
		vp.scaling_3d_scale = p["render_scale"]
		vp.msaa_3d = p["msaa"]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.mesh_lod_threshold = p["lod_threshold"]
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	RenderingServer.environment_set_ssao_quality(p["ssao_quality"], true, 0.5, 2, 50.0, 300.0)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["soft_shadow_quality"])
	EventBus.graphics_preset_changed.emit(get_preset())


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen := bool(get_value("graphics", "fullscreen"))
	if OS.is_debug_build() and Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("autopilot=") or a == "capture"):
		fullscreen = false # capturas automáticas: siempre en ventana
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(get_value("graphics", "vsync")) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(get_value("graphics", "max_fps"))


func _apply_audio(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var linear := clampf(float(get_value("audio", bus_name)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.0001)
