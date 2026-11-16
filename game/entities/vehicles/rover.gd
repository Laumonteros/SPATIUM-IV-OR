class_name Rover
extends VehicleBody3D
## Rover presurizado "Selene". E para subir/bajar; W/S acelera/retrocede,
## A/D gira, Espacio frena. Adentro, el traje no consume (cabina presurizada).
##
## Física lunar: con 1,62 m/s² el rover pesa 1/6, así que tiene poca tracción y
## rebota más; por eso la suspensión es blanda y la velocidad máxima baja
## (el LRV de las misiones Apollo rondaba los 13 km/h).

const SAVE_ID := "rover"
const MODEL := "res://assets/models/vehicles/rover.glb"
## Distancia al astronauta desde la que el rover estacionado se congela (m).
const PARK_FREEZE_DIST := 40.0

@export var max_engine_force: float = 1700.0
@export var max_speed: float = 6.0
@export var max_steer: float = 0.48
@export var brake_force: float = 14.0
## Signo del motor según la orientación del modelo (+Z hacia adelante).
@export var forward_sign: float = 1.0

var driver: Player = null
var _interactable: Interactable
var _motor: AudioStreamPlayer
var _lights: Array[SpotLight3D] = []
var _steer := 0.0


func _ready() -> void:
	add_to_group(&"vehicle")
	add_to_group(&"saveable")
	mass = 900.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.45, 0)
	collision_layer = 1 << 5 # capa 6: vehículos
	collision_mask = 1 | (1 << 2) | (1 << 3)
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(model)
	SurfaceMaterials.apply(model)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.1, 1.25, 3.7)
	cs.shape = bx
	cs.position = Vector3(0, 1.15, -0.2)
	add_child(cs)
	for mi: MeshInstance3D in model.find_children("Wheel_*", "MeshInstance3D", true, false):
		_make_wheel(mi)
	_interactable = Interactable.new()
	_interactable.action_key = "ACTION_ENTER"
	_interactable.name_key = "VEHICLE_ROVER"
	_interactable.max_distance = 4.5
	var ish := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.0
	ish.shape = sph
	ish.position.y = 1.0
	_interactable.add_child(ish)
	add_child(_interactable)
	_interactable.interacted.connect(_on_interacted)
	_motor = AudioStreamPlayer.new()
	_motor.bus = &"Suit"
	_motor.volume_db = -8.0
	if ResourceLoader.exists("res://assets/audio/sfx/rover_motor_loop.wav"):
		_motor.stream = load("res://assets/audio/sfx/rover_motor_loop.wav")
	add_child(_motor)
	for x in [-0.6, 0.6]:
		var l := SpotLight3D.new()
		l.position = Vector3(x, 1.0, 1.7)
		l.rotation = Vector3(deg_to_rad(-6.0), PI, 0.0) # apunta hacia +Z (frente del modelo)
		l.light_color = Color(1.0, 0.92, 0.8)
		l.light_energy = 5.0
		l.spot_range = 40.0
		l.spot_angle = 32.0
		l.visible = false
		add_child(l)
		_lights.append(l)


func _make_wheel(mesh: MeshInstance3D) -> void:
	var w := VehicleWheel3D.new()
	w.name = mesh.name
	w.position = mesh.position
	w.wheel_radius = 0.48
	w.wheel_rest_length = 0.22
	w.suspension_travel = 0.3
	w.suspension_stiffness = 22.0
	w.suspension_max_force = 9000.0
	w.damping_compression = 1.6
	w.damping_relaxation = 2.2
	w.wheel_friction_slip = 1.4
	w.wheel_roll_influence = 0.25
	w.use_as_traction = true
	w.use_as_steering = mesh.name.contains("F")
	add_child(w)
	mesh.get_parent().remove_child(mesh)
	w.add_child(mesh)
	mesh.position = Vector3.ZERO


func _on_interacted(by: Node) -> void:
	var p := by as Player
	if p and driver == null:
		enter(p)


func enter(p: Player) -> void:
	driver = p
	p.enter_vehicle(self)
	_interactable.enabled = false
	for l in _lights:
		l.visible = true
	if _motor.stream:
		_motor.play()
	var es := TranslationServer.get_locale().begins_with("es")
	EventBus.notification_requested.emit("ROVER · W/S acelerar · A/D girar · Espacio frenar · E bajar" if es
		else "ROVER · W/S throttle · A/D steer · Space brake · E exit", &"info")
	EventBus.player_action.emit(&"drive")


func exit() -> void:
	if driver == null:
		return
	var side := global_basis.x.normalized() * -2.2
	driver.exit_vehicle(global_position + side + Vector3(0, 0.6, 0))
	driver = null
	_interactable.enabled = true
	engine_force = 0.0
	brake = brake_force
	for l in _lights:
		l.visible = false
	_motor.stop()


func _unhandled_input(event: InputEvent) -> void:
	if driver and not get_tree().paused and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		exit()


func _physics_process(delta: float) -> void:
	if driver == null:
		engine_force = 0.0
		brake = brake_force * 0.5
		_park_guard()
		return
	var throttle := Input.get_axis(&"move_back", &"move_forward")
	var steer_in := Input.get_axis(&"move_right", &"move_left")
	_steer = move_toward(_steer, steer_in * max_steer, 2.0 * delta)
	steering = _steer
	var speed := linear_velocity.length()
	engine_force = throttle * max_engine_force * forward_sign if speed < max_speed or signf(throttle) != signf(_forward_speed()) else 0.0
	brake = brake_force if Input.is_action_pressed(&"jump") else (1.5 if absf(throttle) < 0.05 else 0.0)
	if _motor.playing:
		_motor.pitch_scale = 0.8 + clampf(speed / max_speed, 0.0, 1.0) * 0.7
		_motor.volume_db = -14.0 + absf(throttle) * 6.0


## La colisión del terreno solo existe alrededor del astronauta: estacionado y lejos
## de él, el rover se congela (si no, caería a través del suelo). Si alguna vez quedó
## por debajo del relieve, se lo vuelve a apoyar sobre la superficie.
func _park_guard() -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	var far := p == null or p.global_position.distance_to(global_position) > PARK_FREEZE_DIST
	if freeze != far:
		freeze = far
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	if region:
		var h := region.get_height(global_position)
		if is_finite(h) and global_position.y < h - 0.3:
			global_position = Vector3(global_position.x, h + 0.9, global_position.z)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO


func _forward_speed() -> float:
	return linear_velocity.dot(global_basis.z) * forward_sign


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


# --- Saveable ---------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"pos": SaveManager.vec3_to_arr(global_position), "yaw": rotation.y}


func load_state(data: Dictionary) -> void:
	if driver:
		exit()
	global_position = SaveManager.arr_to_vec3(data.get("pos"), global_position) + Vector3(0, 0.3, 0)
	rotation = Vector3(0, float(data.get("yaw", rotation.y)), 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
