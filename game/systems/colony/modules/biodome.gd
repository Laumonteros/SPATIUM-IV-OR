class_name Biodome
extends ColonyModule
## Centro de Hidroponía: gran cúpula geodésica con seis bancales de cultivo y un
## almacén refrigerado conectado (al costado +X local).
##
## Producción continua: cada bancal crece si hay energía (luces de cultivo) y agua
## de la base; al madurar se cosecha solo y la cosecha entra al almacén. Si el
## almacén se llena, el excedente pasa directo a las reservas de la base: la
## producción nunca se detiene. Si las raciones de la base bajan de 6, el almacén
## repone automáticamente.

const R := 8.5 # radio de la cúpula
const KNEE := 2.7 # muro perimetral (más alto que la puerta)
const BED_ANGLES := [45.0, 135.0, 180.0, 225.0, 270.0, 315.0] # 0° = puerta (+Z), 90° = almacén (+X)
const BED_R0 := 3.0
const BED_R1 := 6.8
const STORAGE_CAPACITY := 40
const AUTO_RESTOCK_BELOW := 6
const PLANTS_PER_BED := 8

## Estado de cada bancal: {crop, progress (0..1), dry (sin agua)}
var beds: Array[Dictionary] = []
var storage: int = 8 # la colonia ya venía produciendo: el almacén arranca con cosecha
var harvested_total: int = 0
var growth_multiplier: float = 1.0
var crops: Dictionary = {} # id -> datos de data/colony/crops.json

var _leaf_mm: Array[MultiMesh] = []
var _leaf_mmi: Array[MultiMeshInstance3D] = []
var _fruit_mmi: Array[MultiMeshInstance3D] = []
var _bed_points: Array[Interactable] = []
var _fruit_mm: Array[MultiMesh] = []
var _stage_cache: Array[int] = []
var _storage_crates: Array[MeshInstance3D] = []


func _build_module(b: ModuleBuilder) -> void:
	_load_crops()
	if beds.is_empty():
		var order := ["lettuce", "tomato", "potato", "wheat", "soybean", "radish"]
		for i in BED_ANGLES.size():
			beds.append({"crop": order[i % order.size()] if i > 0 else "", "progress": fmod(0.17 * i + 0.1, 1.0) if i > 0 else 0.0, "dry": false})
	foundation(b, Vector2(R * 2.0, R * 2.0), 0.2)
	b.cyl(R + 0.25, 0.2, Vector3(0, -0.1, 0), &"floor", Vector3.ZERO, &"shell", 40)
	_knee_wall(b)
	_geodesic(b)
	_airlock(b)
	_storage_room(b)
	_interior(b)
	interior_volumes = [AABB(Vector3(-R, 0, -R), Vector3(R * 2.0, KNEE + R, R * 2.0)),
		AABB(Vector3(-0.9, 0, R - 0.4), Vector3(1.8, 2.6, 3.0)), # túnel de la esclusa
		AABB(Vector3(R - 0.4, 0, -2.0), Vector3(4.6, 2.8, 4.0))] # almacén


func contains_point(p: Vector3) -> bool:
	var lp := global_transform.affine_inverse() * p
	if Vector2(lp.x, lp.z).length() < R - 0.15 and lp.y > -0.5 and lp.y < KNEE + R:
		return true
	for i in range(1, interior_volumes.size()):
		if interior_volumes[i].has_point(lp):
			return true
	return false


func status_light_position() -> Vector3:
	return Vector3(0, KNEE + R + 0.3, 0)


func _load_crops() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/colony/crops.json"))
	if data is Dictionary:
		for c: Dictionary in data.get("crops", []):
			crops[String(c.id)] = c


# --- Estructura -------------------------------------------------------------------

func _knee_wall(b: ModuleBuilder) -> void:
	var n := 32
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		# huecos: puerta (0°) y almacén (90°)
		if i == 0 or i == n - 1 or i == n / 4 - 1 or i == n / 4:
			continue
		var p0 := Vector3(sin(a0), 0, cos(a0)) * R
		var p1 := Vector3(sin(a1), 0, cos(a1)) * R
		b.wall(p1, p0, KNEE, 0.3, [], &"armor", &"interior_wall")
	# dinteles sobre los dos huecos (el muro sigue por encima de la puerta)
	for ang in [0.0, PI * 0.5]:
		var c := Vector3(sin(ang), 0, cos(ang)) * R
		b.box(Vector3(3.4, KNEE - 2.45, 0.3), c + Vector3(0, (KNEE + 2.45) * 0.5, 0), &"armor", Vector3(0, ang, 0), &"shell")
		for s: float in [-1.0, 1.0]: # jambas
			var side := Basis(Vector3.UP, ang) * Vector3(s * 1.0, 0, 0)
			b.box(Vector3(0.7, 2.45, 0.32), c + side * 1.35 + Vector3(0, 1.225, 0), &"armor", Vector3(0, ang, 0), &"shell")
	b.cyl(R + 0.35, 0.25, Vector3(0, KNEE + 0.12, 0), &"frame", Vector3.ZERO, &"", 40, R + 0.35)
	b.cyl(R + 0.3, 0.3, Vector3(0, 0.15, 0), &"frame", Vector3.ZERO, &"", 40)


## Cúpula geodésica: icosaedro subdividido, solo el hemisferio superior.
func _geodesic(b: ModuleBuilder) -> void:
	var verts: Array[Vector3] = []
	var t := (1.0 + sqrt(5.0)) * 0.5
	for v: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
			Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append((v as Vector3).normalized())
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _k in 2: # dos subdivisiones (frecuencia 4)
		var cache := {}
		var nf: Array = []
		for f: Array in faces:
			var m: Array[int] = []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not cache.has(key):
					verts.append(((verts[e[0]] + verts[e[1]]) * 0.5).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	# Rotación para que haya un anillo de vértices cerca del ecuador
	var edges := {}
	for f: Array in faces:
		for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
			var v0 := verts[e[0]]
			var v1 := verts[e[1]]
			if v0.y < -0.02 or v1.y < -0.02:
				continue
			edges["%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]] = [v0, v1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var strut := CylinderMesh.new()
	strut.top_radius = 0.045
	strut.bottom_radius = 0.045
	strut.height = 1.0
	strut.radial_segments = 6
	strut.rings = 1
	mm.mesh = strut
	mm.instance_count = edges.size()
	var center := Vector3(0, KNEE, 0)
	var i := 0
	for k: String in edges:
		var a: Vector3 = center + Vector3(edges[k][0].x, maxf(edges[k][0].y, 0.0), edges[k][0].z) * R
		var e: Vector3 = center + Vector3(edges[k][1].x, maxf(edges[k][1].y, 0.0), edges[k][1].z) * R
		var d := e - a
		var len := d.length()
		var up := d / len
		var basis := Basis(Quaternion(Vector3.UP, up)) if absf(up.y) < 0.9999 else Basis()
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3(1, len, 1)), (a + e) * 0.5))
		i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GeodesicFrame"
	mmi.multimesh = mm
	mmi.material_override = ModuleBuilder.mat(&"frame")
	b.root.add_child(mmi)
	# Vidrio (hemisferio) con colisión de malla
	var glass := SphereMesh.new()
	glass.radius = R - 0.02
	glass.height = R - 0.02
	glass.is_hemisphere = true
	glass.radial_segments = 40
	glass.rings = 12
	var gi := MeshInstance3D.new()
	gi.name = "Glass"
	gi.mesh = glass
	gi.material_override = ModuleBuilder.mat(&"glass")
	gi.position = center
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.root.add_child(gi)
	var cs := CollisionShape3D.new()
	var shape := glass.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	cs.shape = shape
	cs.position = center
	b.shell.add_child(cs)
	# Linterna superior (anillo de ventilación con baliza)
	b.cyl(0.9, 0.35, center + Vector3(0, R + 0.1, 0), &"frame", Vector3.ZERO, &"", 16)
	b.sphere(0.12, center + Vector3(0, R + 0.4, 0), &"light_magenta")


func _airlock(b: ModuleBuilder) -> void:
	# Túnel de esclusa hacia +Z con puerta exterior y puerta interior
	var z0 := R - 0.2
	var z1 := R + 2.6
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.25, 2.65, z1 - z0), Vector3(s * 0.95, 1.325, (z0 + z1) * 0.5), &"hull", Vector3.ZERO, &"shell")
		b.box(Vector3(0.02, 2.4, z1 - z0 - 0.4), Vector3(s * 0.82, 1.25, (z0 + z1) * 0.5), &"interior_wall")
	b.box(Vector3(2.15, 0.25, z1 - z0), Vector3(0, 2.775, (z0 + z1) * 0.5), &"hull", Vector3.ZERO, &"shell")
	b.box(Vector3(2.15, 0.2, z1 - z0), Vector3(0, -0.1, (z0 + z1) * 0.5), &"floor", Vector3.ZERO, &"shell")
	for k in 4:
		b.box(Vector3(2.3, 2.9, 0.1), Vector3(0, 1.45, z0 + 0.3 + k * 0.75), &"frame")
	# cara exterior del túnel con la puerta
	b.wall(Vector3(1.1, 0, z1), Vector3(-1.1, 0, z1), 2.9, 0.25, [Vector4(0.25, 1.7, 0, 2.45)] as Array[Vector4], &"hull")
	add_door(b, Vector3(0, 0, z1), 0.0)
	add_door(b, Vector3(0, 0, R - 0.05), 0.0, 0.3)
	door_ramp(b, Vector3(0, 0, z1 + 0.18), Vector3(0, 0, 1))
	b.detail = true
	b.ceiling_light(Vector3(0, 2.6, (z0 + z1) * 0.5), Color(0.95, 0.95, 1.0), 0.8, 4.0)
	b.label(tr("COLONY_AIRLOCK_STEPS"), Vector3(-0.8, 1.9, (z0 + z1) * 0.5 + 0.6), Vector3(0, PI * 0.5, 0), 0.0035, Color(1.0, 0.85, 0.5), 300.0).font_size = 22
	b.detail = false
	sign_plate(b, Vector3(0, 3.35, z1 + 0.15), 0.0, tr("COLONY_BIODOME_NAME").to_upper(), tr("COLONY_SECTOR_HYDRO"))
	b.omni(Vector3(0, 3.0, z1 + 1.2), Color(1.0, 0.88, 0.7), 1.6, 6.0)


func _storage_room(b: ModuleBuilder) -> void:
	# Almacén refrigerado pegado al área de cultivo (lado +X), conectado sin salir afuera
	var cx := R + 1.9
	var w := 4.2
	var d := 4.0
	var h := 2.8
	b.slab(Vector3(w + 0.3, 0.2, d + 0.3), Vector3(cx, 0, 0), &"floor")
	b.box(Vector3(w + 0.3, 0.25, d + 0.3), Vector3(cx, h + 0.125, 0), &"hull", Vector3.ZERO, &"shell")
	# paredes: la del lado de la cúpula tiene el paso con puerta
	var hw := w * 0.5
	var hd := d * 0.5
	b.wall(Vector3(cx - hw, 0, -hd), Vector3(cx - hw, 0, hd), h, 0.25, [Vector4(hd - 0.85, 1.7, 0, 2.45)] as Array[Vector4], &"hull", &"interior_wall")
	b.wall(Vector3(cx - hw, 0, hd), Vector3(cx + hw, 0, hd), h, 0.25, [], &"hull", &"interior_wall")
	b.wall(Vector3(cx + hw, 0, hd), Vector3(cx + hw, 0, -hd), h, 0.25, [Vector4(hd - 0.7, 1.4, 0.95, 0.8)] as Array[Vector4], &"hull", &"interior_wall")
	b.wall(Vector3(cx + hw, 0, -hd), Vector3(cx - hw, 0, -hd), h, 0.25, [], &"hull", &"interior_wall")
	add_door(b, Vector3(cx - hw, 0, 0), PI * 0.5)
	# exterior: unidad de refrigeración y radiadores
	b.box(Vector3(1.2, 1.4, 1.6), Vector3(cx + hw + 0.75, 0.7, -0.9), &"hull_panel", Vector3.ZERO, &"shell")
	for k in 5:
		b.box(Vector3(0.05, 1.2, 1.5), Vector3(cx + hw + 1.38, 0.7, -1.55 + k * 0.33), &"frame")
	b.label(tr("COLONY_STORAGE_NAME").to_upper(), Vector3(cx - 1.0, 2.5, hd + 0.14), Vector3.ZERO, 0.006, Color(0.75, 0.97, 1.0), 330.0).font_size = 24
	# interior
	b.detail = true
	for z: float in [-1.3, 1.3]:
		b.rack(Vector3(cx + hw - 0.45, 0, z * 0.85), -PI * 0.5, 2.0)
	var shelf := b.group(Vector3(cx + 0.3, 0, -hd + 0.35), 0.0, "ColdShelf")
	for lvl in 4:
		b.box(Vector3(2.4, 0.04, 0.6), Vector3(0, 0.3 + lvl * 0.5, 0), &"metal", Vector3.ZERO, &"", shelf)
	for x: float in [-1.18, 1.18]:
		for z: float in [-0.28, 0.28]:
			b.box(Vector3(0.05, 2.0, 0.05), Vector3(x, 1.0, z), &"frame", Vector3.ZERO, &"", shelf)
	b.collider(Vector3(2.4, 2.0, 0.6), Vector3(cx + 0.3, 1.0, -hd + 0.35), &"furniture")
	# cajones de cosecha: se llenan según el stock real del almacén
	for lvl in 4:
		for k in 4:
			var crate := ModuleBuilder.mark_dynamic(b.box(Vector3(0.5, 0.3, 0.45), Vector3(-0.9 + k * 0.6, 0.47 + lvl * 0.5, 0), &"leaf" if (lvl + k) % 3 else &"fruit_red", Vector3.ZERO, &"", shelf)) as MeshInstance3D
			_storage_crates.append(crate)
	b.box(Vector3(0.9, 1.9, 0.7), Vector3(cx + 1.4, 0.95, hd - 0.5), &"frost", Vector3.ZERO, &"furniture") # cámara de frío
	b.box(Vector3(0.6, 0.5, 0.02), Vector3(cx + 1.4, 1.5, hd - 0.86), &"screen_dark")
	screens.append(b.terminal(Vector3(cx - 0.5, 0, hd - 0.5), PI, "", &"screen_cyan", true))
	b.ceiling_light(Vector3(cx, h - 0.05, 0), Color(0.75, 0.9, 1.0), 1.2, 5.0)
	b.detail = false
	var it := b.interactable(Vector3(cx - 0.5, 1.0, hd - 0.85), "ACTION_USE_TERMINAL", tr("COLONY_STORAGE_NAME"), 0.6, 2.0)
	it.interacted.connect(func(by: Node) -> void:
		var c := colony()
		if c:
			c.open_terminal(&"storage", self, by))


func _interior(b: ModuleBuilder) -> void:
	b.detail = true
	# torre central de riego con tanque y cañerías a los bancales
	b.cyl(0.75, 2.6, Vector3(0, 1.3, 0), &"pipe_blue", Vector3.ZERO, &"furniture", 20)
	b.cyl(0.8, 0.12, Vector3(0, 2.66, 0), &"frame", Vector3.ZERO, &"", 20)
	b.cyl(0.08, 3.5, Vector3(0, 4.4, 0), &"metal", Vector3.ZERO, &"", 8)
	screens.append(b.wall_screen(Vector3(0, 1.6, 0.79), 0.0, Vector2(0.9, 0.6)))
	# pasarela circular perimetral (piso técnico con franjas)
	b.cyl(R - 0.1, 0.04, Vector3(0, 0.02, 0), &"floor", Vector3.ZERO, &"", 40)
	b.cyl(2.5, 0.04, Vector3(0, 0.045, 0), &"interior_trim", Vector3.ZERO, &"", 24)
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.18
	leaf_mesh.height = 0.26
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 4
	var fruit_mesh := SphereMesh.new()
	fruit_mesh.radius = 0.05
	fruit_mesh.height = 0.1
	fruit_mesh.radial_segments = 6
	fruit_mesh.rings = 3
	for i in BED_ANGLES.size():
		var ang := deg_to_rad(BED_ANGLES[i])
		var dir := Vector3(sin(ang), 0, cos(ang))
		var mid := dir * (BED_R0 + BED_R1) * 0.5
		var len := BED_R1 - BED_R0
		var g := b.group(mid, ang, "Bed_%d" % i)
		b.box(Vector3(1.0, 0.7, len), Vector3(0, 0.35, 0), &"hull_panel", Vector3.ZERO, &"furniture", g)
		b.box(Vector3(0.9, 0.05, len - 0.1), Vector3(0, 0.68, 0), &"soil", Vector3.ZERO, &"", g)
		b.box(Vector3(1.04, 0.06, len + 0.04), Vector3(0, 0.71, 0), &"frame", Vector3.ZERO, &"", g)
		# barra de luz de cultivo (magenta) sobre dos postes
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(0.06, 2.0, 0.06), Vector3(0.55, 1.4, s * (len * 0.5 - 0.2)), &"frame", Vector3.ZERO, &"", g)
		b.box(Vector3(0.7, 0.05, len - 0.3), Vector3(0, 2.35, 0), &"frame", Vector3.ZERO, &"", g)
		b.box(Vector3(0.6, 0.02, len - 0.4), Vector3(0, 2.32, 0), &"light_magenta", Vector3.ZERO, &"", g)
		b.pipe(Vector3(0, 0.75, -len * 0.5) + Vector3(0.4, 0, 0), Vector3(0, 0.75, len * 0.5) + Vector3(0.4, 0, 0), 0.02, &"pipe_white", g)
		# rótulo del cultivo
		var crop: Dictionary = crops.get(String(beds[i].crop), {})
		var tag := b.label(String(crop.get("name_es" if es() else "name_en", beds[i].crop)), Vector3(-0.45, 0.62, len * 0.5 + 0.03), Vector3.ZERO, 0.004, Color(0.75, 0.97, 1.0), 220.0, g)
		tag.font_size = 22
		# plantas: MultiMesh de hojas y frutos (se actualizan según la etapa)
		var lm := MultiMesh.new()
		lm.transform_format = MultiMesh.TRANSFORM_3D
		lm.mesh = leaf_mesh
		lm.instance_count = PLANTS_PER_BED * 3
		var lmi := MultiMeshInstance3D.new()
		lmi.multimesh = lm
		lmi.material_override = ModuleBuilder.mat(&"wheat" if beds[i].crop == "wheat" else (&"leaf_dark" if i % 2 else &"leaf"))
		lmi.visibility_range_end = ModuleBuilder.DETAIL_RANGE
		lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(lmi)
		_leaf_mm.append(lm)
		_leaf_mmi.append(lmi)
		var fm := MultiMesh.new()
		fm.transform_format = MultiMesh.TRANSFORM_3D
		fm.mesh = fruit_mesh
		fm.instance_count = PLANTS_PER_BED * 4
		var fmi := MultiMeshInstance3D.new()
		fmi.multimesh = fm
		fmi.material_override = ModuleBuilder.mat(&"fruit_red" if beds[i].crop in ["tomato", "radish"] else &"wheat")
		fmi.visibility_range_end = ModuleBuilder.DETAIL_RANGE
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(fmi)
		_fruit_mm.append(fm)
		_fruit_mmi.append(fmi)
		_stage_cache.append(-1)
		# punto de inspección en el extremo exterior del bancal (desde la pasarela)
		var it := b.interactable(dir * (BED_R1 + 0.5) + Vector3(0, 0.9, 0), "ACTION_INSPECT", tr("COLONY_CROP_BED") % (i + 1), 0.6, 1.9)
		it.interacted.connect(_on_bed.bind(i))
		_bed_points.append(it)
	# luces de cultivo reales (magenta) y de trabajo
	for k in 3:
		var a := deg_to_rad(135.0 + 90.0 * k)
		b.omni(Vector3(sin(a), 0, cos(a)) * 4.9 + Vector3(0, 2.2, 0), Color(1.0, 0.9, 0.94), 0.7, 7.0)
	b.omni(Vector3(0, 5.0, 0), Color(1.0, 0.96, 0.92), 1.6, 13.0)
	b.omni(Vector3(0, 2.6, R - 2.2), Color(1.0, 0.95, 0.9), 0.7, 6.0)
	for k in 4: # luminarias de la pasarela perimetral
		var a := deg_to_rad(22.5 + 90.0 * k)
		b.omni(Vector3(sin(a), 0, cos(a)) * (R - 1.8) + Vector3(0, 2.2, 0), Color(1.0, 0.94, 0.86), 0.35, 5.0) # lejos del muro: sin manchas quemadas
		b.box(Vector3(0.5, 0.08, 0.2), Vector3(sin(a), 0, cos(a)) * (R - 0.35) + Vector3(0, 2.45, 0), &"light_warm", Vector3(0, a, 0))
	# herramientas de jardinería, regaderas y cajas de semillas junto a la pasarela
	# (en los huecos entre bancales, nunca sobre la pasarela perimetral ni los pasillos)
	var gap := func(deg: float, r: float) -> Vector3: return Vector3(sin(deg_to_rad(deg)), 0, cos(deg_to_rad(deg))) * r
	b.workbench(gap.call(157.5, 5.0), deg_to_rad(157.5) + PI * 0.5, 1.2)
	b.crate(gap.call(202.5, 5.2), 0.7, Vector3(0.6, 0.4, 0.5), &"plastic")
	b.crate(gap.call(247.5, 5.2), -0.4, Vector3(0.5, 0.35, 0.5), &"pipe_blue")
	b.gas_cylinder(gap.call(292.5, 5.0), &"pipe_blue")
	b.gas_cylinder(gap.call(292.5, 5.0) + Vector3(0.3, 0, 0.1), &"pipe_white")
	b.detail = false
	_refresh_plants()


# --- Simulación ---------------------------------------------------------------------

func simulate(dt: float, net: BaseNetwork) -> void:
	var minutes := dt * BaseNetwork.GAME_MINUTES_PER_SECOND
	for i in beds.size():
		var bed := beds[i]
		if String(bed.crop) == "" or float(bed.progress) >= 1.0:
			continue # vacío, o maduro esperando la cosecha
		var crop: Dictionary = crops.get(String(bed.crop), {})
		var grow := float(crop.get("grow_minutes", 480.0))
		var water_need := float(crop.get("water_l_per_min", 0.004)) * minutes
		var got := net.take_water(water_need) if water_need > 0.0 else 0.0
		bed.dry = got + 0.0001 < water_need
		if bed.dry:
			continue
		bed.progress = minf(float(bed.progress) + minutes / grow * growth_multiplier, 1.0)
		if bed.progress >= 1.0:
			EventBus.notification_requested.emit(tr("CROP_READY") % [i + 1, _crop_name(String(bed.crop))], &"info")
	if net.rations < AUTO_RESTOCK_BELOW and storage > 0:
		var move := mini(storage, AUTO_RESTOCK_BELOW - net.rations + 4)
		storage -= move
		net.rations += move
	_refresh_plants()
	super.simulate(dt, net)


func _harvest(rations: int, net: BaseNetwork) -> void:
	harvested_total += rations
	var room := STORAGE_CAPACITY - storage
	var into := mini(room, rations)
	storage += into
	net.rations += rations - into # excedente directo a la base: nunca se frena
	EventBus.player_action.emit(&"harvest")


## Retira raciones del almacén a las reservas de la base.
func transfer_to_base(amount: int) -> int:
	var n := mini(amount, storage)
	storage -= n
	if _network:
		_network.rations += n
	return n


func stage_of(progress: float) -> int:
	if progress < 0.15:
		return 0
	if progress < 0.45:
		return 1
	if progress < 0.8:
		return 2
	return 3


func stage_name(stage: int) -> String:
	return tr(["CROP_STAGE_SEEDLING", "CROP_STAGE_VEGETATIVE", "CROP_STAGE_FLOWERING", "CROP_STAGE_RIPE"][stage])


func _refresh_plants() -> void:
	if _leaf_mm.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	for i in beds.size():
		var p := float(beds[i].progress)
		var key := int(p * 20.0) + (1000 if String(beds[i].crop) == "" else 0) # 20 pasos visibles
		if key == _stage_cache[i]:
			continue
		_stage_cache[i] = key
		rng.seed = 7919 * (i + 1)
		var len := BED_R1 - BED_R0
		var crop := String(beds[i].crop)
		var size := 0.15 + 0.85 * smoothstep(0.0, 0.85, p) if crop != "" else 0.0001
		if i < _bed_points.size():
			_bed_points[i].action_key = "ACTION_PLANT" if crop == "" else ("ACTION_HARVEST" if p >= 1.0 else "ACTION_INSPECT")
		var lm := _leaf_mm[i]
		var fm := _fruit_mm[i]
		var idx := 0
		var fidx := 0
		for k in PLANTS_PER_BED:
			var row := k % 2
			var col := k / 2
			var base := Vector3(-0.22 + row * 0.44, 0.7, -len * 0.5 + 0.45 + col * (len - 0.9) / 3.0)
			for leaf in 3:
				var off := Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))
				var sc: Vector3
				match crop:
					"wheat":
						sc = Vector3(0.18, 2.4, 0.18) * size
					"tomato", "soybean":
						sc = Vector3(0.9, 1.4, 0.9) * size
					"potato":
						sc = Vector3(1.1, 0.9, 1.1) * size
					_:
						sc = Vector3(1.1, 0.55, 1.1) * size
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), base + off + Vector3(0, 0.12 * sc.y + leaf * 0.06 * size, 0))
				lm.set_instance_transform(idx, t)
				idx += 1
			for f in 4:
				var ripe := p >= 0.8 and crop in ["tomato", "radish", "wheat", "soybean"]
				var fs := 1.0 if ripe else 0.0001
				var fo := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.15, 0.4) * size, rng.randf_range(-0.15, 0.15))
				if crop == "wheat":
					fo.y = 0.55 * size
				fm.set_instance_transform(fidx, Transform3D(Basis().scaled(Vector3.ONE * fs), base + fo))
				fidx += 1
	_refresh_storage_crates()


func _refresh_storage_crates() -> void:
	var full := int(round(float(storage) / STORAGE_CAPACITY * _storage_crates.size()))
	for k in _storage_crates.size():
		_storage_crates[k].visible = k < full


func _crop_name(id: String) -> String:
	var crop: Dictionary = crops.get(id, {})
	return String(crop.get("name_es" if es() else "name_en", id))


## Bancal: vacío -> elegir qué plantar; maduro -> cosechar; creciendo -> informe.
func _on_bed(by: Node, i: int) -> void:
	var p := by as Player
	var bed := beds[i]
	if String(bed.crop) == "":
		_plant_dialog(i)
	elif float(bed.progress) >= 1.0 and p:
		var crop: Dictionary = crops.get(String(bed.crop), {})
		var n := int(crop.get("rations_per_harvest", 2))
		var nm := _crop_name(String(bed.crop))
		p.perform_action(&"Collect", func() -> void:
			if harvest_bed(i) > 0:
				EventBus.notification_requested.emit(tr("CROP_HARVESTED") % [n, nm], &"info"), 0.8)
	else:
		EventBus.notification_requested.emit(bed_report(i), &"info")


## Cosecha un bancal maduro: las raciones van al almacén (el excedente, a la base)
## y el bancal queda libre para volver a plantar. Devuelve las raciones.
func harvest_bed(i: int) -> int:
	var bed := beds[i]
	if String(bed.crop) == "" or float(bed.progress) < 1.0:
		return 0
	var crop: Dictionary = crops.get(String(bed.crop), {})
	var n := int(crop.get("rations_per_harvest", 2))
	_harvest(n, _network)
	bed.crop = ""
	bed.progress = 0.0
	_stage_cache[i] = -1
	_refresh_plants()
	return n


func _plant_dialog(i: int) -> void:
	var opts: Array = []
	for id: String in crops:
		var c: Dictionary = crops[id]
		var mins := float(c.get("grow_minutes", 480.0)) / maxf(growth_multiplier, 0.01) / 60.0
		var water := float(c.get("water_l_per_min", 0.004)) * float(c.get("grow_minutes", 480.0))
		opts.append({"label": _crop_name(id),
			"gain": tr("CROP_OPT_GAIN") % int(c.get("rations_per_harvest", 2)),
			"cost": tr("CROP_OPT_COST") % [mins, water],
			"call": func() -> void: plant(i, id)})
	DecisionDialog.ask(tr("CROP_PLANT_TITLE") % (i + 1), tr("CROP_PLANT_BODY"), opts, tr("CROP_PLANT_SOURCE"))


func plant(i: int, crop_id: String) -> void:
	beds[i].crop = crop_id
	beds[i].progress = 0.0
	beds[i].dry = false
	_stage_cache[i] = -1
	if i < _leaf_mmi.size():
		_leaf_mmi[i].material_override = ModuleBuilder.mat(&"wheat" if crop_id == "wheat" else (&"leaf_dark" if i % 2 else &"leaf"))
		_fruit_mmi[i].material_override = ModuleBuilder.mat(&"fruit_red" if crop_id in ["tomato", "radish"] else &"wheat")
	EventBus.player_action.emit(&"plant")
	_refresh_plants()


func bed_report(i: int) -> String:
	var bed := beds[i]
	var crop: Dictionary = crops.get(String(bed.crop), {})
	var nm := String(crop.get("name_es" if es() else "name_en", bed.crop))
	var p := float(bed.progress)
	var cond := tr("CROP_DRY") if bed.dry else (tr("STATUS_NO_POWER") if not is_operational() else tr("CROP_HEALTHY"))
	var left := (1.0 - p) * float(crop.get("grow_minutes", 480.0)) / maxf(growth_multiplier, 0.01)
	return tr("CROP_REPORT") % [i + 1, nm, stage_name(stage_of(p)), p * 100.0, cond, left / 60.0]


func _update_screens() -> void:
	if screens.size() < 2:
		return
	var es_ := es()
	var t := ("ALMACÉN REFRIGERADO\n%d / %d raciones\nCosechado en total: %d\n" if es_ else "COLD STORAGE\n%d / %d rations\nTotal harvested: %d\n") % [storage, STORAGE_CAPACITY, harvested_total]
	t += ("Reserva de la base: %d\nReposición automática < %d" if es_ else "Base reserve: %d\nAuto-restock below %d") % [_network.rations if _network else 0, AUTO_RESTOCK_BELOW]
	screens[0].text = t
	var g := "HIDROPONÍA\n" if es_ else "HYDROPONICS\n"
	for i in beds.size():
		var crop: Dictionary = crops.get(String(beds[i].crop), {})
		g += "%d %-9s %3d%%%s\n" % [i + 1, String(crop.get("name_es" if es_ else "name_en", beds[i].crop)).left(9), int(float(beds[i].progress) * 100.0), " !" if beds[i].dry else ""]
	screens[1].text = g


func get_status_text() -> String:
	return "%s · %s · %s %d/%d" % [def.get_display_name(), tr("STATUS_OPERATIONAL") if is_operational() else tr("STATUS_NO_POWER"), tr("COLONY_STORAGE_SHORT"), storage, STORAGE_CAPACITY]


func save_module() -> Dictionary:
	return {"beds": beds.duplicate(true), "storage": storage, "harvested": harvested_total}


func load_module(d: Dictionary) -> void:
	var saved: Array = d.get("beds", [])
	for i in mini(saved.size(), beds.size()):
		var crop_id := String(saved[i].get("crop", beds[i].crop))
		if crop_id != String(beds[i].crop):
			if crop_id != "":
				plant(i, crop_id)
			beds[i].crop = crop_id
		beds[i].progress = float(saved[i].get("progress", 0.0))
		beds[i].dry = bool(saved[i].get("dry", false))
	storage = int(d.get("storage", 0))
	harvested_total = int(d.get("harvested", 0))
	for i in _stage_cache.size():
		_stage_cache[i] = -1
	_refresh_plants()
