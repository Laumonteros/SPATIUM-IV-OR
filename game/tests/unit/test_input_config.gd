extends GutTest

const TMP := "user://test_input_settings.cfg"


func before_each() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)
	Settings.load_settings(TMP)
	InputConfig.register_defaults()


func after_all() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)
	Settings.load_settings(Settings.DEFAULT_PATH)
	InputConfig.register_defaults()
	InputConfig.apply_overrides()


func test_all_design_controls_exist() -> void:
	# Controles de la sección 6 del documento de diseño + decisiones C2.
	var expected := {&"move_forward": KEY_W, &"move_back": KEY_S, &"move_left": KEY_A,
		&"move_right": KEY_D, &"jump": KEY_SPACE, &"sprint": KEY_SHIFT, &"interact": KEY_E,
		&"flashlight": KEY_F, &"inventory": KEY_TAB, &"build_mode": KEY_B, &"map": KEY_M,
		&"pause": KEY_ESCAPE, &"scan": KEY_Q, &"encyclopedia": KEY_J}
	for action: StringName in expected:
		assert_true(InputMap.has_action(action), "falta acción %s" % action)
		assert_eq(_first_key(action), expected[action], "tecla de %s" % action)


func test_every_movement_action_has_gamepad() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"interact"]:
		var has_pad := InputMap.action_get_events(action).any(
			func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		assert_true(has_pad, "%s sin control de mando" % action)


func test_no_key_conflicts() -> void:
	var seen := {}
	for action: StringName in InputConfig.DEFAULT_BINDINGS:
		var k := _first_key(action)
		if k == KEY_NONE:
			continue
		assert_false(seen.has(k), "tecla %s repetida en %s y %s" % [OS.get_keycode_string(k), action, seen.get(k)])
		seen[k] = action


func test_rebind_persists_and_reset_restores() -> void:
	InputConfig.rebind_key(&"jump", KEY_G)
	assert_eq(_first_key(&"jump"), KEY_G)
	InputConfig.register_defaults()
	InputConfig.apply_overrides()
	assert_eq(_first_key(&"jump"), KEY_G, "la reasignación sobrevive a recargar")
	InputConfig.reset_to_defaults()
	assert_eq(_first_key(&"jump"), KEY_SPACE)


func _first_key(action: StringName) -> Key:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE
