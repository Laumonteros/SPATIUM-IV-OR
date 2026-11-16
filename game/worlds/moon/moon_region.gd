class_name MoonRegion
extends Node3D
## Raíz de una región lunar: fija el cuerpo celeste, el modo de audio de vacío
## y expone utilidades de terreno (altura y normal) para el resto de los sistemas.

@export var body_id: StringName = &"moon"
@export var terrain: Terrain3D
@export var player_spawn: Marker3D

## Puntos de interés generados con el terreno (cráteres, zonas).
var features: Dictionary = {}

const FEATURES_PATH := "res://worlds/moon/data/moon_region_01_features.json"


func _enter_tree() -> void:
	# Se carga antes del _ready de los hijos (ResourceField necesita los cráteres).
	add_to_group(&"world_region")
	var text := FileAccess.get_file_as_string(FEATURES_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed is Dictionary:
		features = parsed


func _ready() -> void:
	GameState.set_body(body_id)
	AudioManager.set_vacuum(true, true)


## Altura del terreno en (x, z). Devuelve NAN fuera del mapa.
func get_height(pos: Vector3) -> float:
	if terrain == null:
		return 0.0
	return terrain.data.get_height(pos)


func get_normal(pos: Vector3) -> Vector3:
	if terrain == null:
		return Vector3.UP
	var n: Vector3 = terrain.data.get_normal(pos)
	return n if n.is_finite() and n != Vector3.ZERO else Vector3.UP


## Posición sobre el suelo para (x, z), con un desplazamiento vertical opcional.
func snap_to_ground(pos: Vector3, offset: float = 0.0) -> Vector3:
	var h := get_height(pos)
	return Vector3(pos.x, (h if is_finite(h) else 0.0) + offset, pos.z)
