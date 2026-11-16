class_name ResearchLab
extends ColonyModule
## Laboratorio Geológico y de Investigación (16 × 9 m, 3,3 m de alto).
##
## Pasillo de acceso al frente y dos salas: análisis geológico (izquierda) y
## control de observatorios (derecha). En el techo, dos cúpulas con telescopio
## articulado (cúpula: giro en azimut; tubo: elevación) que apuntan de verdad al
## objetivo que se calibra desde las consolas.
##
## Puntos de uso: terminal de fichas de rocas, estación de análisis de muestras
## (consume una muestra geológica), consolas de los observatorios 1 y 2.

const W := 16.0
const D := 9.0
const H := 3.3
const T := 0.25
const CORRIDOR_Z := 2.3 # tabique entre pasillo y salas

## Pivotes de los telescopios: [cúpula (azimut), tubo (elevación)]
var telescopes: Array[Array] = []
var _aim: Array[Vector2] = [Vector2(0.6, 0.5), Vector2(-2.2, 0.8)] # azimut, elevación (rad)


func _build_module(b: ModuleBuilder) -> void:
	foundation(b, Vector2(W, D))
	b.slab(Vector3(W + T, 0.2, D + T), Vector3.ZERO, &"floor")
	b.box(Vector3(W + T, 0.25, D + T), Vector3(0, H + 0.125, 0), &"hull", Vector3.ZERO, &"shell")
	perimeter(b, W, D, H, T, {
		&"front": [Vector4(-4.0, ModuleDoor.WIDTH + 0.3, 0, ModuleDoor.HEIGHT + 0.15), Vector4(2.0, 1.6, 1.1, 0.9), Vector4(5.5, 1.6, 1.1, 0.9)],
		&"back": [Vector4(-4.0, 1.4, 1.2, 0.8), Vector4(4.0, 1.4, 1.2, 0.8)],
		&"left": [Vector4(-1.5, 1.2, 1.1, 0.9)],
		&"right": [Vector4(1.5, 1.2, 1.1, 0.9)],
	})
	hull_ribs(b, W, D, H, T, 2.0)
	add_door(b, Vector3(-4.0, 0, D * 0.5), 0.0, T)
	door_ramp(b, Vector3(-4.0, 0, D * 0.5 + T * 0.5 + 0.05), Vector3(0, 0, 1))
	sign_plate(b, Vector3(-1.2, 2.75, D * 0.5 + T * 0.5 + 0.06), 0.0, tr("COLONY_LAB_NAME").to_upper(), tr("COLONY_SECTOR_RESEARCH"))
	b.omni(Vector3(-4.0, 2.9, D * 0.5 + 1.0), Color(1.0, 0.88, 0.7), 1.6, 6.0)
	_partitions(b)
	_geology_room(b)
	_observatory_room(b)
	_corridor(b)
	_observatories(b)
	interior_volumes = [AABB(Vector3(-W * 0.5, 0, -D * 0.5), Vector3(W, H, D - 0.1))]


func status_light_position() -> Vector3:
	return Vector3(-6.5, H + 0.5, D * 0.5)


func _partitions(b: ModuleBuilder) -> void:
	var hw := W * 0.5
	# tabique del pasillo con dos accesos (uno por sala)
	var ops: Array[Vector4] = [Vector4(hw - 4.0 - 0.9, 1.8, 0, 2.4), Vector4(hw + 3.5 - 0.9, 1.8, 0, 2.4)]
	b.wall(Vector3(-hw, 0, CORRIDOR_Z), Vector3(hw, 0, CORRIDOR_Z), H, 0.15, ops, &"interior_trim", &"interior_wall")
	# tabique entre salas con vidrio superior (se ve el otro laboratorio)
	var ops2: Array[Vector4] = [Vector4(1.0, 1.6, 0, 2.4), Vector4(3.6, 2.4, 1.0, 1.4)]
	b.wall(Vector3(0, 0, CORRIDOR_Z), Vector3(0, 0, -D * 0.5), H, 0.15, ops2, &"interior_trim", &"interior_wall")


func _corridor(b: ModuleBuilder) -> void:
	b.detail = true
	var hd := D * 0.5
	b.locker(Vector3(-7.55, 0, 3.4), PI * 0.5, 2)
	b.box(Vector3(1.8, 0.45, 0.45), Vector3(-1.5, 0.23, hd - 0.4), &"interior_trim", Vector3.ZERO, &"furniture")
	b.box(Vector3(1.8, 0.06, 0.45), Vector3(-1.5, 0.48, hd - 0.4), &"fabric_blue")
	screens.append(b.wall_screen(Vector3(2.4, 1.7, CORRIDOR_Z + 0.1), 0.0, Vector2(2.2, 1.0)))
	b.ceiling_services(Vector3(-7.4, H - 0.25, 3.4), Vector3(7.4, H - 0.25, 3.4))
	for x: float in [-5.0, 0.0, 5.0]:
		b.ceiling_light(Vector3(x, H - 0.05, 3.4), Color(0.95, 0.97, 1.0), 1.0, 5.0)
	b.box(Vector3(W - 0.4, 0.02, 0.12), Vector3(0, 0.02, 3.4), &"light_green") # guía de evacuación
	b.detail = false


func _geology_room(b: ModuleBuilder) -> void:
	b.detail = true
	var hd := D * 0.5
	# mesada de análisis con microscopio y espectrómetro (pared del fondo)
	b.desk(Vector3(-5.6, 0, -hd + 0.5), 0.0, 2.6)
	_microscope(b, Vector3(-6.2, 0.79, -hd + 0.5))
	var xrf := b.group(Vector3(-4.9, 0.79, -hd + 0.45), 0.0, "XRF_Spectrometer")
	b.box(Vector3(0.6, 0.45, 0.5), Vector3(0, 0.23, 0), &"plastic", Vector3.ZERO, &"", xrf)
	b.box(Vector3(0.3, 0.2, 0.02), Vector3(0, 0.3, 0.26), &"screen_cyan", Vector3.ZERO, &"", xrf)
	b.box(Vector3(0.35, 0.05, 0.3), Vector3(0, 0.47, 0), &"glass", Vector3.ZERO, &"", xrf)
	b.chair(Vector3(-5.6, 0, -hd + 1.25), 0.0)
	# guantera de muestras (atmósfera de nitrógeno: no contaminar el regolito)
	var gb := b.group(Vector3(-2.2, 0, -hd + 0.55), 0.0, "Glovebox")
	b.box(Vector3(1.6, 0.85, 0.8), Vector3(0, 0.43, 0), &"interior_trim", Vector3.ZERO, &"furniture", gb)
	b.box(Vector3(1.5, 0.7, 0.7), Vector3(0, 1.22, 0), &"glass", Vector3.ZERO, &"furniture", gb)
	b.box(Vector3(1.55, 0.06, 0.75), Vector3(0, 1.6, 0), &"frame", Vector3.ZERO, &"", gb)
	for x: float in [-0.35, 0.35]:
		b.cyl(0.11, 0.05, Vector3(x, 1.15, 0.36), &"plastic_dark", Vector3(PI * 0.5, 0, 0), &"", 12, -1.0, gb)
		b.cyl(0.08, 0.35, Vector3(x, 1.12, 0.18), &"fabric_gray", Vector3(PI * 0.5, 0, 0), &"", 8, -1.0, gb)
	b.sphere(0.12, Vector3(-0.1, 0.95, 0), &"rock_sample", Vector3(1.2, 0.8, 1.0), gb, 8)
	# vitrina de muestras catalogadas
	var vit := b.shelf(Vector3(-7.7, 0, -1.6), PI * 0.5, 2.0, 3, false)
	for lvl in 3:
		for k in 4:
			b.sphere(0.07, Vector3(-0.75 + k * 0.5, 0.48 + lvl * 0.45, 0.02), &"rock_sample", Vector3(1.3, 0.8, 1.0), vit, 6)
	# terminal de fichas de rocas (cian = información)
	screens.append(b.terminal(Vector3(-7.45, 0, 0.0), PI * 0.5, "", &"screen_cyan", true))
	b.rack(Vector3(-0.6, 0, -hd + 0.45), 0.0, 1.8)
	b.ceiling_services(Vector3(-7.5, H - 0.25, -3.6), Vector3(-0.4, H - 0.25, -3.6))
	b.ceiling_light(Vector3(-5.5, H - 0.05, -1.5), Color(0.95, 0.97, 1.0), 1.4, 6.0)
	b.ceiling_light(Vector3(-2.2, H - 0.05, -1.5), Color(0.95, 0.97, 1.0), 1.2, 6.0)
	b.detail = false
	var t1 := b.interactable(Vector3(-6.9, 1.1, 0.0), "ACTION_USE_TERMINAL", tr("COLONY_ROCK_SHEETS"), 0.6, 2.0)
	t1.interacted.connect(func(by: Node) -> void:
		var c := colony()
		if c:
			c.open_terminal(&"rocks", self, by))
	var t2 := b.interactable(Vector3(-5.6, 1.0, -hd + 1.1), "ACTION_ANALYZE", tr("COLONY_ANALYSIS_STATION"), 0.6, 2.0)
	t2.interacted.connect(func(by: Node) -> void:
		var c := colony()
		if c:
			c.analyze_sample(by, self))


func _microscope(b: ModuleBuilder, p: Vector3) -> void:
	var g := b.group(p, 0.0, "Microscope")
	b.box(Vector3(0.25, 0.04, 0.3), Vector3(0, 0.02, 0), &"plastic_dark", Vector3.ZERO, &"", g)
	b.box(Vector3(0.06, 0.35, 0.06), Vector3(0, 0.2, -0.1), &"plastic", Vector3.ZERO, &"", g)
	b.cyl(0.04, 0.25, Vector3(0, 0.33, 0.0), &"plastic_dark", Vector3(0.5, 0, 0), &"", 10, -1.0, g)
	b.box(Vector3(0.18, 0.02, 0.14), Vector3(0, 0.12, 0.02), &"metal", Vector3.ZERO, &"", g)
	b.omni(p + Vector3(0, 0.15, 0.1), Color(0.8, 0.95, 1.0), 0.3, 1.2)


func _observatory_room(b: ModuleBuilder) -> void:
	b.detail = true
	var hd := D * 0.5
	# dos consolas de observatorio (pared del fondo) y pantalla de datos
	for k in 2:
		var x := 2.6 + k * 3.2
		b.desk(Vector3(x, 0, -hd + 0.5), 0.0, 1.8)
		b.chair(Vector3(x, 0, -hd + 1.25), 0.0)
		screens.append(b.wall_screen(Vector3(x, 1.65, -hd + 0.14), 0.0, Vector2(1.5, 0.75)))
		var it := b.interactable(Vector3(x, 1.0, -hd + 1.0), "ACTION_USE_TERMINAL", tr("COLONY_OBSERVATORY") % (k + 1), 0.6, 2.0)
		it.interacted.connect(func(by: Node) -> void:
			var c := colony()
			if c:
				c.open_terminal(&"telescope_%d" % k, self, by))
	b.rack(Vector3(7.6, 0, -0.5), -PI * 0.5, 2.0)
	b.rack(Vector3(7.6, 0, 0.3), -PI * 0.5, 2.0)
	b.table(Vector3(3.8, 0, -0.4), 0.0, Vector2(1.6, 0.9), 2)
	b.shelf(Vector3(7.7, 0, -3.6), -PI * 0.5, 1.2, 3, true)
	# escalera de servicio (cerrada) hacia las cúpulas
	var lad := b.group(Vector3(7.75, 0, -2.2), -PI * 0.5, "ServiceLadder")
	for s: float in [-0.25, 0.25]:
		b.box(Vector3(0.05, H, 0.05), Vector3(s, H * 0.5, 0), &"stripe_amber", Vector3.ZERO, &"", lad)
	for k in 9:
		b.box(Vector3(0.5, 0.03, 0.03), Vector3(0, 0.3 + k * 0.33, 0), &"metal", Vector3.ZERO, &"", lad)
	b.ceiling_services(Vector3(0.6, H - 0.25, -3.6), Vector3(7.5, H - 0.25, -3.6))
	b.ceiling_light(Vector3(2.6, H - 0.05, -1.4), Color(0.9, 0.95, 1.0), 1.1, 6.0)
	b.ceiling_light(Vector3(5.8, H - 0.05, -1.4), Color(0.9, 0.95, 1.0), 1.1, 6.0)
	b.detail = false


## Dos cúpulas de telescopio sobre la sala de observatorios (piezas móviles separadas).
func _observatories(b: ModuleBuilder) -> void:
	for k in 2:
		var base := Vector3(2.6 + k * 3.4, H + 0.25, -1.6)
		b.cyl(1.55, 0.9, base + Vector3(0, 0.45, 0), &"hull", Vector3.ZERO, &"shell", 24)
		b.cyl(1.62, 0.1, base + Vector3(0, 0.9, 0), &"frame", Vector3.ZERO, &"", 24)
		var dome := ModuleBuilder.mark_dynamic(b.group(base + Vector3(0, 0.9, 0), _aim[k].x, "TelescopeDome_%d" % (k + 1))) as Node3D
		var hemi := SphereMesh.new()
		hemi.radius = 1.55
		hemi.height = 1.55
		hemi.is_hemisphere = true
		hemi.radial_segments = 24
		hemi.rings = 8
		var hm := MeshInstance3D.new()
		hm.mesh = hemi
		hm.material_override = ModuleBuilder.mat(&"hull")
		dome.add_child(hm)
		b.box(Vector3(0.55, 0.05, 1.7), Vector3(0, 1.5, 0.35), &"frame", Vector3(-0.35, 0, 0), &"", dome) # ranura
		b.box(Vector3(0.6, 1.6, 0.06), Vector3(0, 0.75, 1.5), &"frame", Vector3.ZERO, &"", dome)
		var tube := b.group(Vector3(0, 0.55, 0), 0.0, "TelescopeTube", dome)
		tube.rotation.x = -_aim[k].y
		b.cyl(0.22, 2.3, Vector3(0, 0, 0.75), &"pipe_white", Vector3(PI * 0.5, 0, 0), &"", 14, -1.0, tube)
		b.cyl(0.24, 0.12, Vector3(0, 0, 1.9), &"frame", Vector3(PI * 0.5, 0, 0), &"", 14, -1.0, tube)
		b.box(Vector3(0.12, 0.12, 0.4), Vector3(0.28, 0.1, 0.3), &"frame", Vector3.ZERO, &"", tube) # buscador
		b.sphere(0.05, base + Vector3(0, 2.5, 0), &"light_red")
		telescopes.append([dome, tube])


## Apunta el telescopio `k` (azimut y elevación en radianes) con giro suave.
func aim_telescope(k: int, azimuth: float, elevation: float) -> void:
	if k < 0 or k >= telescopes.size():
		return
	_aim[k] = Vector2(azimuth, elevation)
	var dome := telescopes[k][0] as Node3D
	var tube := telescopes[k][1] as Node3D
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dome, "rotation:y", azimuth - global_rotation.y, 3.0)
	tw.tween_property(tube, "rotation:x", -clampf(elevation, 0.05, 1.45), 3.0)


func _update_screens() -> void:
	var c := colony()
	if c == null or screens.size() < 4:
		return
	screens[0].text = c.lab_summary()
	screens[1].text = c.rock_terminal_preview()
	for k in 2:
		screens[2 + k].text = c.telescope_screen(k)


func get_status_text() -> String:
	return "%s · %s" % [def.get_display_name(), tr("STATUS_OPERATIONAL") if is_operational() else tr("STATUS_NO_POWER")]
