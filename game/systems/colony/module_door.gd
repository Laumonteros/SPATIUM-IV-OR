class_name ModuleDoor
extends Node3D
## Puerta corrediza de esclusa (dos hojas separadas del cuerpo del módulo, con su
## propio pivote y colisión animable). Se abre sola al acercarse el astronauta, un
## tripulante o un bot (área de detección) y se cierra al alejarse.
##
## Medidas de paso: 1,3 m de ancho × 2,25 m de alto (mínimo de la guía: 1,2 × 2,2).

const WIDTH := 1.3
const HEIGHT := 2.25
const OPEN_TIME := 0.7

var _left: AnimatableBody3D
var _right: AnimatableBody3D
var _sensor: Area3D
var _strip: MeshInstance3D
var _open := false
var _dirty := false
var _poll := 0.0
var _tween: Tween
var _sound: AudioStreamPlayer3D
var thickness := 0.25


func _init(wall_thickness := 0.25) -> void:
	thickness = wall_thickness


func _ready() -> void:
	var b := ModuleBuilder.new(self)
	# Marco y señalización (franjas ámbar = precaución, luz verde/ámbar = estado)
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.14, HEIGHT + 0.14, thickness + 0.1), Vector3(s * (WIDTH * 0.5 + 0.07), (HEIGHT + 0.14) * 0.5, 0), &"frame")
	b.box(Vector3(WIDTH + 0.28, 0.16, thickness + 0.1), Vector3(0, HEIGHT + 0.08, 0), &"frame")
	b.box(Vector3(WIDTH, 0.04, thickness + 0.04), Vector3(0, 0.02, 0), &"stripe_amber")
	_strip = b.box(Vector3(WIDTH * 0.6, 0.05, 0.02), Vector3(0, HEIGHT + 0.08, thickness * 0.5 + 0.06), &"light_amber")
	_left = _leaf(-1.0)
	_right = _leaf(1.0)
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = (1 << 1) | (1 << 7) # jugador + llaves de puerta (tripulantes y bots)
	_sensor.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(WIDTH + 1.0, HEIGHT, 4.2)
	cs.shape = bs
	cs.position.y = HEIGHT * 0.5
	_sensor.add_child(cs)
	add_child(_sensor)
	# Las listas de solapamiento se consultan en cada paso de física (no dentro de
	# las señales de entrada/salida, donde todavía pueden estar desactualizadas):
	# así la puerta nunca queda trabada abierta o cerrada.
	_sensor.body_entered.connect(func(_b: Node) -> void: _dirty = true)
	_sensor.body_exited.connect(func(_b: Node) -> void: _dirty = true)
	_sensor.area_entered.connect(func(_a: Area3D) -> void: _dirty = true)
	_sensor.area_exited.connect(func(_a: Area3D) -> void: _dirty = true)
	_sound = AudioStreamPlayer3D.new()
	_sound.bus = &"SFX"
	_sound.max_distance = 12.0
	_sound.position.y = 1.2
	if ResourceLoader.exists("res://assets/audio/sfx/ui_click.wav"):
		_sound.stream = load("res://assets/audio/sfx/ui_click.wav")
	add_child(_sound)


func _leaf(side: float) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "DoorLeaf_" + ("L" if side < 0 else "R")
	body.collision_layer = ModuleBuilder.LAYER_SHELL
	body.collision_mask = 0
	body.sync_to_physics = false
	body.position = Vector3(side * WIDTH * 0.25, 0, 0)
	add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH * 0.5, HEIGHT, 0.08)
	mi.mesh = bm
	mi.material_override = ModuleBuilder.mat(&"hull_panel")
	mi.position.y = HEIGHT * 0.5
	body.add_child(mi)
	var win := MeshInstance3D.new() # mirilla
	var wm := BoxMesh.new()
	wm.size = Vector3(0.2, 0.35, 0.09)
	win.mesh = wm
	win.material_override = ModuleBuilder.mat(&"glass_gold")
	win.position = Vector3(-side * 0.1, 1.55, 0)
	body.add_child(win)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(WIDTH * 0.5, 0.08, 0.085)
	stripe.mesh = sm
	stripe.material_override = ModuleBuilder.mat(&"stripe_amber")
	stripe.position.y = 1.0
	body.add_child(stripe)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	cs.position.y = HEIGHT * 0.5
	body.add_child(cs)
	return body


func _physics_process(delta: float) -> void:
	_poll -= delta
	if _dirty or _poll <= 0.0:
		_dirty = false
		_poll = 0.25
		_on_change()


func _on_change() -> void:
	if not _sensor.monitoring:
		return
	var want := not _sensor.get_overlapping_bodies().is_empty() or not _sensor.get_overlapping_areas().is_empty()
	if want == _open:
		return
	_open = want
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	var off := WIDTH * 0.5 if _open else 0.0
	_tween.tween_property(_left, "position:x", -WIDTH * 0.25 - off, OPEN_TIME)
	_tween.tween_property(_right, "position:x", WIDTH * 0.25 + off, OPEN_TIME)
	_strip.material_override = ModuleBuilder.mat(&"light_green" if _open else &"light_amber")
	if _sound.stream and is_inside_tree():
		_sound.play()


func is_open() -> bool:
	return _open
