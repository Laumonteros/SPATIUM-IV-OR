class_name CommandCenter
extends ColonyModule
## Centro de Comando y Refugio, instalado en el cohete de llegada de la tripulación.
##
## Cohete vertical de 24 m (referencia visual del mapa) sobre su plataforma, con
## torre de servicio, elevador real (plataforma móvil que lleva al astronauta) y
## pasarela hasta la escotilla de la cabina, a 9 m de altura.
## La cabina es el refugio más protegido de la colonia: está rodeada por los
## tanques de agua y propelente (el agua es buen blindaje contra protones).
## Consolas: guardar la partida, pedidos a la Tierra y estado de la colonia.

const BODY_R := 2.6
const CABIN_FLOOR := 9.0
const CABIN_H := 3.3
const CABIN_R := 2.3
const TOWER_X := 5.4
const PAD_R := 7.5

var _elevator: AnimatableBody3D
var _elevator_up := false
var _elevator_busy := false


func _build_module(b: ModuleBuilder) -> void:
	_pad(b)
	_rocket(b)
	_cabin(b)
	_tower(b)
	interior_volumes = [AABB(Vector3(-CABIN_R, CABIN_FLOOR - 0.2, -CABIN_R), Vector3(CABIN_R * 2.0, CABIN_H, CABIN_R * 2.0))]


func contains_point(p: Vector3) -> bool:
	var lp := global_transform.affine_inverse() * p
	return Vector2(lp.x, lp.z).length() < CABIN_R + 0.1 and lp.y > CABIN_FLOOR - 0.3 and lp.y < CABIN_FLOOR + CABIN_H


func status_light_position() -> Vector3:
	return Vector3(0, 24.4, 0)


func _pad(b: ModuleBuilder) -> void:
	var drop := -ground_drop + 0.35
	b.cyl(PAD_R, drop, Vector3(0, -drop * 0.5, 0), &"concrete", Vector3.ZERO, &"shell", 36)
	b.cyl(PAD_R + 0.1, 0.06, Vector3(0, -0.05, 0), &"frame", Vector3.ZERO, &"", 36, PAD_R)
	b.cyl(3.4, 0.02, Vector3(0, 0.02, 0), &"armor", Vector3.ZERO, &"", 24) # quemado del motor (1 cm sobre la losa)
	for k in 8: # marcas de la plataforma
		var a := TAU * k / 8.0
		b.box(Vector3(0.25, 0.02, 1.2), Vector3(sin(a), 0, cos(a)) * (PAD_R - 0.9) + Vector3(0, 0.025, 0), &"stripe_amber", Vector3(0, a, 0))
		b.box(Vector3(0.1, 0.1, 0.1), Vector3(sin(a), 0, cos(a)) * (PAD_R - 0.25) + Vector3(0, 0.06, 0), &"light_amber" if k % 2 else &"light_red")
	door_ramp(b, Vector3(0, 0, PAD_R), Vector3(0, 0, 1), 2.4)


func _rocket(b: ModuleBuilder) -> void:
	# tobera y patas
	b.cyl(1.0, 1.6, Vector3(0, 1.3, 0), &"armor", Vector3.ZERO, &"shell", 20, 0.45)
	b.cyl(0.55, 0.5, Vector3(0, 2.3, 0), &"frame", Vector3.ZERO, &"", 16)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var top := Vector3(sin(a), 0, cos(a)) * (BODY_R - 0.2) + Vector3(0, 4.2, 0)
		var foot := Vector3(sin(a), 0, cos(a)) * (BODY_R + 1.8) + Vector3(0, 0.15, 0)
		b.pipe(top, foot, 0.16, &"frame")
		# colisión de la pata (caja orientada a lo largo del puntal)
		var leg := foot - top
		var leg_basis := Basis(Quaternion(Vector3.UP, leg.normalized()))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, leg.length(), 0.3)
		cs.shape = bs
		cs.transform = Transform3D(leg_basis, (top + foot) * 0.5)
		b.shell.add_child(cs)
		b.pipe(top - Vector3(0, 1.6, 0), foot + Vector3(0, 0.3, 0), 0.08, &"metal")
		b.cyl(0.55, 0.15, foot, &"metal", Vector3.ZERO, &"furniture", 12)
	# fuselaje: tramo inferior (tanques), cabina y tramo superior
	b.cyl(BODY_R, 6.4, Vector3(0, 2.6 + 3.2, 0), &"hull", Vector3.ZERO, &"shell", 32)
	for y: float in [3.6, 6.2, 8.7]:
		b.cyl(BODY_R + 0.04, 0.25, Vector3(0, y, 0), &"frame", Vector3.ZERO, &"", 32)
	b.cyl(BODY_R, 0.3, Vector3(0, CABIN_FLOOR - 0.15, 0), &"frame", Vector3.ZERO, &"shell", 32)
	b.cyl(BODY_R, 0.35, Vector3(0, CABIN_FLOOR + CABIN_H + 0.18, 0), &"frame", Vector3.ZERO, &"shell", 32)
	b.cyl(BODY_R, 7.0, Vector3(0, CABIN_FLOOR + CABIN_H + 0.35 + 3.5, 0), &"hull", Vector3.ZERO, &"shell", 32)
	b.cyl(BODY_R + 0.04, 0.3, Vector3(0, 16.0, 0), &"frame", Vector3.ZERO, &"", 32)
	b.cyl(BODY_R, 4.0, Vector3(0, 21.65, 0), &"hull", Vector3.ZERO, &"", 32, 0.35) # cono
	b.sphere(0.36, Vector3(0, 23.6, 0), &"hull")
	b.label("CENTINELA", Vector3(-BODY_R - 0.02, 20.0, 1.6), Vector3(0, -PI * 0.5, PI * 0.5), 0.05, Color(0.1, 0.12, 0.15), 900.0).visibility_range_end = 400.0
	# aletas/paneles de radiador y luces de posición
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		b.box(Vector3(0.08, 3.0, 1.2), Vector3(sin(a), 0, cos(a)) * (BODY_R + 0.6) + Vector3(0, 14.5, 0), &"hull_panel", Vector3(0, a, 0))
	b.sphere(0.12, Vector3(0, 24.0, 0), &"light_red")


func _cabin(b: ModuleBuilder) -> void:
	var y0 := CABIN_FLOOR
	b.cyl(CABIN_R + 0.1, 0.05, Vector3(0, y0 + 0.02, 0), &"floor", Vector3.ZERO, &"", 24)
	# muro anular con escotilla (+X, hacia la torre) y dos ojos de buey reales
	var n := 20
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var mid := (a0 + a1) * 0.5
		var deg := fposmod(rad_to_deg(mid), 360.0)
		if absf(deg - 90.0) < 360.0 / n: # hueco de la escotilla
			continue
		var p0 := Vector3(sin(a0), 0, cos(a0)) * (CABIN_R + 0.13) + Vector3(0, y0, 0)
		var p1 := Vector3(sin(a1), 0, cos(a1)) * (CABIN_R + 0.13) + Vector3(0, y0, 0)
		var ops: Array[Vector4] = []
		if absf(deg - 0.0) < 9.5 or absf(deg - 180.0) < 9.5 or absf(deg - 360.0) < 9.5:
			ops = [Vector4(p0.distance_to(p1) * 0.5 - 0.3, 0.6, 1.3, 0.6)]
		b.wall(p1, p0, CABIN_H, 0.18, ops, &"hull", &"interior_wall")
	var hp := Vector3(BODY_R, y0, 0)
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.4, 2.45, 0.35), Vector3(CABIN_R + 0.15, y0 + 1.225, s * 0.83), &"frame", Vector3.ZERO, &"shell")
	b.box(Vector3(0.4, CABIN_H - 2.45, 1.95), Vector3(CABIN_R + 0.15, y0 + 2.45 + (CABIN_H - 2.45) * 0.5, 0), &"frame", Vector3.ZERO, &"shell")
	add_door(b, hp - Vector3(0.12, 0, 0), PI * 0.5, 0.3)
	b.detail = true
	# consolas: guardar, pedidos a la Tierra y estado de la colonia (lado -X)
	var consoles := [[&"save", "COLONY_CMD_SAVE", 200.0], [&"supplies", "COLONY_CMD_SUPPLIES", 270.0], [&"status", "COLONY_CMD_STATUS", 340.0]]
	for c: Array in consoles:
		var a := deg_to_rad(float(c[2]))
		var dir := Vector3(sin(a), 0, cos(a))
		var pos := dir * (CABIN_R - 0.45) + Vector3(0, y0, 0)
		var yaw := atan2(-dir.x, -dir.z)
		screens.append(b.terminal(pos, yaw, "", &"screen_cyan", true))
		b.chair(dir * (CABIN_R - 1.25) + Vector3(0, y0, 0), yaw)
		var it := b.interactable(dir * (CABIN_R - 0.9) + Vector3(0, y0 + 1.1, 0), "ACTION_USE_TERMINAL", tr(String(c[1])), 0.5, 1.9)
		var mode: StringName = c[0]
		it.interacted.connect(func(by: Node) -> void:
			var col := colony()
			if col:
				col.open_terminal(mode if mode != &"status" else &"command_status", self, by))
	# tanques de agua del refugio de tormenta (blindaje) y casilleros
	for deg: float in [30.0, 140.0]:
		var a := deg_to_rad(deg)
		var p := Vector3(sin(a), 0, cos(a)) * (CABIN_R - 0.35) + Vector3(0, y0, 0)
		b.cyl(0.3, 2.6, p + Vector3(0, 1.4, 0), &"pipe_blue", Vector3.ZERO, &"furniture", 14)
		b.box(Vector3(0.1, 0.4, 0.02), p + Vector3(0, 1.6, 0) - Vector3(sin(a), 0, cos(a)) * 0.31, &"stripe_amber", Vector3(0, a, 0))
	b.locker(Vector3(sin(deg_to_rad(60.0)), 0, cos(deg_to_rad(60.0))) * (CABIN_R - 0.35) + Vector3(0, y0, 0), deg_to_rad(60.0) + PI, 1)
	b.locker(Vector3(sin(deg_to_rad(120.0)), 0, cos(deg_to_rad(120.0))) * (CABIN_R - 0.35) + Vector3(0, y0, 0), deg_to_rad(120.0) + PI, 1)
	b.box(Vector3(0.4, 0.3, 0.15), Vector3(-0.3, y0 + 2.4, CABIN_R - 0.12), &"plastic") # botiquín
	b.box(Vector3(0.12, 0.12, 0.01), Vector3(-0.3, y0 + 2.4, CABIN_R - 0.2), &"light_red")
	# escalera a la cubierta superior (escotilla cerrada) y servicios
	for k in 8:
		b.box(Vector3(0.45, 0.03, 0.03), Vector3(0, y0 + 0.35 + k * 0.36, -0.4), &"metal")
	for s: float in [-0.22, 0.22]:
		b.box(Vector3(0.04, CABIN_H, 0.04), Vector3(s, y0 + CABIN_H * 0.5, -0.4), &"stripe_amber")
	b.cyl(0.45, 0.06, Vector3(0, y0 + CABIN_H - 0.03, -0.4), &"frame", Vector3.ZERO, &"", 12)
	b.ceiling_light(Vector3(0.9, y0 + CABIN_H - 0.05, 0.5), Color(0.92, 0.96, 1.0), 1.4, 5.0)
	b.ceiling_light(Vector3(-0.9, y0 + CABIN_H - 0.05, 0.5), Color(0.92, 0.96, 1.0), 1.0, 5.0, false)
	b.omni(Vector3(-1.3, y0 + 1.6, 0), Color(0.4, 0.85, 1.0), 0.6, 3.0) # brillo de consolas
	b.pipe(Vector3(-CABIN_R + 0.15, y0 + CABIN_H - 0.2, -1.2), Vector3(-CABIN_R + 0.15, y0 + CABIN_H - 0.2, 1.2), 0.05, &"pipe_white")
	b.pipe(Vector3(-CABIN_R + 0.3, y0 + CABIN_H - 0.25, -1.2), Vector3(-CABIN_R + 0.3, y0 + CABIN_H - 0.25, 1.2), 0.035, &"copper")
	b.detail = false


func _tower(b: ModuleBuilder) -> void:
	var tx := TOWER_X
	var hs := 1.4
	var top := CABIN_FLOOR + 4.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(Vector3(0.2, top, 0.2), Vector3(tx + sx * hs, top * 0.5, sz * hs), &"frame", Vector3.ZERO, &"shell")
	var y := 1.5
	while y < top: # arriostramiento
		for sz: float in [-1.0, 1.0]:
			b.box(Vector3(hs * 2.0, 0.1, 0.1), Vector3(tx, y, sz * hs), &"stripe_amber" if int(y) % 3 == 0 else &"frame")
		b.pipe(Vector3(tx + hs, y - 1.5, -hs), Vector3(tx + hs, y, hs), 0.04, &"frame")
		y += 1.5
	b.box(Vector3(hs * 2.0 + 0.3, 0.2, hs * 2.0 + 0.3), Vector3(tx, top, 0), &"frame")
	b.sphere(0.12, Vector3(tx, top + 0.3, 0), &"light_red")
	# pasarela torre → escotilla, con barandas
	var bx0 := BODY_R - 0.05
	var bx1 := tx - hs + 0.15 # la pasarela llega al borde del elevador
	b.box(Vector3(bx1 - bx0, 0.15, 1.7), Vector3((bx0 + bx1) * 0.5, CABIN_FLOOR - 0.075, 0), &"floor", Vector3.ZERO, &"shell")
	for s: float in [-1.0, 1.0]:
		b.pipe(Vector3(bx0, CABIN_FLOOR + 1.0, s * 0.85), Vector3(bx1, CABIN_FLOOR + 1.0, s * 0.85), 0.03, &"stripe_amber")
		b.collider(Vector3(bx1 - bx0, 1.0, 0.06), Vector3((bx0 + bx1) * 0.5, CABIN_FLOOR + 0.5, s * 0.85))
	# barandas de la torre a la altura de la cabina (excepto el lado de la pasarela)
	for sz: float in [-1.0, 1.0]:
		b.collider(Vector3(hs * 2.0, 1.1, 0.06), Vector3(tx, CABIN_FLOOR + 0.55, sz * (hs - 0.05)))
	b.collider(Vector3(0.06, 1.1, hs * 2.0), Vector3(tx + hs - 0.05, CABIN_FLOOR + 0.55, 0))
	# elevador (plataforma móvil separada, con baranda y botonera)
	_elevator = ModuleBuilder.mark_dynamic(AnimatableBody3D.new()) as AnimatableBody3D
	_elevator.name = "Elevator"
	_elevator.collision_layer = ModuleBuilder.LAYER_SHELL
	_elevator.sync_to_physics = true
	_elevator.position = Vector3(tx, 0.1, 0)
	b.root.add_child(_elevator)
	var g := Node3D.new()
	_elevator.add_child(g)
	b.box(Vector3(2.4, 0.15, 2.4), Vector3.ZERO, &"floor", Vector3.ZERO, &"", g)
	b.box(Vector3(2.5, 0.05, 2.5), Vector3(0, 0.08, 0), &"stripe_amber", Vector3.ZERO, &"", g).scale = Vector3(1, 1, 1)
	# barandas sur y este; se sube por el norte (abajo) y se sale por el oeste (pasarela)
	b.pipe(Vector3(-1.15, 1.0, -1.15), Vector3(1.15, 1.0, -1.15), 0.03, &"stripe_amber", g)
	b.pipe(Vector3(1.15, 1.0, -1.15), Vector3(1.15, 1.0, 1.15), 0.03, &"stripe_amber", g)
	b.box(Vector3(0.3, 1.1, 0.2), Vector3(0.95, 0.6, -0.95), &"frame", Vector3.ZERO, &"", g)
	b.box(Vector3(0.12, 0.12, 0.02), Vector3(0.95, 1.0, -0.84), &"light_green", Vector3.ZERO, &"", g)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 0.15, 2.4)
	cs.shape = bs
	_elevator.add_child(cs)
	var rail := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = Vector3(2.4, 1.0, 0.06)
	rail.shape = rs
	rail.position = Vector3(0, 0.55, -1.15)
	_elevator.add_child(rail)
	var rail2 := CollisionShape3D.new()
	var rs2 := BoxShape3D.new()
	rs2.size = Vector3(0.06, 1.0, 2.4)
	rail2.shape = rs2
	rail2.position = Vector3(1.15, 0.55, 0)
	_elevator.add_child(rail2)
	var panel := Interactable.new()
	panel.action_key = "ACTION_ELEVATOR"
	panel.display_name = tr("COLONY_ELEVATOR")
	panel.max_distance = 1.9
	var pcs := CollisionShape3D.new()
	var ps := SphereShape3D.new()
	ps.radius = 0.5
	pcs.shape = ps
	panel.add_child(pcs)
	panel.position = Vector3(0.7, 1.0, -0.7)
	_elevator.add_child(panel)
	panel.interacted.connect(func(_by: Node) -> void: ride_elevator())
	# botoneras de llamada: abajo (lado oeste, por donde se entra a la torre) y arriba
	for at: Vector3 in [Vector3(tx + 0.9, 1.2, hs + 0.25), Vector3(bx0 + 0.6, CABIN_FLOOR + 1.1, 0.8)]:
		b.box(Vector3(0.2, 0.35, 0.1), at, &"frame")
		b.box(Vector3(0.1, 0.1, 0.02), at + Vector3(0, 0.05, 0.06), &"light_amber")
		var call := b.interactable(at, "ACTION_CALL_ELEVATOR", tr("COLONY_ELEVATOR"), 0.45, 1.8)
		var want_up: bool = at.y > 5.0
		call.interacted.connect(func(_by: Node) -> void: call_elevator(want_up))
	sign_plate(b, Vector3(tx, 2.6, hs + 0.2), 0.0, tr("COLONY_COMMAND_NAME").to_upper(), tr("COLONY_SECTOR_COMMAND"))
	b.omni(Vector3(tx, 2.8, hs + 1.0), Color(1.0, 0.88, 0.7), 1.6, 7.0)
	b.omni(Vector3(bx1 - 0.6, CABIN_FLOOR + 2.4, 0), Color(1.0, 0.88, 0.7), 1.2, 5.0)


## Sube o baja el elevador (lleva lo que haya encima: el astronauta incluido).
func ride_elevator() -> void:
	call_elevator(not _elevator_up)


func call_elevator(up: bool) -> void:
	if _elevator_busy or up == _elevator_up:
		return
	_elevator_busy = true
	_elevator_up = up
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_elevator, "position:y", CABIN_FLOOR - 0.075 if up else 0.1, 6.0)
	tw.tween_callback(func() -> void: _elevator_busy = false)


func is_elevator_up() -> bool:
	return _elevator_up


func _update_screens() -> void:
	var c := colony()
	if c == null or screens.size() < 3:
		return
	screens[0].text = c.save_screen()
	screens[1].text = c.supply_screen()
	screens[2].text = c.colony_status_text(true)


func get_status_text() -> String:
	return "%s · %s" % [def.get_display_name(), tr("STATUS_OPERATIONAL") if is_operational() else tr("STATUS_NO_POWER")]
