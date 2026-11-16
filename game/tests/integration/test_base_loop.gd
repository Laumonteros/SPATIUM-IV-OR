extends GutTest
## Base lunar: energía solar, baterías, generador de O2, refugio y supervivencia.

const SESSION := "res://main/game_session.tscn"

var _session: GameSession
var _net: BaseNetwork


func before_all() -> void:
	_session = (load(SESSION) as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(10)
	_net = get_tree().get_first_node_in_group(&"base_network") as BaseNetwork


func after_all() -> void:
	_session.queue_free()
	await wait_frames(10) # que el terreno anterior se libere por completo antes de la próxima sesión
	get_tree().paused = false


func _spawn(id: StringName, offset: Vector3) -> Structure:
	var d := DataRegistry.get_def(id) as BuildableDef
	var region := _session.region as MoonRegion
	return _net.spawn_structure(d, region.snap_to_ground(Vector3(20, 0, 20) + offset, 0.0), 0.0, true)


func test_lander_is_initial_shelter() -> void:
	# el módulo de alunizaje sigue en el sitio (ahora en el sector Comando de la colonia)
	var lander := _net.get_lander()
	assert_not_null(lander, "el módulo de alunizaje está en el sitio")
	assert_eq(lander.def.id, &"lander")
	assert_true(lander.is_shelter())


func test_all_structures_defined_as_data() -> void:
	var ids := DataRegistry.get_all_of(BuildableDef).map(func(d: GameDef) -> StringName: return d.id)
	for id in [&"habitat", &"solar_panel", &"battery", &"oxygen_generator", &"water_extractor"]:
		assert_has(ids, id)
		var d := DataRegistry.get_def(id) as BuildableDef
		assert_gt(d.cost.size(), 0, "%s tiene costo" % id)
		assert_not_null(d.model, "%s tiene modelo" % id)


func test_solar_battery_and_oxygen_chain() -> void:
	var panel := _spawn(&"solar_panel", Vector3(0, 0, 0))
	_spawn(&"battery", Vector3(6, 0, 0))
	var gen := _spawn(&"oxygen_generator", Vector3(12, 0, 0))
	await wait_seconds(2.5)
	_net._simulate(1.0)
	assert_gt(_net.production_kw, 0.9, "hay producción solar (panel + módulo)")
	assert_gt(_net.capacity_kwh, 10.0, "la batería suma capacidad")
	gen.stock = 10
	var o2_before := _net.oxygen_kg
	for i in 30:
		_net._simulate(1.0)
	assert_gt(_net.oxygen_kg, o2_before, "el generador produce oxígeno a partir del regolito")
	assert_lt(gen.stock, 10, "consume regolito")
	assert_true(panel.get_solar_factor() >= 0.0)


func test_power_shortage_turns_off_low_priority() -> void:
	_net.stored_kwh = 0.0
	var extra: Array[Structure] = []
	for i in 10: # demanda claramente mayor que la producción (incluye el puesto inicial)
		var s := _spawn(&"water_extractor", Vector3(-15 - (i % 5) * 5, 0, -12 - (i / 5) * 6))
		s.stock = 5
		extra.append(s)
	for i in 3:
		_net._simulate(1.0)
	var unpowered := extra.filter(func(s: Structure) -> bool: return not s.powered)
	assert_gt(unpowered.size(), 0, "sin energía suficiente se apagan estructuras")
	for s in extra:
		s.queue_free()
	await wait_frames(2)


func test_suit_drains_outside_and_refills_in_shelter() -> void:
	var p := _session.player
	var suit := p.get_node("SuitStatus") as SuitStatus
	p.global_position = Vector3(150, 5, 150)
	await wait_physics_frames(5)
	var start := suit.get_value(&"oxygen")
	await wait_seconds(1.5)
	assert_lt(suit.get_value(&"oxygen"), start, "afuera el oxígeno baja")
	var lander := _net.find_nearest_shelter(Vector3.ZERO)
	p.global_position = lander.global_position + Vector3(0, 1, 4)
	suit.values[&"oxygen"] = 50.0
	await wait_seconds(1.5)
	assert_true(suit.sheltered, "dentro del radio del refugio")
	assert_gt(suit.get_value(&"oxygen"), 50.0, "el refugio recarga el traje")


func test_save_restores_built_structures() -> void:
	_spawn(&"battery", Vector3(30, 0, 0))
	var count := _net.get_structures().size()
	var data := _net.save_state()
	_net.load_state(data)
	await wait_frames(3)
	assert_eq(_net.get_structures().size(), count, "la base se reconstruye al cargar")
