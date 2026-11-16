extends GutTest
## Campaña: la misión 1 se completa con acciones reales y la 2 cuenta recursos.

var _session: GameSession
var _mm: MissionManager


func before_all() -> void:
	_session = (load("res://main/game_session.tscn") as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(10)
	_mm = get_tree().get_first_node_in_group(&"mission_manager") as MissionManager


func after_all() -> void:
	_session.queue_free()
	await wait_frames(10)


func test_campaign_loaded() -> void:
	assert_eq(_mm.missions.size(), 13, "13 misiones lunares (sin tutorial)")
	assert_eq(_mm.current, 0)
	for m: Dictionary in _mm.missions:
		assert_ne(_mm.text(m.briefing), "", "cada misión tiene explicación")
		assert_ne(_mm.text(m.debrief), "", "cada misión tiene cierre educativo")


func test_mission_one_completes_with_real_actions() -> void:
	var p := _session.player
	p.jumped.emit()
	p.jumped.emit()
	p.set_flashlight(true)
	EventBus.scan_completed.emit([])
	var lander := (get_tree().get_first_node_in_group(&"base_network") as BaseNetwork).find_nearest_shelter(Vector3.ZERO)
	p.global_position = lander.global_position + Vector3(30, 3, 10)
	await wait_seconds(1.2)
	assert_true(_mm.between, "misión 1 completa")
	assert_has(_mm.achievements, "first_landing", "logro desbloqueado")
	_mm._start(1, false)
	EventBus.resource_collected.emit(&"regolith", 5)
	assert_eq(_mm.progress[0], 5, "la misión 2 cuenta el regolito recolectado")


func test_mission_state_saves() -> void:
	var data := _mm.save_state()
	_mm.load_state(data)
	assert_eq(_mm.current, 1)
