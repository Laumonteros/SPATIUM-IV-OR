class_name IntroDirector
extends CanvasLayer
## Introducción cinematográfica + menú principal (sección 18 del documento de diseño).
##
## Secuencia: negro -> estrellas y la Tierra -> el módulo Ariel desciende con el
## motor encendido -> polvo al tocar el suelo -> el astronauta -> título SPATIUM IV
## -> menú. Cualquier tecla adelanta la cinemática.
## Modo evaluador: empieza con materiales y consumo de oxígeno reducido, para
## recorrer todos los sistemas en pocos minutos.

signal finished(mode: StringName)

## Al volver desde la pausa ("Salir" -> menú principal) se recarga la escena y se
## va directo al menú, sin repetir la cinemática.
static var return_to_menu := false
## Partida a retomar directamente al recargar (cambio de idioma en plena partida).
static var resume_slot := ""

var _session: GameSession
var _cam: Camera3D
var _fade: ColorRect
var _title_box: VBoxContainer
var _menu: VBoxContainer
var _skip_hint: Label
var _lander: Structure
var _lander_rest: Vector3
var _flame: OmniLight3D
var _glow: MeshInstance3D
var _engine: AudioStreamPlayer3D
var _menu_xf: Transform3D
var _drift := 0.0
var _seq: Tween
var _skippable := true
var _orbit_t := 0.0
var _in_menu := false
var _subtitle: Label
var _skip_requested := false
var _onb_tween: Tween
var _voice: AudioStreamPlayer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


## Arranca la intro. Devuelve false si no corresponde (tests, capturas).
func begin(session: GameSession) -> void:
	_session = session
	_build_ui()
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	_lander = net.get_lander()
	_lander_rest = _lander.global_position
	_session.player.visible = false
	_session.player.input_enabled = false
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 8000.0
	_session.add_child(_cam)
	_cam.make_current()
	if resume_slot != "":
		_skip_to_menu()
		_start.call_deferred(&"continue")
		return
	if return_to_menu:
		return_to_menu = false
		AudioManager.set_vacuum(false, true)
		if ResourceLoader.exists("res://assets/audio/music/intro_theme.wav"):
			AudioManager.play_music(load("res://assets/audio/music/intro_theme.wav"))
		_skip_to_menu()
		return
	_play_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and Array(OS.get_cmdline_user_args()).has("capture"):
		return # capturas automáticas: ignorar teclas externas
	if _skippable and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		if _subtitle.visible:
			_skip_requested = true
		else:
			_skip_to_menu()


func _process(delta: float) -> void:
	if _in_menu and _cam:
		# Deriva muy lenta de la cámara: la escena "respira" sin perder la composición
		_drift += delta
		var off := Vector3(sin(_drift * 0.15) * 0.8, sin(_drift * 0.11) * 0.3, 0.0)
		_cam.global_transform = Transform3D(_menu_xf.basis, _menu_xf.origin + _menu_xf.basis * off)


func _play_sequence() -> void:
	var earth_dir := _earth_direction()
	var site := _lander_rest
	_flame = OmniLight3D.new()
	_flame.light_color = Color(1.0, 0.75, 0.45)
	_flame.light_energy = 0.0
	_flame.omni_range = 40.0
	_flame.position = Vector3(0, -0.3, 0)
	_lander.add_child(_flame)
	_glow = _make_glow()
	_lander.add_child(_glow)
	_engine = AudioStreamPlayer3D.new()
	_engine.bus = &"SFX"
	_engine.unit_size = 40.0
	_engine.max_distance = 3000.0
	_engine.volume_db = -60.0
	if ResourceLoader.exists("res://assets/audio/sfx/ship_engine_loop.wav"):
		_engine.stream = load("res://assets/audio/sfx/ship_engine_loop.wav")
	_lander.add_child(_engine)
	AudioManager.set_vacuum(false, true) # la cinemática se escucha "de cine"
	if ResourceLoader.exists("res://assets/audio/music/intro_theme.wav"):
		AudioManager.play_music(load("res://assets/audio/music/intro_theme.wav"))

	# Trayectorias (un único plano continuo)
	var cam_orbit := site + Vector3(-40, 150, 60)                        # cámara en órbita baja
	var star_dir := Vector3(-earth_dir.x, 1.8, -earth_dir.z).normalized()
	var ship_far := cam_orbit + earth_dir * 2600.0 + Vector3(0, 300, 0)  # la nave llega desde la Tierra
	var ship_hover := site + Vector3(0, 150, 0)                          # sobre el sitio de alunizaje
	var cam_ground := site + Vector3(-20, 2.4, 24)
	var astro_cam := _session.player.global_position + (_session.player.global_position - site).slide(Vector3.UP).normalized() * 4.5 + Vector3(1.5, 1.8, 0)
	_lander.global_position = ship_far

	var T := 34.0
	_seq = create_tween()
	_seq.tween_property(_fade, "color:a", 0.0, 2.5)
	_seq.parallel().tween_method(func(t: float) -> void:
		var time := t * T
		var ship := ship_far
		var cam := cam_orbit
		var look := cam_orbit + star_dir * 100.0
		var thrust := 0.0
		if time < 4.0:                                   # estrellas
			pass
		elif time < 8.5:                                 # paneo hasta la Tierra
			var k := smoothstep(4.0, 8.5, time)
			look = cam_orbit + star_dir.slerp(earth_dir, k) * 100.0
		elif time < 16.0:                                # la nave se acerca
			var k := (time - 8.5) / 7.5
			ship = ship_far.lerp(ship_hover, 1.0 - pow(1.0 - k, 1.7))
			look = (cam_orbit + earth_dir * 100.0).lerp(ship, smoothstep(0.0, 0.35, k))
			thrust = 0.6 + 0.4 * k
		elif time < 27.0:                                # descenso: la cámara baja con la nave
			var k := (time - 16.0) / 11.0
			var e := 1.0 - pow(1.0 - k, 2.0)
			ship = ship_hover.lerp(site, e)
			cam = cam_orbit.lerp(cam_ground, smoothstep(0.0, 1.0, k))
			look = ship + Vector3(0, 2.0, 0)
			thrust = 1.0 - 0.3 * k
		else:                                            # aterrizado: la cámara se acerca al astronauta
			var k := smoothstep(27.0, 34.0, time)
			ship = site
			cam = cam_ground.lerp(astro_cam, k)
			look = (site + Vector3(0, 2.0, 0)).lerp(_session.player.global_position + Vector3(0, 1.2, 0), k)
		_lander.global_position = ship
		_cam.look_at_from_position(cam, look)
		_set_thrust(thrust), 0.0, 1.0, T)
	_seq.parallel().tween_callback(_touchdown).set_delay(27.0)
	_seq.parallel().tween_callback(func() -> void: _session.player.visible = true).set_delay(28.5)
	_seq.chain().tween_callback(_glide_to_menu)


## Intensidad del motor (luz, resplandor y sonido) entre 0 y 1.
func _set_thrust(v: float) -> void:
	if not is_instance_valid(_flame):
		return
	_flame.light_energy = 8.0 * v + sin(Time.get_ticks_msec() * 0.09) * 1.2 * v
	_glow.visible = v > 0.01
	_glow.scale = Vector3.ONE * lerpf(2.5, 8.0, v)
	if _engine.stream:
		if v > 0.01 and not _engine.playing:
			_engine.play()
		_engine.volume_db = linear_to_db(maxf(v, 0.001)) - 2.0


## Desliza la cámara hasta la toma del menú (sin corte) y muestra el menú.
func _glide_to_menu() -> void:
	var from := _cam.global_transform
	var to := _menu_pose()
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		_cam.global_transform = from.interpolate_with(to, smoothstep(0.0, 1.0, k)), 0.0, 1.0, 3.5)
	tw.tween_callback(_show_menu)


## Toma del menú: la Tierra queda a la derecha del cuadro y el módulo a la izquierda.
func _menu_pose() -> Transform3D:
	var e := _earth_direction()
	var earth_az := atan2(e.x, -e.z)
	var view_az := earth_az - deg_to_rad(27.0)         # Tierra 27° a la derecha del centro
	var lander_az := view_az - deg_to_rad(24.0)         # módulo 24° a la izquierda
	var dist := 21.0
	var to_lander := Vector3(sin(lander_az), 0.0, -cos(lander_az))
	var cam_pos := _lander_rest - to_lander * dist
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	if region:
		cam_pos = region.snap_to_ground(cam_pos, 1.7)
	var fwd := Vector3(sin(view_az), 0.0, -cos(view_az))
	var pitch := deg_to_rad(13.0)
	var look := cam_pos + (fwd * cos(pitch) + Vector3.UP * sin(pitch)) * 50.0
	return Transform3D(Basis.looking_at(look - cam_pos, Vector3.UP), cam_pos)


func _make_glow() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.62, 0.3, 0.9)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	mat.albedo_texture = tex
	var q := QuadMesh.new()
	q.size = Vector2(3, 3)
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = Vector3(0, -0.6, 0)
	mi.scale = Vector3.ONE * 8.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _touchdown() -> void:
	if is_instance_valid(_engine):
		var puff := AudioStreamPlayer.new()
		puff.bus = &"SFX"
		if ResourceLoader.exists("res://assets/audio/sfx/ship_thruster.wav"):
			puff.stream = load("res://assets/audio/sfx/ship_thruster.wav")
		add_child(puff)
		puff.play()
		_engine.queue_free()
	_flame.queue_free()
	if is_instance_valid(_glow):
		_glow.queue_free()
	_lander.global_position = _lander_rest
	# Polvo balístico del impacto de los gases del motor (sin aire: cae en parábolas)
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 3.5
	pm.emission_ring_inner_radius = 1.0
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0, 0.3, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -1.62, 0)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.6, 0.58, 0.55)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	q.material = m
	p.process_material = pm
	p.draw_pass_1 = q
	p.amount = 600
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 30, 80))
	_session.add_child(p)
	p.global_position = _lander_rest + Vector3(0, 0.2, 0)
	p.emitting = true
	get_tree().create_timer(5.0).timeout.connect(p.queue_free)


func _skip_to_menu() -> void:
	if _in_menu:
		return
	if _seq:
		_seq.kill()
	if is_instance_valid(_flame):
		_flame.queue_free()
	if is_instance_valid(_glow):
		_glow.queue_free()
	if is_instance_valid(_engine):
		_engine.queue_free()
	_lander.global_position = _lander_rest
	_fade.color.a = 0.0
	_session.player.visible = true
	_show_title()
	_show_menu()


func _show_title() -> void:
	_title_box.visible = true
	var tw := create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 1.2)


func _show_menu() -> void:
	_menu_xf = _menu_pose()
	_cam.global_transform = _menu_xf
	_title_box.visible = true
	_cam.fov = 58.0
	_in_menu = true
	_skippable = false
	_skip_hint.visible = false
	_title_box.visible = true
	_title_box.modulate.a = 1.0
	_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first := _menu.get_child(0) as Button
	first.grab_focus.call_deferred()
	if OS.is_debug_build() and Array(OS.get_cmdline_user_args()).has("autostart"):
		get_tree().create_timer(2.0).timeout.connect(func() -> void: _start(&"new")) # capturas automáticas


func _start(mode: StringName) -> void:
	_in_menu = false
	_menu.visible = false
	# Fundido a negro: la cámara nunca viaja atravesando módulos
	var out := create_tween().set_parallel(true)
	out.tween_property(_title_box, "modulate:a", 0.0, 0.5)
	out.tween_property(_fade, "color:a", 1.0, 0.6)
	await out.finished
	if mode == &"continue":
		if resume_slot != "":
			SaveManager.load_slot(resume_slot)
			resume_slot = ""
		else:
			var slots := SaveManager.list_slots()
			if slots.size() > 0:
				SaveManager.load_slot(String(slots[0].slot))
	else:
		await _onboarding()
	var target := _session.player.camera_rig.get_camera()
	target.make_current()
	_cam.queue_free()
	_session.player.input_enabled = true
	AudioManager.set_vacuum(true)
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.7)
	await fade_in.finished
	finished.emit(mode)
	queue_free()


## Mini-intro de la misión, en dos tomas separadas por fundidos (sin atravesar paredes):
##  1) exterior del hábitat, la cámara se acerca a la puerta;
##  2) interior, con la cámara real del juego detrás del astronauta.
## Control de misión habla por radio (voz en inglés, subtítulos en el idioma elegido).
## Cualquier tecla salta la línea actual.
func _onboarding() -> void:
	_title_box.visible = false
	_subtitle.visible = true
	_skippable = true
	_skip_requested = false
	var p := _session.player
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	var home := colony.get_player_home() as Node3D if colony else null
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	var xf := home.global_transform if home else Transform3D(Basis(), p.global_position)
	var focus := xf * Vector3(0, 2.6, 0)
	var a := _above_ground(xf * Vector3(-10.0, 8.0, 32.0), region)
	var b := _above_ground(xf * Vector3(-3.5, 4.4, 19.0), region)
	_cam.fov = 55.0
	_cam.look_at_from_position(a, focus)
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"UI"
	add_child(_voice)
	# Toma 1: exterior
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, 0.8)
	_onb_tween = create_tween()
	_onb_tween.tween_method(func(k: float) -> void:
		_cam.look_at_from_position(a.lerp(b, smoothstep(0.0, 1.0, k)), focus), 0.0, 1.0, 19.0)
	await _say(0)
	await _say(1)
	# Toma 2: interior, con la cámara del juego
	await _fade_to(1.0, 0.45)
	if _onb_tween:
		_onb_tween.kill()
	p.visible = true
	p.camera_rig.get_camera().make_current()
	p.animator.play_action(&"Interact")
	await _fade_to(0.0, 0.6)
	await _say(2)
	_subtitle.visible = false
	_skippable = false
	await _fade_to(1.0, 0.35)


const ONB_LINES := ["onb_1", "onb_2", "onb_3"]


## Reproduce una línea de radio con su subtítulo; vuelve al terminar o al saltarla.
func _say(i: int) -> void:
	_subtitle.text = RadioPanel.text_of(ONB_LINES[i])
	_skip_requested = false
	var dur := 4.5
	var st := RadioPanel.voice_of(ONB_LINES[i])
	if st:
		_voice.stream = st
		_voice.play()
		dur = st.get_length() + 0.4
	var t := 0.0
	while t < dur and not _skip_requested:
		await get_tree().process_frame
		t += get_process_delta_time()
	_voice.stop()


func _fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


func _above_ground(pos: Vector3, region: MoonRegion) -> Vector3:
	if region:
		var h := region.get_height(pos)
		if is_finite(h):
			pos.y = maxf(pos.y, h + 1.4)
	return pos


func _earth_direction() -> Vector3:
	var env := get_tree().get_first_node_in_group(&"world_region").get_node("WorldEnvironment") as WorldEnvironment
	var mat := env.environment.sky.sky_material as ShaderMaterial
	return (mat.get_shader_parameter("planet_direction") as Vector3).normalized()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = SpatiumTheme.get_theme()
	add_child(root)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_title_box = VBoxContainer.new()
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title_box.offset_top = 90
	_title_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := SpatiumTheme.label("SPATIUM IV", 96, &"title", 800, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 0)
	_title_box.add_child(t)
	var es := TranslationServer.get_locale().begins_with("es")
	var sub := SpatiumTheme.label("Entrenamiento de misión para jóvenes astronautas" if es else "Junior astronaut mission trainer", 22, &"title", 500, SpatiumTheme.ORANGE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(sub)
	_title_box.visible = false
	_title_box.modulate.a = 0.0
	root.add_child(_title_box)

	_menu = VBoxContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_menu.offset_top = -300
	_menu.offset_bottom = -70
	_menu.offset_left = -180
	_menu.offset_right = 180
	_menu.add_theme_constant_override("separation", 12)
	_menu.add_child(_btn(tr("MENU_NEW_GAME"), _ask_tutorial))
	var cont := _btn(tr("MENU_CONTINUE"), func() -> void: _start(&"continue"))
	cont.disabled = SaveManager.list_slots().is_empty()
	cont.tooltip_text = tr("LOAD_NONE") if cont.disabled else ""
	_menu.add_child(cont)
	_menu.add_child(_btn(tr("MENU_SETTINGS"), _open_settings))
	_menu.add_child(_btn(tr("MENU_QUIT"), func() -> void: get_tree().quit()))
	_menu.visible = false
	root.add_child(_menu)

	_skip_hint = SpatiumTheme.label("Presioná cualquier tecla para saltar" if es else "Press any key to skip", 14, &"body", 500, SpatiumTheme.TEXT_DIM)
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -360
	_skip_hint.offset_top = -50
	root.add_child(_skip_hint)

	_subtitle = SpatiumTheme.label("", 22, &"body", 500, Color.WHITE)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_top = -170
	_subtitle.offset_bottom = -100
	_subtitle.offset_left = -620
	_subtitle.offset_right = 620
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_constant_override("outline_size", 8)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_subtitle.visible = false
	root.add_child(_subtitle)

	var credit := SpatiumTheme.label("NASA Space Apps Challenge 2026", 13, &"mono", 500, SpatiumTheme.TEXT_DIM)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.offset_left = 28
	credit.offset_top = -44
	root.add_child(credit)


func _ask_tutorial() -> void:
	var mode := &"evaluator" if bool(Settings.get_value("game", "evaluator_mode")) else &"new"
	_menu.visible = false
	DecisionDialog.ask(tr("TUT_ASK_TITLE"), tr("TUT_ASK_BODY"), [
		{"label": tr("TUT_YES"), "gain": tr("TUT_YES_GAIN"), "call": func() -> void:
			GameState.tutorial = true
			_start(mode)},
		{"label": tr("TUT_NO"), "gain": tr("TUT_NO_GAIN"), "call": func() -> void:
			GameState.tutorial = false
			_start(mode)},
	], "", tr("TUT_HEADER"))


## Configuración desde el menú principal (usa las mismas páginas que la pausa).
func _open_settings() -> void:
	var pm := get_tree().get_first_node_in_group(&"pause_menu") as PauseMenu
	if pm == null:
		return
	_menu.visible = false
	_title_box.visible = false
	pm.open_settings(func() -> void:
		_menu.visible = true
		_title_box.visible = true
		(_menu.get_child(0) as Button).grab_focus())


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b
