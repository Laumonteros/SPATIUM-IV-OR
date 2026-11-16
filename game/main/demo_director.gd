class_name DemoDirector
extends Node
## Secuencia automática de demostración (base del futuro "modo evaluadores").
## Se activa con:  -- autopilot=showcase
## Recorre: acercarse a un depósito, recolectar, encender luces, escanear y caminar.

var _session: GameSession


var _perf_frames := 0
var _perf_time := 0.0
var _perf_samples: Array[float] = []


func _ready() -> void:
	_session = get_parent() as GameSession
	var args := Array(OS.get_cmdline_user_args())
	set_process(args.has("perf"))
	if args.has("autopilot=showcase"):
		_run.call_deferred()
	elif args.has("autopilot=base"):
		_run_base.call_deferred()
	elif args.has("autopilot=encyclopedia"):
		(func() -> void:
			await get_tree().create_timer(1.0).timeout
			var enc := get_tree().get_first_node_in_group(&"session_ui")
			for n in get_tree().get_nodes_in_group(&"session_ui"):
				if n is Encyclopedia:
					(n as Encyclopedia)._toggle(true)
					(n as Encyclopedia)._show(6)).call_deferred()
	elif args.has("autopilot=controls"):
		(func() -> void:
			await get_tree().create_timer(1.0).timeout
			for n in get_tree().get_nodes_in_group(&"session_ui"):
				if n is PauseMenu:
					(n as PauseMenu)._open()
					(n as PauseMenu)._show(&"controls")).call_deferred()
	elif args.has("autopilot=features"):
		_run_features.call_deferred()
	elif args.has("autopilot=radiation"):
		_run_radiation.call_deferred()
	elif args.has("autopilot=colony"):
		_run_colony_tour.call_deferred()
	elif not args.has("perf"):
		queue_free()


## Medición de rendimiento:  -- autopilot=run perf   (imprime FPS promedio cada 5 s)
func _process(delta: float) -> void:
	_perf_frames += 1
	_perf_time += delta
	if _perf_time >= 5.0:
		var fps := _perf_frames / _perf_time
		_perf_samples.append(fps)
		print("PERF fps=%.1f frame_ms=%.2f draw_calls=%d prims=%d" % [fps, 1000.0 / fps,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		_perf_frames = 0
		_perf_time = 0.0
		if _perf_samples.size() >= 4:
			get_tree().quit()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	var p := _session.player
	var field := _session.region.get_node_or_null("ResourceField") as ResourceField
	if field == null:
		return
	var target: ResourceDeposit = null
	var best := INF
	for d in field.get_deposits():
		if d.item_id == &"iron":
			var dist := d.global_position.length()
			if dist < best:
				best = dist
				target = d
	if target == null:
		return
	# Ubicar al astronauta junto al depósito, de espaldas al sol para la toma
	var side := Vector3(1.6, 0, 0.6).normalized() * 1.7
	p.global_position = _session.region.call("snap_to_ground", target.global_position + side, 0.3)
	p.camera_rig.yaw = atan2(side.x, side.z) + 0.9
	p.camera_rig.pitch = deg_to_rad(-12.0)
	await get_tree().create_timer(1.0).timeout
	target._on_interacted(p)
	await get_tree().create_timer(2.4).timeout
	p.set_flashlight(true)
	await get_tree().create_timer(0.4).timeout
	(p.get_node("Scanner") as Scanner)._unhandled_input(_scan_event())


## Demostración de la base: construye junto al módulo de alunizaje y muestra el modo construcción.
func _run_base() -> void:
	await get_tree().create_timer(0.6).timeout
	var p := _session.player
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	var region := _session.region as MoonRegion
	var lander := net.get_lander()
	var base := lander.global_position
	var layout := [[&"habitat", Vector3(13, 0, 2)], [&"solar_panel", Vector3(2, 0, 12)], [&"solar_panel", Vector3(8, 0, 13)],
		[&"battery", Vector3(-4, 0, 12)], [&"oxygen_generator", Vector3(12, 0, -7)], [&"water_extractor", Vector3(6, 0, -12)]]
	for e: Array in layout:
		var d := DataRegistry.get_def(e[0]) as BuildableDef
		var s := net.spawn_structure(d, region.snap_to_ground(base + e[1], -0.05), randf() * 0.6, false)
		if d.role == BuildableDef.Role.OXYGEN:
			s.stock = 12
	p.global_position = region.snap_to_ground(base + Vector3(4, 0, 22), 0.3)
	p.camera_rig.yaw = deg_to_rad(10.0)
	p.camera_rig.pitch = deg_to_rad(-16.0)
	p.camera_rig.distance = 7.0
	p.inventory.add(&"iron", 20)
	p.inventory.add(&"regolith", 20)
	await get_tree().create_timer(5.5).timeout
	(p.get_node("BuildSystem") as BuildSystem).set_active(true)


func _run_features() -> void:
	await get_tree().create_timer(1.0).timeout
	var p := _session.player
	p.camera_rig.yaw += 2.4
	(get_tree().get_first_node_in_group(&"radiation_system")) # noop
	EventBus.scan_completed.emit([])
	for d in get_tree().get_nodes_in_group(&"resource_deposit"):
		if (d as ResourceDeposit).scannable and (d as ResourceDeposit).global_position.length() < 160.0:
			(d as ResourceDeposit).discovered = true
	p.set_crouching(true)
	await get_tree().create_timer(2.5).timeout
	p.set_crouching(false)
	p.binoculars_active = true
	await get_tree().create_timer(2.5).timeout
	p.binoculars_active = false


func _run_radiation() -> void:
	await get_tree().create_timer(1.0).timeout
	var rad := get_tree().get_first_node_in_group(&"radiation_system") as RadiationSystem
	rad.start_event()
	await get_tree().create_timer(4.0).timeout
	rad.countdown = 0.1


func _scan_event() -> InputEvent:
	var ev := InputEventAction.new()
	ev.action = &"scan"
	ev.pressed = true
	return ev



## Recorrido de revisión de la colonia (exteriores e interiores) con capturas:
##   -- autopilot=colony shots=<carpeta>
## Sirve para revisar escala, decoración, iluminación y la cámara en interiores.
func _run_colony_tour() -> void:
	await get_tree().create_timer(1.5).timeout
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	if colony == null:
		return
	var dir := "user://captures"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(dir)
	var home := colony.get_player_home() as Node3D
	var dome := colony.get_module("biodome") as Node3D
	var lab := colony.get_module("research_lab") as Node3D
	var ws := colony.get_module("workshop") as Node3D
	var bank := colony.get_module("battery_bank") as Node3D
	var cmd := colony.get_module("command_center") as Node3D
	var cf := CommandCenter.CABIN_FLOOR
	var rover := _session.region.get_node_or_null("Rover") as Node3D
	var shots := [
		["01_overview", Vector3(4, 75, 62), Vector3(0, 0, -6), null],
		["02_hub", Vector3(-0.5, 2.6, 19), Vector3(-0.5, 1.8, 0), null],
		["03_hab_main", Vector3(-2.0, 2.2, 21.0), Vector3(0, 2.5, 0), home],
		["04_hab_34", Vector3(17.0, 5.0, 16.0), Vector3(0, 2.0, 0), home],
		["05_hab_central", Vector3(3.6, 1.7, 3.0), Vector3(-1.0, 1.1, -2.0), home],
		["05b_hab_greenhouse", Vector3(-9.0, 1.7, 0.6), Vector3(-17.0, 0.9, 0.0), home],
		["05c_hab_lifesupport", Vector3(9.0, 1.7, 0.8), Vector3(16.0, 1.0, -1.5), home],
		["06_dome_ext", Vector3(0, 5.5, 27), Vector3(0, 4, 0), dome],
		["07_dome_int", Vector3(0.5, 1.75, 7.6), Vector3(-1.0, 1.2, 0), dome],
		["08_dome_storage", Vector3(9.0, 1.7, 1.5), Vector3(12.4, 1.0, -1.6), dome],
		["09_lab_ext", Vector3(-3, 4.5, 17), Vector3(0, 2, 0), lab],
		["10_lab_geology", Vector3(-1.2, 1.7, 1.7), Vector3(-6.5, 1.0, -3.5), lab],
		["11_lab_obs", Vector3(1.0, 1.7, 1.6), Vector3(6.0, 1.2, -4.0), lab],
		["12_workshop", Vector3(5.6, 2.4, 4.2), Vector3(-3.0, 1.4, -2.0), ws],
		["13_energy", Vector3(5.5, 4.0, 10.0), Vector3(-3.0, 0.5, 0.0), bank],
		["14_command_ext", Vector3(16, 9, 24), Vector3(0, 9, 0), cmd],
		["15_command_cabin", Vector3(1.7, cf + 1.65, 0.4), Vector3(-2.0, cf + 1.1, -0.2), cmd],
		["18_cables", Vector3(-2.0, 6.0, 9.0), Vector3(-6.0, 0.0, -2.0), bank],
		["21_rover", Vector3(5.0, 2.6, 6.0), Vector3(0, 0.8, 0), rover],
	]
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 3000.0
	add_child(cam)
	var p := _session.player
	p.visual.visible = false
	for s: Array in shots:
		var basis_node := s[3] as Node3D
		var from: Vector3 = basis_node.global_transform * (s[1] as Vector3) if basis_node else s[1]
		var to: Vector3 = basis_node.global_transform * (s[2] as Vector3) if basis_node else s[2]
		if not basis_node:
			var region := _session.region as MoonRegion
			from.y += region.get_height(from)
			to.y += region.get_height(to)
		p.global_position = from - Vector3(0, 1.6, 0)
		cam.global_position = from
		cam.look_at(to, Vector3.UP)
		cam.make_current()
		await get_tree().create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(String(s[0]) + ".png"))
	# cámara real del juego dentro del monoblock (tercera persona en interiores)
	p.visual.visible = true
	p.global_position = (home as ColonyModule).spawn_point()
	p.camera_rig.yaw = home.rotation.y + PI * 0.8
	p.camera_rig.get_camera().make_current()
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("16_gameplay_cam_interior.png"))
	# tripulante en su rutina
	var c: CrewMember = colony.crew[0]
	cam.make_current()
	cam.global_position = c.global_position + Vector3(1.5, 1.6, 2.2)
	cam.look_at(c.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("17_crew.png"))
	# cámara de juego afuera: horizonte curvo, barra de herramientas y binoculares
	var hub := colony.resolve_point("hub")
	p.global_position = hub + Vector3(-3.0, 0.2, -3.0)
	p.camera_rig.yaw = PI * 0.15
	p.camera_rig.pitch = deg_to_rad(-5.0)
	p.camera_rig.set_process_unhandled_input(false) # el mouse real no mueve la toma
	p.camera_rig.get_camera().make_current()
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("19_gameplay_horizon.png"))
	p.binoculars_active = true
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("20_binoculars.png"))
	# binoculares hacia la Tierra (círculo de seguimiento y ficha de datos)
	var sky := ((_session.region.get_node("WorldEnvironment") as WorldEnvironment).environment.sky.sky_material as ShaderMaterial)
	var e := (sky.get_shader_parameter("planet_direction") as Vector3).normalized()
	p.camera_rig.yaw = atan2(-e.x, -e.z)
	p.camera_rig.pitch = asin(e.y)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("22_binoculars_earth.png"))
	p.binoculars_active = false
	# el Sol, sin binoculares
	for l in _session.region.find_children("*", "DirectionalLight3D", true, false):
		var sd := (l as DirectionalLight3D).global_basis.z.normalized()
		cam.global_position = hub + Vector3(0, 40.0, 0)
		cam.look_at(cam.global_position + sd, Vector3.UP if absf(sd.y) < 0.95 else Vector3.FORWARD)
		cam.rotate_object_local(Vector3.UP, 0.18)
		cam.make_current()
		break
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("23_sun.png"))
	# binoculares: Júpiter y una roca
	p.camera_rig.get_camera().make_current()
	for b: Dictionary in CelestialCatalog.bodies():
		if String(b.id) == "jupiter":
			var jd := CelestialCatalog.dir_from(float(b.el), float(b.az))
			p.camera_rig.yaw = atan2(-jd.x, -jd.z)
			p.camera_rig.pitch = minf(asin(jd.y), deg_to_rad(44.0))
	p.binoculars_active = true
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("24_binoculars_jupiter.png"))
	var rock: ResourceDeposit = null
	var best := INF
	for n in get_tree().get_nodes_in_group(&"resource_deposit"):
		var d := (n as Node3D).global_position.distance_to(p.global_position)
		if d > 12.0 and d < best:
			best = d
			rock = n as ResourceDeposit
	if rock:
		var to := rock.global_position + Vector3(0, 0.3, 0) - p.camera_rig.get_camera().global_position
		p.camera_rig.yaw = atan2(-to.x, -to.z)
		p.camera_rig.pitch = asin(clampf(to.normalized().y, -0.9, 0.7))
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("25_binoculars_rock.png"))
	p.binoculars_active = false
	# escaneo: rocas marcadas por lo que dan
	p.camera_rig.pitch = deg_to_rad(-12.0)
	(p.get_node("Scanner") as Scanner).call("_emit_pulse")
	await get_tree().create_timer(3.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("26_scan.png"))
	var mm := get_tree().get_first_node_in_group(&"minimap")
	if mm:
		var ev := InputEventAction.new()
		ev.action = &"map"
		ev.pressed = true
		mm.call("_unhandled_input", ev)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("27_full_map.png"))
		mm.call("_unhandled_input", ev)
	# veta de ilmenita (hierro) más cercana
	var iron: ResourceDeposit = null
	var bi := INF
	for n in get_tree().get_nodes_in_group(&"resource_deposit"):
		var dd := n as ResourceDeposit
		if dd.item_id == &"iron" and dd.global_position.length() < bi:
			bi = dd.global_position.length()
			iron = dd
	if iron:
		cam.make_current()
		cam.global_position = iron.global_position + (iron.global_position - Vector3(0, iron.global_position.y, 0)).normalized() * -3.0 + Vector3(0, 1.6, 0)
		cam.look_at(iron.global_position + Vector3(0, 0.3, 0), Vector3.UP)
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("28_iron.png"))
		print("IRON nearest at ", iron.global_position, " dist ", bi)
	# inventario (Tab)
	p.inventory.add(&"iron", 6)
	p.inventory.add(&"regolith", 10)
	for ui in get_tree().get_nodes_in_group(&"session_ui"):
		if ui is InventoryScreen:
			(ui as InventoryScreen)._toggle(true)
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("29_inventory.png"))
			(ui as InventoryScreen)._toggle(false)
	# sucesos: radio y decisión
	var ed := get_tree().get_first_node_in_group(&"event_director") as EventDirector
	if ed:
		p.camera_rig.get_camera().make_current()
		ed.trigger(&"dust")
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("30_radio.png"))
		p.inventory.add(&"iron", 2)
		ed.trigger(&"leak")
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("31_decision.png"))
		for dlg in get_tree().root.get_children():
			if dlg is DecisionDialog:
				(dlg as DecisionDialog)._close()
	# reparto de energía y siembra en el domo
	var col := get_tree().get_first_node_in_group(&"colony") as Colony
	if col:
		var bbank := col.get_module("battery_bank")
		col.open_terminal(&"power", bbank, p)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("32_power.png"))
		(col.get("_terminal") as ColonyTerminal).close()
		var bdome := col.get_biodome()
		if bdome:
			bdome.beds[0].crop = ""
			bdome.call("_plant_dialog", 0)
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("33_plant.png"))
			for dlg in get_tree().root.get_children():
				if dlg is DecisionDialog:
					(dlg as DecisionDialog)._close()
	print("COLONY_TOUR_DONE ", ProjectSettings.globalize_path(dir))
	get_tree().quit()
