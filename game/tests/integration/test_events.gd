extends GutTest
## Sucesos aleatorios: cada uno tiene un efecto real sobre la colonia.

var _session: GameSession
var _ed: EventDirector


func before_all() -> void:
	_session = (load("res://main/game_session.tscn") as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(30)
	_ed = get_tree().get_first_node_in_group(&"event_director") as EventDirector


func after_all() -> void:
	_session.queue_free()
	await wait_frames(10)


func test_director_and_radio_exist() -> void:
	assert_not_null(_ed, "hay director de sucesos")
	assert_not_null(get_tree().get_first_node_in_group(&"radio"), "hay radio de Control de misión")
	assert_ne(RadioPanel.text_of("dust"), "dust", "los mensajes de radio tienen texto")


func test_dust_lowers_panel_power_until_cleaned() -> void:
	var panel: Structure = null
	for s in get_tree().get_nodes_in_group(&"structure"):
		if (s as Structure).def and (s as Structure).def.role == BuildableDef.Role.SOLAR:
			panel = s
			break
	assert_not_null(panel)
	var before := panel.get_power_kw()
	panel.set_dusty(true)
	assert_true(panel.get_power_kw() <= before * Structure.DUST_FACTOR + 0.001, "el polvo baja la potencia")
	panel.set_dusty(false)
	assert_almost_eq(panel.get_power_kw(), before, 0.001, "limpio vuelve a rendir")


func test_blackout_blocks_supply_orders() -> void:
	_ed.trigger(&"blackout")
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	var p: Dictionary = colony.supplies.get("packages", [])[0]
	assert_eq(colony.order_blocker(p), tr("EV_COMMS_DOWN"), "sin comunicaciones no hay pedidos")
	_ed.blackout_left = 0.0


func test_impact_creates_site_with_fresh_samples() -> void:
	var before := get_tree().get_nodes_in_group(&"resource_deposit").size()
	_ed.trigger(&"impact")
	await wait_frames(3)
	assert_eq(_ed.impacts.size(), 1, "se registra el cráter nuevo")
	assert_eq(get_tree().get_nodes_in_group(&"resource_deposit").size(), before + 3, "aparecen 3 muestras frescas")
	assert_true(get_tree().get_nodes_in_group(&"poi").size() >= 1, "el cráter es un punto de interés")


func test_science_request_rewards_research() -> void:
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	var r := colony.research_points
	_ed.trigger(&"science")
	assert_true(_ed.science_active)
	EventBus.resource_collected.emit(&"geo_sample", 1)
	assert_false(_ed.science_active, "el pedido se cumple con una muestra")
	assert_true(colony.research_points >= r + 6, "la Tierra paga con datos científicos")


func test_power_budget_trade_offs() -> void:
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	var full := float(net.group_demand().get("comms", 0.0))
	net.set_throttle("comms", 0.0)
	assert_almost_eq(float(net.group_demand().get("comms", 0.0)), 0.0, 0.001, "apagado no consume")
	var p: Dictionary = colony.supplies.get("packages", [])[0]
	assert_eq(colony.order_blocker(p), tr("POWER_COMMS_OFF"), "pero tampoco se puede pedir nada")
	net.set_throttle("comms", 1.0)
	assert_almost_eq(float(net.group_demand().get("comms", 0.0)), full, 0.001)
	net.set_throttle("life", 0.0)
	assert_eq(float(net.throttles.life), 0.5, "el soporte vital nunca se apaga del todo")
	net.set_throttle("life", 1.0)
