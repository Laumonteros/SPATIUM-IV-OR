class_name ServiceBot
extends ColonyWalker
## Bot de servicio: patrulla los cruces de la colonia y, al consultarlo (E),
## informa la telemetría real de la partida (energía, reservas, radiación).

var _wheels: Array[Node3D] = []
var _beacon: MeshInstance3D
var _t := 0.0


func body_radius() -> float:
	return 0.45


func body_height() -> float:
	return 1.1


func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var b := ModuleBuilder.new(visual)
	b.box(Vector3(0.7, 0.35, 0.9), Vector3(0, 0.42, 0), &"hull")
	b.box(Vector3(0.72, 0.06, 0.92), Vector3(0, 0.62, 0), &"frame")
	b.box(Vector3(0.5, 0.05, 0.02), Vector3(0, 0.45, 0.46), &"light_cyan")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var w := b.group(Vector3(sx * 0.4, 0.18, sz * 0.32), 0.0, "Wheel")
			b.cyl(0.17, 0.12, Vector3.ZERO, &"plastic_dark", Vector3(0, 0, PI * 0.5), &"", 12, -1.0, w)
			_wheels.append(w)
	b.cyl(0.03, 0.45, Vector3(0, 0.87, -0.2), &"metal")
	var head := b.group(Vector3(0, 0.98, 0.05), 0.0, "Head")
	b.box(Vector3(0.36, 0.22, 0.2), Vector3.ZERO, &"hull_panel", Vector3.ZERO, &"", head)
	b.box(Vector3(0.3, 0.14, 0.01), Vector3(0, 0, 0.105), &"screen_cyan", Vector3.ZERO, &"", head)
	_beacon = b.sphere(0.05, Vector3(0, 1.15, -0.2), &"light_amber")
	b.omni(Vector3(0, 0.6, 0.6), Color(0.5, 0.9, 1.0), 0.6, 3.0)
	# elementos de la ficha: esta pieza no colisiona (el cuerpo del caminante sí)
	b.shell.collision_layer = 0
	b.furniture.collision_layer = 0


func _set_anim(_anim: StringName, moving_now: bool) -> void:
	if moving_now:
		for w in _wheels:
			w.rotation.x += 0.12


func _process(delta: float) -> void:
	_t += delta
	if _beacon:
		_beacon.visible = fmod(_t, 1.2) < 0.6


func _on_talk(_by: Node) -> void:
	var c := get_tree().get_first_node_in_group(&"colony") as Colony
	EventBus.notification_requested.emit("%s: %s" % [display_name, c.bot_report() if c else ""], &"info")
