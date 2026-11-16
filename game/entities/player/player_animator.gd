class_name PlayerAnimator
extends Node
## Controla las animaciones del astronauta con fundidos suaves entre estados.
##
## Locomoción: Idle / Walk / Run, con la velocidad de reproducción ajustada a la
## velocidad real (los pies no "patinan"). Aire: JumpStart -> Fall -> Land.
## Acciones: Collect, Scan, Interact (se reproducen una vez).

const LOOPS := [&"Idle", &"Walk", &"Run", &"Fall", &"Crouch", &"CrouchWalk"]
## Velocidad (m/s) a la que cada ciclo de animación coincide con el desplazamiento.
const NATIVE_SPEED := {&"Walk": 1.9, &"Run": 4.0}
const BLEND := 0.28

@export var animation_player_path: NodePath

var _ap: AnimationPlayer
var _current: StringName = &""
var _locked_until: float = 0.0


func _ready() -> void:
	_ap = get_node_or_null(animation_player_path) as AnimationPlayer
	if _ap == null:
		var found := owner.find_children("*", "AnimationPlayer", true, false)
		_ap = found[0] if found.size() > 0 else null
	if _ap == null:
		push_error("PlayerAnimator: no se encontró AnimationPlayer.")
		return
	for clip in LOOPS:
		if _ap.has_animation(clip):
			_ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play(&"Idle", 0.0)


func update_locomotion(speed: float, running: bool, on_floor: bool, vertical_speed: float, crouching: bool = false) -> void:
	if _ap == null or _now() < _locked_until:
		return
	if not on_floor:
		if vertical_speed < 0.4 or _current != &"JumpStart":
			_play(&"Fall", 0.45)
		return
	if crouching:
		if speed < 0.2:
			_play(&"Crouch", 0.3)
		else:
			_play(&"CrouchWalk", 0.25, clampf(speed / 1.0, 0.6, 1.4))
		return
	if speed < 0.25:
		_play(&"Idle", 0.35)
	elif running and speed > NATIVE_SPEED[&"Walk"] * 1.15:
		_play(&"Run", BLEND, clampf(speed / NATIVE_SPEED[&"Run"], 0.6, 1.4))
	else:
		_play(&"Walk", BLEND, clampf(speed / NATIVE_SPEED[&"Walk"], 0.5, 1.5))


func play_jump_start() -> void:
	_play(&"JumpStart", 0.1)
	_locked_until = _now() + 0.25


func on_landed(air_time: float) -> void:
	if air_time > 0.45:
		_play(&"Land", 0.08)
		_locked_until = _now() + minf(0.35, air_time * 0.2)


## Reproduce una acción completa y devuelve su duración en segundos.
func play_action(clip: StringName) -> float:
	if _ap == null or not _ap.has_animation(clip):
		return 0.5
	_play(clip, 0.2)
	var length := _ap.get_animation(clip).length
	_locked_until = _now() + length - 0.15
	return length


func _play(clip: StringName, blend: float, speed: float = 1.0) -> void:
	if not _ap.has_animation(clip):
		return
	if _current == clip and _ap.is_playing():
		_ap.speed_scale = speed
		return
	_current = clip
	_ap.speed_scale = speed
	_ap.play(clip, blend)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
