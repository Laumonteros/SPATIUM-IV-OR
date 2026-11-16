class_name PlayerEffects
extends Node
## Efectos del astronauta: luces del casco, polvo al pisar/aterrizar y sonidos del traje.
##
## Ciencia en el detalle: sin aire, el polvo lunar no forma nubes. Cada grano sigue
## una parábola balística y cae de golpe (sin rozamiento). Las partículas usan la
## gravedad del cuerpo celeste y amortiguación cero.
## En el vacío el sonido no viaja por el aire: los pasos se oyen por vibración a
## través del traje, por eso se reproducen en el bus "Suit" (no son sonidos 3D).

const SFX := {
	&"step": "res://assets/audio/sfx/suit_step.wav",
	&"jump": "res://assets/audio/sfx/suit_jump.wav",
	&"land": "res://assets/audio/sfx/suit_land.wav",
	&"light_on": "res://assets/audio/sfx/light_on.wav",
	&"light_off": "res://assets/audio/sfx/light_off.wav",
	&"breath": "res://assets/audio/sfx/suit_breath_loop.wav",
}

@export var dust_color: Color = Color(0.62, 0.6, 0.57, 0.85)

var _lamps: Array[SpotLight3D] = []
var _dust_pool: Array[GPUParticles3D] = []
var _dust_index := 0
var _land_dust: GPUParticles3D
var _sfx_player: AudioStreamPlayer
var _breath_player: AudioStreamPlayer
var _streams: Dictionary = {}


func _ready() -> void:
	var player := owner as Player
	SurfaceMaterials.apply(player.get_node("Visual"))
	_load_streams()
	_build_lamps(player)
	_build_dust(player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"Suit"
	_sfx_player.max_polyphony = 4
	add_child(_sfx_player)
	_breath_player = AudioStreamPlayer.new()
	_breath_player.bus = &"Suit"
	_breath_player.volume_db = -14.0
	add_child(_breath_player)
	if _streams.has(&"breath"):
		_breath_player.stream = _streams[&"breath"]
		_breath_player.play()
	player.footstep.connect(_on_footstep)
	player.jumped.connect(func() -> void: _play(&"jump", -4.0))
	player.landed.connect(_on_landed)


func set_flashlight(on: bool) -> void:
	for lamp in _lamps:
		lamp.visible = on
	_play(&"light_on" if on else &"light_off", -6.0)


func _on_footstep(running: bool) -> void:
	_play(&"step", -3.0 if running else -7.0, randf_range(0.9, 1.1))
	var p := _dust_pool[_dust_index]
	_dust_index = (_dust_index + 1) % _dust_pool.size()
	p.global_position = (owner as Node3D).global_position + Vector3(0, 0.05, 0)
	p.amount_ratio = 1.0 if running else 0.55
	p.restart()


func _on_landed(air_time: float) -> void:
	if air_time < 0.3:
		return
	_play(&"land", -2.0)
	_land_dust.global_position = (owner as Node3D).global_position + Vector3(0, 0.05, 0)
	_land_dust.amount_ratio = clampf(air_time / 2.5, 0.35, 1.0)
	_land_dust.restart()


func _play(id: StringName, db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(id):
		return
	_sfx_player.stream = _streams[id]
	_sfx_player.volume_db = db
	_sfx_player.pitch_scale = pitch
	_sfx_player.play()


func _load_streams() -> void:
	for id: StringName in SFX:
		if ResourceLoader.exists(SFX[id]):
			_streams[id] = load(SFX[id]) # los bucles se configuran en la importación


func _build_lamps(player: Player) -> void:
	var skel := player.find_children("*", "Skeleton3D", true, false)
	if skel.is_empty():
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	(skel[0] as Skeleton3D).add_child(att)
	# Las luces del casco están a los lados del visor; apuntan hacia el frente (+Z del modelo).
	for x in [-0.175, 0.175]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(x, 0.14, 0.11)
		lamp.rotation = Vector3(deg_to_rad(-8.0), PI, 0.0)
		lamp.light_color = Color(1.0, 0.96, 0.88)
		lamp.light_energy = 6.0
		lamp.spot_range = 32.0
		lamp.spot_angle = 28.0
		lamp.spot_attenuation = 0.8
		lamp.shadow_enabled = x > 0.0 # una sola sombra: rendimiento
		lamp.visible = false
		att.add_child(lamp)
		_lamps.append(lamp)


func _build_dust(player: Player) -> void:
	var g := -9.8
	if player.is_inside_tree():
		g = player.get_gravity().y
	for i in 3:
		var p := _make_dust(12, 0.9, 1.5, g)
		_dust_pool.append(p)
	_land_dust = _make_dust(45, 1.6, 2.4, g)


func _make_dust(amount: int, vmin: float, vmax: float, gravity_y: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = vmin * 0.4
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, gravity_y if gravity_y < -0.1 else -1.62, 0)
	pm.damping_min = 0.0
	pm.damping_max = 0.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.22
	pm.emission_ring_inner_radius = 0.05
	pm.emission_ring_height = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex

	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = dust_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	quad.material = mat

	var p := GPUParticles3D.new()
	p.top_level = true
	p.amount = amount
	p.lifetime = 1.5 # ~ tiempo de vuelo balístico de vuelta al suelo (2·v/g)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.process_material = pm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8))
	p.collision_base_size = 0.02
	add_child(p)
	return p
