extends Node
## Mapa de controles de SPATIUM IV, definido como datos.
##
## Registra las acciones por defecto (teclado/mouse + mando) al iniciar y aplica
## las reasignaciones guardadas en `Settings` (sección "bindings").
## Así los controles son reasignables y quedan preparados para mando y móvil.

const SECTION := "bindings"
const STICK_DEADZONE := 0.2

## acción -> { "keys": [Key], "mouse": [MouseButton], "pad_buttons": [JoyButton],
##             "pad_axis": [[JoyAxis, dirección]] }
const DEFAULT_BINDINGS := {
	&"move_forward": {"keys": [KEY_W, KEY_UP], "pad_axis": [[JOY_AXIS_LEFT_Y, -1.0]]},
	&"move_back": {"keys": [KEY_S, KEY_DOWN], "pad_axis": [[JOY_AXIS_LEFT_Y, 1.0]]},
	&"move_left": {"keys": [KEY_A, KEY_LEFT], "pad_axis": [[JOY_AXIS_LEFT_X, -1.0]]},
	&"move_right": {"keys": [KEY_D, KEY_RIGHT], "pad_axis": [[JOY_AXIS_LEFT_X, 1.0]]},
	&"look_up": {"pad_axis": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	&"look_down": {"pad_axis": [[JOY_AXIS_RIGHT_Y, 1.0]]},
	&"look_left": {"pad_axis": [[JOY_AXIS_RIGHT_X, -1.0]]},
	&"look_right": {"pad_axis": [[JOY_AXIS_RIGHT_X, 1.0]]},
	&"jump": {"keys": [KEY_SPACE], "pad_buttons": [JOY_BUTTON_A]},
	&"sprint": {"keys": [KEY_SHIFT], "pad_buttons": [JOY_BUTTON_LEFT_STICK]},
	&"crouch": {"keys": [KEY_C], "pad_buttons": [JOY_BUTTON_RIGHT_STICK]},
	&"interact": {"keys": [KEY_E], "pad_buttons": [JOY_BUTTON_X]},
	&"tool_primary": {"mouse": [MOUSE_BUTTON_LEFT], "pad_axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	&"tool_secondary": {"mouse": [MOUSE_BUTTON_RIGHT]},
	&"scan": {"keys": [KEY_Q], "pad_buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	&"flashlight": {"keys": [KEY_F], "pad_buttons": [JOY_BUTTON_DPAD_UP]},
	&"inventory": {"keys": [KEY_TAB], "pad_buttons": [JOY_BUTTON_Y]},
	&"build_mode": {"keys": [KEY_B], "pad_buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	&"build_rotate_left": {"keys": [KEY_X], "pad_buttons": [JOY_BUTTON_DPAD_LEFT]},
	&"build_rotate_right": {"keys": [KEY_R], "pad_buttons": [JOY_BUTTON_DPAD_RIGHT]},
	&"map": {"keys": [KEY_M], "pad_buttons": [JOY_BUTTON_BACK]},
	&"encyclopedia": {"keys": [KEY_J], "pad_buttons": [JOY_BUTTON_DPAD_DOWN]},
	&"pause": {"keys": [KEY_ESCAPE], "pad_buttons": [JOY_BUTTON_START]},
	&"ui_quick_save": {"keys": [KEY_F5]},
	&"ui_quick_load": {"keys": [KEY_F9]},
}


func _ready() -> void:
	register_defaults()
	apply_overrides()


## Crea (o recrea) todas las acciones con sus controles por defecto.
func register_defaults() -> void:
	for action: StringName in DEFAULT_BINDINGS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, STICK_DEADZONE)
		for ev in _build_events(DEFAULT_BINDINGS[action]):
			InputMap.action_add_event(action, ev)


## Reemplaza la tecla principal de una acción y la persiste.
func rebind_key(action: StringName, keycode: Key) -> void:
	assert(DEFAULT_BINDINGS.has(action), "Acción desconocida: %s" % action)
	_set_primary_key(action, keycode)
	Settings.get_config().set_value(SECTION, String(action), int(keycode))
	Settings.save_settings()


func reset_to_defaults() -> void:
	var cfg := Settings.get_config()
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	Settings.save_settings()
	register_defaults()


func apply_overrides() -> void:
	var cfg := Settings.get_config()
	if not cfg.has_section(SECTION):
		return
	for key in cfg.get_section_keys(SECTION):
		var action := StringName(key)
		if DEFAULT_BINDINGS.has(action):
			_set_primary_key(action, int(cfg.get_value(SECTION, key)) as Key)


## Texto legible de la tecla principal (para HUD e indicadores de interacción).
func get_key_label(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return tr("INPUT_MOUSE_LEFT")
				MOUSE_BUTTON_RIGHT: return tr("INPUT_MOUSE_RIGHT")
	return "?"


func _set_primary_key(action: StringName, keycode: Key) -> void:
	# Reemplaza solo la tecla principal (las alternativas, como las flechas, se conservan)
	var primary: Key = KEY_NONE
	var defaults: Array = DEFAULT_BINDINGS.get(action, {}).get("keys", [])
	if defaults.size() > 0:
		primary = defaults[0]
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := (ev as InputEventKey).physical_keycode
			if k == primary or defaults.size() <= 1 or k not in defaults:
				InputMap.action_erase_event(action, ev)
				break
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = keycode
	InputMap.action_add_event(action, key_ev)


func _build_events(spec: Dictionary) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for k: int in spec.get("keys", []):
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		out.append(ev)
	for b: int in spec.get("mouse", []):
		var ev := InputEventMouseButton.new()
		ev.button_index = b as MouseButton
		out.append(ev)
	for b: int in spec.get("pad_buttons", []):
		var ev := InputEventJoypadButton.new()
		ev.button_index = b as JoyButton
		out.append(ev)
	for pair: Array in spec.get("pad_axis", []):
		var ev := InputEventJoypadMotion.new()
		ev.axis = int(pair[0]) as JoyAxis
		ev.axis_value = float(pair[1])
		out.append(ev)
	return out
