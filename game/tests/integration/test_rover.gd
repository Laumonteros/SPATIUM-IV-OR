extends GutTest
## Rover: subir, avanzar hacia el frente del modelo, cabina presurizada y bajar.

var _session: GameSession
var _rover: Rover


func before_all() -> void:
	_session = (load("res://main/game_session.tscn") as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(30)
	_rover = get_tree().get_first_node_in_group(&"vehicle") as Rover


func after_all() -> void:
	Input.action_release(&"move_forward")
	_session.queue_free()
	await wait_frames(10)


func test_rover_exists_with_four_wheels() -> void:
	assert_not_null(_rover, "hay un rover al empezar")
	assert_eq(_rover.find_children("*", "VehicleWheel3D", false, false).size(), 4)


func test_drive_forward_and_exit() -> void:
	var p := _session.player
	await wait_seconds(1.5) # que se asiente la suspensión
	_rover.enter(p)
	assert_eq(p.vehicle, _rover)
	assert_false(p.visible, "el astronauta va dentro de la cabina")
	var start := _rover.global_position
	var fwd := _rover.global_basis.z
	Input.action_press(&"move_forward")
	await wait_seconds(3.0)
	Input.action_release(&"move_forward")
	var moved := _rover.global_position - start
	moved.y = 0.0
	gut.p("rover movió %.2f m, dot frente %.2f" % [moved.length(), moved.normalized().dot(fwd)])
	assert_gt(moved.length(), 2.0, "el rover avanza")
	assert_gt(moved.normalized().dot(fwd), 0.5, "avanza hacia el frente del modelo")
	var suit := p.get_node("SuitStatus") as SuitStatus
	var o2 := suit.get_value(&"oxygen")
	await wait_seconds(0.6)
	assert_eq(suit.get_value(&"oxygen"), o2, "en la cabina el traje no consume")
	_rover.exit()
	await wait_physics_frames(5)
	assert_null(p.vehicle)
	assert_true(p.visible)
