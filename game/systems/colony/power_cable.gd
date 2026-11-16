class_name PowerCable
extends Node3D
## Cable eléctrico grueso apoyado sobre el regolito, entre dos bornes fijos.
##
## El tendido pasa por abrazaderas (anclas) que el astronauta puede agarrar (E),
## llevar y soltar (E) donde quiera. Los bornes no se desconectan nunca: el cable
## tiene un largo máximo y, si el astronauta tira más allá, la abrazadera se queda
## en el límite ("cable tenso"). Así se ordena el tendido sin cortar el suministro.
## Sin colisión: el cable nunca bloquea puertas ni caminos.

signal changed

const RADIUS := 0.06
const SIDES := 6
const STEP := 0.6 # m entre muestras del terreno a lo largo del cable

var cable_id: String = ""
var start_point: Vector3
var end_point: Vector3
var clamps: Array[Vector3] = []
var max_length: float = 30.0
var label_text: String = ""

var _mesh: MeshInstance3D
var _clamp_nodes: Array[Node3D] = []
var _held := -1
var _holder: Player
var _region: MoonRegion
var _dirty := true


func setup(id: String, a: Vector3, b: Vector3, anchor_points: Array[Vector3], slack := 1.3, text := "") -> void:
	cable_id = id
	start_point = a
	end_point = b
	clamps = anchor_points.duplicate()
	label_text = text
	max_length = _path_length(clamps) * slack + 2.0


func _ready() -> void:
	_region = get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	_mesh = MeshInstance3D.new()
	_mesh.name = "CableMesh"
	_mesh.material_override = ModuleBuilder.mat(&"power_cable")
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visibility_range_end = 250.0
	add_child(_mesh)
	for i in clamps.size():
		_clamp_nodes.append(_make_clamp(i))
	_rebuild()


func _make_clamp(i: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Clamp_%d" % i
	add_child(n)
	var b := ModuleBuilder.new(n)
	b.box(Vector3(0.32, 0.12, 0.22), Vector3(0, 0.06, 0), &"stripe_amber")
	b.box(Vector3(0.12, 0.14, 0.12), Vector3(0, 0.13, 0), &"frame")
	b.box(Vector3(0.05, 0.03, 0.05), Vector3(0, 0.21, 0), &"light_amber")
	var it := b.interactable(Vector3(0, 0.3, 0), "ACTION_GRAB_CABLE", tr("COLONY_CABLE"), 0.55, 2.0)
	it.interacted.connect(_on_grab.bind(i))
	return n


func _on_grab(by: Node, i: int) -> void:
	var p := by as Player
	if p == null or _held >= 0 or p.held_object != null:
		return
	_held = i
	_holder = p
	p.held_object = self
	p.perform_action(&"Collect")
	EventBus.notification_requested.emit(tr("COLONY_CABLE_GRABBED"), &"info")


## Lo llama el astronauta al volver a pulsar interactuar.
func drop_held() -> void:
	if _held < 0:
		return
	_held = -1
	if _holder:
		_holder.held_object = null
		_holder.perform_action(&"Interact")
	_holder = null
	changed.emit()
	EventBus.notification_requested.emit(tr("COLONY_CABLE_PLACED"), &"info")


func is_held() -> bool:
	return _held >= 0


func _physics_process(_delta: float) -> void:
	if _held >= 0 and is_instance_valid(_holder):
		var fwd := _holder.visual.global_basis.z
		fwd.y = 0.0
		var want := _holder.global_position + fwd.normalized() * 0.8
		move_clamp(_held, want)
	if _dirty:
		_rebuild()


## Mueve una abrazadera respetando el largo máximo (los bornes no se sueltan).
## Devuelve true si llegó a la posición pedida.
func move_clamp(i: int, want: Vector3) -> bool:
	var test := clamps.duplicate()
	test[i] = want
	var ok := true
	if _path_length(test) > max_length:
		# búsqueda binaria del punto más lejano permitido en esa dirección
		var lo := 0.0
		var hi := 1.0
		var from := clamps[i]
		for _k in 12:
			var mid := (lo + hi) * 0.5
			test[i] = from.lerp(want, mid)
			if _path_length(test) <= max_length:
				lo = mid
			else:
				hi = mid
		test[i] = from.lerp(want, lo)
		ok = false
	if test[i].distance_squared_to(clamps[i]) > 0.0001:
		clamps[i] = _ground(test[i])
		_dirty = true
	return ok


func get_length() -> float:
	return _path_length(clamps)


func is_taut() -> bool:
	return get_length() > max_length * 0.97


func _path_length(pts: Array) -> float:
	var all: Array = [start_point] + pts + [end_point]
	var l := 0.0
	for k in all.size() - 1:
		var a: Vector3 = all[k]
		var b: Vector3 = all[k + 1]
		l += Vector2(a.x - b.x, a.z - b.z).length()
	return l


func _ground(p: Vector3) -> Vector3:
	if _region == null:
		return p
	var h := _region.get_height(p)
	return Vector3(p.x, (h if is_finite(h) else p.y), p.z)


## Malla tubular que sigue el terreno entre bornes y abrazaderas.
func _rebuild() -> void:
	_dirty = false
	for i in _clamp_nodes.size():
		_clamp_nodes[i].global_position = _ground(clamps[i])
	var pts: Array[Vector3] = []
	var all: Array[Vector3] = [start_point]
	for c in clamps:
		all.append(_ground(c) + Vector3(0, 0.1, 0))
	all.append(end_point)
	for k in all.size() - 1:
		var a := all[k]
		var b := all[k + 1]
		var n := maxi(int(Vector2(a.x - b.x, a.z - b.z).length() / STEP), 1)
		for s in n:
			var t := float(s) / n
			var p := a.lerp(b, t)
			var g := _ground(p)
			# en los extremos sube hasta el borne; en el resto apoya sobre el suelo
			var lift := RADIUS + 0.01
			var y := maxf(g.y + lift, p.y if (k == 0 and t < 0.15) or (k == all.size() - 2 and t > 0.85) else g.y + lift)
			pts.append(Vector3(p.x, y, p.z))
	pts.append(all[all.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := global_transform.affine_inverse()
	var prev_ring: PackedVector3Array = []
	for i in pts.size():
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if dir == Vector3.ZERO:
			dir = Vector3.FORWARD
		var side := dir.cross(Vector3.UP).normalized()
		if side == Vector3.ZERO:
			side = Vector3.RIGHT
		var up := side.cross(dir).normalized()
		var ring: PackedVector3Array = []
		for s in SIDES:
			var a := TAU * s / SIDES
			ring.append(inv * (pts[i] + (side * cos(a) + up * sin(a)) * RADIUS))
		if i > 0:
			for s in SIDES:
				var s2 := (s + 1) % SIDES
				st.add_vertex(prev_ring[s])
				st.add_vertex(ring[s])
				st.add_vertex(ring[s2])
				st.add_vertex(prev_ring[s])
				st.add_vertex(ring[s2])
				st.add_vertex(prev_ring[s2])
		prev_ring = ring
	st.generate_normals()
	_mesh.mesh = st.commit()


func save_state() -> Array:
	return clamps.map(func(c: Vector3) -> Array: return SaveManager.vec3_to_arr(c))


func load_state(data: Array) -> void:
	for i in mini(data.size(), clamps.size()):
		clamps[i] = SaveManager.arr_to_vec3(data[i], clamps[i])
	_dirty = true
