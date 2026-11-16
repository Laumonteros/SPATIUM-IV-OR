class_name Interactable
extends Area3D
## Componente: hace que un objeto del mundo se pueda usar con la tecla de interacción.
##
## Se agrega como hijo (con su CollisionShape3D) a cualquier objeto. El `Interactor`
## del jugador detecta el más cercano/centrado y muestra `get_prompt()` en el HUD.
## El objeto dueño se conecta a `interacted` para reaccionar.

signal interacted(by: Node)

## Clave de traducción del verbo (p. ej. "ACTION_COLLECT").
@export var action_key: String = "ACTION_USE"
## Clave de traducción del nombre del objeto (si está vacío se usa `display_name`).
@export var name_key: String = ""
@export var display_name: String = ""
@export var enabled: bool = true
## Distancia máxima de uso, en metros.
@export var max_distance: float = 2.4


func _ready() -> void:
	collision_layer = 1 << 4 # capa 5: interactuables
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_interact(_by: Node) -> bool:
	return enabled


func get_prompt() -> String:
	var n := tr(name_key) if name_key != "" else display_name
	return "%s %s" % [tr(action_key), n] if n != "" else tr(action_key)


func interact(by: Node) -> void:
	if can_interact(by):
		interacted.emit(by)
