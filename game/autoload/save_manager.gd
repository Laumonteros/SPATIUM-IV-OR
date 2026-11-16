extends Node
## Guardado y carga de partidas (manual, rápido y automático).
##
## Protocolo "Saveable": cualquier nodo en el grupo `GROUP` que implemente
##   get_save_id() -> String          (único y estable)
##   save_state() -> Dictionary        (solo tipos JSON: usar los helpers vec3/…)
##   load_state(data: Dictionary)
## participa automáticamente. Los sistemas que crean entidades en tiempo de
## ejecución (p. ej. construcción) guardan la lista y las recrean al cargar.
##
## Formato: JSON versionado en `user://saves/<slot>.json`, escrito de forma
## atómica (archivo temporal + renombrado) para no corromper partidas.

const GROUP := &"saveable"
const SAVE_DIR := "user://saves"
const FORMAT_VERSION := 1
const AUTOSAVE_SLOT := "autosave"
const QUICKSAVE_SLOT := "quicksave"

var save_dir := SAVE_DIR
var _autosave_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_on_autosave)
	add_child(_autosave_timer)
	EventBus.settings_changed.connect(_on_settings_changed)
	_restart_autosave()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_playing:
		return
	if event.is_action_pressed(&"ui_quick_save"):
		save_slot(QUICKSAVE_SLOT)
	elif event.is_action_pressed(&"ui_quick_load") and has_slot(QUICKSAVE_SLOT):
		load_slot(QUICKSAVE_SLOT)


func save_slot(slot: String) -> Error:
	var payload := {
		"format_version": FORMAT_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": Time.get_datetime_string_from_system(true),
		"playtime_seconds": GameState.playtime_seconds,
		"body": String(GameState.current_body),
		"data": collect_state(),
	}
	DirAccess.make_dir_recursive_absolute(save_dir)
	var final_path := _slot_path(slot)
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return _fail(slot, FileAccess.get_open_error())
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp_path, final_path)
	if err != OK:
		return _fail(slot, err)
	EventBus.game_saved.emit(slot)
	return OK


func load_slot(slot: String) -> Error:
	var payload := read_slot(slot)
	if payload.is_empty():
		return _fail(slot, ERR_FILE_CORRUPT)
	if int(payload.get("format_version", 0)) > FORMAT_VERSION:
		return _fail(slot, ERR_FILE_UNRECOGNIZED)
	apply_state(payload.get("data", {}))
	EventBus.game_loaded.emit(slot)
	return OK


## Lee y valida un archivo de partida; devuelve {} si no existe o está dañado.
func read_slot(slot: String) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("SaveManager: JSON inválido en %s (línea %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: String) -> Error:
	if not has_slot(slot):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(_slot_path(slot))


## Lista de partidas con metadatos, de la más reciente a la más antigua.
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var slot := file.get_basename()
		var p := read_slot(slot)
		if p.is_empty():
			continue
		out.append({"slot": slot, "saved_at": p.get("saved_at", ""),
			"playtime_seconds": p.get("playtime_seconds", 0.0), "body": p.get("body", "")})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.saved_at) > str(b.saved_at))
	return out


func collect_state() -> Dictionary:
	var data := {}
	for node in get_tree().get_nodes_in_group(GROUP):
		var sid: String = node.call("get_save_id")
		if data.has(sid):
			push_error("SaveManager: save_id duplicado '%s'." % sid)
			continue
		data[sid] = node.call("save_state")
	return data


func apply_state(data: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group(GROUP):
		var sid: String = node.call("get_save_id")
		if data.has(sid):
			node.call("load_state", data[sid])


# --- Helpers de serialización JSON ------------------------------------------

static func vec3_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func arr_to_vec3(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


# --- Interno ----------------------------------------------------------------

func _slot_path(slot: String) -> String:
	return save_dir.path_join(slot.validate_filename() + ".json")


func _fail(slot: String, err: Error) -> Error:
	var reason := error_string(err)
	push_warning("SaveManager: falló '%s': %s" % [slot, reason])
	EventBus.save_failed.emit(slot, reason)
	return err


func _restart_autosave() -> void:
	var minutes := float(Settings.get_value("game", "autosave_minutes"))
	if minutes <= 0.0:
		_autosave_timer.stop()
		return
	_autosave_timer.start(minutes * 60.0)


func _on_autosave() -> void:
	if GameState.is_playing and not get_tree().paused:
		save_slot(AUTOSAVE_SLOT)


func _on_settings_changed(section: String, key: String, _value: Variant) -> void:
	if section == "game" and key == "autosave_minutes":
		_restart_autosave()
