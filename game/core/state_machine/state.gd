class_name State
extends Node
## Estado base para `StateMachine`. Sobrescribir solo lo necesario.

var machine: StateMachine
var actor: Node


func enter(_from: StringName, _msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
