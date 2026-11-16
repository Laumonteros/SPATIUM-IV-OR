class_name CelestialInfo
extends Control
## Ficha de observación de los binoculares. Al apuntar con los binoculares a:
##   - la Tierra o un planeta (Venus, Marte, Júpiter, Saturno), o
##   - una roca (cualquier depósito recolectable),
## aparece un círculo de seguimiento que se cierra sobre el objetivo, una línea guía
## y una ficha al costado con datos reales (NASA / Lunar Sourcebook). La fase de la
## Tierra y de Venus se calcula en vivo con las direcciones del Sol y del planeta.

## Ángulo al centro de la vista (rad) desde el que se "engancha" un cuerpo del cielo.
const SKY_LOCK := 0.06
const ROCK_RANGE := 350.0
const ROCK_MASK := 1 | (1 << 2) | (1 << 3)

var _player: Player
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _alpha := 0.0
var _lock_t := 0.0
var _target: Dictionary = {}
var _rock_sheets: Dictionary = {}


func bind(p: Player) -> void:
	_player = p


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_rock_sheets()


func _es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _load_rock_sheets() -> void:
	var f := FileAccess.open("res://data/colony/rock_sheets.json", FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for sh: Dictionary in (data as Dictionary).get("sheets", []):
			if sh.has("unlock"):
				_rock_sheets[String(sh.unlock)] = sh


func _find_sky() -> void:
	var region := get_tree().get_first_node_in_group(&"world_region")
	if region == null:
		return
	var env := region.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env and env.environment and env.environment.sky:
		_sky = env.environment.sky.sky_material as ShaderMaterial
	for n in region.find_children("*", "DirectionalLight3D", true, false):
		_sun = n as DirectionalLight3D
		break


## Parámetro del cielo (los que quedan en su valor por defecto vuelven como null).
func _param(n: String, fallback: float) -> float:
	var v: Variant = _sky.get_shader_parameter(n)
	return float(v) if v != null else fallback


func _body_dir(b: Dictionary) -> Vector3:
	if String(b.get("sky", "")) == "earth":
		return (_sky.get_shader_parameter("planet_direction") as Vector3).normalized()
	return CelestialCatalog.dir_from(float(b.el), float(b.az))


func _body_radius(b: Dictionary) -> float:
	if String(b.get("sky", "")) == "earth":
		return _param("planet_angular_radius", 0.0166) * _param("planet_scale", 2.4)
	return float(b.get("radius_rad", 0.002)) * (2.3 if String(b.id) == "saturn" else 1.0)


func _process(delta: float) -> void:
	var found: Dictionary = {}
	if _player and _player.binoculars_active and not get_tree().paused:
		if _sky == null:
			_find_sky()
		found = _pick_target()
	var same: bool = not found.is_empty() and not _target.is_empty() and str(found.get("key")) == str(_target.get("key"))
	if found.is_empty():
		_alpha = move_toward(_alpha, 0.0, delta * 6.0)
		if _alpha <= 0.0:
			_target = {}
	else:
		if not same:
			_lock_t = 0.0
		_target = found
		_alpha = move_toward(_alpha, 1.0, delta * 3.0)
		var was := _lock_t
		_lock_t += delta
		if was < 0.6 and _lock_t >= 0.6:
			EventBus.player_action.emit(&"observe")
	queue_redraw()


func _pick_target() -> Dictionary:
	var cam := _player.camera_rig.get_camera()
	var from := cam.global_position
	var fwd := -cam.global_basis.z
	# 1) una roca en la mira
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * ROCK_RANGE, ROCK_MASK)
	q.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var dep := _deposit_of(hit.collider as Node)
		if dep and not dep.is_depleted():
			return {"key": dep.get_instance_id(), "kind": &"rock", "node": dep}
		if (hit.position as Vector3).distance_to(from) < 60.0:
			return {} # algo cercano tapa la vista
	# 2) un cuerpo del cielo cerca del centro
	if _sky == null:
		return {}
	var best: Dictionary = {}
	var best_ang := INF
	for b: Dictionary in CelestialCatalog.bodies():
		var ang := fwd.angle_to(_body_dir(b))
		if ang < maxf(SKY_LOCK, _body_radius(b) * 3.0) and ang < best_ang:
			best_ang = ang
			best = b
	if best.is_empty():
		return {}
	return {"key": String(best.id), "kind": &"sky", "body": best}


func _deposit_of(n: Node) -> ResourceDeposit:
	while n:
		if n is ResourceDeposit:
			return n as ResourceDeposit
		n = n.get_parent()
	return null


## Fracción iluminada de un cuerpo visto desde la Luna (0-1).
func _illuminated_fraction(dir: Vector3, dist_au: float = 0.0) -> float:
	if _sun == null:
		return 1.0
	var sun := _sun.global_basis.z.normalized() # la luz apunta hacia -Z
	var to_sun := (sun - dir * dist_au).normalized() # desde el cuerpo (Sol a 1 UA)
	var phase := (-dir).angle_to(to_sun)
	return (1.0 + cos(phase)) * 0.5


# --- Dibujo ---------------------------------------------------------------------

func _draw() -> void:
	if _alpha <= 0.0 or _target.is_empty() or _player == null:
		return
	var cam := _player.camera_rig.get_camera()
	var center: Vector2
	var r: float
	var info: Dictionary
	if _target.kind == &"rock":
		var dep := _target.node as ResourceDeposit
		if not is_instance_valid(dep):
			return
		var pos := dep.global_position + Vector3(0, 0.4 * dep.scale.y, 0)
		if cam.is_position_behind(pos):
			return
		center = cam.unproject_position(pos)
		var edge := cam.unproject_position(pos + cam.global_basis.x * maxf(0.6, 0.9 * dep.scale.x))
		r = clampf(center.distance_to(edge), 24.0, size.y * 0.3)
		info = _rock_info(dep, cam.global_position.distance_to(dep.global_position))
	else:
		if _sky == null:
			return
		var b: Dictionary = _target.body
		var dir := _body_dir(b)
		var world := cam.global_position + dir * 1000.0
		if cam.is_position_behind(world):
			return
		center = cam.unproject_position(world)
		var e := cam.unproject_position(cam.global_position + (dir + cam.global_basis.x * tan(_body_radius(b))).normalized() * 1000.0)
		r = maxf(center.distance_to(e) * 1.35, 22.0)
		info = _sky_info(b, dir)
	_draw_lock(center, r, info)


func _sky_info(b: Dictionary, dir: Vector3) -> Dictionary:
	var es := _es()
	var rows: Array = []
	var phase := "%d %%" % roundi(_illuminated_fraction(dir, float(b.get("dist_au", 0.0))) * 100.0)
	for row: Array in b.get("rows", []):
		rows.append([String(row[0] if es else row[1]), String(row[2] if es else row[3]).replace("{phase}", phase)])
	return {
		"title": String(b.get("name_es" if es else "name_en", "")),
		"sub": tr("EARTH_INFO_SUB"),
		"rows": rows,
		"note": String(b.get("note_es" if es else "note_en", "")),
		"source": String(b.get("source", "")),
		"color": Color(String(b.get("color", "#6AB0FF"))),
	}


func _rock_info(dep: ResourceDeposit, dist: float) -> Dictionary:
	var es := _es()
	var item := dep.get_item_def()
	var item_name := tr(item.name_key) if item else String(dep.item_id)
	var gives := item_name
	if dep.bonus_item != &"":
		gives += " + " + ResourceColors.item_name(dep.bonus_item)
	var sheet: Dictionary = _rock_sheets.get(String(dep.item_id), {})
	var comp := ""
	var parts: Array = sheet.get("composition", [])
	for i in mini(3, parts.size()):
		comp += ("  " if i > 0 else "") + "%s %s %%" % [parts[i][0], str(parts[i][1]).replace(".", "," if es else ".")]
	var rarity := int(sheet.get("rarity", 1))
	var rows: Array = [
		[tr("ROCK_INFO_GIVES"), gives],
		[tr("ROCK_INFO_DISTANCE"), "%d m" % int(dist)],
		[tr("ROCK_INFO_LEFT"), "%d × %d" % [maxi(dep.remaining, 0), dep.yield_per_harvest]],
		[tr("ROCK_INFO_RARITY"), "★".repeat(rarity) + "☆".repeat(maxi(0, 4 - rarity))],
		[tr("ROCK_INFO_SCANNED"), tr("COMMON_YES") if dep.discovered else tr("COMMON_NO")],
	]
	var sci: Dictionary = sheet.get("science", {})
	return {
		"title": String(sheet.get("name_es" if es else "name_en", item_name)),
		"sub": tr("ROCK_INFO_SUB"),
		"rows": rows,
		"extra": (tr("ROCK_INFO_COMPOSITION") + ":  " + comp) if comp != "" else "",
		"note": String(sheet.get("utility_es" if es else "utility_en", "")),
		"source": String(sci.get("source", "")),
		"color": ResourceColors.of(dep.item_id),
	}


func _row_wraps(font: Font, mono: Font, row: Array, inner: float) -> bool:
	var lw := font.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var vw := mono.get_string_size(String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	return lw + vw + 12.0 > inner


func _draw_lock(c: Vector2, r: float, info: Dictionary) -> void:
	var a := _alpha
	var col: Color = info.color
	var accent := Color(col.r, col.g, col.b, 0.95 * a)
	var k := clampf(_lock_t / 0.6, 0.0, 1.0)
	var rr := r * (1.6 - 0.6 * k)
	draw_arc(c, rr, 0.0, TAU, 64, accent, 2.0, true)
	for i in 4:
		var t0 := i * PI * 0.5 + PI * 0.25 + _lock_t * 0.4
		draw_arc(c, rr + 7.0, t0 - 0.22, t0 + 0.22, 12, accent, 3.0, true)
	var box_w := 320.0
	var right := c.x + rr + 60.0 + box_w < size.x
	var sx := 1.0 if right else -1.0
	var p0 := c + Vector2(sx * rr * 0.72, -rr * 0.72)
	var p1 := p0 + Vector2(sx * 40.0, -40.0)
	var box_x := p1.x + 10.0 if right else p1.x - 10.0 - box_w
	draw_line(p0, p1, accent, 1.5, true)
	draw_line(p1, Vector2(box_x if right else box_x + box_w, p1.y), accent, 1.5, true)
	if k < 1.0:
		return
	var title_font := SpatiumTheme.font(&"title", 700)
	var font := SpatiumTheme.font(&"body", 500)
	var mono := SpatiumTheme.font(&"mono", 600)
	var rows: Array = info.rows
	var line_h := 22.0
	var inner := box_w - 30.0
	var note: String = info.note
	var note_h := 0.0
	if note != "":
		note_h = font.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, inner, 12, 4).y
	var extra: String = info.get("extra", "")
	var src: String = info.source
	var src_h := mono.get_multiline_string_size(src, HORIZONTAL_ALIGNMENT_LEFT, inner, 10, 2).y
	var two_line := 0
	for row: Array in rows:
		if _row_wraps(font, mono, row, inner):
			two_line += 1
	var h := 58.0 + (rows.size() + two_line) * line_h + (20.0 if extra != "" else 0.0) + 10.0 + note_h + src_h + 14.0
	var top := clampf(p1.y - 22.0, 8.0, maxf(8.0, size.y - h - 8.0))
	var box := Rect2(Vector2(box_x, top), Vector2(box_w, h))
	var sb := SpatiumTheme.panel_style(accent, Color(0.03, 0.06, 0.1, 0.8 * a))
	draw_style_box(sb, box)
	var x := box.position.x + 16.0
	var y := box.position.y + 28.0
	draw_string(title_font, Vector2(x, y), String(info.title), HORIZONTAL_ALIGNMENT_LEFT, inner, 20, Color(1, 1, 1, a))
	draw_string(mono, Vector2(x, y + 20.0), String(info.sub), HORIZONTAL_ALIGNMENT_LEFT, inner, 11, Color(col.r, col.g, col.b, 0.85 * a))
	y += 46.0
	for row: Array in rows:
		draw_string(font, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, inner, 14, Color(0.85, 0.88, 0.92, 0.9 * a))
		if _row_wraps(font, mono, row, inner):
			y += line_h
		draw_string(mono, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, inner, 13, Color(1, 1, 1, a))
		y += line_h
	if extra != "":
		draw_string(mono, Vector2(x, y), extra, HORIZONTAL_ALIGNMENT_LEFT, inner, 12, Color(col.r, col.g, col.b, 0.95 * a))
		y += 20.0
	if note != "":
		draw_multiline_string(font, Vector2(x, y + 6.0), note, HORIZONTAL_ALIGNMENT_LEFT, inner, 12, 4, Color(0.8, 0.83, 0.88, 0.85 * a))
	draw_multiline_string(mono, Vector2(x, box.end.y - src_h - 2.0), src, HORIZONTAL_ALIGNMENT_LEFT, inner, 10, 2, Color(0.6, 0.65, 0.72, 0.8 * a))
