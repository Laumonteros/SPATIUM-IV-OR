class_name BaseNetwork
extends Node3D
## Red de la base: energía (producción, consumo, baterías) y reservas de
## oxígeno, agua y raciones. Conecta las estructuras con la supervivencia.
##
## Tiempo de simulación: 1 segundo real = 1 minuto de juego (GAME_MINUTES_PER_SECOND).
## Así un panel de 3 kW llena una batería de 10 kWh en unos 3 minutos reales.
## Si la energía no alcanza, se apagan primero las estructuras de menor prioridad.

signal changed

const SAVE_ID := "base_network"
const GAME_MINUTES_PER_SECOND := 1.0
const TICK := 0.5
## Roles con interior presurizado donde el traje se recarga.
const SHELTER_ROLES: Array[BuildableDef.Role] = [BuildableDef.Role.SHELTER, BuildableDef.Role.GREENHOUSE,
	BuildableDef.Role.LAB, BuildableDef.Role.WORKSHOP, BuildableDef.Role.COMMAND]

## Reservas iniciales del módulo de alunizaje (valores de juego).
@export var oxygen_kg: float = 6.0
@export var water_l: float = 12.0
@export var rations: int = 14
## Reparto de energía (decisión del jugador): 1 = normal, 0,5 = reducido, 0 = apagado.
## Menos energía = menos consumo, pero el sistema rinde menos (o se detiene).
var throttles: Dictionary = {"life": 1.0, "food": 1.0, "science": 1.0, "comms": 1.0}
const GROUPS := {
	&"oxygen_generator": "life", &"water_extractor": "life", &"spatium_habitat": "life", &"monoblock": "life", &"habitat": "life", &"lander": "life",
	&"biodome": "food", &"research_lab": "science", &"workshop": "science", &"command_center": "comms",
}
@export var oxygen_capacity_kg: float = 12.0
@export var water_capacity_l: float = 40.0

var stored_kwh: float = 4.0
var capacity_kwh: float = 6.0 # baterías internas del módulo de alunizaje
var production_kw: float = 0.0
var demand_kw: float = 0.0
var supplied_kw: float = 0.0

var _structures: Array[Structure] = []
var _acc := 0.0


## Módulo de alunizaje: refugio inicial (no se construye; ya está en el sitio).
@export var lander_def: BuildableDef
@export var region: MoonRegion

var _next_id := 0
## Módulo de alunizaje "Ariel" (refugio de respaldo del sector Comando).
var lander: Structure
## Bonificaciones de mejoras del Taller (multiplicadores).
var solar_multiplier: float = 1.0
var extra_capacity_kwh: float = 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(&"base_network")
	if lander_def and region:
		# El módulo de alunizaje quedó en el sector de Comando (ver data/colony/colony_layout.json)
		var lp := Colony.layout_vec(Colony.load_layout().get("lander", {}).get("pos", [-9.0, -6.0]))
		var yaw := deg_to_rad(float(Colony.load_layout().get("lander", {}).get("yaw_deg", 35.0)))
		var p := region.snap_to_ground(lp, -0.1)
		lander = spawn_structure(lander_def, p, yaw, true, "lander")
		lander.fixture = true
		# Colonia preinstalada: sectores, módulos, cables y tripulación
		var colony := Colony.new()
		colony.name = "Colony"
		colony.setup(self, region)
		add_child(colony)


## Crea una estructura en el mundo. `built=false` reproduce la animación de construcción.
func spawn_structure(d: BuildableDef, pos: Vector3, yaw: float, built: bool, id: String = "") -> Structure:
	var s := Structure.new()
	if id == "":
		_next_id += 1
		id = "%s_%03d" % [d.id, _next_id]
	s.setup(d, id, built)
	s.name = id
	add_child(s)
	s.global_position = pos
	s.rotation.y = yaw
	return s


## Refugio que contiene el punto (volumen presurizado), o null si está afuera.
func find_shelter_at(pos: Vector3) -> Structure:
	var best: Structure = null
	var best_d := INF
	for s in _structures:
		if s.def.role in SHELTER_ROLES and s.is_built() and s.contains_point(pos):
			var d := s.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = s
	return best


func get_lander() -> Structure:
	return lander if is_instance_valid(lander) else null


func find_nearest_shelter(pos: Vector3) -> Structure:
	var best: Structure = null
	var best_d := INF
	for s in _structures:
		if s.def.role == BuildableDef.Role.SHELTER and s.is_built():
			var d := s.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = s
	return best


func register(s: Structure) -> void:
	if s not in _structures:
		_structures.append(s)
		_recalc_capacity()
		changed.emit()


func unregister(s: Structure) -> void:
	_structures.erase(s)
	_recalc_capacity()
	changed.emit()


func get_structures() -> Array[Structure]:
	return _structures


func has_powered(role: BuildableDef.Role) -> bool:
	for s in _structures:
		if s.def and s.def.role == role and s.is_operational():
			return true
	return false


func _process(delta: float) -> void:
	_acc += delta
	if _acc < TICK:
		return
	var dt := _acc
	_acc = 0.0
	_simulate(dt)


func _simulate(dt: float) -> void:
	var hours := dt * GAME_MINUTES_PER_SECOND / 60.0
	production_kw = 0.0
	demand_kw = 0.0
	var consumers: Array[Structure] = []
	for s in _structures:
		if not s.is_built():
			continue
		var p := s.get_power_kw()
		if p > 0.0:
			p *= solar_multiplier if s.def.role == BuildableDef.Role.SOLAR else 1.0
			production_kw += p
		elif p < 0.0:
			p *= throttle_of(s)
			demand_kw += -p
			consumers.append(s)
	# Prioridad: los más importantes se alimentan primero
	consumers.sort_custom(func(a: Structure, b: Structure) -> bool: return a.def.priority > b.def.priority)
	var available_kw := production_kw + (stored_kwh / hours if hours > 0.0 else 0.0)
	supplied_kw = 0.0
	for s in consumers:
		var t := throttle_of(s)
		var need := -s.get_power_kw() * t
		var ok := available_kw >= need and t > 0.0
		s.set_powered(ok)
		if ok:
			available_kw -= need
			supplied_kw += need
	var net := production_kw - supplied_kw
	stored_kwh = clampf(stored_kwh + net * hours, 0.0, capacity_kwh)
	for s in _structures:
		if s.is_built() and s.is_operational():
			s.simulate(dt * (throttle_of(s) if s.get_power_kw() < 0.0 else 1.0), self)
	changed.emit()


## Grupo de reparto de una instalación ("" = no se regula, p. ej. paneles y baterías).
func group_of(s: Structure) -> String:
	return String(GROUPS.get(s.def.id, "")) if s.def else ""


func throttle_of(s: Structure) -> float:
	var g := group_of(s)
	return float(throttles.get(g, 1.0)) if g != "" else 1.0


func set_throttle(group: String, value: float) -> void:
	if group == "life":
		value = maxf(value, 0.5) # el soporte vital nunca se apaga del todo
	throttles[group] = clampf(value, 0.0, 1.0)
	_simulate(0.0001)


## Demanda (kW) por grupo de reparto, con el reparto actual.
func group_demand() -> Dictionary:
	var out := {"life": 0.0, "food": 0.0, "science": 0.0, "comms": 0.0}
	for s in _structures:
		var g := group_of(s)
		if g != "" and s.is_built():
			out[g] = float(out[g]) - minf(s.get_power_kw(), 0.0) * float(throttles.get(g, 1.0))
	return out


func _recalc_capacity() -> void:
	var cap := 0.0
	for s in _structures:
		if s.def and s.is_built():
			cap += s.def.storage_kwh
	capacity_kwh = maxf(cap + extra_capacity_kwh, 0.1)
	stored_kwh = minf(stored_kwh, capacity_kwh)


func recalc_capacity() -> void:
	_recalc_capacity()
	changed.emit()


## Energía por sector de la colonia (kW consumidos por las instalaciones de cada sector).
func get_sector_demand() -> Dictionary:
	var out := {}
	for s in _structures:
		if not s.is_built():
			continue
		var p := s.get_power_kw()
		var key := String(s.get_sector()) if s.get_sector() != &"" else "base"
		if not out.has(key):
			out[key] = {"demand": 0.0, "production": 0.0, "powered": true}
		if p < 0.0:
			out[key].demand += -p
			if not s.powered:
				out[key].powered = false
		else:
			out[key].production += p * (solar_multiplier if s.def.role == BuildableDef.Role.SOLAR else 1.0)
	return out


func notify_built(_s: Structure) -> void:
	_recalc_capacity()
	changed.emit()


func add_oxygen(kg: float) -> float:
	var add := minf(kg, oxygen_capacity_kg - oxygen_kg)
	oxygen_kg += maxf(add, 0.0)
	return add


func add_water(l: float) -> float:
	var add := minf(l, water_capacity_l - water_l)
	water_l += maxf(add, 0.0)
	return add


## Toma de las reservas para recargar el traje; devuelve lo entregado.
func take_oxygen(kg: float) -> float:
	var t := minf(kg, oxygen_kg)
	oxygen_kg -= t
	return t


func take_water(l: float) -> float:
	var t := minf(l, water_l)
	water_l -= t
	return t


func take_energy_kwh(kwh: float) -> float:
	var t := minf(kwh, stored_kwh)
	stored_kwh -= t
	return t


func take_ration() -> bool:
	if rations <= 0:
		return false
	rations -= 1
	return true


func is_self_sufficient() -> bool:
	return production_kw >= demand_kw and has_powered(BuildableDef.Role.OXYGEN) and has_powered(BuildableDef.Role.WATER)


# --- Saveable ---------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var list: Array = []
	for s in _structures:
		if not s.fixture:
			list.append(s.save_state())
	return {"oxygen_kg": oxygen_kg, "water_l": water_l, "rations": rations, "stored_kwh": stored_kwh,
		"next_id": _next_id, "structures": list, "throttles": throttles.duplicate()}


func load_state(data: Dictionary) -> void:
	var th: Dictionary = data.get("throttles", {})
	for k: String in th:
		throttles[k] = float(th[k])
	# Reconstruir la base guardada
	for s in _structures.duplicate():
		if s.fixture:
			continue # instalaciones preinstaladas: las administra Colony
		s.queue_free()
		_structures.erase(s)
	_next_id = int(data.get("next_id", 0))
	for e: Dictionary in data.get("structures", []):
		var d := DataRegistry.get_def(StringName(e.get("def", ""))) as BuildableDef
		if d == null or (String(e.get("id", "")) == "lander" and get_lander() != null):
			continue
		var s := spawn_structure(d, SaveManager.arr_to_vec3(e.get("pos")), float(e.get("yaw", 0.0)), true, String(e.get("id", "")))
		s.stock = int(e.get("stock", 0))
	_recalc_capacity()
	oxygen_kg = float(data.get("oxygen_kg", oxygen_kg))
	water_l = float(data.get("water_l", water_l))
	rations = int(data.get("rations", rations))
	stored_kwh = float(data.get("stored_kwh", stored_kwh))
	changed.emit()
