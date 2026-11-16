class_name RadioPanel
extends CanvasLayer
## Radio de Control de misión: muestra quién habla, el texto (se escribe mientras
## suena) y una onda animada; reproduce la voz grabada en el idioma elegido
## (inglés por defecto, español si el juego está en español). Los mensajes se encolan.
##
## Uso: RadioPanel.say("dust")  (los textos están en data/events/radio_lines.json)

const LINES := "res://data/events/radio_lines.json"
const VOICE_DIR := "res://assets/audio/voice/"

static var _lines: Dictionary = {}

var _queue: Array[String] = []
var _panel: PanelContainer
var _text: Label
var _wave: Control
var _voice: AudioStreamPlayer
var _left := 0.0
var _total := 1.0
var _full := ""
var _t := 0.0


static func lines() -> Dictionary:
	if _lines.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES))
		if d is Dictionary:
			_lines = (d as Dictionary).get("lines", {})
	return _lines


static func lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"


static func text_of(id: String) -> String:
	return String((lines().get(id, {}) as Dictionary).get(lang(), id))


static func voice_of(id: String) -> AudioStream:
	var p := VOICE_DIR + "%s_%s.wav" % [id, lang()]
	return load(p) as AudioStream if ResourceLoader.exists(p) else null


## Encola un mensaje de radio (desde cualquier sistema).
static func say(id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var p := tree.get_first_node_in_group(&"radio") as RadioPanel if tree else null
	if p:
		p._queue.append(id)


func _ready() -> void:
	add_to_group(&"radio")
	add_to_group(&"session_ui")
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"UI"
	add_child(_voice)
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SpatiumTheme.get_theme()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(SpatiumTheme.ORANGE, Color(0.03, 0.05, 0.08, 0.88)))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_top = 170
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	_panel.add_child(hb)
	_wave = Control.new()
	_wave.custom_minimum_size = Vector2(70, 70)
	_wave.draw.connect(_draw_badge)
	hb.add_child(_wave)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	vb.add_child(SpatiumTheme.label(tr("RADIO_FROM"), 13, &"mono", 600, SpatiumTheme.ORANGE))
	_text = SpatiumTheme.label("", 17, &"body", 500)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 540
	vb.add_child(_text)


func _process(delta: float) -> void:
	_t += delta
	if _left > 0.0:
		if not get_tree().paused:
			_left -= delta
		var shown := clampf(1.0 - (_left - 1.0) / maxf(_total - 1.0, 0.1), 0.0, 1.0)
		_text.visible_ratio = shown
		_wave.queue_redraw()
		if _left <= 0.0:
			var tw := create_tween()
			tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void: _panel.visible = false)
	elif not _queue.is_empty() and not get_tree().paused:
		_play(_queue.pop_front())


func _play(id: String) -> void:
	_full = text_of(id)
	_text.text = _full
	_text.visible_ratio = 0.0
	var st := voice_of(id)
	_voice.stream = st
	if st:
		_voice.play()
	_total = (st.get_length() if st else 2.0 + _full.length() * 0.05) + 1.6
	_left = _total
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)


func _draw_badge() -> void:
	var c := Vector2(35, 35)
	_wave.draw_circle(c, 32, Color(1.0, 0.54, 0.24, 0.15))
	_wave.draw_arc(c, 32, 0, TAU, 40, SpatiumTheme.ORANGE, 2.0, true)
	var speaking := _voice.playing
	for i in 7:
		var x := 14.0 + i * 7.0
		var h := 4.0 + (absf(sin(_t * 9.0 + i * 1.3)) * 18.0 if speaking else 2.0)
		_wave.draw_line(Vector2(x, c.y - h * 0.5), Vector2(x, c.y + h * 0.5), SpatiumTheme.ORANGE, 3.0)
