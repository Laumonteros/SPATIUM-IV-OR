class_name InventoryScreen
extends CanvasLayer
## Inventario (Tab): lo que lleva el traje y las reservas de la colonia.
##
## Cada recurso se muestra con su ícono (forma y color propios), cantidad, masa,
## para qué sirve, dónde se encuentra y de dónde sale el dato científico. La barra
## de carga recuerda el límite del traje: llevar más de una cosa es llevar menos de otra.

const RAW := [&"regolith", &"iron", &"water_ice", &"geo_sample", &"helium_3"]
const KIND_KEYS := ["SCI_KIND_REAL", "SCI_KIND_ADAPTED", "SCI_KIND_GAME"]

var _session: GameSession
var _root: Control
var _cards: GridContainer
var _mass_bar: ProgressBar
var _mass_label: Label
var _reserves: VBoxContainer


func _ready() -> void:
	add_to_group(&"session_ui")
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func bind_session(session: GameSession) -> void:
	_session = session
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null:
		return
	if event.is_action_pressed(&"inventory"):
		get_viewport().set_input_as_handled()
		_toggle(not visible)
	elif visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_toggle(false)


func _toggle(on: bool) -> void:
	if on == visible:
		return
	if on and get_tree().paused:
		return
	if on:
		_refresh()
		EventBus.player_action.emit(&"inventory")
	visible = on
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SpatiumTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.01, 0.03, 0.78)
	_root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	_root.add_child(margin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	margin.add_child(hb)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	hb.add_child(left)
	left.add_child(SpatiumTheme.label(tr("INV_TITLE"), 30, &"title", 700, SpatiumTheme.ORANGE))
	var mass_row := HBoxContainer.new()
	mass_row.add_theme_constant_override("separation", 12)
	left.add_child(mass_row)
	_mass_bar = ProgressBar.new()
	_mass_bar.custom_minimum_size = Vector2(320, 14)
	_mass_bar.show_percentage = false
	_mass_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mass_row.add_child(_mass_bar)
	_mass_label = SpatiumTheme.label("", 16, &"mono", 600)
	mass_row.add_child(_mass_label)
	left.add_child(SpatiumTheme.label(tr("INV_MASS_HINT"), 14, &"body", 450, SpatiumTheme.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 14)
	_cards.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_cards)

	var right := PanelContainer.new()
	right.custom_minimum_size.x = 330
	hb.add_child(right)
	_reserves = VBoxContainer.new()
	_reserves.add_theme_constant_override("separation", 10)
	right.add_child(_reserves)

	var close := SpatiumTheme.label(tr("INV_CLOSE"), 14, &"mono", 500, SpatiumTheme.TEXT_DIM)
	close.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	close.offset_left = -300
	close.offset_top = -36
	_root.add_child(close)


func _refresh() -> void:
	var inv := _session.player.inventory
	var mass := inv.get_total_mass()
	_mass_bar.max_value = inv.max_mass_kg
	_mass_bar.value = mass
	_mass_label.text = "%.1f / %d kg" % [mass, int(inv.max_mass_kg)]
	for c in _cards.get_children():
		c.queue_free()
	var ids: Array = RAW.duplicate()
	for id: StringName in inv.get_all():
		if id not in ids:
			ids.append(id)
	for id: StringName in ids:
		_cards.add_child(_card(id, inv.get_amount(id)))
	_refresh_reserves()


func _card(id: StringName, amount: int) -> Control:
	var def := DataRegistry.get_def(id) as ItemDef if DataRegistry.has_def(id) else null
	var col := ResourceColors.of(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SpatiumTheme.panel_style(Color(col, 0.55), Color(0.04, 0.07, 0.11, 0.9)))
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.modulate.a = 1.0 if amount > 0 else 0.55
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.draw.connect(func() -> void:
		icon.draw_circle(Vector2(32, 32), 30, Color(col, 0.12))
		icon.draw_arc(Vector2(32, 32), 30, 0, TAU, 40, Color(col, 0.6), 2.0, true)
		ResourceColors.draw_icon(icon, Vector2(32, 34), 15.0, id))
	hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var name_l := SpatiumTheme.label(ResourceColors.item_name(id), 19, &"title", 700, col)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var unit := def.unit_mass_kg if def else 1.0
	head.add_child(SpatiumTheme.label("× %d   (%.1f kg)" % [amount, amount * unit], 17, &"mono", 700))
	if def:
		vb.add_child(_para(tr("INV_USE") + " " + tr(def.utility_key)))
		vb.add_child(_para(tr("INV_WHERE") + " " + tr(def.location_key)))
		if def.science:
			var k := clampi(int(def.science.kind), 0, 2)
			var src := SpatiumTheme.label("%s · %s" % [tr(KIND_KEYS[k]), def.science.source_name], 12, &"mono", 500, SpatiumTheme.TEXT_DIM)
			src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(src)
	return panel


func _para(t: String) -> Label:
	var l := SpatiumTheme.label(t, 14, &"body", 450, SpatiumTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	return l


func _refresh_reserves() -> void:
	for c in _reserves.get_children():
		c.queue_free()
	_reserves.add_child(SpatiumTheme.label(tr("INV_COLONY"), 20, &"title", 700, SpatiumTheme.CYAN))
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	if net:
		_bar(tr("INV_O2"), net.oxygen_kg, net.oxygen_capacity_kg, "%.1f / %.0f kg", Color(0.55, 0.85, 1.0))
		_bar(tr("INV_WATER"), net.water_l, net.water_capacity_l, "%.1f / %.0f L", Color(0.35, 0.65, 1.0))
		_bar(tr("INV_POWER"), net.stored_kwh, maxf(net.capacity_kwh, 0.1), "%.1f / %.0f kWh", Color(1.0, 0.84, 0.26))
		_reserves.add_child(SpatiumTheme.label(tr("INV_RATIONS") % net.rations, 16, &"mono", 600))
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	if colony:
		_reserves.add_child(SpatiumTheme.label(tr("INV_RESEARCH") % colony.research_points, 16, &"mono", 600, SpatiumTheme.AMBER))
		if not colony.kits.is_empty():
			_reserves.add_child(SpatiumTheme.label(tr("INV_KITS"), 16, &"title", 600))
			for bid: String in colony.kits:
				if int(colony.kits[bid]) > 0:
					var bd := DataRegistry.get_def(StringName(bid))
					var nm := bd.get_display_name() if bd else bid
					_reserves.add_child(SpatiumTheme.label("  • %s × %d" % [nm, int(colony.kits[bid])], 15))
	var tip := SpatiumTheme.label(tr("INV_TIP"), 13, &"body", 450, SpatiumTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reserves.add_child(tip)


func _bar(label: String, v: float, maxv: float, fmt: String, col: Color) -> void:
	var row := VBoxContainer.new()
	var head := HBoxContainer.new()
	var l := SpatiumTheme.label(label, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(SpatiumTheme.label(fmt % [v, maxv], 14, &"mono", 600))
	row.add_child(head)
	var bar := ProgressBar.new()
	bar.max_value = maxv
	bar.value = v
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	_reserves.add_child(row)
