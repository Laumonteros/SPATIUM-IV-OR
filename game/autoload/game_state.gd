extends Node
## Estado global y liviano de la partida en curso.
##
## Solo guarda lo que no pertenece a ningún sistema concreto: cuerpo celeste
## actual, tiempo jugado y desbloqueos. Inventario, base, misiones, etc. viven
## en sus propios sistemas y se guardan a sí mismos (ver SaveManager).

const SAVE_ID := "game_state"

var current_body: StringName = &"moon"
var playtime_seconds: float = 0.0
var unlocks: Dictionary[StringName, bool] = {}
var is_playing: bool = false
## Partida con tutorial (se elige al empezar).
var tutorial: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"saveable") # SaveManager.GROUP (literal: SaveManager carga después)


func _process(delta: float) -> void:
	if is_playing:
		playtime_seconds += delta


func new_game() -> void:
	current_body = &"moon"
	playtime_seconds = 0.0
	unlocks.clear()
	is_playing = true


func set_body(body_id: StringName) -> void:
	if body_id == current_body:
		return
	current_body = body_id
	EventBus.celestial_body_changed.emit(body_id)


func unlock(key: StringName) -> void:
	unlocks[key] = true


func is_unlocked(key: StringName) -> bool:
	return unlocks.get(key, false)


# --- Protocolo Saveable -----------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {
		"current_body": String(current_body),
		"playtime_seconds": playtime_seconds,
		"unlocks": unlocks.keys().map(func(k: StringName) -> String: return String(k)),
	}


func load_state(data: Dictionary) -> void:
	current_body = StringName(data.get("current_body", "moon"))
	playtime_seconds = float(data.get("playtime_seconds", 0.0))
	unlocks.clear()
	for k: String in data.get("unlocks", []):
		unlocks[StringName(k)] = true
	is_playing = true
