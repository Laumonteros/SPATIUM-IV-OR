class_name ResourceColors
extends RefCounted
## Código visual común de los recursos (escáner, marcadores, minimapa, fichas, carga):
## cada recurso tiene un color y una forma propia, para reconocerlo de un vistazo.
##   regolito  arena        círculo
##   hierro    óxido        hexágono
##   hielo     celeste      gota
##   muestra   violeta      triángulo

const COLORS := {
	&"regolith": Color(0.86, 0.8, 0.62),
	&"iron": Color(0.95, 0.47, 0.3),
	&"water_ice": Color(0.45, 0.85, 1.0),
	&"geo_sample": Color(0.78, 0.56, 1.0),
	&"helium_3": Color(1.0, 0.84, 0.32),
}


static func of(item_id: StringName) -> Color:
	return COLORS.get(item_id, SpatiumTheme.CYAN)


static func item_name(item_id: StringName) -> String:
	var def := DataRegistry.get_def(item_id) as ItemDef if DataRegistry.has_def(item_id) else null
	return def.get_display_name() if def else String(item_id)


## Dibuja el ícono del recurso en `c` (un Control dentro de su _draw).
static func draw_icon(c: CanvasItem, p: Vector2, r: float, item_id: StringName, alpha := 1.0) -> void:
	var col := of(item_id)
	col.a *= alpha
	var dark := Color(0.02, 0.03, 0.05, 0.75 * alpha)
	var pts := PackedVector2Array()
	match item_id:
		&"iron":
			for i in 6:
				var a := PI / 6.0 + i * TAU / 6.0
				pts.append(p + Vector2(cos(a), sin(a)) * r)
		&"water_ice":
			pts.append(p + Vector2(0, -r * 1.25))
			for i in 9:
				var a := -0.35 + i * (PI + 0.7) / 8.0
				pts.append(p + Vector2(cos(a), sin(a)) * r * 0.82 + Vector2(0, r * 0.2))
		&"helium_3": # estrella dorada (recurso escaso y especial)
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(p + Vector2(cos(a), sin(a)) * (r * 1.25 if i % 2 == 0 else r * 0.55))
		&"geo_sample":
			for i in 3:
				var a := -PI / 2.0 + i * TAU / 3.0
				pts.append(p + Vector2(cos(a), sin(a)) * r * 1.15)
		_:
			c.draw_circle(p, r + 1.2, dark)
			c.draw_circle(p, r, col)
			return
	var outline := PackedVector2Array()
	var center := p
	for q in pts:
		outline.append(center + (q - center) * 1.0 + (q - center).normalized() * 1.2)
	c.draw_colored_polygon(outline, dark)
	c.draw_colored_polygon(pts, col)
