extends GutTest

const TMP := "user://test_settings.cfg"


func before_each() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)
	Settings.load_settings(TMP)


func after_all() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)
	Settings.load_settings(Settings.DEFAULT_PATH)
	Settings.apply_all()


func test_defaults_when_file_missing() -> void:
	assert_eq(Settings.get_preset(), Settings.GraphicsPreset.MEDIUM)
	assert_almost_eq(float(Settings.get_value("controls", "mouse_sensitivity")), 0.25, 0.0001)


func test_every_preset_has_full_profile() -> void:
	var keys := (Settings.PRESET_PROFILES[Settings.GraphicsPreset.MEDIUM] as Dictionary).keys()
	for preset: int in Settings.GraphicsPreset.values():
		assert_true(Settings.PRESET_PROFILES.has(preset), "falta preset %d" % preset)
		for k: String in keys:
			assert_true((Settings.PRESET_PROFILES[preset] as Dictionary).has(k), "preset %d sin '%s'" % [preset, k])


func test_value_persists_to_disk() -> void:
	Settings.set_value("audio", "Music", 0.3)
	Settings.load_settings(TMP)
	assert_almost_eq(float(Settings.get_value("audio", "Music")), 0.3, 0.0001)


func test_audio_volume_applied_to_bus() -> void:
	Settings.set_value("audio", "SFX", 0.5, false)
	var idx := AudioServer.get_bus_index(&"SFX")
	assert_gt(idx, -1, "existe el bus SFX")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.01)


func test_change_emits_signal() -> void:
	watch_signals(EventBus)
	Settings.set_value("graphics", "preset", Settings.GraphicsPreset.LOW, false)
	assert_signal_emitted(EventBus, "graphics_preset_changed")
	assert_eq(Settings.get_preset(), Settings.GraphicsPreset.LOW)
