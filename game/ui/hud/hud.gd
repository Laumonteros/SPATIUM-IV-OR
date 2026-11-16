class_name Hud
extends CanvasLayer
## HUD del visor: indicación de interacción, carga del traje, avisos y
## marcadores de recursos detectados por el escáner.

const MARKER_RANGE := 220.0
const TYPE_COLORS := {
	&"regolith": Color(0.85, 0.82, 0.76),
	&"iron": Color(0.62, 0.68, 0.78),
	&"water_ice": Color(0.55, 0.85, 1.0),
	&"geo_sample": Color(1.0, 0.62, 0.32),
}

var _player: Player
var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_text: Label
var _cargo_title: Label
var _cargo_bar: ProgressBar
var _cargo_list: VBoxContainer
var _toasts: VBoxContainer
var _hint: Label
var _markers: Control
var _marker_nodes: Dictionary = {}
var _notify_sfx: AudioStreamPlayer
var _vital_bars: Dictionary = {}
var _vital_labels: Dictionary = {}
var _shelter_label: Label
var _base_label: Label
var _build_panel: PanelContainer
var _build_list: VBoxContainer
var _build_reason: Label
var _suit: SuitStatus
var _builder: BuildSystem
var _net: BaseNetwork
var _rad: RadiationSystem
var _rad_label: Label
var _rad_banner: Label
var _flash_layer: Control
var _toolbar: ToolBar
var _celestial: CelestialInfo


func _ready() -> void:
	add_to_group(&"session_ui")
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SpatiumTheme.get_theme()
	add_child(root)
	_build_visor(root)
	_markers = Control.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_markers)
	_build_prompt(root)
	_build_cargo(root)
	_build_toasts(root)
	_build_hint(root)
	_build_vitals(root)
	_build_base_panel(root)
	_build_build_panel(root)
	_rad_banner = SpatiumTheme.label("", 24, &"title", 700, SpatiumTheme.RED)
	_rad_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_rad_banner.offset_top = 215
	_rad_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_rad_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rad_banner.visible = false
	root.add_child(_rad_banner)
	_build_toolbar(root)
	_flash_layer = Control.new()
	_flash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash_layer)
	_notify_sfx = AudioStreamPlayer.new()
	_notify_sfx.bus = &"UI"
	if ResourceLoader.exists("res://assets/audio/sfx/ui_notify.wav"):
		_notify_sfx.stream = load("res://assets/audio/sfx/ui_notify.wav")
	add_child(_notify_sfx)
	EventBus.notification_requested.connect(_toast)
	EventBus.resource_collected.connect(_on_collected)
	EventBus.scan_completed.connect(_on_scan)
	EventBus.game_saved.connect(func(_s: String) -> void: _toast(tr("SAVE_OK"), &"info"))
	EventBus.game_loaded.connect(func(_s: String) -> void: _toast(tr("LOAD_OK"), &"info"))
	EventBus.save_failed.connect(func(_s: String, _r: String) -> void: _toast(tr("SAVE_FAILED"), &"alert"))
	EventBus.pause_changed.connect(func(p: bool) -> void: visible = not p)


func bind_session(session: GameSession) -> void:
	_player = session.player
	if _toolbar:
		_toolbar.bind(_player)
		_celestial.bind(_player)
	_player.interactor.focus_changed.connect(_on_focus)
	_player.inventory.changed.connect(_on_inventory_changed)
	_refresh_cargo()
	_suit = _player.get_node_or_null("SuitStatus") as SuitStatus
	if _suit:
		_suit.vitals_changed.connect(_refresh_vitals)
		_suit.sheltered_changed.connect(_on_sheltered)
		_refresh_vitals()
	_builder = _player.get_node_or_null("BuildSystem") as BuildSystem
	if _builder:
		_builder.mode_changed.connect(_on_build_mode)
		_builder.selection_changed.connect(_on_build_selection)
		_builder.validity_changed.connect(_on_build_validity)
	_net = get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	if _net:
		_net.changed.connect(_refresh_base)
		_refresh_base()
	_rad = get_tree().get_first_node_in_group(&"radiation_system") as RadiationSystem
	if _rad:
		_rad.dose_changed.connect(_on_dose)
	EventBus.vital_alert.connect(_on_vital_alert)
	EventBus.player_rescued.connect(_on_rescued)


func _process(_delta: float) -> void:
	if _player == null:
		return
	_update_markers()
	_update_radiation_banner()


# --- Construcción -----------------------------------------------------------

func _build_visor(root: Control) -> void:
	# Viñeta sutil del visor del casco
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.25;
	float v = smoothstep(0.85, 1.55, length(p));
	COLOR = vec4(0.0, 0.01, 0.02, v * 0.55);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	root.add_child(vig)


func _build_prompt(root: Control) -> void:
	_prompt = PanelContainer.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -215
	_prompt.offset_bottom = -165
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(SpatiumTheme.ORANGE))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_prompt.add_child(hb)
	var key_panel := PanelContainer.new()
	var ksb := SpatiumTheme.panel_style(SpatiumTheme.ORANGE, Color(1.0, 0.54, 0.24, 0.9))
	ksb.content_margin_left = 10
	ksb.content_margin_right = 10
	ksb.content_margin_top = 2
	ksb.content_margin_bottom = 2
	key_panel.add_theme_stylebox_override("panel", ksb)
	_prompt_key = SpatiumTheme.label("E", 18, &"mono", 700, Color(0.05, 0.05, 0.05))
	key_panel.add_child(_prompt_key)
	hb.add_child(key_panel)
	_prompt_text = SpatiumTheme.label("", 19, &"title", 600)
	hb.add_child(_prompt_text)
	_prompt.visible = false
	root.add_child(_prompt)


func _build_cargo(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300
	panel.offset_right = -28
	panel.offset_top = 28
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	_cargo_title = SpatiumTheme.label("", 15, &"mono", 600, SpatiumTheme.CYAN)
	vb.add_child(_cargo_title)
	_cargo_bar = ProgressBar.new()
	_cargo_bar.custom_minimum_size = Vector2(0, 6)
	_cargo_bar.show_percentage = false
	vb.add_child(_cargo_bar)
	_cargo_list = VBoxContainer.new()
	_cargo_list.add_theme_constant_override("separation", 2)
	vb.add_child(_cargo_list)
	root.add_child(panel)


func _build_toasts(root: Control) -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_toasts.offset_left = 28
	_toasts.offset_bottom = -240
	_toasts.offset_top = -520
	_toasts.offset_right = 560
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)


func _build_hint(root: Control) -> void:
	_hint = SpatiumTheme.label(tr("CONTROLS_HINT"), 15, &"body", 500, SpatiumTheme.TEXT_DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_top = 22
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)
	var tw := create_tween()
	tw.tween_interval(30.0)
	tw.tween_property(_hint, "modulate:a", 0.0, 2.0)


func _build_vitals(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 28
	panel.offset_bottom = -28
	panel.offset_top = -180
	panel.offset_right = 330
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)
	for k: StringName in SuitStatus.VITALS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l := SpatiumTheme.label(tr("VITAL_" + String(k).to_upper()), 15, &"title", 600)
		name_l.custom_minimum_size.x = 82
		row.add_child(name_l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(130, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = 100.0
		row.add_child(bar)
		var val := SpatiumTheme.label("100%", 15, &"mono", 600)
		val.custom_minimum_size.x = 48
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		vb.add_child(row)
		_vital_bars[k] = bar
		_vital_labels[k] = val
	_rad_label = SpatiumTheme.label("", 14, &"mono", 600, SpatiumTheme.TEXT_DIM)
	vb.add_child(_rad_label)
	_shelter_label = SpatiumTheme.label(tr("HUD_SHELTERED"), 14, &"body", 600, SpatiumTheme.CYAN)
	_shelter_label.visible = false
	vb.add_child(_shelter_label)
	root.add_child(panel)


func _build_base_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300
	panel.offset_right = -28
	panel.offset_top = 250
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	vb.add_child(SpatiumTheme.label(tr("BASE_TITLE"), 15, &"mono", 700, SpatiumTheme.ORANGE))
	_base_label = SpatiumTheme.label("", 14, &"mono", 500)
	vb.add_child(_base_label)
	root.add_child(panel)


func _build_build_panel(root: Control) -> void:
	_build_panel = PanelContainer.new()
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_build_panel.offset_top = -340
	_build_panel.offset_bottom = -190
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_panel.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(SpatiumTheme.ORANGE))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_build_panel.add_child(vb)
	vb.add_child(SpatiumTheme.label(tr("BUILD_MODE"), 16, &"title", 700, SpatiumTheme.ORANGE))
	_build_list = VBoxContainer.new()
	_build_list.add_theme_constant_override("separation", 2)
	vb.add_child(_build_list)
	_build_reason = SpatiumTheme.label("", 14, &"body", 600, SpatiumTheme.RED)
	vb.add_child(_build_reason)
	vb.add_child(SpatiumTheme.label(tr("BUILD_HELP"), 13, &"body", 450, SpatiumTheme.TEXT_DIM))
	_build_panel.visible = false
	root.add_child(_build_panel)


func _on_inventory_changed(_id: StringName, _a: int, _d: int) -> void:
	_refresh_cargo()
	_refresh_build()


func _on_sheltered(on: bool) -> void:
	_shelter_label.visible = on


func _on_build_mode(on: bool) -> void:
	_build_panel.visible = on
	_refresh_build()


func _on_build_selection(_d: BuildableDef) -> void:
	_refresh_build()


func _on_build_validity(ok: bool, why: String) -> void:
	_build_reason.text = why
	_build_reason.visible = not ok and why != ""


func _on_rescued() -> void:
	_toast(tr("HUD_RESCUED"), &"alert")


func _refresh_vitals() -> void:
	for k: StringName in SuitStatus.VITALS:
		var v := _suit.get_value(k)
		var bar: ProgressBar = _vital_bars[k]
		bar.value = v
		var col := SpatiumTheme.CYAN if v > 25.0 else (SpatiumTheme.AMBER if v > 10.0 else SpatiumTheme.RED)
		var fill := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill.bg_color = col
		bar.add_theme_stylebox_override("fill", fill)
		var lab: Label = _vital_labels[k]
		lab.text = "%d%%" % int(round(v))
		lab.add_theme_color_override("font_color", col if v <= 25.0 else SpatiumTheme.TEXT)


func _refresh_base() -> void:
	var n := _net
	var lines: PackedStringArray = [
		"%s  %+.1f kW  (%.1f / %.1f)" % [tr("BASE_POWER"), n.production_kw - n.supplied_kw, n.production_kw, n.demand_kw],
		"%s %5.1f / %.1f kWh" % [tr("BASE_STORED"), n.stored_kwh, n.capacity_kwh],
		"%s %5.2f kg" % [tr("BASE_O2"), n.oxygen_kg],
		"%s %5.1f L" % [tr("BASE_WATER"), n.water_l],
		"%s %d" % [tr("BASE_RATIONS"), n.rations],
	]
	_base_label.text = "\n".join(lines)


func _refresh_build() -> void:
	if _builder == null or not _builder.active:
		return
	for c in _build_list.get_children():
		c.queue_free()
	for i in _builder.options.size():
		var d := _builder.options[i]
		var sel := i == _builder.selected
		var afford := _builder.can_afford(d)
		var col := SpatiumTheme.ORANGE if sel else (SpatiumTheme.TEXT if afford else SpatiumTheme.TEXT_DIM)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(SpatiumTheme.label("%s%d" % ["> " if sel else "  ", i + 1], 15, &"mono", 700, col))
		var nm := SpatiumTheme.label(d.get_display_name(), 16, &"title", 600 if sel else 500, col)
		nm.custom_minimum_size.x = 210
		row.add_child(nm)
		var colony := get_tree().get_first_node_in_group(&"colony") as Colony
		var kit := colony != null and colony.has_kit(d.id)
		row.add_child(SpatiumTheme.label(tr("HUD_KIT_AVAILABLE") if kit else d.cost_text(), 14, &"mono", 500, SpatiumTheme.AMBER if kit else (SpatiumTheme.CYAN if afford else SpatiumTheme.RED)))
		_build_list.add_child(row)
		if sel:
			_build_list.add_child(SpatiumTheme.label("      " + tr(d.function_key), 13, &"body", 450, SpatiumTheme.TEXT_DIM))


func _on_vital_alert(vital: StringName, level: StringName) -> void:
	var vname := tr("VITAL_" + String(vital).to_upper())
	if level == &"critical":
		_toast(tr("VITAL_ALERT_CRITICAL") % vname.to_upper(), &"alert")
	else:
		_toast(tr("VITAL_ALERT_LOW") % vname, &"warning")


# --- Actualizaciones --------------------------------------------------------

func _on_focus(target: Interactable) -> void:
	_prompt.visible = target != null
	if target:
		_prompt_key.text = InputConfig.get_key_label(&"interact")
		_prompt_text.text = target.get_prompt()


func _refresh_cargo() -> void:
	var inv := _player.inventory
	var mass := inv.get_total_mass()
	_cargo_title.text = "%s  %5.1f / %3.0f kg" % [tr("HUD_CARGO").to_upper(), mass, inv.max_mass_kg]
	_cargo_bar.max_value = inv.max_mass_kg
	_cargo_bar.value = mass
	for c in _cargo_list.get_children():
		c.queue_free()
	var items := inv.get_all()
	for id: StringName in items:
		var def := DataRegistry.get_def(id) as ItemDef
		var row := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = ResourceColors.of(id)
		row.add_child(dot)
		var name_l := SpatiumTheme.label(def.get_display_name() if def else String(id), 16)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(SpatiumTheme.label(str(items[id]), 16, &"mono", 600))
		_cargo_list.add_child(row)


func _toast(text: String, kind: StringName = &"info") -> void:
	var color: Color = {&"warning": SpatiumTheme.AMBER, &"alert": SpatiumTheme.RED}.get(kind, SpatiumTheme.CYAN)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(color))
	panel.add_child(SpatiumTheme.label(text, 17, &"body", 500))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(panel)
	if _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.8)
	tw.tween_callback(panel.queue_free)
	if kind != &"info" and _notify_sfx.stream:
		_notify_sfx.play()


func _on_collected(item_id: StringName, amount: int) -> void:
	var def := DataRegistry.get_def(item_id) as ItemDef
	_toast(tr("HUD_COLLECTED") % [amount, def.get_display_name() if def else String(item_id)], &"info")


func _on_scan(found: Array) -> void:
	if found.is_empty():
		_toast(tr("HUD_SCAN_NONE"), &"info")
	else:
		# resumen por tipo: "Escaneo: 14 Regolito · 2 Hierro (ilmenita) · 1 Hielo de agua"
		var counts := {}
		for d: ResourceDeposit in found:
			counts[d.item_id] = int(counts.get(d.item_id, 0)) + 1
			if d.bonus_item != &"":
				counts[d.bonus_item] = int(counts.get(d.bonus_item, 0)) + 1
		var parts: Array[String] = []
		for id: StringName in counts:
			parts.append("%d %s" % [counts[id], ResourceColors.item_name(id)])
		_toast(tr("HUD_SCAN_SUMMARY") % " · ".join(parts), &"info")
		if _notify_sfx.stream:
			_notify_sfx.play()


func _update_markers() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var seen := {}
	var origin := _player.global_position
	for node in get_tree().get_nodes_in_group(&"resource_deposit"):
		var dep := node as ResourceDeposit
		if dep == null or not dep.discovered or dep.is_depleted():
			continue
		var pos := dep.global_position + Vector3(0, 1.2, 0)
		var dist := origin.distance_to(dep.global_position)
		var max_d := MARKER_RANGE if dep.scannable or dep.bonus_item != &"" else MARKER_RANGE * 0.45
		if dist > max_d or dist < 2.5 or cam.is_position_behind(pos):
			var old: Control = _marker_nodes.get(dep)
			if old:
				old.visible = false
			continue
		var m: Control = _marker_nodes.get(dep)
		if m == null:
			m = _make_marker(dep)
			_markers.add_child(m)
			_marker_nodes[dep] = m
		m.visible = true
		m.position = cam.unproject_position(pos) - Vector2(9, 9)
		(m.get_child(0) as Label).text = "%s · %d m" % [ResourceColors.item_name(dep.item_id), int(dist)]
		m.queue_redraw()
		m.modulate.a = clampf(1.2 - dist / MARKER_RANGE, 0.35, 1.0)
		m.visible = true
		seen[dep] = true
	for dep: Variant in _marker_nodes.keys():
		if not seen.has(dep):
			var m: Control = _marker_nodes[dep]
			if not is_instance_valid(dep):
				m.queue_free()
				_marker_nodes.erase(dep)
			else:
				m.visible = false


## Marcador de un depósito escaneado: ícono con la forma y el color del recurso
## (y un anillo si además da una muestra geológica), nombre y distancia.
func _make_marker(dep: ResourceDeposit) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := ResourceColors.of(dep.item_id)
	var l := SpatiumTheme.label("", 12, &"mono", 600, color)
	l.position = Vector2(-40, 22)
	l.size = Vector2(98, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	c.add_child(l)
	var id := dep.item_id
	var bonus := dep.bonus_item
	c.draw.connect(func() -> void:
		var p := Vector2(9, 9)
		c.draw_circle(p, 13.0, Color(0.02, 0.04, 0.07, 0.45))
		ResourceColors.draw_icon(c, p, 7.0, id)
		if bonus != &"":
			c.draw_arc(p, 12.0, 0.0, TAU, 24, ResourceColors.of(bonus), 2.0, true))
	return c


func _on_dose(total: float, rate: float) -> void:
	var es := TranslationServer.get_locale().begins_with("es")
	_rad_label.text = ("Radiación %.3f mSv · %d µSv/h" if es else "Radiation %.3f mSv · %d µSv/h") % [total, int(rate)]
	var col := SpatiumTheme.TEXT_DIM if rate < 500.0 else (SpatiumTheme.AMBER if rate < 5000.0 else SpatiumTheme.RED)
	_rad_label.add_theme_color_override("font_color", col)


func _update_radiation_banner() -> void:
	if _rad == null:
		return
	var es := TranslationServer.get_locale().begins_with("es")
	match _rad.phase:
		&"warning":
			_rad_banner.visible = true
			_rad_banner.text = ("⚠ PROTONES SOLARES EN %d s · BUSCÁ REFUGIO" if es else "⚠ SOLAR PROTONS IN %d s · TAKE SHELTER") % int(ceil(_rad.countdown))
			_rad_banner.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		&"storm":
			_rad_banner.visible = true
			var sh := _rad.shield_factor() < 1.0
			var state := ("blindado" if es else "shielded") if sh else ("¡EXPUESTO!" if es else "EXPOSED!")
			_rad_banner.text = ("TORMENTA SOLAR EN CURSO · %s" if es else "SOLAR STORM IN PROGRESS · %s") % state
			_rad_banner.add_theme_color_override("font_color", SpatiumTheme.AMBER if sh else SpatiumTheme.RED)
			# Destellos de rayos cósmicos: los astronautas del Apollo reportaron ver
			# destellos de luz (partículas que atraviesan la retina).
			if randf() < 0.25 * (1.0 if not sh else 0.2):
				_flash()
		_:
			_rad_banner.visible = false


func _flash() -> void:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.9)
	r.size = Vector2(randf_range(2, 5), randf_range(2, 5))
	r.position = Vector2(randf() * _flash_layer.size.x, randf() * _flash_layer.size.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.18)
	tw.tween_callback(r.queue_free)


## Barra de herramientas (mano, escáner, binoculares), abajo al centro.
func _build_toolbar(root: Control) -> void:
	_toolbar = ToolBar.new()
	_toolbar.name = "ToolBar"
	root.add_child(_toolbar)
	_celestial = CelestialInfo.new()
	_celestial.name = "CelestialInfo"
	root.add_child(_celestial)
