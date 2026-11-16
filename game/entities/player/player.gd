class_name Player
extends CharacterBody3D
## Astronauta controlado por el jugador.
##
## Física de baja gravedad: la gravedad sale del cuerpo celeste (`get_gravity()`,
## 1,62 m/s² en la Luna). Con poco peso hay poca tracción: el astronauta acelera
## y frena despacio, y los saltos son largos. Las acciones (recolectar, escanear,
## interactuar) bloquean el movimiento mientras dura su animación.

signal jumped
signal landed(air_time: float)
signal footstep(running: bool)
signal action_started(action: StringName)
signal action_finished(action: StringName)

const SAVE_ID := "player"

@export_group("Movimiento")
@export var walk_speed: float = 2.4
@export var run_speed: float = 4.3
@export var ground_accel: float = 6.5
@export var ground_decel: float = 5.0
@export var air_accel: float = 1.2
@export var turn_speed: float = 7.0
@export_group("Salto")
## Velocidad inicial del salto. En la Luna: altura = v² / (2·1,62) ≈ 1,6 m.
@export var jump_velocity: float = 2.3
## Tiempo de flexión antes del impulso (sincronizado con la animación JumpStart).
@export var jump_windup: float = 0.16
@export var coyote_time: float = 0.15
@export_group("Pasos")
@export var stride_walk: float = 1.05
@export var stride_run: float = 1.9

@onready var visual: Node3D = $Visual
@onready var animator: PlayerAnimator = $Animator
@onready var interactor: Interactor = $Interactor
@onready var camera_rig: CameraRig = $CameraRig
@onready var inventory: Inventory = $Inventory
@onready var effects: PlayerEffects = $Effects

var input_enabled: bool = true
var current_action: StringName = &""
var air_time: float = 0.0
var flashlight_on: bool = false
## Vehículo en el que viaja (null si está a pie).
var vehicle: Node3D = null
var crouching: bool = false
## Objeto que el astronauta lleva en la mano (p. ej. la abrazadera de un cable).
var held_object: Node = null
## Mirando por los binoculares (herramienta 3 de la barra).
var binoculars_active: bool = false
@export var crouch_speed: float = 1.1

var _was_on_floor: bool = true
var _coyote: float = 0.0
var _jump_timer: float = -1.0
var _step_distance: float = 0.0
var _autopilot: Dictionary = {}


func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"saveable")
	floor_max_angle = deg_to_rad(42.0)
	floor_snap_length = 0.45
	_parse_autopilot()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or get_tree().paused:
		return
	if event.is_action_pressed(&"flashlight"):
		set_flashlight(not flashlight_on)
	elif event.is_action_pressed(&"crouch") and is_on_floor():
		set_crouching(not crouching)
	elif event.is_action_pressed(&"interact") and held_object != null and is_instance_valid(held_object):
		held_object.call("drop_held")
	elif event.is_action_pressed(&"interact") and is_on_floor() and current_action == &"":
		interactor.try_interact(self)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
	else:
		_coyote -= delta
		air_time += delta
		velocity += get_gravity() * delta

	var move_input := _read_move_input()
	var dir := camera_rig.get_yaw_basis() * Vector3(move_input.x, 0.0, move_input.y)
	dir.y = 0.0
	dir = dir.normalized() * minf(move_input.length(), 1.0)
	var running := _is_sprinting() and move_input.length() > 0.3
	if crouching:
		running = false
	var target := dir * (crouch_speed if crouching else (run_speed if running else walk_speed))

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var accel: float
	if on_floor:
		accel = ground_accel if dir.length() > 0.01 else ground_decel
	else:
		accel = air_accel
	hv = hv.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	# Salto con flexión previa
	if crouching and _jump_pressed():
		set_crouching(false) # saltar levanta al astronauta
	elif _jump_timer < 0.0 and _coyote > 0.0 and _can_act() and _jump_pressed():
		_jump_timer = jump_windup
		animator.play_jump_start()
	if _jump_timer >= 0.0:
		_jump_timer -= delta
		if _jump_timer < 0.0:
			velocity.y = jump_velocity
			_coyote = 0.0
			jumped.emit()

	move_and_slide()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		landed.emit(air_time)
		animator.on_landed(air_time)
		air_time = 0.0
	_was_on_floor = now_on_floor

	_update_facing(hv, delta)
	_update_steps(hv, now_on_floor, running, delta)
	animator.update_locomotion(hv.length(), running, now_on_floor, velocity.y, crouching)


## Ejecuta una acción con animación. `event_time` (s) dispara `on_event` a mitad
## de la animación (p. ej. el instante en que la mano toca la muestra).
func perform_action(action: StringName, on_event: Callable = Callable(), event_time: float = -1.0) -> bool:
	if not _can_act() or not is_on_floor():
		return false
	current_action = action
	velocity.x = 0.0
	velocity.z = 0.0
	action_started.emit(action)
	var length := animator.play_action(action)
	if on_event.is_valid():
		var t := event_time if event_time >= 0.0 else length * 0.5
		get_tree().create_timer(t, false).timeout.connect(on_event)
	get_tree().create_timer(maxf(length - 0.12, 0.05), false).timeout.connect(_end_action.bind(action))
	return true


## Gira el modelo para mirar hacia un punto (antes de recolectar, por ejemplo).
func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.05:
		visual.rotation.y = atan2(d.x, d.z)


func set_flashlight(on: bool) -> void:
	flashlight_on = on
	effects.set_flashlight(on)
	if on:
		EventBus.player_action.emit(&"flashlight")


## Agacharse (C): más lento, más bajo (pasa debajo de salientes, mira rocas de cerca).
func set_crouching(on: bool) -> void:
	crouching = on
	var shape := ($Collision as CollisionShape3D).shape as CapsuleShape3D
	shape.height = 1.25 if on else 1.8
	($Collision as CollisionShape3D).position.y = shape.height * 0.5
	camera_rig.target_offset.y = 1.1 if on else 1.55


func enter_vehicle(v: Node3D) -> void:
	vehicle = v
	input_enabled = false
	visible = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	camera_rig.set_target(v, 8.5, Vector3(0, 2.2, 0))
	interactor.monitoring = false


func exit_vehicle(at: Vector3) -> void:
	vehicle = null
	global_position = at
	collision_layer = 2
	collision_mask = 5
	visible = true
	input_enabled = true
	set_physics_process(true)
	camera_rig.set_target(self, 4.4, Vector3(0, 1.55, 0))
	interactor.monitoring = true


func _process(_delta: float) -> void:
	if vehicle:
		global_position = vehicle.global_position + Vector3(0, 0.5, 0) # viaja dentro de la cabina


func is_busy() -> bool:
	return current_action != &""


func _end_action(action: StringName) -> void:
	if current_action == action:
		current_action = &""
		action_finished.emit(action)


func _can_act() -> bool:
	return input_enabled and current_action == &""


func _read_move_input() -> Vector2:
	if not _can_act():
		return Vector2.ZERO
	if _autopilot.has("move"):
		return _autopilot["move"]
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func _is_sprinting() -> bool:
	return _autopilot.get("sprint", false) or Input.is_action_pressed(&"sprint")


func _jump_pressed() -> bool:
	if _autopilot.get("jump", false) and Engine.get_physics_frames() % 240 == 30:
		return true
	return Input.is_action_just_pressed(&"jump")


func _update_facing(hv: Vector3, delta: float) -> void:
	if hv.length() < 0.25 or is_busy():
		return
	var target_yaw := atan2(hv.x, hv.z)
	var rate := turn_speed * (0.6 if not is_on_floor() else 1.0)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-rate * delta))


func _update_steps(hv: Vector3, on_floor: bool, running: bool, delta: float) -> void:
	if not on_floor:
		_step_distance = 0.0
		return
	_step_distance += hv.length() * delta
	var stride := stride_run if running else stride_walk
	if _step_distance >= stride:
		_step_distance = 0.0
		footstep.emit(running)


## Modo de demostración para capturas automáticas (solo en builds de depuración):
##   -- autopilot=walk | run | jump | run_jump
func _parse_autopilot() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("autopilot="):
			var mode := arg.get_slice("=", 1)
			if mode in ["walk", "run", "jump", "run_jump"]:
				_autopilot["move"] = Vector2(0.0, -1.0)
			_autopilot["sprint"] = mode.begins_with("run")
			_autopilot["jump"] = mode.ends_with("jump")


# --- Protocolo Saveable -----------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {
		"position": SaveManager.vec3_to_arr(global_position),
		"yaw": visual.rotation.y,
		"camera": camera_rig.save_state(),
		"flashlight": flashlight_on,
	}


func load_state(data: Dictionary) -> void:
	global_position = SaveManager.arr_to_vec3(data.get("position"), global_position)
	velocity = Vector3.ZERO
	visual.rotation.y = float(data.get("yaw", 0.0))
	camera_rig.load_state(data.get("camera", {}))
	set_flashlight(bool(data.get("flashlight", false)))
