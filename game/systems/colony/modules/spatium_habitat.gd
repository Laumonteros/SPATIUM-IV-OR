class_name SpatiumHabitat
extends ColonyModule
## Hábitat Spatium: el hogar del jugador (diseño de referencia del equipo).
##
## Módulo central de 12 lados elevado sobre patas, con banda alta de ventanas y
## techo facetado de vidrio, mástil con parabólica y escalera de acceso. Dos
## túneles presurizados lo unen con las alas:
##   - Oeste (-X): invernadero con techo de vidrio y huerta personal.
##   - Este (+X): soporte vital (tanques, filtros) con paneles solares en el techo.
## Revestimiento blanco con franjas naranjas y estructura oscura.
##
## Funciones: cama (descansar/comer/guardar), consola central (estado de la
## colonia), huerta (cosecha raciones cuando madura), terminal de soporte vital.

const N := 12 # lados del módulo central
const R := 5.6 # radio a los vértices
const H := 3.0 # altura de pared
const BAND := 0.9 # banda alta con ventanas
const T := 0.25
const TL := 2.4 # largo de los túneles
const WW := 6.6 # ala: largo (X)
const WD := 5.6 # ala: ancho (Z)
const WH := 3.0
const ROOF_SOLAR_KW := 0.5
## Huerta personal: minutos de juego hasta la cosecha y raciones que rinde (valores de juego).
const GARDEN_MINUTES := 540.0
const GARDEN_RATIONS := 3

var garden_progress: float = 0.35
var _garden_mm: MultiMesh
var _garden_stage := -1
var _globe: Node3D
var A := R * cos(PI / N) # apotema


func _build_module(b: ModuleBuilder) -> void:
	_hub_shell(b)
	_roof(b)
	_tunnel(b, 1.0)
	_tunnel(b, -1.0)
	_wing(b, 1.0) # soporte vital
	_wing(b, -1.0) # invernadero
	_legs(b)
	_stairs(b)
	_exterior_details(b)
	_hub_interior(b)
	_greenhouse_interior(b)
	_life_support_interior(b)
	var wx0 := A + TL
	interior_volumes = [
		AABB(Vector3(A - 0.3, 0.0, -1.0), Vector3(TL + 0.6, 2.5, 2.0)),
		AABB(Vector3(-A - TL - 0.3, 0.0, -1.0), Vector3(TL + 0.6, 2.5, 2.0)),
		AABB(Vector3(wx0, 0.0, -WD * 0.5), Vector3(WW, WH, WD)),
		AABB(Vector3(-wx0 - WW, 0.0, -WD * 0.5), Vector3(WW, WH, WD)),
	]


func contains_point(p: Vector3) -> bool:
	var lp := global_transform.affine_inverse() * p
	if Vector2(lp.x, lp.z).length() < A - 0.15 and lp.y > -0.3 and lp.y < H + BAND + 1.6:
		return true
	for v in interior_volumes:
		if v.has_point(lp):
			return true
	return false


func status_light_position() -> Vector3:
	return Vector3(0, H + BAND + 4.2, 0)


func spawn_point() -> Vector3:
	return global_transform * Vector3(1.6, 0.05, 2.2)


func get_power_kw() -> float:
	if not is_built():
		return 0.0
	return def.power_kw + ROOF_SOLAR_KW # el techo solar del ala este cubre parte del consumo


# --- Utilidades geométricas -----------------------------------------------------------

func _vertex(angle: float, r := R) -> Vector3:
	return Vector3(sin(angle), 0.0, cos(angle)) * r


## Ángulo del centro del lado k (k = 0 mira a +Z: la puerta).
func _phi(k: int) -> float:
	return TAU * k / N


# --- Exterior ---------------------------------------------------------------------------

func _hub_shell(b: ModuleBuilder) -> void:
	# piso de 12 lados (girado medio lado para coincidir con los muros)
	var floor_mi := b.cyl(R + 0.1, 0.3, Vector3(0, -0.15, 0), &"floor", Vector3(0, PI / N, 0), &"shell", N)
	floor_mi.rotation.y = PI / N
	b.cyl(R + 0.25, 0.25, Vector3(0, -0.42, 0), &"frame", Vector3(0, PI / N, 0), &"", N)
	var L := 2.0 * R * sin(PI / N)
	for k in N:
		var phi := _phi(k)
		var a := _vertex(phi + PI / N)
		var e := _vertex(phi - PI / N)
		var ops: Array[Vector4] = []
		# banda alta: ventanas en todos los lados
		ops.append(Vector4((L - 1.6) * 0.5, 1.6, H + 0.15, BAND - 0.3))
		match k:
			0: # puerta
				ops.append(Vector4((L - (ModuleDoor.WIDTH + 0.3)) * 0.5, ModuleDoor.WIDTH + 0.3, 0.0, ModuleDoor.HEIGHT + 0.15))
			3, 9: # túneles
				ops.append(Vector4((L - 2.1) * 0.5, 2.1, 0.0, 2.35))
			1, 2, 10, 11: # ventanas a la altura de los ojos
				ops.append(Vector4((L - 1.2) * 0.5, 1.2, 1.05, 0.85))
		b.wall(a, e, H + BAND, T, ops, &"hull", &"interior_wall")
		# franjas naranjas exteriores (abajo y sobre las aberturas)
		var out := Vector3(sin(phi), 0, cos(phi))
		for y: float in [0.45, H - 0.15]:
			if k == 0 and y < 2.5:
				continue
			if (k == 3 or k == 9) and y < 2.4:
				continue
			b.box(Vector3(L - 0.25, 0.16, 0.06), out * (A + T * 0.5 + 0.04) + Vector3(0, y, 0), &"paint_orange", Vector3(0, phi, 0))
	# postes en los vértices (cubren las juntas de los muros)
	for k in N:
		var v := _vertex(_phi(k) + PI / N, R + 0.02)
		b.cyl(0.17, H + BAND + 0.1, v + Vector3(0, (H + BAND) * 0.5, 0), &"frame", Vector3.ZERO, &"shell", 8)
	add_door(b, Vector3(0, 0, A), 0.0, T)
	# marco de puerta octogonal (como en el diseño)
	var df := A + T * 0.5 + 0.08
	b.box(Vector3(2.3, 0.22, 0.2), Vector3(0, 2.62, df), &"frame")
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.22, 2.4, 0.2), Vector3(s * 1.05, 1.3, df), &"frame")
		b.box(Vector3(0.12, 2.3, 0.06), Vector3(s * 0.95, 1.25, df + 0.1), &"paint_orange")
		b.box(Vector3(0.5, 0.22, 0.2), Vector3(s * 0.88, 2.48, df), &"frame", Vector3(0, 0, s * 0.6))
	b.box(Vector3(0.6, 0.08, 0.04), Vector3(0, 2.78, df + 0.1), &"light_warm")


func _roof(b: ModuleBuilder) -> void:
	# techo facetado de vidrio: 12 trapecios entre el borde de la banda y la cúpula superior
	var y0 := H + BAND
	var y1 := y0 + 1.7
	var r0 := R + 0.05
	var r1 := 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in N:
		var a0 := _phi(k) - PI / N
		var a1 := _phi(k) + PI / N
		var p00 := _vertex(a0, r0) + Vector3(0, y0, 0)
		var p01 := _vertex(a1, r0) + Vector3(0, y0, 0)
		var p10 := _vertex(a0, r1) + Vector3(0, y1, 0)
		var p11 := _vertex(a1, r1) + Vector3(0, y1, 0)
		for v in [p00, p10, p11, p00, p11, p01]:
			st.add_vertex(v)
		# nervio estructural en cada arista
		b.pipe(p01, p11, 0.07, &"frame")
		b.pipe(_vertex(_phi(k), r0) + Vector3(0, y0, 0), _vertex(_phi(k), r1) + Vector3(0, y1, 0), 0.035, &"frame")
	st.generate_normals()
	var mesh := st.commit()
	var gi := MeshInstance3D.new()
	gi.name = "GlassRoof"
	gi.mesh = mesh
	gi.material_override = ModuleBuilder.mat(&"glass")
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(gi)
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	cs.shape = shape
	b.shell.add_child(cs)
	# anillos del borde y cúpula superior con mástil, parabólica y antenas
	# anillo del borde (segmentos: deja ver el vidrio desde adentro)
	var L := 2.0 * R * sin(PI / N)
	for k in N:
		var v := Vector3(sin(_phi(k)), 0, cos(_phi(k)))
		b.box(Vector3(L + 0.1, 0.22, 0.4), v * (A + 0.05) + Vector3(0, y0 + 0.05, 0), &"frame", Vector3(0, _phi(k), 0))
		b.box(Vector3(L + 0.1, 0.14, 0.06), v * (A + T * 0.5 + 0.06) + Vector3(0, y0 - 0.2, 0), &"paint_orange", Vector3(0, _phi(k), 0))
	b.cyl(r1 + 0.1, 0.5, Vector3(0, y1 + 0.2, 0), &"hull", Vector3.ZERO, &"shell", N, r1 - 0.2)
	b.cyl(r1 + 0.12, 0.1, Vector3(0, y1 + 0.02, 0), &"paint_orange", Vector3.ZERO, &"", N)
	b.cyl(0.6, 0.6, Vector3(0, y1 + 0.75, 0), &"hull_panel", Vector3.ZERO, &"", 10)
	b.pipe(Vector3(0, y1 + 1.0, 0), Vector3(0, y1 + 3.6, 0), 0.07, &"metal")
	for y: float in [y1 + 2.2, y1 + 3.0]:
		b.box(Vector3(0.9, 0.05, 0.05), Vector3(0, y, 0), &"metal")
	b.sphere(0.07, Vector3(0, y1 + 3.65, 0), &"light_red")
	var dish := b.group(Vector3(0.9, y1 + 1.5, -0.4), 0.6, "Dish")
	b.sphere(0.55, Vector3.ZERO, &"hull", Vector3(1, 0.35, 1), dish, 14)
	b.pipe(Vector3(0, 0.1, 0), Vector3(0, 0.6, 0.0), 0.02, &"metal", dish)
	b.pipe(Vector3(0, -0.2, 0), Vector3(-0.4, -0.9, 0.2), 0.04, &"frame", dish)
	dish.rotation.x = -0.6
	for k in 3: # antenas látigo
		var a := TAU * k / 3.0 + 0.4
		b.pipe(_vertex(a, 1.4) + Vector3(0, y1 + 0.4, 0), _vertex(a, 1.4) + Vector3(0, y1 + 1.6, 0), 0.015, &"metal")


func _tunnel(b: ModuleBuilder, side: float) -> void:
	var x0 := side * (A - 0.05)
	var x1 := side * (A + TL + 0.05)
	var cx := (x0 + x1) * 0.5
	b.cyl(1.5, TL + 0.3, Vector3(cx, 1.3, 0), &"hull_2s", Vector3(0, 0, PI * 0.5), &"", 20)
	for f: float in [0.2, 0.8]:
		b.cyl(1.62, 0.18, Vector3(lerpf(x0, x1, f), 1.3, 0), &"paint_orange", Vector3(0, 0, PI * 0.5), &"", 20)
	b.box(Vector3(TL + 0.4, 0.3, 2.1), Vector3(cx, -0.15, 0), &"floor", Vector3.ZERO, &"shell")
	for s: float in [-1.0, 1.0]:
		b.collider(Vector3(TL + 0.4, 2.6, 0.2), Vector3(cx, 1.3, s * 1.2))
	b.collider(Vector3(TL + 0.4, 0.2, 2.4), Vector3(cx, 2.55, 0))
	b.detail = true
	b.box(Vector3(TL + 0.2, 0.03, 0.4), Vector3(cx, 0.03, 0), &"stripe_amber")
	b.box(Vector3(TL, 0.05, 0.3), Vector3(cx, 2.42, 0), &"light_warm")
	b.omni(Vector3(cx, 2.1, 0), Color(1.0, 0.94, 0.86), 0.9, 4.0)
	b.pipe(Vector3(x0, 2.2, 0.8), Vector3(x1, 2.2, 0.8), 0.04, &"pipe_white")
	b.pipe(Vector3(x0, 2.25, -0.8), Vector3(x1, 2.25, -0.8), 0.03, &"copper")
	b.detail = false


func _wing(b: ModuleBuilder, side: float) -> void:
	var xn := side * (A + TL) # lado que da al túnel
	var xf := side * (A + TL + WW) # extremo exterior
	var x0 := minf(xn, xf)
	var x1 := maxf(xn, xf)
	var cx := (x0 + x1) * 0.5
	var hd := WD * 0.5
	b.box(Vector3(WW + T, 0.3, WD + T), Vector3(cx, -0.15, 0), &"floor", Vector3.ZERO, &"shell")
	b.box(Vector3(WW + 0.4, 0.2, WD + 0.4), Vector3(cx, -0.4, 0), &"frame")
	var tunnel_op: Array[Vector4] = [Vector4((WD - T - 2.1) * 0.5, 2.1, 0.0, 2.35)]
	var win_front: Array[Vector4] = [Vector4((WW + T - 1.4) * 0.5 - 1.4, 1.3, 1.05, 0.85), Vector4((WW + T - 1.4) * 0.5 + 1.6, 1.3, 1.05, 0.85)]
	var none: Array[Vector4] = []
	# muros en sentido horario (revestimiento adentro)
	b.wall(Vector3(x1 + T * 0.5, 0, hd), Vector3(x0 - T * 0.5, 0, hd), WH, T, win_front, &"hull", &"interior_wall")
	b.wall(Vector3(x0 - T * 0.5, 0, -hd), Vector3(x1 + T * 0.5, 0, -hd), WH, T, win_front, &"hull", &"interior_wall")
	b.wall(Vector3(x0, 0, hd - T * 0.5), Vector3(x0, 0, -hd + T * 0.5), WH, T, tunnel_op if side > 0 else none, &"hull", &"interior_wall")
	b.wall(Vector3(x1, 0, -hd + T * 0.5), Vector3(x1, 0, hd - T * 0.5), WH, T, tunnel_op if side < 0 else none, &"hull", &"interior_wall")
	# franjas naranjas
	for y: float in [0.45, WH - 0.2]:
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(WW + 0.1, 0.16, 0.06), Vector3(cx, y, s * (hd + T * 0.5 + 0.04)), &"paint_orange")
		b.box(Vector3(0.06, 0.16, WD + 0.1), Vector3(xf + side * (T * 0.5 + 0.04), y, 0), &"paint_orange")
	# nervios verticales
	for k in 5:
		var x := lerpf(x0, x1, k / 4.0)
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(0.12, WH, 0.1), Vector3(x, WH * 0.5, s * (hd + T * 0.5 + 0.05)), &"frame")
	if side > 0:
		# soporte vital: techo opaco con paneles solares
		b.box(Vector3(WW + T + 0.1, 0.25, WD + T + 0.1), Vector3(cx, WH + 0.125, 0), &"hull", Vector3.ZERO, &"shell")
		# panel inclinado 20° hacia +Z, completamente por encima del techo (antes lo atravesaba)
		var tilt := 0.35
		var pz := WD - 1.2
		var lift := sin(tilt) * pz * 0.5 + 0.25 # borde bajo del panel 0,2 m sobre el techo
		var sol := b.group(Vector3(cx, WH + 0.36 + lift, 0), 0.0, "RoofSolar")
		b.box(Vector3(WW - 0.6, 0.08, pz), Vector3.ZERO, &"solar_cell", Vector3(tilt, 0, 0), &"", sol)
		b.box(Vector3(WW - 0.5, 0.05, 0.08), Vector3(0, 0.0, 0.0), &"frame", Vector3(tilt, 0, 0), &"", sol)
		for s: float in [-1.0, 1.0]:
			for z: float in [-0.8, 0.8]:
				var under := -sin(tilt) * z - 0.05 # cara inferior del panel en esa z
				var base := -lift
				b.box(Vector3(0.1, under - base, 0.1), Vector3(s * (WW * 0.5 - 0.5), (under + base) * 0.5, z * cos(tilt)), &"frame", Vector3.ZERO, &"", sol)
	else:
		# invernadero: techo de vidrio sobre una grilla de perfiles
		b.box(Vector3(WW + T, 0.12, WD + T), Vector3(cx, WH + 0.06, 0), &"glass", Vector3.ZERO, &"shell")
		for k in 7:
			b.box(Vector3(0.1, 0.16, WD + T), Vector3(lerpf(x0, x1, k / 6.0), WH + 0.08, 0), &"frame")
		for k in 4:
			b.box(Vector3(WW + T, 0.16, 0.1), Vector3(cx, WH + 0.08, lerpf(-hd, hd, k / 3.0)), &"frame")
		# torre-tanque de agua al costado (como en el diseño)
		var tx := xf - 1.1
		b.cyl(0.95, 3.8, Vector3(tx, WH + 1.9, -1.2), &"hull", Vector3.ZERO, &"shell", 16)
		for y: float in [WH + 0.6, WH + 3.2]:
			b.cyl(1.0, 0.18, Vector3(tx, y, -1.2), &"paint_orange", Vector3.ZERO, &"", 16)
		b.cyl(1.0, 0.12, Vector3(tx, WH + 3.85, -1.2), &"frame", Vector3.ZERO, &"", 16)
		b.box(Vector3(0.3, 0.6, 0.05), Vector3(tx, WH + 2.0, -0.23), &"glass_gold")
	b.box(Vector3(WW + T + 0.2, 0.14, WD + T + 0.2), Vector3(cx, WH + 0.29 if side > 0 else WH + 0.2, 0), &"frame")


func _legs(b: ModuleBuilder) -> void:
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	var spots: Array[Vector3] = []
	for k in N:
		if k % 2 == 0:
			spots.append(_vertex(_phi(k) + PI / N, R - 0.4))
	spots.append(Vector3(0, 0, 0))
	for side: float in [-1.0, 1.0]:
		var x0 := side * (A + TL + 0.6)
		var x1 := side * (A + TL + WW - 0.6)
		for z: float in [-WD * 0.5 + 0.6, WD * 0.5 - 0.6]:
			spots.append(Vector3(x0, 0, z))
			spots.append(Vector3(x1, 0, z))
	for p in spots:
		var ground := ground_drop - 0.3
		if region:
			var h := region.get_height(global_transform * p)
			if is_finite(h):
				ground = h - global_position.y
		var top := -0.5
		var len := top - ground
		if len <= 0.05:
			continue
		b.box(Vector3(0.28, len, 0.28), p + Vector3(0, (top + ground) * 0.5, 0), &"frame", Vector3.ZERO, &"shell")
		b.box(Vector3(0.6, 0.12, 0.6), p + Vector3(0, ground + 0.06, 0), &"metal", Vector3.ZERO, &"")
		b.box(Vector3(0.32, 0.18, 0.32), p + Vector3(0, top - 0.25, 0), &"paint_orange")


func _stairs(b: ModuleBuilder) -> void:
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	var z0 := A + T * 0.5
	var landing := 1.2
	b.box(Vector3(2.4, 0.2, landing), Vector3(0, -0.1, z0 + landing * 0.5), &"floor", Vector3.ZERO, &"shell")
	var rise := 1.4
	var run := 0.0
	for _i in 3: # ajustar el largo al terreno donde termina la escalera
		run = maxf(rise / tan(deg_to_rad(32.0)), 1.2)
		if region:
			var h := region.get_height(global_transform * Vector3(0, 0, z0 + landing + run))
			if is_finite(h):
				rise = maxf(global_position.y - h, 0.2)
	var steps := maxi(int(ceil(rise / 0.2)), 1)
	var sr := rise / steps
	var sd := run / steps
	for i in steps:
		var y := -sr * (i + 1)
		var z := z0 + landing + sd * (i + 0.5)
		b.box(Vector3(2.0, 0.06, sd + 0.02), Vector3(0, y + sr - 0.03, z), &"floor")
		b.box(Vector3(2.0, 0.02, 0.06), Vector3(0, y + sr - 0.005, z + sd * 0.5 - 0.05), &"stripe_amber")
	for s: float in [-1.0, 1.0]:
		b.pipe(Vector3(s * 1.05, 0.0, z0 + landing), Vector3(s * 1.05, -rise, z0 + landing + run), 0.07, &"frame")
		var top := Vector3(s * 1.15, 1.0, z0)
		var mid := Vector3(s * 1.15, 1.0, z0 + landing)
		var bot := Vector3(s * 1.15, 1.0 - rise, z0 + landing + run)
		b.pipe(top, mid, 0.035, &"paint_orange")
		b.pipe(mid, bot, 0.035, &"paint_orange")
		for p: Vector3 in [top, mid, bot, mid.lerp(bot, 0.5)]:
			b.pipe(p - Vector3(0, 1.0, 0), p, 0.03, &"paint_orange")
		b.collider(Vector3(0.08, 1.0, landing), Vector3(s * 1.15, 0.5, z0 + landing * 0.5))
		var ang := atan2(rise, run)
		var hyp := sqrt(run * run + rise * rise)
		b.collider(Vector3(0.08, 1.0, hyp), Vector3(s * 1.15, 0.5 - rise * 0.5, z0 + landing + run * 0.5), &"shell", Vector3(ang, 0, 0))
	# rampa invisible bajo los escalones (el astronauta sube sin trabarse)
	var ang2 := atan2(rise, run)
	var hyp2 := sqrt(run * run + rise * rise)
	b.collider(Vector3(2.0, 0.1, hyp2 + 0.1), Vector3(0, -rise * 0.5 - 0.05, z0 + landing + run * 0.5), &"shell", Vector3(ang2, 0, 0))


func _exterior_details(b: ModuleBuilder) -> void:
	sign_plate(b, Vector3(0, H + 0.45, A + T * 0.5 + 0.12), 0.0, tr("COLONY_HABITAT_NAME").to_upper(), tr("COLONY_YOU"))
	b.omni(Vector3(0, 2.9, A + 1.4), Color(1.0, 0.9, 0.78), 1.8, 7.0)
	for k: int in [1, 11]:
		var v := Vector3(sin(_phi(k)), 0, cos(_phi(k)))
		b.box(Vector3(0.12, 0.3, 0.06), v * (A + T * 0.5 + 0.05) + Vector3(0, 2.3, 0), &"light_warm", Vector3(0, _phi(k), 0))
	# caja de servicios y cañería bajo el piso
	b.box(Vector3(1.2, 0.5, 0.8), Vector3(-2.0, -0.8, -3.0), &"hull_panel", Vector3.ZERO, &"shell")
	b.pipe(Vector3(-2.0, -0.6, -2.6), Vector3(-2.0, -0.6, 2.0), 0.08, &"pipe_white")


# --- Interiores ------------------------------------------------------------------------

func _place(k: int, inset: float) -> Vector3:
	return Vector3(sin(_phi(k)), 0, cos(_phi(k))) * (A - T * 0.5 - inset)


func _hub_interior(b: ModuleBuilder) -> void:
	b.detail = true
	# piso: círculo central claro y anillo de circulación
	b.cyl(3.0, 0.04, Vector3(0, 0.02, 0), &"floor_light", Vector3.ZERO, &"", 32)
	b.cyl(3.15, 0.03, Vector3(0, 0.015, 0), &"paint_orange", Vector3.ZERO, &"", 32)
	# consola central octogonal con pantallas y globo holográfico
	b.cyl(1.25, 0.95, Vector3(0, 0.475, 0), &"hull_panel", Vector3.ZERO, &"furniture", 8)
	b.cyl(1.32, 0.08, Vector3(0, 0.98, 0), &"frame", Vector3.ZERO, &"", 8)
	b.cyl(1.28, 0.1, Vector3(0, 0.2, 0), &"paint_orange", Vector3.ZERO, &"", 8)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var g := b.group(Vector3(sin(a), 0, cos(a)) * 1.0, a, "ConsoleScreen")
		b.box(Vector3(0.7, 0.42, 0.04), Vector3(0, 1.22, 0.05), &"frame", Vector3(-0.5, 0, 0), &"", g)
		b.box(Vector3(0.64, 0.36, 0.01), Vector3(0, 1.22, 0.075), &"screen_dark", Vector3(-0.5, 0, 0), &"", g)
	screens.append(b.label("", Vector3(-0.3, 1.38, 1.2), Vector3(-0.5, 0, 0), 0.0028, Color(0.75, 0.93, 0.97), 230.0))
	_globe = ModuleBuilder.mark_dynamic(b.group(Vector3(0, 1.75, 0), 0.0, "HoloGlobe")) as Node3D
	b.sphere(0.42, Vector3.ZERO, &"holo", Vector3.ONE, _globe, 16)
	for r in 3:
		b.cyl(0.45, 0.01, Vector3.ZERO, &"holo", Vector3(PI * 0.5, r * PI / 3.0, 0), &"", 24, -1.0, _globe)
	b.cyl(0.25, 0.05, Vector3(0, 1.02, 0), &"metal", Vector3.ZERO, &"", 12)
	# perímetro: cama (atrás), casilleros, cocina, estantes, asientos bajo ventanas
	b.bed(_place(6, 0.55), _phi(6) + PI * 0.5)
	b.locker(_place(5, 0.3), _phi(5) + PI, 2)
	b.locker(_place(7, 0.3), _phi(7) + PI, 2)
	b.kitchenette(_place(4, 0.32), _phi(4) + PI)
	b.shelf(_place(8, 0.2), _phi(8) + PI, 1.8, 3, true)
	for k: int in [1, 11]:
		var c := b.group(_place(k, 0.45), _phi(k) + PI, "Lounge")
		b.box(Vector3(1.8, 0.45, 0.6), Vector3(0, 0.23, 0), &"fabric_gray", Vector3.ZERO, &"furniture", c)
		b.box(Vector3(1.8, 0.5, 0.15), Vector3(0, 0.6, -0.25), &"fabric_gray", Vector3.ZERO, &"furniture", c)
		b.box(Vector3(1.8, 0.06, 0.62), Vector3(0, 0.47, 0), &"fabric_blue", Vector3.ZERO, &"", c)
	for k: int in [2, 10]:
		var pp := _place(k, 0.4)
		b.cyl(0.22, 0.4, pp + Vector3(0, 0.2, 0), &"plastic", Vector3.ZERO, &"furniture", 12, 0.28)
		b.sphere(0.35, pp + Vector3(0, 0.62, 0), &"leaf", Vector3(1, 1.2, 1), null, 10)
	screens.append(b.wall_screen(_place(4, 0.05) + Vector3(0, 2.55, 0), _phi(4) + PI, Vector2(1.4, 0.6)))
	# luces: anillo de lámparas en la banda alta, cañerías y luz central
	for k in N:
		if k in [0, 3, 9]:
			continue
		b.box(Vector3(1.2, 0.06, 0.12), _place(k, 0.1) + Vector3(0, H - 0.05, 0), &"light_warm", Vector3(0, _phi(k), 0))
	for k: int in [4, 5, 6, 7, 8]:
		var a := _vertex(_phi(k) - PI / N, A - 0.35) + Vector3(0, H - 0.3, 0)
		var e := _vertex(_phi(k) + PI / N, A - 0.35) + Vector3(0, H - 0.3, 0)
		b.pipe(a, e, 0.05, &"pipe_white")
		b.pipe(a + Vector3(0, -0.15, 0), e + Vector3(0, -0.15, 0), 0.035, &"copper")
	b.omni(Vector3(0, 3.6, 0), Color(1.0, 0.95, 0.88), 2.2, 10.0)
	for k: int in [2, 6, 10]:
		b.omni(_place(k, 1.4) + Vector3(0, 2.4, 0), Color(1.0, 0.92, 0.82), 0.8, 5.0)
	b.detail = false
	var bed_it := b.interactable(_place(6, 1.0) + Vector3(0, 0.7, 0), "ACTION_REST", tr("COLONY_BED"), 0.7, 2.0)
	bed_it.interacted.connect(_on_bed)
	var con := b.interactable(Vector3(0, 1.0, 1.4), "ACTION_USE_TERMINAL", tr("COLONY_TERMINAL_STATUS"), 0.7, 2.0)
	con.interacted.connect(func(by: Node) -> void:
		var c := colony()
		if c:
			c.open_terminal(&"status", self, by))


func _greenhouse_interior(b: ModuleBuilder) -> void:
	b.detail = true
	var x0 := -(A + TL + WW)
	var x1 := -(A + TL)
	var cx := (x0 + x1) * 0.5
	var hd := WD * 0.5
	var leaf := SphereMesh.new()
	leaf.radius = 0.16
	leaf.height = 0.24
	leaf.radial_segments = 8
	leaf.rings = 4
	_garden_mm = MultiMesh.new()
	_garden_mm.transform_format = MultiMesh.TRANSFORM_3D
	_garden_mm.mesh = leaf
	_garden_mm.instance_count = 40
	for s: float in [-1.0, 1.0]:
		var z := s * (hd - T * 0.5 - 0.5)
		b.box(Vector3(WW - 1.4, 0.65, 0.9), Vector3(cx + 0.3, 0.33, z), &"hull_panel", Vector3.ZERO, &"furniture")
		b.box(Vector3(WW - 1.5, 0.05, 0.8), Vector3(cx + 0.3, 0.64, z), &"soil")
		b.box(Vector3(WW - 1.3, 0.06, 0.94), Vector3(cx + 0.3, 0.68, z), &"paint_orange")
		b.box(Vector3(WW - 1.6, 0.04, 0.5), Vector3(cx + 0.3, WH - 0.35, z), &"light_magenta")
		for e: float in [-1.0, 1.0]:
			b.pipe(Vector3(cx + 0.3 + e * (WW - 1.8) * 0.5, WH - 0.35, z), Vector3(cx + 0.3 + e * (WW - 1.8) * 0.5, WH, z), 0.02, &"frame")
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _garden_mm
	mmi.material_override = ModuleBuilder.mat(&"leaf")
	mmi.visibility_range_end = ModuleBuilder.DETAIL_RANGE
	b.root.add_child(mmi)
	b.cyl(0.45, 1.6, Vector3(x0 + 0.7, 0.8, 0), &"pipe_blue", Vector3.ZERO, &"furniture", 14) # tanque de riego
	b.pipe(Vector3(x0 + 0.7, 1.4, 0), Vector3(x0 + 0.7, WH - 0.4, 0), 0.04, &"pipe_white")
	b.pipe(Vector3(x0 + 0.7, WH - 0.4, -hd + 0.6), Vector3(x0 + 0.7, WH - 0.4, hd - 0.6), 0.04, &"pipe_white")
	b.omni(Vector3(cx, 2.3, 0), Color(1.0, 0.9, 0.92), 1.4, 6.0)
	b.omni(Vector3(cx, 1.6, 0), Color(1.0, 0.95, 0.9), 0.6, 4.0)
	b.detail = false
	_refresh_garden()
	var it := b.interactable(Vector3(cx, 0.9, hd - 1.2), "ACTION_HARVEST", tr("COLONY_GARDEN"), 0.8, 2.2)
	it.interacted.connect(_on_garden)


func _life_support_interior(b: ModuleBuilder) -> void:
	b.detail = true
	var x0 := A + TL
	var x1 := A + TL + WW
	var cx := (x0 + x1) * 0.5
	var hd := WD * 0.5
	for k in 3:
		var p := Vector3(x0 + 1.4 + k * 1.6, 0, -hd + T * 0.5 + 0.7)
		b.cyl(0.58, 2.4, p + Vector3(0, 1.25, 0), &"hull", Vector3.ZERO, &"furniture", 18)
		b.sphere(0.58, p + Vector3(0, 2.45, 0), &"hull", Vector3(1, 0.45, 1), null, 14)
		b.cyl(0.6, 0.35, p + Vector3(0, 1.4, 0), &"paint_blue", Vector3.ZERO, &"", 18)
		b.cyl(0.6, 0.1, p + Vector3(0, 0.15, 0), &"frame", Vector3.ZERO, &"", 18)
		b.pipe(p + Vector3(0, 2.6, 0), p + Vector3(0, WH - 0.1, 0), 0.05, &"pipe_white")
	b.pipe(Vector3(x0 + 1.0, WH - 0.25, -hd + 0.7), Vector3(x1 - 0.5, WH - 0.25, -hd + 0.7), 0.06, &"pipe_white")
	b.pipe(Vector3(x0 + 1.0, WH - 0.4, -hd + 0.5), Vector3(x1 - 0.5, WH - 0.4, -hd + 0.5), 0.04, &"copper")
	# equipos: depurador de CO₂, electrolizador y bombas (frente), terminal
	b.rack(Vector3(x1 - 0.5, 0, hd - 0.6), PI, 2.0)
	b.box(Vector3(1.4, 1.5, 0.8), Vector3(x1 - 1.6, 0.75, hd - 0.6), &"hull_panel", Vector3.ZERO, &"furniture")
	b.box(Vector3(0.5, 0.3, 0.02), Vector3(x1 - 1.6, 1.15, hd - 1.01), &"screen_dark")
	b.box(Vector3(1.0, 1.0, 0.7), Vector3(x0 + 1.2, 0.5, hd - 0.55), &"interior_trim", Vector3.ZERO, &"furniture")
	b.gas_cylinder(Vector3(x1 - 0.4, 0, -0.2), &"pipe_white")
	b.gas_cylinder(Vector3(x1 - 0.4, 0, 0.25), &"pipe_blue")
	screens.append(b.terminal(Vector3(cx, 0, hd - 0.55), PI, "", &"screen_cyan", true))
	for x: float in [x0 + 1.6, x1 - 1.6]:
		b.ceiling_light(Vector3(x, WH - 0.05, 0), Color(0.95, 0.97, 1.0), 1.1, 5.5)
	b.detail = false
	var it := b.interactable(Vector3(cx, 1.0, hd - 1.0), "ACTION_USE_TERMINAL", tr("COLONY_LIFE_SUPPORT"), 0.6, 2.0)
	it.interacted.connect(func(_by: Node) -> void: EventBus.notification_requested.emit(life_support_text(), &"info"))


# --- Funciones ---------------------------------------------------------------------

func _on_bed(by: Node) -> void:
	if not is_operational():
		EventBus.notification_requested.emit(tr("STATUS_NO_POWER"), &"warning")
		return
	var session := get_tree().get_first_node_in_group(&"game_session")
	if session and session.has_method("rest_in_cabin"):
		session.call("rest_in_cabin", self)
	elif by is Player:
		(by as Player).perform_action(&"Interact")


func _on_garden(by: Node) -> void:
	if garden_progress < 1.0:
		EventBus.notification_requested.emit(tr("COLONY_GARDEN_GROWING") % int(garden_progress * 100.0), &"info")
		return
	garden_progress = 0.0
	if _network:
		_network.rations += GARDEN_RATIONS
	if by is Player:
		(by as Player).perform_action(&"Collect")
	EventBus.player_action.emit(&"harvest")
	EventBus.notification_requested.emit(tr("COLONY_GARDEN_HARVESTED") % GARDEN_RATIONS, &"info")
	_refresh_garden()


func simulate(dt: float, net: BaseNetwork) -> void:
	if garden_progress < 1.0:
		garden_progress = minf(garden_progress + dt * BaseNetwork.GAME_MINUTES_PER_SECOND / GARDEN_MINUTES, 1.0)
		_refresh_garden()
	super.simulate(dt, net)


func _refresh_garden() -> void:
	if _garden_mm == null:
		return
	var stage := int(garden_progress * 10.0)
	if stage == _garden_stage:
		return
	_garden_stage = stage
	var x0 := -(A + TL + WW)
	var cx := x0 + WW * 0.5 + 0.3
	var hd := WD * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var s := 0.2 + 0.8 * garden_progress
	for i in _garden_mm.instance_count:
		var side := -1.0 if i < 20 else 1.0
		var j := i % 20
		var p := Vector3(cx - (WW - 1.7) * 0.5 + (j % 10) * (WW - 1.7) / 9.0, 0.72, side * (hd - T * 0.5 - 0.5) + (0.18 if j >= 10 else -0.18))
		var sc := Vector3(1.0, 1.3, 1.0) * s * rng.randf_range(0.8, 1.2)
		_garden_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), p + Vector3(0, 0.12 * sc.y, 0)))


func life_support_text() -> String:
	if _network == null:
		return ""
	var n := _network
	var es_ := es()
	return ("Soporte vital · O₂ %.1f kg · agua %.0f L · %d raciones · batería %d %%" if es_ else "Life support · O₂ %.1f kg · water %.0f L · %d rations · battery %d %%") % [n.oxygen_kg, n.water_l, n.rations, int(n.stored_kwh / maxf(n.capacity_kwh, 0.01) * 100.0)]


func _process(delta: float) -> void:
	super._process(delta)
	if _globe:
		_globe.rotation.y += delta * 0.4


func _update_screens() -> void:
	if screens.size() < 3:
		return
	var c := colony()
	var es_ := es()
	screens[0].text = ("HÁBITAT · %s" if es_ else "HABITAT · %s") % (tr("STATUS_OPERATIONAL") if is_operational() else tr("STATUS_NO_POWER"))
	screens[1].text = (c.short_status_line() if c else "")
	screens[2].text = life_support_text() + ("\nHuerta: %d %%" if es_ else "\nGarden: %d %%") % int(garden_progress * 100.0)


func get_status_text() -> String:
	return "%s · %s" % [def.get_display_name(), tr("STATUS_OPERATIONAL") if is_operational() else tr("STATUS_NO_POWER")]


func save_module() -> Dictionary:
	return {"garden": garden_progress}


func load_module(d: Dictionary) -> void:
	garden_progress = float(d.get("garden", garden_progress))
	_garden_stage = -1
	_refresh_garden()
