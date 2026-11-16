class_name Colony
extends Node3D
## Colonia lunar preinstalada: sectores, módulos, tripulación y su economía.
##
## Al empezar una partida ya están instalados y operativos (data/colony/colony_layout.json):
##   - Residencial: 5 monoblocks (jugador + 2 tripulantes + 2 de reserva) y planta de O₂.
##   - Hidroponía: gran cúpula con almacén refrigerado (producción continua).
##   - Energía: 2 paneles + banco de baterías, con cables que el jugador reubica.
##   - Investigación: laboratorio con fichas de rocas, análisis y 2 observatorios.
##   - Taller: fabricación de kits de módulos, equipamiento y mejoras.
##   - Comando: cohete con refugio, guardado, pedidos a la Tierra y estado general.
## También coloca caminos señalizados, balizas, el bot de servicio y el rover.
##
## Economía: los datos científicos (fichas nuevas, análisis, observaciones) pagan
## mejoras del Taller y pedidos a la Tierra. Todo se guarda (protocolo Saveable).

const SAVE_ID := "colony"
const LAYOUT_PATH := "res://data/colony/colony_layout.json"
const ROCKS_PATH := "res://data/colony/rock_sheets.json"
const FAB_PATH := "res://data/colony/fabrication.json"
const SUPPLY_PATH := "res://data/colony/supplies.json"
const TELESCOPE_PATH := "res://data/colony/telescope_targets.json"
## Colores de sector: tonos apagados (pintura), no neón.
const SECTOR_COLORS := {"cyan": Color("#8FB8BE"), "amber": Color("#D9B26A"), "magenta": Color("#C99AAE")}

signal research_changed(points: int)
signal colony_changed

static var _layout_cache: Dictionary = {}

var network: BaseNetwork
var region: MoonRegion
var layout: Dictionary = {}
var modules: Dictionary = {} # id -> Structure (módulos y estructuras preinstaladas)
var cables: Array[PowerCable] = []
var crew: Array[CrewMember] = []
var bots: Array[ServiceBot] = []

# --- Estado de la partida --------------------------------------------------------
var research_points: int = 0
var unlocked_sheets: Dictionary = {} # id -> true
var analyses: int = 0
var observations: Dictionary = {} # target id -> true
var upgrades: Dictionary = {} # recipe id -> true
var kits: Dictionary = {} # buildable id -> cantidad
var fab_job: Dictionary = {} # {recipe, left, total}
var supply_order: Dictionary = {} # {package, left}
var capsule_waiting: String = "" # paquete alunizado, sin descargar
## Cápsulas ya descargadas: quedan en el área de aterrizaje (máx. 6 visibles).
var landed_capsules: int = 0
## Propelente cargado en el módulo Ariel (tanques) y si ya despegó.
const PROPELLANT_NEEDED := 5
var propellant: int = 0
var _empty_capsules: Array[Node3D] = []

var rock_sheets: Array = []
var recipes: Array = []
var supplies: Dictionary = {}
var telescopes: Array = []

var _distribution_point := Vector3.ZERO
var _capsule: Node3D
var _terminal: ColonyTerminal
var _applied_runtime: Dictionary = {} # mejoras ya aplicadas a nodos de esta sesión
var _supply_pad := Vector3.ZERO


# --- Utilidades estáticas (las usan otros sistemas antes de que exista la colonia) ---

static func load_layout() -> Dictionary:
	if _layout_cache.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
		_layout_cache = d if d is Dictionary else {}
	return _layout_cache


static func layout_vec(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 2:
		return Vector3(float(a[0]), 0.0, float(a[1]))
	return Vector3.ZERO


## ¿El punto cae en una zona reservada a la colonia o sobre un camino? (para no poner rocas)
static func is_reserved(p: Vector3, margin := 0.0) -> bool:
	var l := load_layout()
	for z: Dictionary in l.get("clear_zones", []):
		var c := layout_vec(z.center)
		if Vector2(p.x - c.x, p.z - c.z).length() < float(z.r) + margin:
			return true
	# cada módulo e instalación del plano (aunque no tenga zona despejada propia)
	for m: Dictionary in l.get("modules", []):
		if m.has("pos") and Vector2(p.x, p.z).distance_to(_v2(layout_vec(m.pos))) < 13.0 + margin:
			return true
	for st: Variant in l.get("structures", []):
		if st is Dictionary and (st as Dictionary).has("pos") and Vector2(p.x, p.z).distance_to(_v2(layout_vec(st.pos))) < 6.0 + margin:
			return true
	for key: String in ["supply_pad", "lander", "distribution_box"]:
		var v: Variant = l.get(key)
		if v is Dictionary:
			v = (v as Dictionary).get("pos")
		if v is Array and Vector2(p.x, p.z).distance_to(_v2(layout_vec(v))) < 10.0 + margin:
			return true
	var hub := layout_vec(l.get("hub", [0, 0]))
	for route: Array in (l.get("routes", {}) as Dictionary).values():
		var prev := hub
		for w: Variant in route:
			if not (w is Array):
				continue
			var q := layout_vec(w)
			if _dist_to_segment(Vector2(p.x, p.z), Vector2(prev.x, prev.z), Vector2(q.x, q.z)) < 2.5 + margin:
				return true
			prev = q
	return false


static func _v2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Instalación -------------------------------------------------------------------

func setup(net: BaseNetwork, reg: MoonRegion) -> void:
	network = net
	region = reg


func _ready() -> void:
	add_to_group(&"colony")
	add_to_group(&"saveable")
	layout = load_layout()
	rock_sheets = _json(ROCKS_PATH).get("sheets", [])
	recipes = _json(FAB_PATH).get("recipes", [])
	supplies = _json(SUPPLY_PATH)
	telescopes = _json(TELESCOPE_PATH).get("observatories", [])
	research_points = int(supplies.get("start_research", 0))
	if network == null:
		network = get_parent() as BaseNetwork
	if region == null and network:
		region = network.region
	if network == null or region == null:
		push_error("Colony: falta la red o la región.")
		return
	_spawn_modules()
	_spawn_structures()
	_spawn_distribution_box()
	_spawn_cables()
	_spawn_paths_and_beacons()
	_spawn_supply_pad()
	_spawn_crew()
	_spawn_bots()
	EventBus.resource_collected.connect(_on_resource_collected)
	EventBus.structure_built.connect(_on_structure_built)
	network.recalc_capacity()
	# Arranque: el banco llegó cargado en la misión de carga previa (valor de juego)
	network.stored_kwh = minf(18.0, network.capacity_kwh)


func _json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _yaw_for(e: Dictionary, pos: Vector3) -> float:
	if e.has("yaw_to"):
		var to := resolve_point(e.yaw_to)
		return atan2(to.x - pos.x, to.z - pos.z)
	return deg_to_rad(float(e.get("yaw_deg", 0.0)))


## Altura de apoyo: el piso queda por encima del punto más alto del terreno bajo la huella.
func _foundation(pos: Vector3, radius: float) -> Vector2:
	var hmax := -INF
	var hmin := INF
	for ring in [0.0, radius * 0.5, radius]:
		var n := 1 if ring == 0.0 else 12
		for i in n:
			var a := TAU * i / n
			var h := region.get_height(pos + Vector3(cos(a), 0, sin(a)) * ring)
			if is_finite(h):
				hmax = maxf(hmax, h)
				hmin = minf(hmin, h)
	if not is_finite(hmax):
		return Vector2(0.3, -0.3)
	return Vector2(hmax + 0.3, hmin - (hmax + 0.3))


func _spawn_modules() -> void:
	for e: Dictionary in layout.get("modules", []):
		var d := DataRegistry.get_def(StringName(e.def)) as BuildableDef
		if d == null or d.module_script == null:
			push_warning("Colony: definición de módulo '%s' inválida." % e.def)
			continue
		var pos := layout_vec(e.pos)
		var yaw := _yaw_for(e, pos)
		var f := _foundation(pos, d.footprint_radius)
		var m := d.module_script.new() as ColonyModule
		m.setup(d, String(e.id), true)
		m.fixture = true
		m.name = String(e.id)
		# "lift": el módulo se eleva sobre patas (p. ej. el Hábitat Spatium)
		var lift := float(e.get("lift", 0.0))
		m.ground_drop = f.y - lift
		var occ := String(e.get("occupant", ""))
		m.occupant = StringName(occ)
		m.occupant_name = _crew_name(occ)
		m.plate_number = modules.size() + 1
		m.position = network.to_local(Vector3(pos.x, f.x + lift, pos.z))
		m.rotation.y = yaw
		network.add_child(m)
		modules[String(e.id)] = m


func _crew_name(id: String) -> String:
	if id == "player":
		return tr("COLONY_YOU")
	for c: Dictionary in layout.get("crew", []):
		if String(c.id) == id:
			return String(c.name)
	return ""


func _spawn_structures() -> void:
	for e: Dictionary in layout.get("structures", []):
		var d := DataRegistry.get_def(StringName(e.def)) as BuildableDef
		if d == null:
			continue
		var pos := layout_vec(e.pos)
		var s := network.spawn_structure(d, region.snap_to_ground(pos, -0.05), _yaw_for(e, pos), true, String(e.id))
		s.fixture = true
		s.stock = int(e.get("stock", 0))
		s.sector_override = StringName(e.get("sector", ""))
		modules[String(e.id)] = s


func _spawn_distribution_box() -> void:
	var p := region.snap_to_ground(layout_vec(layout.get("distribution_box", [-5, 2])))
	var n := Node3D.new()
	n.name = "DistributionBox"
	add_child(n)
	n.global_position = p
	var b := ModuleBuilder.new(n)
	b.box(Vector3(1.2, 0.2, 0.9), Vector3(0, 0.1, 0), &"concrete", Vector3.ZERO, &"shell")
	b.box(Vector3(0.8, 1.3, 0.5), Vector3(0, 0.85, 0), &"frame", Vector3.ZERO, &"shell")
	b.box(Vector3(0.7, 0.04, 0.02), Vector3(0, 1.3, 0.26), &"light_amber")
	b.box(Vector3(0.3, 0.3, 0.01), Vector3(0, 0.9, 0.26), &"stripe_amber")
	b.label(tr("COLONY_DISTRIBUTION"), Vector3(-0.38, 1.62, 0.27), Vector3.ZERO, 0.0026, Color(0.95, 0.9, 0.8), 290.0).font_size = 24
	# conducto hacia el monoblock del jugador
	var home := get_player_home()
	if home:
		var to := home.global_position + Vector3(0, 0.3, 0)
		b.pipe(Vector3(0, 0.4, 0), n.to_local(to + (p - to).normalized() * 3.5), 0.05, &"cable")
	_distribution_point = p + Vector3(0, 0.45, -0.3)
	var it := b.interactable(Vector3(0, 1.0, 0.5), "ACTION_INSPECT", tr("COLONY_DISTRIBUTION"), 0.5, 2.0)
	it.interacted.connect(func(_by: Node) -> void: EventBus.notification_requested.emit(cable_status_line(), &"info"))


func _endpoint(spec: String) -> Vector3:
	if spec == "distribution":
		return _distribution_point
	var parts := spec.split(":")
	var s: Node3D = modules.get(parts[0])
	if s == null:
		return Vector3.ZERO
	if parts.size() > 1 and s is BatteryBank:
		return (s as BatteryBank).connector_global(parts[1])
	# caja de conexión del panel, al pie del mástil
	return s.global_position + s.global_basis * Vector3(0.0, 0.45, 1.0)


func _spawn_cables() -> void:
	for e: Dictionary in layout.get("cables", []):
		var c := PowerCable.new()
		var clamps: Array[Vector3] = []
		for p: Variant in e.get("clamps", []):
			clamps.append(region.snap_to_ground(layout_vec(p)))
		c.setup(String(e.id), _endpoint(String(e.from)), _endpoint(String(e.to)), clamps, 1.45, tr(String(e.get("label_key", ""))))
		c.name = String(e.id)
		add_child(c)
		cables.append(c)


## Tramos de todas las rutas y recorridos (en el mundo), para dejar libres los caminos.
func _route_segments() -> Array:
	var segs: Array = []
	for rid: String in layout.get("routes", {}):
		var route: Array = layout.routes[rid]
		for i in route.size() - 1:
			segs.append([resolve_point(route[i]), resolve_point(route[i + 1])])
	for c: Dictionary in layout.get("crew", []):
		var prev: Variant = null
		for s: Dictionary in c.get("stops", []):
			for p: Variant in s.get("points", []):
				var q := resolve_point(p)
				if prev != null:
					segs.append([prev, q])
				prev = q
	return segs


func _clear_of_routes(p: Vector3, segs: Array, margin: float) -> bool:
	for sg: Array in segs:
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		if _dist_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z)) < margin:
			return false
	return true


## Primer punto libre alrededor de `p` (a `r` metros), fuera de los caminos.
func _free_spot(p: Vector3, r: float, segs: Array, margin: float) -> Vector3:
	for k in 16:
		var a := TAU * k / 16.0 + 0.785
		var q := p + Vector3(cos(a), 0, sin(a)) * r
		if _clear_of_routes(q, segs, margin):
			return q
	return p + Vector3(r, 0, r)


func _spawn_paths_and_beacons() -> void:
	var segs := _route_segments()
	var markers := Node3D.new()
	markers.name = "PathMarkers"
	add_child(markers)
	var mb := ModuleBuilder.new(markers)
	var drawn := {}
	for rid: String in layout.get("routes", {}):
		var route: Array = layout.routes[rid]
		for i in route.size() - 1:
			var a := resolve_point(route[i])
			var b := resolve_point(route[i + 1])
			var key := "%d_%d_%d_%d" % [int(a.x), int(a.z), int(b.x), int(b.z)]
			if drawn.has(key):
				continue
			drawn[key] = true
			var n := maxi(int(a.distance_to(b) / 6.0), 1)
			for k in range(1, n + 1):
				var p := a.lerp(b, float(k) / (n + 1))
				var side := (b - a).normalized().cross(Vector3.UP) * 1.8
				for s: float in [-1.0, 1.0]:
					var q := region.snap_to_ground(p + side * s)
					if not _clear_of_routes(q, segs, 1.2):
						continue # el poste caería sobre otro camino
					mb.cyl(0.05, 0.6, q + Vector3(0, 0.3, 0), &"frame", Vector3.ZERO, &"furniture", 6)
					mb.box(Vector3(0.1, 0.08, 0.1), q + Vector3(0, 0.64, 0), _sector_light(rid))
	mb.finalize()
	for e: Dictionary in layout.get("beacons", []):
		_spawn_beacon(e, segs)


func _sector_color(sector_id: String) -> Color:
	var s: Dictionary = layout.get("sectors", {}).get(sector_id, {})
	return SECTOR_COLORS.get(String(s.get("color", "cyan")), SECTOR_COLORS.cyan)


func _sector_light(sector_id: String) -> StringName:
	var s: Dictionary = layout.get("sectors", {}).get(sector_id, {})
	match String(s.get("color", "cyan")):
		"amber":
			return &"paint_ochre"
		"magenta":
			return &"paint_rose"
	return &"paint_teal"


func _spawn_beacon(e: Dictionary, segs: Array) -> void:
	var p := resolve_point(e.at)
	var n := Node3D.new()
	n.name = "Beacon"
	add_child(n)
	n.global_position = region.snap_to_ground(_free_spot(p, 3.2, segs, 1.6)) # al costado del cruce, fuera de todo camino
	var b := ModuleBuilder.new(n)
	b.cyl(0.08, 2.6, Vector3(0, 1.3, 0), &"frame", Vector3.ZERO, &"shell", 8)
	b.cyl(0.4, 0.15, Vector3(0, 0.07, 0), &"concrete", Vector3.ZERO, &"furniture", 10)
	b.sphere(0.1, Vector3(0, 2.68, 0), &"light_amber")
	b.omni(Vector3(0, 2.55, 0.6), Color(1.0, 0.9, 0.75), 0.7, 5.0).distance_fade_begin = 60.0
	var targets: Array = e.get("targets", [])
	if String(e.get("kind", "")) == "hub":
		targets = (layout.get("sectors", {}) as Dictionary).keys().filter(func(k: String) -> bool: return k != "residential")
	var y := 2.45
	for t: String in targets:
		var sec: Dictionary = layout.sectors.get(t, {})
		var dest := resolve_point(_route_end(t))
		var dir := dest - n.global_position
		var dist := Vector2(dir.x, dir.z).length()
		# tabla indicadora: apunta al destino (+Z local), texto legible en ambas caras
		var arm := b.group(Vector3(0, y, 0), atan2(dir.x, dir.z), "Sign_" + t)
		const LEN := 2.4
		b.box(Vector3(0.06, 0.44, LEN), Vector3(0, 0, 0.12 + LEN * 0.5), &"sign_board", Vector3.ZERO, &"", arm)
		b.box(Vector3(0.08, 0.06, LEN), Vector3(0, -0.19, 0.12 + LEN * 0.5), _sector_light(t), Vector3.ZERO, &"", arm)
		# punta de flecha
		b.box(Vector3(0.06, 0.31, 0.31), Vector3(0, 0, 0.12 + LEN + 0.02), &"sign_board", Vector3(PI * 0.25, 0, 0), &"", arm)
		var name := tr(String(sec.get("name_key", t)))
		for side: float in [1.0, -1.0]:
			# cara +X: el texto corre hacia -Z (la punta queda a la izquierda); cara -X: al revés
			var txt := ("◀ %s · %d m" if side > 0 else "%s · %d m ▶") % [name, int(dist)]
			var l := b.label(txt, Vector3(side * 0.045, 0.03, 0.12 + LEN * 0.5), Vector3(0, side * PI * 0.5, 0), 0.0044, Color(0.97, 0.97, 0.94), 2000.0, arm)
			l.font_size = 32
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.visibility_range_end = 45.0
		y -= 0.48
	b.finalize()


func _route_end(sector_id: String) -> Variant:
	var r: Array = layout.get("routes", {}).get(sector_id, [])
	return r[r.size() - 1] if not r.is_empty() else [0, 0]


## Punto del mundo: [x, z] o "modulo@x,z" (coordenadas locales del módulo) o "hub".
func resolve_point(spec: Variant) -> Vector3:
	if spec is Array:
		return region.snap_to_ground(layout_vec(spec))
	var s := String(spec)
	if s == "hub":
		return region.snap_to_ground(layout_vec(layout.get("hub", [0, 0])))
	if "@" in s:
		var parts := s.split("@")
		var xz := parts[1].split(",")
		var m: Node3D = modules.get(parts[0])
		if m:
			# a nivel del piso del módulo; los caminantes ajustan la altura con un rayo
			return m.global_transform * Vector3(float(xz[0]), 0.05, float(xz[1]))
	if modules.has(s):
		return (modules[s] as Node3D).global_position
	return region.snap_to_ground(Vector3.ZERO)


func _spawn_supply_pad() -> void:
	_supply_pad = region.snap_to_ground(layout_vec(layout.get("supply_pad", [0, -30])))
	var n := Node3D.new()
	n.name = "SupplyPad"
	add_child(n)
	n.global_position = _supply_pad
	var b := ModuleBuilder.new(n)
	b.cyl(3.2, 0.25, Vector3(0, 0.05, 0), &"concrete", Vector3.ZERO, &"shell", 24)
	b.cyl(2.6, 0.02, Vector3(0, 0.19, 0), &"stripe_amber", Vector3.ZERO, &"", 24, 2.6)
	b.cyl(2.3, 0.025, Vector3(0, 0.195, 0), &"concrete", Vector3.ZERO, &"", 24)
	for k in 4:
		var a := TAU * k / 4.0
		b.box(Vector3(0.12, 0.12, 0.12), Vector3(sin(a), 0, cos(a)) * 3.0 + Vector3(0, 0.25, 0), &"light_amber")
	b.label(tr("COLONY_SUPPLY_PAD"), Vector3(-1.2, 0.21, 2.0), Vector3(-PI * 0.5, 0, 0), 0.01, Color(1.0, 0.85, 0.5), 260.0)


func _spawn_crew() -> void:
	for e: Dictionary in layout.get("crew", []):
		var c := CrewMember.new()
		c.walker_id = StringName(e.id)
		c.display_name = String(e.name)
		c.role = StringName(e.get("role", ""))
		c.home_id = StringName(e.get("home", ""))
		c.accent = Color(String(e.get("accent", "#4FD1E8")))
		c.name = String(e.id)
		c.stops = _resolve_stops(e.get("stops", []))
		add_child(c)
		# arranca en su monoblock (última parada de la rutina = "en casa")
		c.teleport_to_stop(c.stops.size() - 1)
		c.dwell_left = randf_range(4.0, 12.0) if not Engine.is_editor_hint() else 8.0
		crew.append(c)


func _resolve_stops(src: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in src:
		var pts: Array = []
		for p: Variant in s.get("points", []):
			pts.append(resolve_point(p))
		var st := {"points": pts, "dwell": float(s.get("dwell", 10.0)), "anim": StringName(s.get("anim", "Idle")),
			"activity": tr(String(s.get("activity_key", "")))}
		if s.has("face"):
			st["face"] = resolve_point(s.face)
		out.append(st)
	return out


func _spawn_bots() -> void:
	for e: Dictionary in layout.get("bots", []):
		var bot := ServiceBot.new()
		bot.walker_id = StringName(e.id)
		bot.display_name = String(e.name)
		bot.speed = 1.6
		bot.name = String(e.id)
		var stops: Array[Dictionary] = []
		for p: Variant in e.get("route", []):
			stops.append({"points": [resolve_point(p)], "dwell": float(e.get("dwell", 5.0)), "anim": &"Idle", "activity": tr("CREW_ACT_PATROL")})
		bot.stops = stops
		add_child(bot)
		bot.teleport_to_stop(0)
		bots.append(bot)


# --- Consultas -----------------------------------------------------------------------

func get_module(id: String) -> Structure:
	return modules.get(id)


func get_player_home() -> ColonyModule:
	for m in modules.values():
		if m is ColonyModule and (m as ColonyModule).occupant == &"player":
			return m
	return null


func get_biodome() -> Biodome:
	return modules.get("biodome") as Biodome


func get_workshop() -> Workshop:
	return modules.get("workshop") as Workshop


func get_lab() -> ResearchLab:
	return modules.get("research_lab") as ResearchLab


## Transformación inicial del rover (estacionamiento junto al inicio).
func rover_transform() -> Transform3D:
	var r: Dictionary = layout.get("rover", {})
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(r.get("yaw_deg", 0.0)))), region.snap_to_ground(layout_vec(r.get("pos", [6, 6])), 0.9))


func es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func _loc(d: Dictionary, key: String) -> String:
	return String(d.get(key + ("_es" if es() else "_en"), d.get(key + "_es", "")))


# --- Ciencia: fichas, análisis y observaciones -----------------------------------------

func add_research(n: int) -> void:
	research_points = maxi(research_points + n, 0)
	research_changed.emit(research_points)
	colony_changed.emit()


func _on_resource_collected(item_id: StringName, _amount: int) -> void:
	for s: Dictionary in rock_sheets:
		if String(s.get("unlock", "")) == String(item_id) and not unlocked_sheets.has(String(s.id)):
			unlock_sheet(String(s.id))


func unlock_sheet(id: String) -> void:
	if unlocked_sheets.has(id):
		return
	unlocked_sheets[id] = true
	add_research(1)
	var s := get_sheet(id)
	EventBus.notification_requested.emit(tr("COLONY_SHEET_UNLOCKED") % _loc(s, "name"), &"info")


func get_sheet(id: String) -> Dictionary:
	for s: Dictionary in rock_sheets:
		if String(s.id) == id:
			return s
	return {}


func analyze_sample(by: Node, lab: ResearchLab) -> void:
	var p := by as Player
	if p == null:
		return
	if not lab.is_operational():
		EventBus.notification_requested.emit(tr("STATUS_NO_POWER"), &"warning")
		return
	if not p.inventory.has(&"geo_sample", 1):
		EventBus.notification_requested.emit(tr("COLONY_NEED_SAMPLE"), &"warning")
		return
	p.face_towards(lab.global_transform * Vector3(-5.6, 0, -4.0))
	p.perform_action(&"Interact", func() -> void:
		if not p.inventory.remove(&"geo_sample", 1):
			return
		analyses += 1
		var found := ""
		for s: Dictionary in rock_sheets:
			if int(s.get("analysis", 0)) == analyses:
				unlocked_sheets[String(s.id)] = true
				found = _loc(s, "name")
		add_research(2)
		EventBus.player_action.emit(&"analyze")
		EventBus.notification_requested.emit(tr("COLONY_ANALYSIS_DONE") % [analyses, (found if found != "" else tr("COLONY_ANALYSIS_DATING"))], &"info"), 0.5)


func complete_observation(obs: int, target: Dictionary) -> void:
	var id := String(target.id)
	var first := not observations.has(id)
	observations[id] = true
	var lab := get_lab()
	if lab:
		lab.aim_telescope(obs, deg_to_rad(float(target.az_deg)), deg_to_rad(float(target.el_deg)))
	add_research(2 if first else 0)
	EventBus.player_action.emit(&"observe")


# --- Taller: fabricación ----------------------------------------------------------------

func get_recipe(id: String) -> Dictionary:
	for r: Dictionary in recipes:
		if String(r.id) == id:
			return r
	return {}


## Motivo por el que no se puede fabricar ("" si se puede).
func fabrication_blocker(r: Dictionary, inv: Inventory) -> String:
	if not fab_job.is_empty():
		return tr("COLONY_FAB_BUSY")
	if String(r.kind) == "propellant" and propellant >= PROPELLANT_NEEDED:
		return tr("ROCKET_FULL")
	if String(r.kind) in ["upgrade", "equipment"] and upgrades.has(String(r.id)):
		return tr("COLONY_FAB_DONE")
	var ws := get_workshop()
	if ws == null or not ws.is_built():
		return tr("COLONY_FAB_NO_WORKSHOP")
	if research_points < int(r.get("research", 0)):
		return tr("COLONY_FAB_NEED_RESEARCH") % int(r.get("research", 0))
	for id: String in r.get("cost", {}):
		if not inv.has(StringName(id), int(r.cost[id])):
			return tr("BUILD_MISSING") % cost_text(r)
	return ""


func cost_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in r.get("cost", {}):
		var d := DataRegistry.get_def(StringName(id))
		parts.append("%d %s" % [int(r.cost[id]), d.get_display_name() if d else id])
	if int(r.get("research", 0)) > 0:
		parts.append(tr("COLONY_RESEARCH_UNITS") % int(r.research))
	return ", ".join(parts)


func start_fabrication(id: String, inv: Inventory) -> bool:
	var r := get_recipe(id)
	if r.is_empty() or fabrication_blocker(r, inv) != "":
		return false
	for item: String in r.get("cost", {}):
		inv.remove(StringName(item), int(r.cost[item]))
	add_research(-int(r.get("research", 0)))
	fab_job = {"recipe": id, "left": float(r.seconds), "total": float(r.seconds)}
	EventBus.notification_requested.emit(tr("COLONY_FAB_STARTED") % _loc(r, "name"), &"info")
	colony_changed.emit()
	return true


func _finish_fabrication() -> void:
	var r := get_recipe(String(fab_job.recipe))
	fab_job = {}
	var ws := get_workshop()
	if ws:
		ws.set_fabrication(false, 0.0)
	if r.is_empty():
		return
	if String(r.kind) == "kit":
		var b := String(r.buildable)
		kits[b] = int(kits.get(b, 0)) + 1
	elif String(r.kind) == "energy":
		network.stored_kwh = minf(network.stored_kwh + float(r.get("kwh", 10.0)), network.capacity_kwh)
		EventBus.player_action.emit(&"fusion_cell")
	elif String(r.kind) == "propellant":
		propellant = mini(propellant + 1, PROPELLANT_NEEDED)
		EventBus.player_action.emit(&"propellant")
		if propellant >= PROPELLANT_NEEDED:
			RadioPanel.say("return_ready")
	else:
		upgrades[String(r.id)] = true
		apply_upgrades()
	EventBus.player_action.emit(&"fabricate")
	EventBus.notification_requested.emit(tr("COLONY_FAB_FINISHED") % _loc(r, "name"), &"info")
	colony_changed.emit()


func has_kit(buildable: StringName) -> bool:
	return int(kits.get(String(buildable), 0)) > 0


func consume_kit(buildable: StringName) -> bool:
	var k := String(buildable)
	if int(kits.get(k, 0)) <= 0:
		return false
	kits[k] = int(kits[k]) - 1
	colony_changed.emit()
	return true


## Aplica los efectos reales de las mejoras fabricadas (idempotente).
func apply_upgrades() -> void:
	network.solar_multiplier = 1.25 if upgrades.has("solar_hpe") else 1.0
	network.extra_capacity_kwh = 10.0 if upgrades.has("battery_ext") else 0.0
	network.recalc_capacity()
	var dome := get_biodome()
	if dome:
		dome.growth_multiplier = 1.35 if upgrades.has("grow_led") else 1.0
	for s in network.get_structures():
		if s.def.role == BuildableDef.Role.OXYGEN:
			s.rate_multiplier = 1.5 if upgrades.has("o2_catalyst") else 1.0
		if s is Monoblock or s is SpatiumHabitat:
			(s as ColonyModule).shield_override = 0.09 if upgrades.has("regolith_shield_plus") else -1.0
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player:
		var suit := player.get_node_or_null("SuitStatus") as SuitStatus
		if suit:
			if upgrades.has("suit_o2_tank") and not _applied_runtime.has("suit_o2_tank"):
				suit.oxygen_rate *= 0.7
				_applied_runtime["suit_o2_tank"] = true
			if upgrades.has("suit_battery") and not _applied_runtime.has("suit_battery"):
				suit.energy_rate *= 0.7
				_applied_runtime["suit_battery"] = true
	if upgrades.has("drill_upgrade") and not _applied_runtime.has("drill_upgrade"):
		for f in get_tree().get_nodes_in_group(&"saveable"):
			if f is ResourceField:
				for dep in (f as ResourceField).get_deposits():
					dep.yield_per_harvest += 1
		_applied_runtime["drill_upgrade"] = true


func _on_structure_built(_s: Node) -> void:
	apply_upgrades()


# --- Comando: pedidos a la Tierra ------------------------------------------------------

func get_package(id: String) -> Dictionary:
	for p: Dictionary in supplies.get("packages", []):
		if String(p.id) == id:
			return p
	return {}


func order_blocker(p: Dictionary) -> String:
	if not supply_order.is_empty() or capsule_waiting != "":
		return tr("COLONY_SUPPLY_BUSY")
	if float(network.throttles.get("comms", 1.0)) <= 0.0:
		return tr("POWER_COMMS_OFF")
	var ed := get_tree().get_first_node_in_group(&"event_director") as EventDirector
	if ed and ed.is_comms_down():
		return tr("EV_COMMS_DOWN")
	if research_points < int(p.get("research", 0)):
		return tr("COLONY_FAB_NEED_RESEARCH") % int(p.get("research", 0))
	var cmd := modules.get("command_center") as CommandCenter
	if cmd == null or not cmd.is_operational():
		return tr("STATUS_NO_POWER")
	return ""


func order_supply(id: String) -> bool:
	var p := get_package(id)
	if p.is_empty() or order_blocker(p) != "":
		return false
	add_research(-int(p.get("research", 0)))
	supply_order = {"package": id, "left": float(p.get("delivery_s", 90.0))}
	EventBus.notification_requested.emit(tr("COLONY_SUPPLY_ORDERED") % [_loc(p, "name"), int(supply_order.left)], &"info")
	return true


func _supply_arrived() -> void:
	capsule_waiting = String(supply_order.package)
	supply_order = {}
	_spawn_capsule(true)
	EventBus.notification_requested.emit(tr("COLONY_SUPPLY_LANDED"), &"warning")


func _spawn_capsule(animate: bool) -> void:
	if _capsule:
		_capsule.queue_free()
	_capsule = Node3D.new()
	_capsule.name = "SupplyCapsule"
	add_child(_capsule)
	var land := _supply_pad + Vector3(0, 0.2, 0)
	_capsule.global_position = land + (Vector3(0, 90, 0) if animate else Vector3.ZERO)
	var b := ModuleBuilder.new(_capsule)
	b.cyl(0.9, 1.6, Vector3(0, 1.1, 0), &"hull", Vector3.ZERO, &"shell", 16, 0.55)
	b.cyl(0.95, 0.12, Vector3(0, 0.3, 0), &"frame", Vector3.ZERO, &"", 16)
	b.box(Vector3(0.6, 0.7, 0.05), Vector3(0, 1.0, 0.75), &"stripe_amber")
	for k in 3:
		var a := TAU * k / 3.0
		b.pipe(Vector3(sin(a), 0, cos(a)) * 0.6 + Vector3(0, 0.4, 0), Vector3(sin(a), 0, cos(a)) * 1.1 + Vector3(0, 0.02, 0), 0.04, &"metal")
	var flame := b.omni(Vector3(0, -0.4, 0), Color(1.0, 0.7, 0.4), 6.0 if animate else 0.0, 12.0)
	var it := b.interactable(Vector3(0, 1.0, 1.1), "ACTION_UNLOAD", tr("COLONY_SUPPLY_CAPSULE"), 0.7, 2.4)
	it.interacted.connect(_unload_capsule)
	if animate:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_capsule, "global_position", land, 8.0)
		tw.tween_property(flame, "light_energy", 0.0, 0.6)


func _unload_capsule(by: Node) -> void:
	var p := get_package(capsule_waiting)
	var player := by as Player
	if p.is_empty():
		return
	for k: String in p.get("contents", {}):
		var v: Variant = p.contents[k]
		if k == "rations":
			network.rations += int(v)
		elif k == "oxygen_kg":
			network.add_oxygen(float(v))
		elif k.begins_with("item:") and player:
			player.inventory.add(StringName(k.substr(5)), int(v))
		elif k.begins_with("kit:"):
			var bid := k.substr(4)
			kits[bid] = int(kits.get(bid, 0)) + int(v)
	if player:
		player.perform_action(&"Collect")
	EventBus.notification_requested.emit(tr("COLONY_SUPPLY_UNLOADED") % _loc(p, "name"), &"info")
	capsule_waiting = ""
	if _capsule:
		_capsule.queue_free()
		_capsule = null
	landed_capsules += 1
	_spawn_empty_capsule(landed_capsules - 1, true)
	colony_changed.emit()


## Cápsula vacía: escotilla abierta y cajas descargadas al lado. Se acomodan en
## semicírculo alrededor de la plataforma (no desaparecen al descargarlas).
func _spawn_empty_capsule(index: int, fresh: bool) -> void:
	var slot := index % 6
	if _empty_capsules.size() > slot and is_instance_valid(_empty_capsules[slot]):
		_empty_capsules[slot].queue_free()
	var a := deg_to_rad(-60.0 + slot * 24.0)
	var pos := region.snap_to_ground(_supply_pad + Vector3(sin(a), 0, cos(a)) * 6.5)
	var n := Node3D.new()
	n.name = "EmptyCapsule_%d" % index
	add_child(n)
	n.global_position = pos
	n.rotation.y = a + PI
	var b := ModuleBuilder.new(n)
	b.cyl(0.9, 1.6, Vector3(0, 1.1, 0), &"hull", Vector3.ZERO, &"shell", 16, 0.55)
	b.cyl(0.95, 0.12, Vector3(0, 0.3, 0), &"frame", Vector3.ZERO, &"", 16)
	b.box(Vector3(0.5, 0.6, 0.06), Vector3(0, 1.0, 0.86), &"frame") # hueco de la escotilla
	var hatch := b.group(Vector3(0.32, 1.0, 0.82), -1.4, "Hatch") # escotilla abierta
	b.box(Vector3(0.6, 0.7, 0.05), Vector3(-0.3, 0, 0), &"stripe_amber", Vector3.ZERO, &"", hatch)
	for k in 3:
		var la := TAU * k / 3.0
		b.pipe(Vector3(sin(la), 0, cos(la)) * 0.6 + Vector3(0, 0.4, 0), Vector3(sin(la), 0, cos(la)) * 1.1 + Vector3(0, 0.02, 0), 0.04, &"metal")
	b.crate(Vector3(1.3, 0, 0.9), 0.4, Vector3(0.6, 0.45, 0.6), &"plastic")
	b.crate(Vector3(1.25, 0.45, 0.95), 0.1, Vector3(0.45, 0.35, 0.45), &"hull_panel")
	b.crate(Vector3(-1.2, 0, 1.0), -0.3, Vector3(0.7, 0.4, 0.5), &"plastic")
	var es := es()
	b.label(("CRS-%02d · VACÍA" if es else "CRS-%02d · EMPTY") % (index + 1), Vector3(-0.35, 1.75, 0.62), Vector3(-0.3, 0, 0), 0.006, Color(1.0, 0.85, 0.5), 160.0)
	b.finalize()
	if _empty_capsules.size() <= slot:
		_empty_capsules.resize(slot + 1)
	_empty_capsules[slot] = n
	if fresh:
		n.scale = Vector3.ONE * 0.9
		create_tween().tween_property(n, "scale", Vector3.ONE, 0.3)


# --- Bucle --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not fab_job.is_empty():
		var ws := get_workshop()
		if ws and ws.is_operational():
			fab_job.left = float(fab_job.left) - delta * float(network.throttles.get("science", 1.0))
			ws.set_fabrication(true, 1.0 - float(fab_job.left) / maxf(float(fab_job.total), 0.01))
			if float(fab_job.left) <= 0.0:
				_finish_fabrication()
		elif ws:
			ws.set_fabrication(false, 1.0 - float(fab_job.left) / maxf(float(fab_job.total), 0.01))
	if not supply_order.is_empty():
		supply_order.left = float(supply_order.left) - delta * maxf(float(network.throttles.get("comms", 1.0)), 0.0)
		if float(supply_order.left) <= 0.0:
			_supply_arrived()


## Avanza el tiempo de la colonia sin esperar (tests y modo evaluador).
func fast_forward(seconds: float) -> void:
	var step := 0.5
	var t := 0.0
	while t < seconds:
		_process(step)
		t += step


# --- Terminales ----------------------------------------------------------------------------

func open_terminal(mode: StringName, module: Node, by: Node) -> void:
	if not (by is Player):
		return
	if module is Structure and not (module as Structure).is_operational():
		EventBus.notification_requested.emit(tr("STATUS_NO_POWER"), &"warning")
		return
	if _terminal == null:
		_terminal = ColonyTerminal.new()
		_terminal.name = "ColonyTerminal"
		add_child(_terminal)
	(by as Player).face_towards((module as Node3D).global_position)
	_terminal.open(mode, self, module, by as Player)


# --- Textos de pantallas e informes (datos reales de la partida) -------------------------

func short_status_line() -> String:
	var dome := get_biodome()
	var t := ("DOMO %d raciones · DATOS %d\n" if es() else "DOME %d rations · DATA %d\n") % [dome.storage if dome else 0, research_points]
	if not fab_job.is_empty():
		t += ("TALLER fabricando (%d s)\n" if es() else "WORKSHOP fabricating (%d s)\n") % int(fab_job.left)
	return t


func cable_status_line() -> String:
	var t := ""
	for c in cables:
		t += ("%s: %.0f/%.0f m %s\n" % [c.label_text, c.get_length(), c.max_length, ("TENSO" if es() else "TAUT") if c.is_taut() else "OK"])
	return t


func lab_summary() -> String:
	var t := ("LABORATORIO · DATOS CIENTÍFICOS: %d\n" if es() else "LABORATORY · SCIENCE DATA: %d\n") % research_points
	t += ("Fichas de rocas: %d/%d · Análisis: %d\n" if es() else "Rock sheets: %d/%d · Analyses: %d\n") % [unlocked_sheets.size(), rock_sheets.size(), analyses]
	var obs_total := 0
	for o: Dictionary in telescopes:
		obs_total += (o.get("targets", []) as Array).size()
	t += ("Observaciones: %d/%d" if es() else "Observations: %d/%d") % [observations.size(), obs_total]
	return t


func rock_terminal_preview() -> String:
	var t := "FICHAS DE ROCAS\n" if es() else "ROCK SHEETS\n"
	for s: Dictionary in rock_sheets:
		t += ("■ " if unlocked_sheets.has(String(s.id)) else "□ ") + (_loc(s, "name") if unlocked_sheets.has(String(s.id)) else "?????") + "\n"
	return t


func telescope_screen(k: int) -> String:
	if k >= telescopes.size():
		return ""
	var o: Dictionary = telescopes[k]
	var t := "OBS-%d · %s\n" % [k + 1, tr(String(o.get("name_key", "")))]
	for tg: Dictionary in o.get("targets", []):
		t += ("✓ " if observations.has(String(tg.id)) else "· ") + _loc(tg, "name") + "  az %d° el %d°\n" % [int(tg.az_deg), int(tg.el_deg)]
	return t


func fabrication_screen(compact := false) -> String:
	var t := "TALLER · " if es() else "WORKSHOP · "
	if fab_job.is_empty():
		t += "en espera\n" if es() else "idle\n"
	else:
		var r := get_recipe(String(fab_job.recipe))
		t += "%s  %d %%  (%d s)\n" % [_loc(r, "name"), int((1.0 - float(fab_job.left) / float(fab_job.total)) * 100.0), int(fab_job.left)]
	if compact:
		t += ("Kits: %s\nDatos: %d" if es() else "Kits: %s\nData: %d") % [_kits_text(), research_points]
		return t
	t += ("Mejoras instaladas: %d\n" if es() else "Upgrades installed: %d\n") % upgrades.size()
	t += "Kits: %s" % _kits_text()
	return t


func _kits_text() -> String:
	var parts: PackedStringArray = []
	for k: String in kits:
		if int(kits[k]) > 0:
			var d := DataRegistry.get_def(StringName(k))
			parts.append("%s ×%d" % [d.get_display_name() if d else k, int(kits[k])])
	return ", ".join(parts) if not parts.is_empty() else "—"


func save_screen() -> String:
	var t := "GUARDADO\n" if es() else "SAVE\n"
	var slots := SaveManager.list_slots()
	if slots.is_empty():
		t += "sin partidas" if es() else "no saves"
	else:
		t += ("Última: %s" if es() else "Latest: %s") % String(slots[0].saved_at).replace("T", " ").left(16)
	return t


func supply_screen() -> String:
	var t := "COMUNICACIONES · TIERRA\n" if es() else "COMMS · EARTH\n"
	if not supply_order.is_empty():
		t += ("Pedido en camino: %d s\n" if es() else "Order inbound: %d s\n") % int(supply_order.left)
	elif capsule_waiting != "":
		t += "Cápsula en la plataforma\n" if es() else "Capsule on the pad\n"
	else:
		t += "Sin pedidos\n" if es() else "No orders\n"
	t += ("Datos disponibles: %d" if es() else "Data available: %d") % research_points
	return t


func colony_status_text(compact := false) -> String:
	var n := network
	var es_ := es()
	var t := ("COLONIA · ENERGÍA %.1f/%.1f kWh · %+.1f kW\n" if es_ else "COLONY · POWER %.1f/%.1f kWh · %+.1f kW\n") % [n.stored_kwh, n.capacity_kwh, n.production_kw - n.supplied_kw]
	t += ("O₂ %.1f kg · Agua %.0f L · Raciones %d\n" if es_ else "O₂ %.1f kg · Water %.0f L · Rations %d\n") % [n.oxygen_kg, n.water_l, n.rations]
	var by_sector := n.get_sector_demand()
	for sid: String in by_sector:
		var sec: Dictionary = layout.get("sectors", {}).get(sid, {})
		var nm := tr(String(sec.get("name_key", ""))) if not sec.is_empty() else (tr("COLONY_SECTOR_OTHER"))
		var v: Dictionary = by_sector[sid]
		t += "  %s: %.1f kW%s%s\n" % [nm, float(v.demand), (" (+%.1f)" % float(v.production)) if float(v.production) > 0.0 else "", "" if v.powered else " ⚠"]
	if compact:
		return t
	var dome := get_biodome()
	if dome:
		t += ("Domo: almacén %d/%d\n" if es_ else "Dome: storage %d/%d\n") % [dome.storage, Biodome.STORAGE_CAPACITY]
	for c in crew:
		t += "%s · %s\n" % [c.display_name, c.activity]
	var rad := get_tree().get_first_node_in_group(&"radiation_system")
	if rad and "phase" in rad:
		t += ("Clima espacial: %s\n" if es_ else "Space weather: %s\n") % String(rad.get("phase"))
	t += short_status_line()
	return t


func crew_report(c: CrewMember) -> String:
	var es_ := es()
	match c.role:
		&"botanist":
			var dome := get_biodome()
			if dome == null:
				return c.activity
			var best := 0
			for i in dome.beds.size():
				if float(dome.beds[i].progress) > float(dome.beds[best].progress):
					best = i
			var crop: Dictionary = dome.crops.get(String(dome.beds[best].crop), {})
			if not dome.is_operational():
				return "¡El domo se quedó sin energía! Las plantas no crecen sin luz." if es_ else "The dome lost power! Plants won't grow without light."
			return ("Hay %d raciones en el almacén. El bancal %d (%s) va al %d %%; cuando madura se cosecha solo." if es_ else "There are %d rations in storage. Bed %d (%s) is at %d %%; it harvests itself when ripe.") % [dome.storage, best + 1, _loc(crop, "name"), int(float(dome.beds[best].progress) * 100.0)]
		&"engineer":
			var soc := network.stored_kwh / maxf(network.capacity_kwh, 0.01) * 100.0
			var msg := ("El banco está al %d %%: producimos %.1f kW y consumimos %.1f kW. " if es_ else "The bank is at %d %%: we produce %.1f kW and use %.1f kW. ") % [int(soc), network.production_kw, network.supplied_kw]
			msg += ("Podés reacomodar los cables agarrando las abrazaderas amarillas; no se desconectan." if es_ else "You can rearrange the cables by grabbing the yellow clamps; they never disconnect.")
			return msg
	return c.activity


func bot_report() -> String:
	var n := network
	var es_ := es()
	var t := ("Telemetría: batería %d %%, O₂ de reserva %.1f kg, agua %.0f L, %d raciones." if es_ else "Telemetry: battery %d %%, reserve O₂ %.1f kg, water %.0f L, %d rations.") % [int(n.stored_kwh / maxf(n.capacity_kwh, 0.01) * 100.0), n.oxygen_kg, n.water_l, n.rations]
	var dark := 0
	for s in n.get_structures():
		if s.is_built() and not s.powered:
			dark += 1
	if dark > 0:
		t += (" ⚠ %d instalaciones sin energía." if es_ else " ⚠ %d facilities unpowered.") % dark
	return t


# --- Saveable --------------------------------------------------------------------------------

## Estado propio de los módulos que lo tienen (huerta del hábitat, etc.).
func _save_modules() -> Dictionary:
	var out := {}
	for id: String in modules:
		var m: Node = modules[id]
		if m is ColonyModule and not (m is Biodome) and m.has_method("save_module"):
			out[id] = m.call("save_module")
	return out


func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var cab := {}
	for c in cables:
		cab[c.cable_id] = c.save_state()
	var walkers := {}
	for w in crew:
		walkers[String(w.walker_id)] = w.save_state()
	for w in bots:
		walkers[String(w.walker_id)] = w.save_state()
	var dome := get_biodome()
	return {
		"research": research_points, "sheets": unlocked_sheets.keys(), "analyses": analyses,
		"observations": observations.keys(), "upgrades": upgrades.keys(), "kits": kits.duplicate(),
		"fab_job": fab_job.duplicate(), "supply_order": supply_order.duplicate(), "capsule": capsule_waiting, "landed_capsules": landed_capsules, "propellant": propellant,
		"cables": cab, "walkers": walkers, "dome": dome.save_module() if dome else {},
		"modules": _save_modules(),
		"o2_stock": (modules.get("oxygen_plant") as Structure).stock if modules.has("oxygen_plant") else 0,
	}


func load_state(d: Dictionary) -> void:
	research_points = int(d.get("research", research_points))
	unlocked_sheets.clear()
	for k: String in d.get("sheets", []):
		unlocked_sheets[k] = true
	analyses = int(d.get("analyses", 0))
	observations.clear()
	for k: String in d.get("observations", []):
		observations[k] = true
	upgrades.clear()
	for k: String in d.get("upgrades", []):
		upgrades[k] = true
	kits = (d.get("kits", {}) as Dictionary).duplicate()
	fab_job = (d.get("fab_job", {}) as Dictionary).duplicate()
	supply_order = (d.get("supply_order", {}) as Dictionary).duplicate()
	capsule_waiting = String(d.get("capsule", ""))
	landed_capsules = int(d.get("landed_capsules", 0))
	propellant = int(d.get("propellant", 0))
	for c in _empty_capsules:
		if is_instance_valid(c):
			c.queue_free()
	_empty_capsules.clear()
	for i in range(maxi(0, landed_capsules - 6), landed_capsules):
		_spawn_empty_capsule(i, false)
	if capsule_waiting != "":
		_spawn_capsule(false)
	for c in cables:
		var data: Variant = (d.get("cables", {}) as Dictionary).get(c.cable_id)
		if data is Array:
			c.load_state(data)
	var walkers: Dictionary = d.get("walkers", {})
	var all: Array[ColonyWalker] = []
	all.append_array(crew)
	all.append_array(bots)
	for w in all:
		var wd: Variant = walkers.get(String(w.walker_id))
		if wd is Dictionary:
			w.load_state(wd)
	var dome := get_biodome()
	if dome and d.has("dome"):
		dome.load_module(d.dome)
	var ms: Dictionary = d.get("modules", {})
	for id: String in ms:
		var m := modules.get(id) as ColonyModule
		if m and not (m is Biodome) and m.has_method("load_module"):
			m.call("load_module", ms[id])
	if modules.has("oxygen_plant"):
		(modules.oxygen_plant as Structure).stock = int(d.get("o2_stock", 0))
	apply_upgrades()
	research_changed.emit(research_points)
	colony_changed.emit()
