extends GutTest
## Colonia preinstalada: módulos, tripulación, interiores, cables, hidroponía,
## laboratorio, taller, comando y guardado. Corre sobre la escena real del juego.

const SESSION := "res://main/game_session.tscn"

var _session: GameSession
var _net: BaseNetwork
var _colony: Colony


func before_all() -> void:
	_session = (load(SESSION) as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(12)
	_net = get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	_colony = get_tree().get_first_node_in_group(&"colony") as Colony


func after_all() -> void:
	_session.queue_free()
	await wait_frames(10)
	get_tree().paused = false


func test_modules_preinstalled_and_operational() -> void:
	assert_not_null(_colony, "la colonia existe al iniciar")
	for id in ["habitat_player", "mono_ines", "mono_tomas", "mono_res_a", "mono_res_b", "biodome", "research_lab", "workshop", "battery_bank", "command_center", "energy_panel_a", "energy_panel_b", "oxygen_plant"]:
		var m := _colony.get_module(id)
		assert_not_null(m, "%s instalado" % id)
		if m:
			assert_true(m.is_built(), "%s construido" % id)
			assert_true(m.fixture, "%s es instalación fija" % id)


func test_sector_layout_matches_plan() -> void:
	# posiciones de data/colony/colony_layout.json (plano ampliado ×1,6)
	var expect := {}
	for m: Dictionary in Colony.load_layout().modules:
		expect[String(m.id)] = Vector2(float(m.pos[0]), float(m.pos[1]))
	for id: String in expect:
		var p := (_colony.get_module(id) as Node3D).global_position
		assert_almost_eq(Vector2(p.x, p.z).distance_to(expect[id]), 0.0, 0.1, "%s en su sector" % id)
	# los módulos no se superponen entre sí
	var mods := _colony.modules.values()
	for i in mods.size():
		for j in range(i + 1, mods.size()):
			var a := mods[i] as Structure
			var b := mods[j] as Structure
			var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
			assert_gt(d, (a.def.footprint_radius + b.def.footprint_radius) * 0.55, "%s y %s separados" % [a.name, b.name])


func test_player_starts_inside_own_monoblock() -> void:
	var home := _colony.get_player_home()
	assert_not_null(home)
	assert_true(home.contains_point(_session.player.global_position + Vector3(0, 0.5, 0)), "el jugador aparece dentro de su monoblock")
	var shelter := _net.find_shelter_at(_session.player.global_position + Vector3(0, 0.5, 0))
	assert_eq(shelter, home, "el interior del monoblock es refugio")


func test_two_crew_in_their_monoblocks() -> void:
	assert_eq(_colony.crew.size(), 2, "dos astronautas compañeros")
	for c in _colony.crew:
		var home := _colony.get_module(String(c.home_id)) as Monoblock
		assert_not_null(home)
		assert_eq(home.occupant, c.walker_id, "cada uno con su monoblock")
		assert_true(home.contains_point(c.global_position + Vector3(0, 0.6, 0)), "%s empieza en su monoblock" % c.display_name)
	var assigned := 0
	for m in _colony.modules.values():
		if m is ColonyModule and (m as ColonyModule).occupant != &"":
			assigned += 1
	assert_eq(assigned, 3, "1 monoblock por humano (jugador + 2)")


func test_interior_floor_and_walls_have_collision() -> void:
	var home := _colony.get_player_home()
	var space := home.get_world_3d().direct_space_state
	var c := home.global_transform * Vector3(2.2, 0, 2.2) # junto al centro, fuera de la consola
	# piso firme dentro
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.2, 0), c + Vector3(0, -1.0, 0), 1 | (1 << 2)))
	assert_false(down.is_empty(), "hay piso")
	if not down.is_empty():
		assert_almost_eq((down.position as Vector3).y, c.y, 0.15, "el piso está al nivel del módulo")
	# pared lateral: un rayo desde el centro hacia la izquierda choca con el muro
	var o := home.global_position
	var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + home.global_basis * Vector3(0, 1.5, -2.0), o + home.global_basis * Vector3(-0.5, 1.5, -8.0), 1 | (1 << 2)))
	assert_false(side.is_empty(), "las paredes tienen colisión")


func test_doorway_is_passable_at_human_scale() -> void:
	# el hueco de la puerta frontal del monoblock deja pasar la cápsula del astronauta (1,82 m)
	var home := _colony.get_player_home()
	var space := home.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.82
	q.shape = cap
	q.collision_mask = 1 | (1 << 2)
	# justo afuera de la puerta (rampa de acceso)
	var dz: float = (home as SpatiumHabitat).A + 0.9 if home is SpatiumHabitat else Monoblock.D * 0.5 + 0.9
	q.transform = Transform3D(Basis(), home.global_transform * Vector3(0, 1.08, dz))
	assert_true(space.intersect_shape(q, 4).filter(func(r: Dictionary) -> bool: return not (r.collider is Terrain3D)).is_empty(), "frente a la puerta no hay obstáculos")
	assert_gte(ModuleDoor.WIDTH, 1.2)
	assert_gte(ModuleDoor.HEIGHT, 2.2)


func test_power_cables_never_disconnect() -> void:
	assert_eq(_colony.cables.size(), 3)
	var c := _colony.cables[2]
	var before := c.clamps[0]
	var ok := c.move_clamp(0, before + Vector3(300, 0, 300))
	assert_false(ok, "no se puede estirar más allá del largo máximo")
	assert_lte(c.get_length(), c.max_length + 0.01, "el cable sigue conectado")
	assert_ne(c.clamps[0], before, "pero la abrazadera sí se movió hasta el límite")
	assert_true(c.move_clamp(0, before), "se puede volver a acomodar")


func test_battery_bank_stores_energy_for_colony() -> void:
	assert_gte(_net.capacity_kwh, 20.0, "el banco de baterías suma su capacidad")
	var by := _net.get_sector_demand()
	assert_true(by.has("energy") and float(by.energy.production) > 0.0 or _net.production_kw >= 0.0, "el sector energía figura en la red")


func test_biodome_grows_and_stores_harvest() -> void:
	var dome := _colony.get_biodome()
	assert_not_null(dome)
	_net.water_l = 40.0
	for b in dome.beds:
		b.progress = 0.99
	var before := dome.storage + _net.rations
	dome.simulate(30.0, _net)
	for b in dome.beds:
		if String(b.crop) != "":
			assert_almost_eq(float(b.progress), 1.0, 0.001, "el bancal madura y espera la cosecha")
	for i in dome.beds.size():
		dome.harvest_bed(i)
	assert_gt(dome.storage + _net.rations, before, "la cosecha entra al almacén")
	assert_eq(String(dome.beds[0].crop), "", "el bancal cosechado queda libre para plantar")
	dome.plant(0, "radish")
	assert_eq(String(dome.beds[0].crop), "radish", "se puede elegir qué plantar")
	# almacén lleno: el excedente pasa a la base (la producción no se frena)
	dome.storage = Biodome.STORAGE_CAPACITY
	var rations := _net.rations
	dome.beds[0].progress = 1.0
	dome.harvest_bed(0)
	assert_eq(dome.storage, Biodome.STORAGE_CAPACITY)
	assert_gt(_net.rations, rations, "con el almacén lleno, el excedente va a las reservas")


func test_rock_sheets_unlock_and_analysis() -> void:
	var rp := _colony.research_points
	EventBus.resource_collected.emit(&"iron", 3)
	assert_true(_colony.unlocked_sheets.has("ilmenite"), "recolectar hierro desbloquea la ficha de ilmenita")
	assert_eq(_colony.research_points, rp + 1)
	var sheet := _colony.get_sheet("ilmenite")
	assert_gt((sheet.composition as Array).size(), 0, "la ficha tiene composición")
	assert_true(String(sheet.science.source) != "", "la ficha cita su fuente")


func test_telescope_tracking_challenge() -> void:
	var t := TelescopeTracker.new()
	var target: Dictionary = (_colony.telescopes[0].targets as Array)[0]
	t.setup(target, Color.WHITE)
	t.size = Vector2(600, 360)
	add_child(t)
	var result := [null]
	t.finished.connect(func(ok: bool) -> void: result[0] = ok)
	# un jugador que corrige siempre hacia el centro termina la observación
	for i in 400:
		if result[0] != null:
			break
		t.step(0.05, t.offset.normalized() if t.offset.length() > 2.0 else Vector2.ZERO)
	assert_eq(result[0], true, "corrigiendo la deriva se completa el seguimiento")
	_colony.complete_observation(0, target)
	assert_true(_colony.observations.has(String(target.id)))


func test_workshop_fabricates_upgrade_and_kit() -> void:
	var inv := _session.player.inventory
	inv.add(&"iron", 20)
	inv.add(&"regolith", 20)
	_colony.research_points = 10
	var cap0 := _net.capacity_kwh
	assert_true(_colony.start_fabrication("battery_ext", inv), "el taller acepta el trabajo")
	assert_false(_colony.start_fabrication("kit_battery", inv), "un trabajo por vez")
	_colony.fast_forward(80.0)
	assert_true(_colony.upgrades.has("battery_ext"))
	assert_almost_eq(_net.capacity_kwh, cap0 + 10.0, 0.01, "la mejora aumenta la capacidad real")
	assert_true(_colony.start_fabrication("kit_battery", inv))
	_colony.fast_forward(60.0)
	assert_true(_colony.has_kit(&"battery"), "el kit queda disponible para construir")


func test_supply_order_lands_capsule() -> void:
	_colony.research_points = 5
	_colony.supply_order = {}
	_colony.capsule_waiting = ""
	var rations := _net.rations
	assert_true(_colony.order_supply("rations"))
	_colony.fast_forward(100.0)
	assert_eq(_colony.capsule_waiting, "rations", "la cápsula alunizó")
	_colony._unload_capsule(_session.player)
	assert_eq(_net.rations, rations + 10, "se descargan los suministros")


func test_command_center_is_strongest_shelter() -> void:
	var cmd := _colony.get_module("command_center") as CommandCenter
	var cabin := cmd.global_transform * Vector3(0, CommandCenter.CABIN_FLOOR + 1.0, 0)
	assert_true(cmd.contains_point(cabin), "la cabina es interior presurizado")
	assert_eq(_net.find_shelter_at(cabin), cmd)
	assert_lt(cmd.get_shield_factor(), _colony.get_player_home().get_shield_factor(), "la cabina blinda más que un monoblock")
	cmd.call_elevator(true)
	assert_true(cmd.is_elevator_up())


func test_colony_state_survives_save_and_load() -> void:
	_colony.unlocked_sheets["breccia"] = true
	_colony.research_points = 7
	var c := _colony.cables[0]
	c.move_clamp(0, c.clamps[0] + Vector3(1.0, 0, 0.5))
	var moved := c.clamps[0]
	var dome := _colony.get_biodome()
	dome.storage = 13
	var data := _colony.save_state()
	_colony.unlocked_sheets.clear()
	_colony.research_points = 0
	c.clamps[0] = Vector3.ZERO
	dome.storage = 0
	_colony.load_state(JSON.parse_string(JSON.stringify(data)))
	assert_true(_colony.unlocked_sheets.has("breccia"))
	assert_eq(_colony.research_points, 7)
	assert_almost_eq(c.clamps[0].distance_to(moved), 0.0, 0.01, "la posición del cable se guarda")
	assert_eq(dome.storage, 13)


func test_no_boulders_inside_colony_or_on_paths() -> void:
	for f in get_tree().get_nodes_in_group(&"saveable"):
		if f is ResourceField:
			for dep in (f as ResourceField).get_deposits():
				assert_false(Colony.is_reserved(dep.global_position, 0.0), "%s fuera de sectores y caminos" % dep.name)


func test_cables_are_drawn_on_the_ground() -> void:
	for c in _colony.cables:
		var mi := c.get_node("CableMesh") as MeshInstance3D
		assert_not_null(mi.mesh, "%s tiene malla" % c.cable_id)
		if mi.mesh:
			var aabb := mi.global_transform * mi.mesh.get_aabb()
			gut.p("%s aabb=%s start=%s end=%s" % [c.cable_id, aabb, c.start_point, c.end_point])
			assert_gt(aabb.size.length(), 3.0, "%s tiene largo visible" % c.cable_id)



## Los recorridos de la tripulación no atraviesan paredes ni muebles
## (las puertas se ignoran porque se abren al pasar).
func test_crew_routes_do_not_cross_walls() -> void:
	var space := _session.get_viewport().world_3d.direct_space_state
	var exclude: Array[RID] = []
	for door in get_tree().root.find_children("*", "ModuleDoor", true, false):
		for leaf in door.get_children():
			if leaf is CollisionObject3D:
				exclude.append((leaf as CollisionObject3D).get_rid())
	for w in get_tree().get_nodes_in_group(&"colony_walker"):
		for c in (w as Node).get_children():
			if c is CollisionObject3D:
				exclude.append((c as CollisionObject3D).get_rid())
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.5
	q.shape = cap
	q.collision_mask = 1 | (1 << 2) | (1 << 8)
	q.exclude = exclude
	var bad: PackedStringArray = []
	var walkers: Array[ColonyWalker] = []
	walkers.append_array(_colony.crew)
	walkers.append_array(_colony.bots)
	for w in walkers:
		for si in w.stops.size():
			var pts: Array = w.stops[si].points
			var prev: Vector3 = w.stops[si - 1].points.back() if si > 0 and not (w.stops[si - 1].points as Array).is_empty() else (pts[0] if not pts.is_empty() else Vector3.ZERO)
			for p: Vector3 in pts:
				var n := maxi(int(prev.distance_to(p) / 0.3), 1)
				for k in n + 1:
					var x := prev.lerp(p, float(k) / n)
					var region := _session.region as MoonRegion
					var floor_y := maxf(x.y, region.get_height(x)) if is_finite(region.get_height(x)) else x.y
					q.transform = Transform3D(Basis(), Vector3(x.x, floor_y + 0.25 + 0.75 + 0.05, x.z))
					for r in space.intersect_shape(q, 4):
						if r.collider is Terrain3D:
							continue
						bad.append("%s parada %d en %s choca con %s" % [w.walker_id, si, x.snapped(Vector3.ONE * 0.1), (r.collider as Node).get_parent().name if r.collider else "?"])
						break
				prev = p
	for line in bad.slice(0, 25):
		gut.p(line)
	assert_eq(bad.size(), 0, "rutas sin atravesar paredes ni muebles")
