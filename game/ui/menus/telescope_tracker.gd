class_name TelescopeTracker
extends Control
## Desafío de calibración y seguimiento del telescopio.
##
## El campo de estrellas deriva (error de seguimiento de la montura más la
## rotación lenta de la Luna); el jugador corrige con WASD / flechas / stick o
## arrastrando con el mouse, y tiene que mantener el objetivo dentro de la
## retícula durante `hold_s` segundos antes de que se acabe el tiempo.

signal progress(hold: float, total: float, time_left: float)
signal finished(ok: bool)

const TIME_LIMIT := 30.0
const RADIUS := 26.0
const CORRECTION := 170.0

var target: Dictionary
var color := Color.WHITE
var hold := 0.0
var time_left := TIME_LIMIT
var offset := Vector2.ZERO # posición del objetivo respecto de la retícula
var _vel := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _stars: PackedVector3Array = []
var _done := false
var _drag := false
## En los tests se puede inyectar la corrección (en lugar del teclado).
var test_input := Vector2.ZERO


func setup(t: Dictionary, c: Color) -> void:
	target = t
	color = c
	_rng.seed = hash(String(t.get("id", "")))
	offset = Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-90, 90))
	for i in 160:
		_stars.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.4, 1.6)))
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	grab_focus.call_deferred()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_drag = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _drag:
		offset += (event as InputEventMouseMotion).relative
		accept_event()


func _process(delta: float) -> void:
	if _done:
		return
	step(delta, _read_input() + test_input)


## Un paso de simulación (público para los tests).
func step(delta: float, correction: Vector2) -> void:
	var drift := float(target.get("drift", 0.5))
	# deriva: componente constante (rotación) + ruido de la montura
	_vel += Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 60.0 * drift * delta
	_vel = _vel.limit_length(55.0 * drift + 10.0)
	offset += (_vel + Vector2(18.0, -6.0) * drift) * delta
	offset -= correction * CORRECTION * delta
	offset = offset.clamp(-size * 0.5 + Vector2(10, 10), size * 0.5 - Vector2(10, 10)) if size != Vector2.ZERO else offset
	time_left -= delta
	if offset.length() < RADIUS:
		hold += delta
	else:
		hold = maxf(hold - delta * 0.5, 0.0)
	progress.emit(hold, float(target.get("hold_s", 3.0)), time_left)
	queue_redraw()
	if hold >= float(target.get("hold_s", 3.0)):
		_finish(true)
	elif time_left <= 0.0:
		_finish(false)


func _finish(ok: bool) -> void:
	_done = true
	finished.emit(ok)
	queue_free()


func _read_input() -> Vector2:
	var v := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_forward", &"move_back"))
	if Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	return v.limit_length(1.0)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.0, 0.01, 0.03))
	var c := size * 0.5
	for s in _stars:
		var p := Vector2(s.x * size.x, s.y * size.y) + offset * 0.35
		p = Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y))
		draw_circle(p, s.z * 0.8, Color(1, 1, 1, 0.35 + s.z * 0.3))
	var tp := c + offset
	for k in 4:
		draw_circle(tp, 14.0 - k * 3.0, Color(color.r, color.g, color.b, 0.12 + k * 0.18))
	if String(target.get("id", "")) == "jupiter":
		for m in 4: # lunas galileanas alineadas
			draw_circle(tp + Vector2(-30 + m * 20 + (8 if m > 1 else 0), 1), 1.6, Color(1, 1, 0.9))
	var ok := offset.length() < RADIUS
	var rc := SpatiumTheme.CYAN if ok else SpatiumTheme.AMBER
	draw_arc(c, RADIUS, 0, TAU, 48, rc, 2.0)
	draw_line(c - Vector2(RADIUS + 14, 0), c - Vector2(RADIUS - 6, 0), rc, 2.0)
	draw_line(c + Vector2(RADIUS - 6, 0), c + Vector2(RADIUS + 14, 0), rc, 2.0)
	draw_line(c - Vector2(0, RADIUS + 14), c - Vector2(0, RADIUS - 6), rc, 2.0)
	draw_line(c + Vector2(0, RADIUS - 6), c + Vector2(0, RADIUS + 14), rc, 2.0)
	var frac := hold / maxf(float(target.get("hold_s", 3.0)), 0.01)
	draw_rect(Rect2(10, size.y - 18, (size.x - 20) * clampf(frac, 0, 1), 8), SpatiumTheme.CYAN)
	draw_rect(Rect2(10, size.y - 18, size.x - 20, 8), Color(1, 1, 1, 0.3), false, 1.0)
