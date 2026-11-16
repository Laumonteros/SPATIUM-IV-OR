class_name SpatiumTheme
extends RefCounted
## Tema visual de la interfaz (biblia de arte: HUD proyectado en el visor).
## Cian para datos, naranja para la acción principal, números en monoespaciada.

const CYAN := Color("#4FD1E8")
const ORANGE := Color("#FF8A3D")
const AMBER := Color("#FFC23D")
const RED := Color("#FF4D4D")
const TEXT := Color("#E8EEF5")
const TEXT_DIM := Color(0.78, 0.84, 0.9, 0.7)
const PANEL := Color(0.03, 0.05, 0.08, 0.62)
const PANEL_BORDER := Color(0.31, 0.82, 0.91, 0.35)

const FONT_TITLE := "res://assets/fonts/Exo2-Variable.ttf"
const FONT_BODY := "res://assets/fonts/Inter-Variable.ttf"
const FONT_MONO := "res://assets/fonts/JetBrainsMono-Variable.ttf"

static var _theme: Theme
static var _fonts: Dictionary = {}


static func font(kind: StringName, weight: int = 400) -> Font:
	var key := "%s_%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var path: String = {&"title": FONT_TITLE, &"body": FONT_BODY, &"mono": FONT_MONO}.get(kind, FONT_BODY)
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	_fonts[key] = fv
	return fv


static func panel_style(border: Color = PANEL_BORDER, bg: Color = PANEL) -> StyleBoxFlat:
	# Paneles de visor: fondo oscuro translúcido, borde fino, acento a la izquierda
	# y sombra suave para despegarlos de la escena.
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(10)
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_left = 4
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.anti_aliasing = true
	sb.content_margin_left = 16
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(&"body", 450)
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	var normal := panel_style(Color(1, 1, 1, 0.1), Color(0.05, 0.08, 0.12, 0.82))
	normal.border_color = Color(1, 1, 1, 0.1)
	var hover := panel_style(CYAN, Color(0.07, 0.17, 0.22, 0.94))
	hover.border_width_left = 6
	var pressed := panel_style(ORANGE, Color(0.22, 0.12, 0.06, 0.96))
	pressed.border_width_left = 6
	var disabled := panel_style(Color(1, 1, 1, 0.05), Color(0.04, 0.05, 0.07, 0.6))
	var focus := panel_style(CYAN, Color(0, 0, 0, 0))
	focus.shadow_size = 0
	for sb in [normal, hover, pressed, disabled]:
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		sb.content_margin_left = 24
		sb.content_margin_right = 22
		sb.shadow_size = 4
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ORANGE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_font("font", "Button", font(&"title", 600))
	t.set_font_size("font_size", "Button", 20)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(1, 1, 1, 0.12)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	slider_bg.set_corner_radius_all(3)
	var slider_fill := slider_bg.duplicate() as StyleBoxFlat
	slider_fill.bg_color = CYAN
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "TooltipPanel", panel_style(CYAN, Color(0.03, 0.06, 0.1, 0.95)))

	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_font("font", "OptionButton", font(&"body", 500))
	t.set_color("font_color", "CheckButton", TEXT)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.1)
	bar_bg.set_corner_radius_all(4)
	bar_bg.anti_aliasing = true
	var bar_fill := bar_bg.duplicate() as StyleBoxFlat
	bar_fill.bg_color = CYAN
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("separation", "VBoxContainer", 8)
	_theme = t
	return t


static func label(text: String, size: int = 18, kind: StringName = &"body", weight: int = 450, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
