class_name StateMachine
extends Node
## Máquina de estados genérica basada en nodos hijos `State`.
##
## Uso: agregar estados como hijos, asignar `initial_state` y llamar a
## `transition_to(&"NombreDelNodo")` desde los estados. Reenvía process,
## physics_process y input solo al estado activo.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State
## Nodo dueño (p. ej. el astronauta); se inyecta en cada estado.
@export var actor: Node

var current: State
var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	if actor == null:
		actor = owner if owner else get_parent()
	for child in get_children():
		if child is State:
			var s := child as State
			s.machine = self
			s.actor = actor
			_states[s.name] = s
	if initial_state:
		current = initial_state
		current.enter(&"", {})


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: estado inexistente '%s' en %s." % [state_name, get_path()])
		return
	var prev: StringName = current.name if current else &""
	if current:
		current.exit()
	current = _states[state_name]
	current.enter(prev, msg)
	state_changed.emit(prev, state_name)


func _process(delta: float) -> void:
	if current:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current:
		current.handle_input(event)
