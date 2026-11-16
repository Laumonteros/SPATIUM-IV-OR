class_name BuildSystem
extends Node
## Modo construcción (B): elegir estructura (1-5 o rueda), ver un fantasma
## sobre el terreno, rotar (Z/R) y colocar (clic izquierdo o E).
##
## La colocación es válida si: hay terreno, la pendiente es suave (< 14°),
## no se superpone con otra estructura o roca, está a alcance y hay materiales.
## Al colocar se descuentan los materiales y empieza la animación de construcción.

signal mode_changed(active: bool)
signal selection_changed(def: BuildableDef)
signal validity_changed(valid: bool, reason: String)

const MAX_SLOPE_DEG := 14.0
const PLACE_RANGE := 14.0
const MIN_RANGE := 3.0

var active: bool = false
var options: Array[BuildableDef] = []
var selected: int = 0
var valid: bool = false
var reason: String = ""

var _ghost: Node3D
var _ghost_mat: StandardMaterial3D
var _yaw: float = 0.0
var _target := Vector3.ZERO
var _sfx: AudioStreamPlayer
var _deny: AudioStream
var _confirm: AudioStream


func _ready() -> void:
	for d: GameDef in DataRegistry.get_all_of(BuildableDef):
		var b := d as BuildableDef
		if b.cost.size() > 0: # el módulo de alunizaje no se construye
			options.append(b)
	options.sort_custom(func(a: BuildableDef, b: BuildableDef) -> bool: return a.priority > b.priority if a.role == b.role else a.role < b.role)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.3, 0.85, 0.95, 0.35)
	_ghost_mat.no_depth_test = false
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"UI"
	add_child(_sfx)
	if ResourceLoader.exists("res://assets/audio/sfx/ui_deny.wav"):
		_deny = load("res://assets/audio/sfx/ui_deny.wav")
	if ResourceLoader.exists("res://assets/audio/sfx/ui_click.wav"):
		_confirm = load("res://assets/audio/sfx/ui_click.wav")


func _unhandled_input(event: InputEvent) -> void:
	var player := owner as Player
	if player == null or get_tree().paused or not player.input_enabled:
		return
	if event.is_action_pressed(&"build_mode"):
		set_active(not active)
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < options.size():
			select(k - KEY_1)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		var mb := (event as InputEventMouseButton).button_index
		if mb == MOUSE_BUTTON_WHEEL_UP:
			select((selected - 1 + options.size()) % options.size())
		elif mb == MOUSE_BUTTON_WHEEL_DOWN:
			select((selected + 1) % options.size())
	if event.is_action_pressed(&"tool_primary") or event.is_action_pressed(&"interact"):
		try_place()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"tool_secondary"):
		set_active(false)
		get_viewport().set_input_as_handled()


func set_active(on: bool) -> void:
	if on == active or options.is_empty():
		return
	active = on
	if active:
		_spawn_ghost()
	elif _ghost:
		_ghost.queue_free()
		_ghost = null
	(owner as Player).interactor.monitoring = not active
	mode_changed.emit(active)
	selection_changed.emit(current())


func select(i: int) -> void:
	selected = clampi(i, 0, options.size() - 1)
	if active:
		_spawn_ghost()
	selection_changed.emit(current())


func current() -> BuildableDef:
	return options[selected] if options.size() > 0 else null


func can_afford(d: BuildableDef) -> bool:
	if _has_kit(d):
		return true
	var inv := (owner as Player).inventory
	for id: StringName in d.cost:
		if not inv.has(id, d.cost[id]):
			return false
	return true


func _process(delta: float) -> void:
	if not active or _ghost == null:
		return
	if Input.is_action_pressed(&"build_rotate_left"):
		_yaw += 1.8 * delta
	if Input.is_action_pressed(&"build_rotate_right"):
		_yaw -= 1.8 * delta
	_update_target()
	_ghost.global_position = _target
	_ghost.rotation.y = _yaw
	_validate()


func _update_target() -> void:
	var player := owner as Player
	var cam := player.camera_rig.get_camera()
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 1)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3 = hit.position if not hit.is_empty() else from + dir * 10.0
	var flat := p - player.global_position
	flat.y = 0.0
	var dist := clampf(flat.length(), MIN_RANGE + current().footprint_radius, PLACE_RANGE)
	var d2 := flat.normalized() if flat.length() > 0.01 else -player.camera_rig.get_yaw_basis().z
	var pos := player.global_position + d2 * dist
	_target = region.snap_to_ground(pos, 0.0) if region else pos


func _validate() -> void:
	var d := current()
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	var ok := true
	var why := ""
	if region:
		# Pendiente: muestras en el borde de la huella
		var hmin := INF
		var hmax := -INF
		for i in 8:
			var a := TAU * i / 8.0
			var h := region.get_height(_target + Vector3(cos(a), 0, sin(a)) * d.footprint_radius)
			if not is_finite(h):
				ok = false
				why = tr("BUILD_INVALID_TERRAIN")
				break
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
		if ok and rad_to_deg(atan((hmax - hmin) / (d.footprint_radius * 2.0))) > MAX_SLOPE_DEG:
			ok = false
			why = tr("BUILD_INVALID_SLOPE")
	if ok:
		for s in get_tree().get_nodes_in_group(&"structure"):
			var st := s as Structure
			if Vector2(st.global_position.x - _target.x, st.global_position.z - _target.z).length() < st.def.footprint_radius + d.footprint_radius + 0.4:
				ok = false
				why = tr("BUILD_INVALID_OVERLAP")
				break
	if ok:
		var space := (owner as Player).get_world_3d().direct_space_state
		var qp := PhysicsShapeQueryParameters3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = d.footprint_radius * 0.8
		cyl.height = 1.6
		qp.shape = cyl
		qp.transform = Transform3D(Basis(), _target + Vector3(0, 1.1, 0))
		qp.collision_mask = 1 | (1 << 2) | (1 << 3)
		for r in space.intersect_shape(qp, 4):
			if not (r.collider is Terrain3D) and r.collider != owner:
				ok = false
				why = tr("BUILD_INVALID_OBSTACLE")
				break
	if ok and not can_afford(d):
		ok = false
		why = tr("BUILD_MISSING") % d.cost_text()
	_ghost_mat.albedo_color = Color(0.3, 0.85, 0.95, 0.38) if ok else Color(1.0, 0.35, 0.3, 0.38)
	if ok != valid or why != reason:
		valid = ok
		reason = why
		validity_changed.emit(valid, reason)


func try_place() -> void:
	var d := current()
	if not valid:
		_play(_deny)
		EventBus.notification_requested.emit(reason, &"warning")
		return
	var inv := (owner as Player).inventory
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	if colony and colony.consume_kit(d.id):
		pass # kit fabricado en el Taller: no gasta materiales
	else:
		for id: StringName in d.cost:
			inv.remove(id, d.cost[id])
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	net.spawn_structure(d, _target, _yaw, false)
	_play(_confirm)
	(owner as Player).face_towards(_target)
	(owner as Player).perform_action(&"Interact")
	EventBus.player_action.emit(&"build")
	_validate()


func _spawn_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = current().model.instantiate() as Node3D
	_ghost.add_to_group(&"flat") # el fantasma cambia de color en vivo: sin curvatura
	for mi: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _ghost_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Anillo que marca la huella en el suelo
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = current().footprint_radius - 0.06
	torus.outer_radius = current().footprint_radius
	ring.mesh = torus
	ring.material_override = _ghost_mat
	ring.position.y = 0.05
	_ghost.add_child(ring)
	_ghost.top_level = true
	add_child(_ghost)


func _play(stream: AudioStream) -> void:
	if stream:
		_sfx.stream = stream
		_sfx.play()


## ¿Hay un kit prefabricado en el Taller para esta estructura?
func _has_kit(d: BuildableDef) -> bool:
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	return colony != null and colony.has_kit(d.id)
