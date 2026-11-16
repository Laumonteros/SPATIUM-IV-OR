class_name ResourceDeposit
extends Node3D
## Depósito de un recurso recolectable (regolito, ilmenita, hielo, muestra...).
##
## Se recolecta con la tecla de interacción: el astronauta se agacha (animación
## Collect) y, cuando la mano llega al material, el recurso pasa al inventario.
## Cada recolección achica el depósito; al agotarse desaparece. Empieza oculto
## para el HUD hasta que el escáner lo detecta (no se revela todo desde el inicio).

signal harvested(amount: int)
signal depleted

const COLLECT_EVENT_TIME := 0.8 # s: instante en que la mano toma el material

@export var item_id: StringName
@export var yield_per_harvest: int = 3
@export var harvests: int = 3
@export var collect_sound: AudioStream
@export var particle_color: Color = Color(0.6, 0.58, 0.55)

## Recompensa extra al agotarse (p. ej. una muestra al romper un bloque grande).
@export var bonus_item: StringName = &""
@export var bonus_amount: int = 0
## Si el escáner lo marca en el HUD (los bloques de roca comunes no).
@export var scannable: bool = true

var deposit_id: String = ""
var remaining: int = -1
var discovered: bool = false

var _model: Node3D
var _interactable: Interactable
var _sfx: AudioStreamPlayer3D
var _base_scale: Vector3 = Vector3.ONE


## Configura el depósito (lo usa ResourceField al generarlo).
func setup(id: String, def_item: StringName, model_scene: PackedScene, scale_factor: float, collider_radius: float, custom_shape: Shape3D = null) -> void:
	deposit_id = id
	item_id = def_item
	_model = model_scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * scale_factor
	_base_scale = _model.scale
	add_child(_model)
	MoonMaterials.apply(_model)

	var body := StaticBody3D.new()
	body.collision_layer = 1 << 3 # capa 4: recursos
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	if custom_shape:
		body.collision_layer |= 1 # los bloques grandes bloquean como el terreno
		shape.shape = custom_shape
		shape.scale = Vector3.ONE * scale_factor
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = collider_radius * scale_factor
		cyl.height = maxf(0.3, collider_radius * scale_factor * 0.9)
		shape.shape = cyl
		shape.position.y = cyl.height * 0.5
	body.add_child(shape)
	add_child(body)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 260.0 + scale_factor * 90.0
		mi.visibility_range_end_margin = 15.0

	_interactable = Interactable.new()
	_interactable.action_key = "ACTION_COLLECT"
	_interactable.max_distance = 1.6 + collider_radius * scale_factor
	var area_shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.6 + collider_radius * scale_factor
	area_shape.shape = sph
	area_shape.position.y = 0.4
	_interactable.add_child(area_shape)
	add_child(_interactable)

	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = &"SFX"
	_sfx.unit_size = 4.0
	_sfx.max_distance = 25.0
	add_child(_sfx)


func _ready() -> void:
	add_to_group(&"resource_deposit")
	if remaining < 0:
		remaining = harvests
	var def := DataRegistry.get_def(item_id) as ItemDef
	if _interactable:
		_interactable.name_key = def.name_key if def else ""
		_interactable.interacted.connect(_on_interacted)
	_update_visual(false)


func get_item_def() -> ItemDef:
	return DataRegistry.get_def(item_id) as ItemDef


func is_depleted() -> bool:
	return remaining <= 0


## Estado persistente (lo guarda ResourceField).
func set_state(rem: int, disc: bool) -> void:
	remaining = rem
	discovered = disc
	_update_visual(false)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null or is_depleted():
		return
	player.face_towards(global_position)
	player.perform_action(&"Collect", _harvest.bind(player), COLLECT_EVENT_TIME)


func _harvest(player: Player) -> void:
	if is_depleted() or not is_instance_valid(player):
		return
	var added := player.inventory.add(item_id, yield_per_harvest)
	if added <= 0:
		EventBus.notification_requested.emit(tr("HUD_INVENTORY_FULL"), &"warning")
		return
	discovered = true
	remaining -= 1
	if collect_sound:
		_sfx.stream = collect_sound
		_sfx.pitch_scale = randf_range(0.95, 1.05)
		_sfx.play()
	_burst()
	_pickup_feedback(player, item_id, added)
	harvested.emit(added)
	EventBus.resource_collected.emit(item_id, added)
	_update_visual(true)
	if is_depleted():
		if bonus_item != &"" and bonus_amount > 0:
			var got := player.inventory.add(bonus_item, bonus_amount)
			if got > 0:
				EventBus.resource_collected.emit(bonus_item, got)
				get_tree().create_timer(0.5).timeout.connect(_pickup_feedback.bind(player, bonus_item, got))
		depleted.emit()
		EventBus.deposit_depleted.emit(deposit_id)


func _update_visual(animate: bool) -> void:
	if _model == null:
		return
	var frac := clampf(float(remaining) / maxf(1.0, float(harvests)), 0.0, 1.0)
	var goal := _base_scale * (0.45 + 0.55 * frac) if remaining > 0 else _base_scale * 0.05
	if _interactable:
		_interactable.enabled = remaining > 0
	if animate:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_model, "scale", goal, 0.45)
		if remaining <= 0:
			tw.tween_callback(func() -> void: visible = false)
	else:
		_model.scale = goal
		visible = remaining > 0
	for body: StaticBody3D in find_children("*", "StaticBody3D", false, false):
		body.process_mode = Node.PROCESS_MODE_INHERIT if remaining > 0 else Node.PROCESS_MODE_DISABLED


## Respuesta visual de la recolección: fragmentos del color del recurso que viajan
## hasta la bolsa del traje y un rótulo flotante "+5 Regolito".
func _pickup_feedback(player: Player, id: StringName, amount: int) -> void:
	if not is_instance_valid(player) or not is_inside_tree():
		return
	var col := ResourceColors.of(id)
	var from := global_position + Vector3(0, 0.4, 0)
	var host: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.6
	for i in 5:
		var frag := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.05, 0.09)
		frag.mesh = bm
		frag.material_override = mat
		host.add_child(frag)
		frag.global_position = from + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.3), randf_range(-0.3, 0.3))
		var mid := frag.global_position + Vector3(0, randf_range(0.6, 1.0), 0)
		var tw := frag.create_tween()
		var start := frag.global_position
		tw.tween_method(func(k: float) -> void:
			if is_instance_valid(player):
				var end := player.global_position + Vector3(0, 1.1, 0)
				frag.global_position = start.lerp(mid, k).lerp(mid.lerp(end, k), k)
				frag.scale = Vector3.ONE * (1.0 - k * 0.7), 0.0, 1.0, 0.55 + i * 0.06)
		tw.tween_callback(frag.queue_free)
	var label := Label3D.new()
	label.text = "+%d %s" % [amount, ResourceColors.item_name(id)]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 36
	label.outline_size = 10
	label.modulate = col
	label.outline_modulate = Color(0, 0, 0, 0.75)
	host.add_child(label)
	label.global_position = from + Vector3(0, 0.9, 0)
	var lt := label.create_tween().set_parallel(true)
	lt.tween_property(label, "global_position:y", label.global_position.y + 1.0, 1.4)
	lt.tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.5)
	lt.chain().tween_callback(label.queue_free)


## Pequeña explosión de partículas balísticas (vacío: sin nube de polvo).
func _burst() -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -1.62, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = particle_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = mat
	p.process_material = pm
	p.draw_pass_1 = quad
	p.amount = 24
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 0.9
	p.position.y = 0.3
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)
