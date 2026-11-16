class_name ReturnLaunch
extends CanvasLayer
## Despegue de regreso del módulo Ariel (final de la campaña): cuenta regresiva por
## radio, llama del motor, ascenso con la cámara siguiéndolo y resumen de la misión.

var _session: GameSession
var _cam: Camera3D
var _lander: Node3D
var _rest: Vector3
var _fade: ColorRect
var _panel: PanelContainer


static func start(session: GameSession) -> void:
	var r := ReturnLaunch.new()
	session.add_child(r)
	r._run(session)


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS


func _run(session: GameSession) -> void:
	_session = session
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	_lander = net.get_lander() if net else null
	if _lander == null:
		_finish()
		return
	_rest = _lander.global_position
	session.player.input_enabled = false
	session._set_ui_visible(false)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = SpatiumTheme.get_theme()
	add_child(root)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 6000.0
	session.add_child(_cam)
	var side := (_rest - Vector3(0, _rest.y, 0)).normalized().cross(Vector3.UP)
	_cam.global_position = _rest + side * 34.0 + Vector3(0, 6.0, 0)
	_cam.look_at(_rest + Vector3(0, 4, 0), Vector3.UP)
	_cam.make_current()
	RadioPanel.say("launch_go")
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.75, 0.45)
	flame.omni_range = 40.0
	flame.light_energy = 0.0
	flame.position = Vector3(0, -0.3, 0)
	_lander.add_child(flame)
	await get_tree().create_timer(5.0).timeout
	var tw := create_tween()
	tw.tween_property(flame, "light_energy", 12.0, 1.0)
	tw.tween_method(func(k: float) -> void:
		_lander.global_position = _rest + Vector3(0, k * k * 420.0, 0)
		_cam.look_at(_lander.global_position + Vector3(0, 2, 0), Vector3.UP), 0.0, 1.0, 12.0)
	tw.parallel().tween_property(_fade, "color:a", 1.0, 3.0).set_delay(9.0)
	await tw.finished
	flame.queue_free()
	EventBus.player_action.emit(&"launch")
	_summary()


func _summary() -> void:
	var rad := get_tree().get_first_node_in_group(&"radiation_system") as RadiationSystem
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	var mm := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	var dome := colony.get_biodome() if colony else null
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	(get_child(0) as Control).add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)
	vb.add_child(SpatiumTheme.label(tr("RETURN_TITLE"), 30, &"title", 700, SpatiumTheme.ORANGE))
	var lines := [
		tr("RETURN_TIME") % (GameState.playtime_seconds / 60.0),
		tr("RETURN_DOSE") % (rad.total_msv if rad else 0.0),
		tr("RETURN_RESEARCH") % (colony.research_points if colony else 0),
		tr("RETURN_FOOD") % (dome.harvested_total if dome else 0),
		tr("RETURN_ACH") % (mm.achievements.size() if mm else 0),
	]
	for l: String in lines:
		vb.add_child(SpatiumTheme.label(l, 18, &"mono", 600))
	var note := SpatiumTheme.label(tr("RETURN_NOTE"), 15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 660
	vb.add_child(note)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var stay := Button.new()
	stay.text = tr("RETURN_STAY")
	stay.pressed.connect(_finish)
	hb.add_child(stay)
	var menu := Button.new()
	menu.text = tr("RETURN_MENU")
	menu.pressed.connect(func() -> void:
		IntroDirector.return_to_menu = true
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred())
	hb.add_child(menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stay.grab_focus.call_deferred()


## Seguir explorando: el Ariel vuelve a su plataforma (otra tripulación lo reabastece).
func _finish() -> void:
	if _lander:
		_lander.global_position = _rest
	if _session:
		_session.player.input_enabled = true
		_session._set_ui_visible(true)
		_session.player.camera_rig.get_camera().make_current()
	if _cam:
		_cam.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
