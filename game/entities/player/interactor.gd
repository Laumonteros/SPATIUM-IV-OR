class_name Interactor
extends Area3D
## Detecta los `Interactable` cercanos y elige el que está más al frente de la cámara.

signal focus_changed(target: Interactable)

@export var camera_weight: float = 0.6

var focused: Interactable


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 4 # capa 5: interactuables
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not monitoring: # desactivado durante el modo construcción
		if focused:
			focused = null
			focus_changed.emit(null)
		return
	var player := owner as Player
	var best: Interactable = null
	var best_score := INF
	if player and not player.is_busy():
		var cam_fwd := -player.camera_rig.get_camera().global_basis.z
		cam_fwd.y = 0.0
		cam_fwd = cam_fwd.normalized()
		for area in get_overlapping_areas():
			var it := area as Interactable
			if it == null or not it.can_interact(player):
				continue
			var to := it.global_position - player.global_position
			var dist := to.length()
			if dist > it.max_distance:
				continue
			to.y = 0.0
			var facing := cam_fwd.dot(to.normalized()) if to.length() > 0.01 else 1.0
			var score := dist - facing * camera_weight
			if score < best_score:
				best_score = score
				best = it
	if best != focused:
		focused = best
		focus_changed.emit(focused)


func try_interact(by: Node) -> void:
	if focused and is_instance_valid(focused):
		focused.interact(by)
