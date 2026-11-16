class_name ColonyWalker
extends Node3D
## Base de los habitantes móviles de la colonia (tripulantes y bots).
##
## Recorre una rutina en bucle: cada parada tiene un camino (puntos en el mundo,
## que rodean edificios y entran por las puertas), un tiempo de permanencia y una
## animación. La altura sale de un rayo hacia abajo (terreno, rampas y pisos de
## los módulos). Si el astronauta se cruza en el camino, espera. Lleva una "llave"
## (Area3D, capa 8) que abre las puertas automáticas, y un cuerpo que bloquea.

signal stop_reached(index: int)

var walker_id: StringName = &""
var display_name: String = ""
var speed: float = 1.25
## Paradas: {points: Array[Vector3], dwell: float, anim: StringName, activity: String, face: Vector3}
var stops: Array[Dictionary] = []

var stop_index := 0
var point_index := 0
var dwell_left := 0.0
var activity: String = ""

var _body: AnimatableBody3D
var _key: Area3D
var _interact: Interactable
var _facing := 0.0
var _moving := false
var _player: Node3D


func _ready() -> void:
	add_to_group(&"colony_walker")
	_build_visual()
	_body = AnimatableBody3D.new()
	_body.collision_layer = 1 << 2 # bloquea al astronauta (capa estructuras)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_radius()
	cap.height = body_height()
	cs.shape = cap
	cs.position.y = body_height() * 0.5
	_body.add_child(cs)
	add_child(_body)
	_key = Area3D.new()
	_key.collision_layer = 1 << 7
	_key.collision_mask = 0
	_key.monitoring = false
	var ks := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.4
	ks.shape = sp
	ks.position.y = 1.0
	_key.add_child(ks)
	add_child(_key)
	_interact = Interactable.new()
	_interact.action_key = "ACTION_TALK"
	_interact.display_name = display_name
	_interact.max_distance = 2.4
	var is_ := CollisionShape3D.new()
	var isp := SphereShape3D.new()
	isp.radius = 0.7
	is_.shape = isp
	is_.position.y = 1.0
	_interact.add_child(is_)
	add_child(_interact)
	_interact.interacted.connect(_on_talk)
	if not stops.is_empty() and point_index == 0 and dwell_left <= 0.0:
		_begin_stop()


func body_radius() -> float:
	return 0.35


func body_height() -> float:
	return 1.8


func _build_visual() -> void:
	pass


func _set_anim(_anim: StringName, _moving_now: bool) -> void:
	pass


func _on_talk(_by: Node) -> void:
	pass


func _begin_stop() -> void:
	var s := stops[stop_index]
	activity = String(s.get("activity", ""))
	point_index = 0
	dwell_left = float(s.get("dwell", 10.0))


func _physics_process(delta: float) -> void:
	if stops.is_empty():
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var s := stops[stop_index]
	var pts: Array = s.get("points", [])
	if point_index < pts.size():
		var target: Vector3 = pts[point_index]
		var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		var d := to.length()
		if d < 0.15:
			point_index += 1
			if point_index >= pts.size():
				stop_reached.emit(stop_index)
			return
		var dir := to / d
		# esperar si el astronauta está justo adelante
		if _player and _player.global_position.distance_to(global_position + dir * 0.8) < 0.9:
			_set_moving(false)
			return
		var step := minf(speed * delta, d)
		var np := global_position + dir * step
		np.y = _ground_y(np)
		global_position = np
		_facing = lerp_angle(_facing, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * delta))
		_apply_facing()
		_set_moving(true)
	else:
		_set_moving(false)
		var face: Variant = s.get("face", null)
		if face is Vector3:
			var f := (face as Vector3) - global_position
			_facing = lerp_angle(_facing, atan2(f.x, f.z), 1.0 - exp(-4.0 * delta))
			_apply_facing()
		dwell_left -= delta
		if dwell_left <= 0.0:
			stop_index = (stop_index + 1) % stops.size()
			_begin_stop()


func _set_moving(on: bool) -> void:
	_moving = on
	var arrived := point_index >= (stops[stop_index].get("points", []) as Array).size()
	var anim: StringName = &"Walk"
	if not on:
		anim = StringName(stops[stop_index].get("anim", "Idle")) if arrived else &"Idle"
	_set_anim(anim, on)


func _apply_facing() -> void:
	for c in get_children():
		if c is Node3D and c.name == "Visual":
			(c as Node3D).rotation.y = _facing


func _ground_y(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.4, 0), p + Vector3(0, -3.0, 0), 1 | (1 << 2))
	q.exclude = [_body.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return (hit.position as Vector3).y
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	return region.get_height(p) if region else p.y


## Lleva al caminante directamente a una parada (al cargar o en los tests).
func teleport_to_stop(i: int) -> void:
	stop_index = clampi(i, 0, stops.size() - 1)
	_begin_stop()
	var pts: Array = stops[stop_index].get("points", [])
	if not pts.is_empty():
		global_position = pts[pts.size() - 1]
		point_index = pts.size()


func current_location_text() -> String:
	return activity


func save_state() -> Dictionary:
	return {"stop": stop_index, "point": point_index, "dwell": dwell_left, "pos": SaveManager.vec3_to_arr(global_position)}


func load_state(d: Dictionary) -> void:
	stop_index = clampi(int(d.get("stop", 0)), 0, maxi(stops.size() - 1, 0))
	_begin_stop()
	point_index = int(d.get("point", 0))
	dwell_left = float(d.get("dwell", dwell_left))
	global_position = SaveManager.arr_to_vec3(d.get("pos"), global_position)
