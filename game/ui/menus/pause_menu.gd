class_name PauseMenu
extends CanvasLayer
## Menú de pausa (Esc): continuar, guardar, cargar, opciones y salir.
## Todas las opciones se aplican al instante y se guardan en Settings.

const MANUAL_SLOT := "manual"

var _session: GameSession
var _root: Control
var _pages: Dictionary = {}
var _click: AudioStreamPlayer
var _load_list: VBoxContainer
## Abierta desde el menú principal (solo la configuración); al volver se llama a esto.
var _menu_return: Callable = Callable()


func _ready() -> void:
	add_to_group(&"session_ui")
	add_to_group(&"pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_click = AudioStreamPlayer.new()
	_click.bus = &"UI"
	if ResourceLoader.exists("res://assets/audio/sfx/ui_click.wav"):
		_click.stream = load("res://assets/audio/sfx/ui_click.wav")
	add_child(_click)
	_build()
	visible = false


func bind_session(session: GameSession) -> void:
	_session = session


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if not visible:
			if _menu_return.is_null():
				_open()
		elif _pages[&"controls"].visible:
			_show(&"options")
		elif _pages[&"options"].visible:
			_options_back()
		elif _pages[&"main"].visible:
			_close()
		else:
			_show(&"main")


func _open() -> void:
	if _session == null:
		return
	_session.set_paused(true)
	visible = true
	_show(&"main")


## Muestra solo la configuración, por encima del menú principal.
func open_settings(on_close: Callable) -> void:
	_menu_return = on_close
	layer = 40
	visible = true
	_show(&"options")


func _options_back() -> void:
	if _menu_return.is_null():
		_show(&"main")
		return
	var cb := _menu_return
	_menu_return = Callable()
	visible = false
	layer = 20
	cb.call()


func _close() -> void:
	visible = false
	if _session:
		_session.set_paused(false)


func _show(page: StringName) -> void:
	for k: StringName in _pages:
		(_pages[k] as Control).visible = k == page
	if page == &"load":
		_refresh_load_list()
	var first := (_pages[page] as Control).find_children("*", "Button", true, false)
	if first.size() > 0:
		(first[0] as Button).grab_focus.call_deferred()


# --- Construcción -----------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SpatiumTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.01, 0.03, 0.72)
	_root.add_child(dim)

	_pages[&"main"] = _page(tr("PAUSE_TITLE"), [
		[tr("PAUSE_RESUME"), _close],
		[tr("PAUSE_SAVE"), _on_save],
		[tr("PAUSE_LOAD"), _show.bind(&"load")],
		[tr("PAUSE_OPTIONS"), _show.bind(&"options")],
		[tr("PAUSE_EXIT"), _show.bind(&"exit")],
	])
	_pages[&"exit"] = _page(tr("PAUSE_EXIT_TITLE"), [
		[tr("PAUSE_SAVE_AND_MENU"), _to_main_menu.bind(true)],
		[tr("PAUSE_MENU_NO_SAVE"), _to_main_menu.bind(false)],
		[tr("PAUSE_QUIT_DESKTOP"), func() -> void: get_tree().quit()],
		[tr("PAUSE_CANCEL"), _show.bind(&"main")],
	])
	_pages[&"options"] = _options_page()
	_pages[&"load"] = _load_page()
	_pages[&"controls"] = _controls_page()


func _page(title: String, buttons: Array) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var t := SpatiumTheme.label(title.to_upper(), 30, &"title", 700, SpatiumTheme.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = SpatiumTheme.ORANGE
	vb.add_child(line)
	for b: Array in buttons:
		vb.add_child(_button(b[0], b[1]))
	center.set_meta("content", vb)
	return center


func _button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(func() -> void:
		if _click.stream:
			_click.play()
		cb.call())
	return btn


func _options_page() -> Control:
	var page := _page(tr("PAUSE_OPTIONS"), [])
	var vb: VBoxContainer = page.get_meta("content")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(grid)

	var preset := OptionButton.new()
	for k in ["GRAPHICS_PRESET_LOW", "GRAPHICS_PRESET_MEDIUM", "GRAPHICS_PRESET_HIGH"]:
		preset.add_item(tr(k))
	preset.selected = Settings.get_preset()
	preset.item_selected.connect(func(i: int) -> void: Settings.set_value("graphics", "preset", i))
	_row(grid, tr("OPT_GRAPHICS"), preset)

	var fs := CheckButton.new()
	fs.button_pressed = bool(Settings.get_value("graphics", "fullscreen"))
	fs.toggled.connect(func(on: bool) -> void: Settings.set_value("graphics", "fullscreen", on))
	_row(grid, tr("OPT_FULLSCREEN"), fs)

	for pair in [["OPT_VOLUME_MASTER", "Master"], ["OPT_VOLUME_MUSIC", "Music"], ["OPT_VOLUME_SFX", "SFX"]]:
		_row(grid, tr(pair[0]), _slider(0.0, 1.0, 0.05, float(Settings.get_value("audio", pair[1])),
			func(v: float) -> void: Settings.set_value("audio", pair[1], v)))

	_row(grid, tr("OPT_MOUSE"), _slider(0.05, 1.0, 0.01, float(Settings.get_value("controls", "mouse_sensitivity")),
		func(v: float) -> void: Settings.set_value("controls", "mouse_sensitivity", v)))

	var inv := CheckButton.new()
	inv.button_pressed = bool(Settings.get_value("controls", "invert_y"))
	inv.toggled.connect(func(on: bool) -> void: Settings.set_value("controls", "invert_y", on))
	_row(grid, tr("OPT_INVERT_Y"), inv)

	var lang := OptionButton.new()
	lang.add_item("Español")
	lang.add_item("English")
	lang.selected = 1 if str(Settings.get_value("game", "locale")) == "en" else 0
	lang.item_selected.connect(func(i: int) -> void:
		Settings.set_value("game", "locale", "en" if i == 1 else "es")
		_reload_for_language.call_deferred())
	_row(grid, tr("OPT_LANGUAGE"), lang)

	var ev := CheckButton.new()
	ev.button_pressed = bool(Settings.get_value("game", "evaluator_mode"))
	ev.tooltip_text = tr("OPT_EVALUATOR_HINT")
	ev.toggled.connect(func(on: bool) -> void: Settings.set_value("game", "evaluator_mode", on))
	_row(grid, tr("OPT_EVALUATOR"), ev)

	vb.add_child(_button(tr("OPT_CONTROLS"), _show.bind(&"controls")))
	vb.add_child(_button(tr("PAUSE_BACK"), _options_back))
	return page


func _controls_page() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var cp := ControlsPage.new()
	cp.back_requested.connect(_show.bind(&"options"))
	panel.add_child(cp)
	return center


func _load_page() -> Control:
	var page := _page(tr("PAUSE_LOAD"), [])
	var vb: VBoxContainer = page.get_meta("content")
	_load_list = VBoxContainer.new()
	vb.add_child(_load_list)
	vb.add_child(_button(tr("PAUSE_BACK"), _show.bind(&"main")))
	return page


func _refresh_load_list() -> void:
	for c in _load_list.get_children():
		c.queue_free()
	var slots := SaveManager.list_slots()
	if slots.is_empty():
		_load_list.add_child(SpatiumTheme.label(tr("LOAD_NONE"), 17, &"body", 450, SpatiumTheme.TEXT_DIM))
		return
	for info: Dictionary in slots:
		var mins := int(float(info.playtime_seconds) / 60.0)
		var text := "%s   ·   %s   ·   %d min" % [String(info.slot).capitalize(), str(info.saved_at).replace("T", " ").left(16), mins]
		_load_list.add_child(_button(text, _on_load.bind(String(info.slot))))


func _row(grid: GridContainer, text: String, control: Control) -> void:
	var l := SpatiumTheme.label(text, 17)
	grid.add_child(l)
	control.custom_minimum_size.x = 220
	grid.add_child(control)


func _slider(min_v: float, max_v: float, step: float, value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(cb)
	return s


## Vuelve al menú principal sin cerrar el juego (recarga la escena de la partida).
func _to_main_menu(save_first: bool) -> void:
	if save_first:
		SaveManager.save_slot(MANUAL_SLOT)
	visible = false
	get_tree().paused = false
	IntroDirector.return_to_menu = true
	get_tree().reload_current_scene.call_deferred()


## Los carteles y pantallas 3D se arman al cargar el mundo: para que todo quede en
## el idioma nuevo se recarga la escena (desde el menú, vuelve al menú; en partida,
## se guarda y se retoma en el mismo lugar).
func _reload_for_language() -> void:
	if _menu_return.is_null() and _session:
		SaveManager.save_slot("autosave")
		IntroDirector.resume_slot = "autosave"
	else:
		IntroDirector.return_to_menu = true
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


func _rebuild() -> void:
	for c in _root.get_children():
		c.queue_free()
	_root.queue_free()
	_pages.clear()
	_build()
	_show(&"options")


# --- Acciones ---------------------------------------------------------------

func _on_save() -> void:
	SaveManager.save_slot(MANUAL_SLOT)
	_close()


func _on_load(slot: String) -> void:
	if SaveManager.load_slot(slot) == OK:
		_close()
