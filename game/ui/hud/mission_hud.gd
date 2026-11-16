class_name MissionHud
extends CanvasLayer
## Panel de objetivos (arriba a la izquierda) y tarjeta de "Control de misión"
## con las explicaciones al comenzar y terminar cada misión.

var _mm: MissionManager
var _title: Label
var _list: VBoxContainer
var _card: PanelContainer
var _card_title: Label
var _card_text: Label
var _card_tween: Tween
var _sfx: AudioStreamPlayer


func _ready() -> void:
	add_to_group(&"session_ui")
	layer = 11
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SpatiumTheme.get_theme()
	add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28 + Minimap.RADIUS_PX * 2 + 14) # debajo del minimapa
	panel.custom_minimum_size = Vector2(380, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	_title = SpatiumTheme.label("", 17, &"title", 700, SpatiumTheme.ORANGE)
	vb.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	vb.add_child(_list)
	root.add_child(panel)

	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.offset_top = 60
	_card.custom_minimum_size = Vector2(640, 0)
	_card.offset_left = -320
	_card.offset_right = 320
	_card.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(SpatiumTheme.CYAN, Color(0.02, 0.05, 0.08, 0.86)))
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 6)
	_card.add_child(cvb)
	cvb.add_child(SpatiumTheme.label("CONTROL DE MISIÓN · SPATIUM IV" if TranslationServer.get_locale().begins_with("es") else "MISSION CONTROL · SPATIUM IV", 13, &"mono", 600, SpatiumTheme.CYAN))
	_card_title = SpatiumTheme.label("", 22, &"title", 700)
	cvb.add_child(_card_title)
	_card_text = SpatiumTheme.label("", 17, &"body", 450)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(600, 0)
	cvb.add_child(_card_text)
	_card.modulate.a = 0.0
	root.add_child(_card)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"UI"
	if ResourceLoader.exists("res://assets/audio/sfx/ui_notify.wav"):
		_sfx.stream = load("res://assets/audio/sfx/ui_notify.wav")
	add_child(_sfx)
	EventBus.pause_changed.connect(func(p: bool) -> void: visible = not p)
	EventBus.radiation_event.connect(_on_radiation)


func bind_session(_session: GameSession) -> void:
	_mm = get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if _mm == null:
		return
	_mm.objectives_changed.connect(_refresh)
	_mm.briefing.connect(_show_card)
	_mm.achievement_unlocked.connect(func(_id: String, title: String) -> void:
		EventBus.notification_requested.emit(("Logro desbloqueado: %s" if TranslationServer.get_locale().begins_with("es") else "Achievement unlocked: %s") % title, &"warning"))
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _mm.finished or _mm.current_mission().is_empty():
		_title.text = "SPATIUM IV"
		_list.add_child(SpatiumTheme.label("Campaña lunar completada · Próxima etapa: Marte" if TranslationServer.get_locale().begins_with("es") else "Lunar campaign completed · Next stage: Mars", 15, &"body", 500, SpatiumTheme.CYAN))
		return
	var m := _mm.current_mission()
	_title.text = _mm.text(m.title).to_upper()
	var objs: Array = m.get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		var done := _mm.is_objective_done(i)
		var target := _mm.objective_target(o)
		var count := "" if target <= 1 or _mm.between else "  %d/%d" % [_mm.progress[i] if i < _mm.progress.size() else 0, target]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(SpatiumTheme.label("■" if done else "□", 15, &"mono", 700, SpatiumTheme.CYAN if done else SpatiumTheme.TEXT_DIM))
		var l := SpatiumTheme.label(_mm.text(o.text) + count, 15, &"body", 500, SpatiumTheme.TEXT_DIM if done else SpatiumTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 330
		row.add_child(l)
		_list.add_child(row)


func _show_card(title: String, body: String) -> void:
	_card_title.text = title
	_card_text.text = body
	if _sfx.stream:
		_sfx.play()
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.4)
	_card_tween.tween_interval(clampf(body.length() * 0.06, 8.0, 16.0))
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.8)


func _on_radiation(phase: StringName, body: String) -> void:
	var es := TranslationServer.get_locale().begins_with("es")
	match phase:
		&"warning":
			_show_card("⚠ " + ("Evento de partículas solares" if es else "Solar particle event"), body)
		&"over":
			_show_card("Informe: tormenta solar (datos NASA DONKI)" if es else "Report: solar storm (NASA DONKI data)", body)
