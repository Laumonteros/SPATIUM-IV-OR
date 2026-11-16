class_name CameraRig
extends Node3D
## Cámara en tercera persona: sigue al astronauta con suavidad, gira con mouse
## o stick derecho y usa un SpringArm para no atravesar el terreno.

@export var target_offset: Vector3 = Vector3(0.0, 1.55, 0.0)
@export var follow_smoothing: float = 9.0
@export var distance: float = 4.4
@export var pitch_min_deg: float = -65.0
@export var pitch_max_deg: float = 45.0
@export var run_fov_boost: float = 6.0
@export var base_fov: float = 70.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
## Catalejo: la cámara pasa al casco y el campo visual se cierra (zoom ~6x).
var zooming: bool = false
var zoom_fov: float = 11.0
var pitch: float = deg_to_rad(-5.0) # cámara casi a nivel: el horizonte (y la curvatura) quedan al centro
var _target: Node3D


func _ready() -> void:
	top_level = true
	_target = get_parent() as Node3D
	_arm.spring_length = distance
	_arm.add_excluded_object((get_parent() as CollisionObject3D).get_rid())
	_camera.fov = base_fov
	if _target:
		global_position = _target.global_position + target_offset


## En interiores la cámara se acerca para no chocar con techos y paredes.
const INTERIOR_DISTANCE := 2.3
var _interior := false


func set_interior(on: bool) -> void:
	_interior = on


func is_interior() -> bool:
	return _interior


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sens := float(Settings.get_value("controls", "mouse_sensitivity")) * 0.01 * (0.2 if zooming else 1.0)
		var invert := -1.0 if bool(Settings.get_value("controls", "invert_y")) else 1.0
		var rel := (event as InputEventMouseMotion).relative
		yaw -= rel.x * sens
		pitch = clampf(pitch - rel.y * sens * invert, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func _process(delta: float) -> void:
	if _target == null:
		return
	# Stick derecho del mando
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length() > 0.0:
		var sens := float(Settings.get_value("controls", "gamepad_sensitivity"))
		yaw -= look.x * sens * delta
		pitch = clampf(pitch - look.y * sens * delta, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))

	var want_zoom := _target is Player and (_target as Player).binoculars_active and not get_tree().paused and (_target as Player).input_enabled
	if want_zoom != zooming:
		zooming = want_zoom
		(_target as Node3D).get_node("Visual").visible = not zooming
	var arm_goal := minf(distance, INTERIOR_DISTANCE) if _interior and _target is Player else distance
	_arm.spring_length = lerpf(_arm.spring_length, 0.0 if zooming else arm_goal, 1.0 - exp(-(4.0 if _interior else 10.0) * delta))
	var goal := _target.global_position + target_offset
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))
	rotation = Vector3(pitch, yaw, 0.0)

	var hspeed := 0.0
	if _target is CharacterBody3D:
		hspeed = Vector2((_target as CharacterBody3D).velocity.x, (_target as CharacterBody3D).velocity.z).length()
	elif _target is RigidBody3D:
		hspeed = (_target as RigidBody3D).linear_velocity.length() * 0.6
	var fov_goal := base_fov + clampf((hspeed - 2.5) / 2.0, 0.0, 1.0) * run_fov_boost
	if zooming:
		fov_goal = zoom_fov
	_camera.fov = lerpf(_camera.fov, fov_goal, 1.0 - exp(-(8.0 if zooming else 3.0) * delta))


## Base horizontal de la cámara (para convertir la entrada en dirección de mundo).
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


## Cambia a quién sigue la cámara (el astronauta o el rover).
func set_target(t: Node3D, dist: float, offset: Vector3) -> void:
	_target = t
	distance = dist
	target_offset = offset
	if t is CollisionObject3D:
		_arm.add_excluded_object((t as CollisionObject3D).get_rid())


func get_camera() -> Camera3D:
	return _camera


func save_state() -> Dictionary:
	return {"yaw": yaw, "pitch": pitch}


func load_state(data: Dictionary) -> void:
	yaw = float(data.get("yaw", yaw))
	pitch = float(data.get("pitch", pitch))
	if _target:
		global_position = _target.global_position + target_offset
