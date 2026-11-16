class_name Workshop
extends ColonyModule
## Taller de Fabricación e Ingeniería (14 × 10 m, nave de 5 m de alto).
##
## Impresora 3D de regolito de gran formato (cabezal con pórtico móvil), brazo
## robótico de tres articulaciones, bancos de trabajo, tablero de herramientas,
## puente grúa y terminal de fabricación. El portón de carga (4 × 3,4 m) se abre
## desde su botonera; la puerta de personal es automática.
##
## Mientras fabrica, consume más energía y las piezas móviles trabajan de verdad:
## sin energía la fabricación se detiene.

const W := 14.0
const D := 10.0
const H := 5.0
const T := 0.3
const IDLE_FACTOR := 0.2
const CARGO_W := 4.0
const CARGO_H := 3.4

var fabricating: bool = false
var _gantry: Node3D
var _head: Node3D
var _printed: MeshInstance3D
var _arm: Array[Node3D] = []
var _cargo: AnimatableBody3D
var _cargo_open := false
var _t := 0.0
var fab_progress: float = 0.0


func _build_module(b: ModuleBuilder) -> void:
	foundation(b, Vector2(W, D))
	b.slab(Vector3(W + T, 0.2, D + T), Vector3.ZERO, &"floor")
	b.box(Vector3(W + T, 0.3, D + T), Vector3(0, H + 0.15, 0), &"hull", Vector3.ZERO, &"shell")
	perimeter(b, W, D, H, T, {
		&"front": [Vector4(3.5, ModuleDoor.WIDTH + 0.3, 0, ModuleDoor.HEIGHT + 0.15), Vector4(-2.5, CARGO_W, 0, CARGO_H)],
		&"left": [Vector4(0.0, 3.0, 3.2, 1.2)], # ventanas altas (luz de trabajo)
		&"right": [Vector4(0.0, 3.0, 3.2, 1.2)],
	}, &"armor", &"interior_wall")
	hull_ribs(b, W, D, H, T, 2.0)
	add_door(b, Vector3(3.5, 0, D * 0.5), 0.0, T)
	door_ramp(b, Vector3(3.5, 0, D * 0.5 + T * 0.5 + 0.05), Vector3(0, 0, 1))
	door_ramp(b, Vector3(-2.5, 0, D * 0.5 + T * 0.5 + 0.05), Vector3(0, 0, 1), CARGO_W)
	_cargo_door(b)
	sign_plate(b, Vector3(3.5, 3.0, D * 0.5 + T * 0.5 + 0.06), 0.0, tr("COLONY_WORKSHOP_NAME").to_upper(), tr("COLONY_SECTOR_WORKSHOP"))
	b.omni(Vector3(0.5, 4.2, D * 0.5 + 1.5), Color(1.0, 0.88, 0.7), 2.4, 9.0)
	_printer(b)
	_robot_arm(b)
	_benches(b)
	interior_volumes = [AABB(Vector3(-W * 0.5, 0, -D * 0.5), Vector3(W, H, D - 0.15))]


func status_light_position() -> Vector3:
	return Vector3(5.5, H + 0.6, D * 0.5)


func _cargo_door(b: ModuleBuilder) -> void:
	_cargo = ModuleBuilder.mark_dynamic(AnimatableBody3D.new()) as AnimatableBody3D
	_cargo.name = "CargoDoor"
	_cargo.collision_layer = ModuleBuilder.LAYER_SHELL
	_cargo.sync_to_physics = false
	_cargo.position = Vector3(-2.5, 0, D * 0.5)
	b.root.add_child(_cargo)
	var g := Node3D.new()
	_cargo.add_child(g)
	for k in 8: # lamas del portón
		b.box(Vector3(CARGO_W, CARGO_H / 8.0 - 0.02, 0.08), Vector3(0, (k + 0.5) * CARGO_H / 8.0, 0), &"hull_panel" if k % 2 else &"metal", Vector3.ZERO, &"", g)
	b.box(Vector3(CARGO_W, 0.12, 0.1), Vector3(0, 0.06, 0), &"stripe_amber", Vector3.ZERO, &"", g)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CARGO_W, CARGO_H, 0.12)
	cs.shape = bs
	cs.position.y = CARGO_H * 0.5
	_cargo.add_child(cs)
	# botoneras exterior e interior
	for side: float in [1.0, -1.0]:
		var p := Vector3(-2.5 + CARGO_W * 0.5 + 0.5, 1.3, D * 0.5 + side * (T * 0.5 + 0.08))
		b.box(Vector3(0.3, 0.45, 0.08), p, &"frame")
		b.box(Vector3(0.12, 0.12, 0.02), p + Vector3(0, 0.08, side * 0.05), &"light_amber")
		var it := b.interactable(p + Vector3(0, 0, side * 0.4), "ACTION_TOGGLE_CARGO", tr("COLONY_CARGO_DOOR"), 0.5, 1.8)
		it.interacted.connect(func(_by: Node) -> void: toggle_cargo_door())


func toggle_cargo_door() -> void:
	_cargo_open = not _cargo_open
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cargo, "position:y", CARGO_H - 0.25 if _cargo_open else 0.0, 2.2)


func _printer(b: ModuleBuilder) -> void:
	b.detail = true
	var c := Vector3(-3.0, 0, -1.8)
	# bastidor de la impresora de regolito sinterizado
	b.box(Vector3(3.6, 0.35, 3.0), c + Vector3(0, 0.18, 0), &"frame", Vector3.ZERO, &"furniture")
	b.box(Vector3(3.0, 0.06, 2.5), c + Vector3(0, 0.38, 0), &"concrete")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(Vector3(0.14, 3.2, 0.14), c + Vector3(sx * 1.75, 1.6, sz * 1.45), &"stripe_amber", Vector3.ZERO, &"furniture")
	for sz: float in [-1.0, 1.0]:
		b.box(Vector3(3.6, 0.14, 0.14), c + Vector3(0, 3.2, sz * 1.45), &"frame")
	_gantry = ModuleBuilder.mark_dynamic(b.group(c + Vector3(0, 3.05, 0), 0.0, "PrinterGantry")) as Node3D
	b.box(Vector3(3.4, 0.12, 0.18), Vector3.ZERO, &"metal", Vector3.ZERO, &"", _gantry)
	_head = b.group(Vector3(0, -0.2, 0), 0.0, "PrinterHead", _gantry)
	b.box(Vector3(0.3, 0.35, 0.3), Vector3.ZERO, &"plastic", Vector3.ZERO, &"", _head)
	b.cyl(0.04, 0.4, Vector3(0, -0.35, 0), &"metal", Vector3.ZERO, &"", 8, 0.015, _head)
	b.box(Vector3(0.06, 0.06, 0.02), Vector3(0, 0.05, 0.16), &"light_amber", Vector3.ZERO, &"", _head)
	_head.add_child(OmniLight3D.new())
	var tip := _head.get_child(_head.get_child_count() - 1) as OmniLight3D
	tip.position = Vector3(0, -0.6, 0)
	tip.light_color = Color(1.0, 0.6, 0.3)
	tip.light_energy = 0.0
	tip.omni_range = 2.0
	tip.name = "SinterGlow"
	# pieza en impresión (crece con el progreso real de fabricación)
	_printed = ModuleBuilder.mark_dynamic(b.box(Vector3(1.2, 1.0, 1.0), c + Vector3(0, 0.41, 0), &"concrete")) as MeshInstance3D
	_printed.scale = Vector3(1, 0.001, 1)
	# tolva de regolito y conducto
	b.cyl(0.6, 1.4, c + Vector3(-2.3, 2.2, -1.0), &"hull_panel", Vector3.ZERO, &"furniture", 16, 0.15)
	b.box(Vector3(0.4, 1.5, 0.4), c + Vector3(-2.3, 0.75, -1.0), &"frame", Vector3.ZERO, &"furniture")
	b.pipe(c + Vector3(-2.3, 2.9, -1.0), c + Vector3(-1.75, 3.2, -1.0), 0.08, &"pipe_white")
	screens.append(b.wall_screen(Vector3(-3.0, 2.4, -D * 0.5 + 0.18), 0.0, Vector2(2.0, 1.0)))
	b.detail = false


func _robot_arm(b: ModuleBuilder) -> void:
	b.detail = true
	var base := ModuleBuilder.mark_dynamic(b.group(Vector3(0.2, 0, -2.8), 0.0, "RobotArm_Base")) as Node3D
	b.cyl(0.45, 0.4, Vector3(0, 0.2, 0), &"frame", Vector3.ZERO, &"furniture", 16, -1.0, base)
	var j1 := b.group(Vector3(0, 0.4, 0), 0.0, "RobotArm_J1", base)
	b.cyl(0.32, 0.4, Vector3(0, 0.2, 0), &"stripe_amber", Vector3.ZERO, &"", 14, -1.0, j1)
	var j2 := b.group(Vector3(0, 0.45, 0), 0.0, "RobotArm_J2", j1)
	b.box(Vector3(0.22, 1.4, 0.22), Vector3(0, 0.7, 0), &"stripe_amber", Vector3.ZERO, &"", j2)
	b.cyl(0.16, 0.35, Vector3(0, 0, 0), &"frame", Vector3(0, 0, PI * 0.5), &"", 12, -1.0, j2)
	var j3 := b.group(Vector3(0, 1.4, 0), 0.0, "RobotArm_J3", j2)
	b.cyl(0.14, 0.3, Vector3.ZERO, &"frame", Vector3(0, 0, PI * 0.5), &"", 12, -1.0, j3)
	b.box(Vector3(0.16, 1.1, 0.16), Vector3(0, 0.55, 0), &"stripe_amber", Vector3.ZERO, &"", j3)
	var tool := b.group(Vector3(0, 1.1, 0), 0.0, "RobotArm_Tool", j3)
	b.box(Vector3(0.25, 0.12, 0.25), Vector3.ZERO, &"metal", Vector3.ZERO, &"", tool)
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.04, 0.2, 0.08), Vector3(s * 0.09, 0.15, 0), &"frame", Vector3.ZERO, &"", tool)
	_arm = [j1, j2, j3]
	j2.rotation.x = 0.35
	j3.rotation.x = 0.9
	b.box(Vector3(2.0, 0.02, 2.0), Vector3(0.2, 0.02, -2.8), &"stripe_amber") # zona de seguridad
	b.detail = false


func _benches(b: ModuleBuilder) -> void:
	b.detail = true
	var hw := W * 0.5
	var hd := D * 0.5
	b.workbench(Vector3(hw - 0.55, 0, -2.0), -PI * 0.5, 2.4)
	b.workbench(Vector3(hw - 0.55, 0, 1.3), -PI * 0.5, 2.0)
	b.tool_wall(Vector3(hw - 0.2, 0, -2.0), -PI * 0.5, 2.4)
	b.tool_wall(Vector3(0.0, 0, -hd + 0.2), 0.0, 2.4)
	b.chair(Vector3(hw - 1.4, 0, 1.3), PI * 0.5)
	# terminal de fabricación y mejoras (cian = información)
	screens.append(b.terminal(Vector3(2.2, 0, -hd + 0.6), 0.0, "", &"screen_cyan", true))
	b.rack(Vector3(5.0, 0, -hd + 0.45), 0.0, 2.0)
	# depósito de piezas y materiales (contra la pared izquierda, fuera de los pasos)
	for k in 3:
		b.crate(Vector3(-hw + 0.5, 0, 2.6 - k * 0.75), 0.05 * k, Vector3(0.7, 0.55, 0.65), [&"plastic", &"hull_panel", &"pipe_blue"][k])
	b.crate(Vector3(-hw + 0.5, 0.55, 2.6), 0.2, Vector3(0.55, 0.4, 0.5), &"plastic")
	for k in 4:
		b.gas_cylinder(Vector3(-hw + 0.35 + (k % 2) * 0.3, 0, -4.2 + (k / 2) * 0.3), &"pipe_white" if k % 2 else &"pipe_blue")
	b.shelf(Vector3(-hw + 0.2, 0, -0.6), PI * 0.5, 1.8, 4, false)
	# puente grúa (riel y carro)
	for z: float in [-3.8, 3.2]:
		b.box(Vector3(W - 0.6, 0.25, 0.2), Vector3(0, H - 0.5, z), &"frame")
	b.box(Vector3(0.3, 0.3, 7.2), Vector3(-3.0, H - 0.75, -0.3), &"stripe_amber")
	b.box(Vector3(0.5, 0.4, 0.5), Vector3(-3.0, H - 1.05, 0.8), &"frame")
	b.pipe(Vector3(-3.0, H - 1.25, 0.8), Vector3(-3.0, H - 2.4, 0.8), 0.015, &"cable")
	b.box(Vector3(0.25, 0.12, 0.12), Vector3(-3.0, H - 2.45, 0.8), &"metal")
	b.ceiling_services(Vector3(-hw + 0.5, H - 0.9, -hd + 0.5), Vector3(hw - 0.5, H - 0.9, -hd + 0.5))
	for x: float in [-4.0, 0.0, 4.0]:
		for z: float in [-2.0, 2.0]:
			b.ceiling_light(Vector3(x, H - 0.1, z), Color(1.0, 0.95, 0.88), 1.3, 8.0, z < 0.0 or x == 0.0)
	b.box(Vector3(0.6, 0.02, D - 1.0), Vector3(1.6, 0.02, 0.0), &"stripe_amber") # pasillo peatonal señalizado
	b.detail = false
	var it := b.interactable(Vector3(2.2, 1.1, -hd + 1.1), "ACTION_USE_TERMINAL", tr("COLONY_FAB_TERMINAL"), 0.6, 2.0)
	it.interacted.connect(func(by: Node) -> void:
		var c := colony()
		if c:
			c.open_terminal(&"fabrication", self, by))


func get_power_kw() -> float:
	if not is_built():
		return 0.0
	return def.power_kw if fabricating else def.power_kw * IDLE_FACTOR


func _process(delta: float) -> void:
	super._process(delta)
	var working := fabricating and is_operational()
	if not working:
		return
	_t += delta
	# pórtico y cabezal recorren la cama de impresión; el brazo alimenta piezas
	if _gantry:
		_gantry.position.z = sin(_t * 0.7) * 1.1
		_head.position.x = sin(_t * 1.9) * 1.3
		var glow := _head.get_node_or_null("SinterGlow") as OmniLight3D
		if glow:
			glow.light_energy = 1.2 + sin(_t * 23.0) * 0.4
	if _arm.size() == 3:
		_arm[0].rotation.y = sin(_t * 0.5) * 1.2
		_arm[1].rotation.x = 0.35 + sin(_t * 0.9) * 0.3
		_arm[2].rotation.x = 0.9 + sin(_t * 1.3) * 0.4


## La lleva `Colony` según el trabajo en curso (0..1).
func set_fabrication(on: bool, progress: float) -> void:
	if on != fabricating:
		fabricating = on
		if not on and _head:
			var glow := _head.get_node_or_null("SinterGlow") as OmniLight3D
			if glow:
				glow.light_energy = 0.0
	fab_progress = progress
	if _printed:
		_printed.scale = Vector3(1, maxf(progress, 0.001) if on else 0.001, 1)
		_printed.position.y = 0.41 + 0.5 * maxf(progress, 0.001)


func _update_screens() -> void:
	var c := colony()
	if c == null or screens.size() < 2:
		return
	screens[0].text = c.fabrication_screen()
	screens[1].text = c.fabrication_screen(true)
