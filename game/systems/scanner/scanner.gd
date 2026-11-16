class_name Scanner
extends Node
## Escáner de recursos del traje (tecla Q).
##
## Emite un pulso que se expande desde el astronauta; los depósitos dentro del
## alcance quedan "descubiertos" y el HUD los marca. Nada se revela antes de
## escanear: el mapa de recursos se construye explorando.

@export var scan_range: float = 75.0
@export var cooldown: float = 5.0
@export var pulse_duration: float = 2.6

var _ready_at: float = 0.0
var _sfx: AudioStreamPlayer
var _pulse: MeshInstance3D


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"Suit"
	_sfx.volume_db = -4.0
	if ResourceLoader.exists("res://assets/audio/sfx/scanner_ping.wav"):
		_sfx.stream = load("res://assets/audio/sfx/scanner_ping.wav")
	add_child(_sfx)
	_pulse = _make_pulse_mesh()
	add_child(_pulse)


func _unhandled_input(event: InputEvent) -> void:
	var player := owner as Player
	if player == null or not player.input_enabled or get_tree().paused:
		return
	if event.is_action_pressed(&"scan"):
		try_scan()


## Dispara un pulso (tecla Q o la ranura Escáner de la barra de herramientas).
func try_scan() -> bool:
	var player := owner as Player
	if player == null or not player.input_enabled:
		return false
	if Time.get_ticks_msec() / 1000.0 < _ready_at:
		EventBus.notification_requested.emit(tr("HUD_SCAN_COOLDOWN"), &"info")
		return false
	if player.perform_action(&"Scan", _emit_pulse, 0.45):
		_ready_at = Time.get_ticks_msec() / 1000.0 + cooldown
		return true
	return false


func get_cooldown_left() -> float:
	return maxf(0.0, _ready_at - Time.get_ticks_msec() / 1000.0)


func _emit_pulse() -> void:
	var origin := (owner as Node3D).global_position
	_sfx.play()
	_pulse.global_position = origin + Vector3(0, 0.6, 0)
	_pulse.visible = true
	_pulse.scale = Vector3.ONE * 0.5
	var mat := _pulse.material_override as ShaderMaterial
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_pulse, "scale", Vector3.ONE * scan_range, pulse_duration).set_trans(Tween.TRANS_LINEAR)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, pulse_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(func() -> void: _pulse.visible = false)

	# Todas las rocas y depósitos del alcance quedan marcados según lo que dan;
	# cada uno se revela cuando lo alcanza la onda del pulso.
	var found: Array = []
	for node in get_tree().get_nodes_in_group(&"resource_deposit"):
		var dep := node as ResourceDeposit
		if dep == null or dep.is_depleted():
			continue
		var d := dep.global_position.distance_to(origin)
		if d > scan_range:
			continue
		found.append(dep)
		if not dep.discovered:
			get_tree().create_timer(pulse_duration * d / scan_range).timeout.connect(func() -> void:
				if is_instance_valid(dep):
					dep.discovered = true)
	EventBus.scan_completed.emit(found)


func _make_pulse_mesh() -> MeshInstance3D:
	var sh := Shader.new()
	# El anillo aparece donde la esfera del pulso corta el terreno (comparación con el búfer de profundidad).
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.31, 0.82, 0.91, 1.0);
uniform float fade = 1.0;
uniform float line_width = 1.4;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float diff = abs(view.z - VERTEX.z);
	float line = smoothstep(line_width, 0.0, diff);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);
	ALBEDO = color.rgb * 1.6;
	ALPHA = clamp((line + rim * 0.08) * fade, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	mi.top_level = true
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
