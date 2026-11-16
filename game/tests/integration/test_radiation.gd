extends GutTest
## Radiación: fondo real, evento solar con datos DONKI, blindaje parcial.

var _session: GameSession
var _rad: RadiationSystem


func before_all() -> void:
	_session = (load("res://main/game_session.tscn") as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(10)
	_rad = get_tree().get_first_node_in_group(&"radiation_system") as RadiationSystem


func after_all() -> void:
	_session.queue_free()
	await wait_frames(10)


func test_uses_real_data_package() -> void:
	assert_eq(_rad.data.get("kind"), "REAL_DATA")
	assert_almost_eq(_rad.flare_delay_minutes(), 60.0, 0.01, "1 h entre fulguración y protones (DONKI, mayo 2024)")
	assert_almost_eq(_rad.background_usv_per_hour(), 1369.0 / 24.0, 0.01, "fondo medido por Chang'e 4")


func test_shield_is_partial_not_immunity() -> void:
	assert_gt(RadiationSystem.SHIELD_HABITAT, 0.0, "el blindaje no da inmunidad")
	assert_lt(RadiationSystem.SHIELD_HABITAT, RadiationSystem.SHIELD_LANDER, "el hábitat protege más que el módulo")


func test_event_phases_and_shelter_reduce_dose() -> void:
	var p := _session.player
	p.global_position = Vector3(120, 5, 120)
	await wait_physics_frames(5)
	assert_eq(_rad.shield_factor(), 1.0, "afuera: expuesto")
	_rad.start_event()
	assert_eq(_rad.phase, &"warning")
	assert_gt(_rad.countdown, 30.0, "hay tiempo para buscar refugio")
	_rad.countdown = 0.01
	await wait_seconds(0.3)
	assert_eq(_rad.phase, &"storm")
	_rad.storm_left = RadiationSystem.STORM_DURATION * 0.8
	var d0 := _rad.total_msv
	await wait_seconds(1.0)
	var exposed := _rad.total_msv - d0
	var lander := (get_tree().get_first_node_in_group(&"base_network") as BaseNetwork).find_nearest_shelter(Vector3.ZERO)
	p.global_position = lander.global_position + Vector3(0, 1, 3)
	await wait_physics_frames(5)
	assert_lt(_rad.shield_factor(), 1.0, "en el refugio: blindado")
	var d1 := _rad.total_msv
	await wait_seconds(1.0)
	var sheltered := _rad.total_msv - d1
	assert_lt(sheltered, exposed, "el refugio reduce la dosis")
	assert_gt(sheltered, 0.0, "pero no la anula")
