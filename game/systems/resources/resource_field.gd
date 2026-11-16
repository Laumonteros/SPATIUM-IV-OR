class_name ResourceField
extends Node3D
## Puebla la región: depósitos de recursos, bloques de roca con colisión y
## pedregullo (MultiMesh por celdas, con distancia de visibilidad).
##
## Cada partida nueva usa su propia semilla (se guarda con la partida): el reparto
## cambia entre partidas, pero siempre sigue la geología del terreno:
##  - regolito: en todas partes; montículos finos cerca del sitio de alunizaje,
##  - ilmenita (hierro): vetas de basalto en las llanuras; siempre hay una cerca,
##  - muestras: bloques de eyecta junto a los bordes de cráteres,
##  - hielo: fondo en sombra del cráter grande (Albor).
## Guarda qué depósitos se agotaron o descubrieron (protocolo Saveable).

const SAVE_ID := "resource_field_moon_01"
const MODELS := "res://assets/models/environment/moon/"
const SFX := "res://assets/audio/sfx/"

## tipo -> configuración de generación
const DEPOSITS := {
	&"regolith": {"model": "deposit_regolith.glb", "count": 26, "rule": "near_spawn", "min_r": 12.0, "max_r": 140.0,
		"yield": 5, "harvests": 3, "radius": 0.9, "scale": [0.8, 1.2], "sound": "collect_regolith.wav", "color": Color(0.62, 0.6, 0.56)},
	&"iron": {"model": "deposit_iron.glb", "count": 30, "rule": "veins", "min_r": 45.0, "max_r": 600.0,
		"yield": 3, "harvests": 4, "radius": 0.8, "scale": [0.8, 1.4], "sound": "collect_rock.wav", "color": Color(0.25, 0.25, 0.27)},
	&"geo_sample": {"model": "sample_breccia.glb", "count": 22, "rule": "crater_rims", "min_r": 40.0, "max_r": 900.0,
		"yield": 1, "harvests": 1, "radius": 0.35, "scale": [0.9, 1.3], "sound": "collect_rock.wav", "color": Color(0.7, 0.66, 0.6)},
	&"helium_3": {"model": "deposit_regolith.glb", "count": 7, "rule": "plains", "min_r": 170.0, "max_r": 650.0,
		"yield": 1, "harvests": 2, "radius": 0.8, "scale": [0.7, 1.0], "sound": "collect_crystal.wav", "color": Color(1.0, 0.85, 0.4)},
	&"water_ice": {"model": "deposit_ice.glb", "count": 12, "rule": "albor_floor", "min_r": 0.0, "max_r": 0.0,
		"yield": 2, "harvests": 3, "radius": 0.9, "scale": [0.9, 1.3], "sound": "collect_crystal.wav", "color": Color(0.75, 0.9, 1.0)},
}

@export var region_seed: int = 4_2026
@export var boulder_count: int = 160
@export var pebble_cell_size: float = 96.0
@export var pebbles_per_cell: int = 70
@export var pebble_visibility: float = 170.0
@export var play_radius: float = 760.0

var _region: MoonRegion
var _rng := RandomNumberGenerator.new()
var _deposits: Dictionary[String, ResourceDeposit] = {}
var _pending_state: Dictionary = {}
## Semilla de esta partida (0 = elegir una al azar). Headless (tests): fija.
var world_seed: int = 0
## Riqueza de cada recurso en esta partida (0,7 a 1,4): cada mundo es distinto.
var richness: Dictionary = {}
var _vein_centers: Array[Vector3] = []


var _extra: Array = [] # [{"type", "pos"}] depósitos creados por sucesos


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(&"resource_field")
	_region = get_parent() as MoonRegion
	if world_seed == 0:
		world_seed = 1 if DisplayServer.get_name() == "headless" else (randi() % 2_000_000_000) + 2
	_generate()
	_rng.seed = region_seed
	_spawn_pebbles()
	if not _pending_state.is_empty():
		load_state(_pending_state)


func get_deposits() -> Array[ResourceDeposit]:
	var out: Array[ResourceDeposit] = []
	out.assign(_deposits.values())
	return out


# --- Depósitos ---------------------------------------------------------------

func _generate() -> void:
	_rng.seed = hash(region_seed * 31 + world_seed)
	richness.clear()
	for type: StringName in DEPOSITS:
		richness[type] = _rng.randf_range(0.7, 1.4)
	# vetas de ilmenita: una siempre cerca del inicio, el resto en las llanuras
	_vein_centers.clear()
	for i in 5:
		var c := Vector3.ZERO
		for _try in 30: # el centro de la veta, fuera de la colonia y en terreno transitable
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(75.0, 120.0) if i == 0 else _rng.randf_range(140.0, 600.0)
			c = Vector3(cos(a) * r, 0, sin(a) * r)
			if _is_valid_spot(c, 0.3) and not Colony.is_reserved(c, 25.0):
				break
		_vein_centers.append(c)
	_spawn_deposits()
	_spawn_boulders()


## Lugar libre para un suceso (fuera de la colonia, transitable).
func is_free_spot(p: Vector3) -> bool:
	return _is_valid_spot(p, 0.35) and not _too_close(p, 8.0)


## Crea un depósito nuevo (p. ej. muestras frescas de un impacto). Se guarda.
func spawn_extra(type: StringName, p: Vector3, record := true) -> ResourceDeposit:
	var cfg: Dictionary = DEPOSITS.get(type, {})
	if cfg.is_empty():
		return null
	var dep := ResourceDeposit.new()
	var id := "extra_%s_%03d" % [type, _extra.size() if record else _deposits.size()]
	dep.setup(id, type, load(MODELS + cfg.model), randf_range(cfg.scale[0], cfg.scale[1]), float(cfg.radius))
	dep.name = id
	dep.yield_per_harvest = int(cfg.yield)
	dep.harvests = int(cfg.harvests)
	dep.particle_color = cfg.color
	if ResourceLoader.exists(SFX + cfg.sound):
		dep.collect_sound = load(SFX + cfg.sound)
	add_child(dep)
	dep.global_position = _region.snap_to_ground(p, -0.05)
	dep.discovered = true
	_deposits[id] = dep
	if record:
		_extra.append({"type": String(type), "pos": [p.x, p.y, p.z], "id": id})
	return dep


func _clear_generated() -> void:
	for d: ResourceDeposit in _deposits.values():
		if is_instance_valid(d):
			d.queue_free()
	_deposits.clear()


func _spawn_deposits() -> void:
	for type: StringName in DEPOSITS:
		var cfg: Dictionary = DEPOSITS[type]
		var count := maxi(4, int(round(float(cfg.count) * float(richness.get(type, 1.0)))))
		var model: PackedScene = load(MODELS + cfg.model)
		var sound: AudioStream = load(SFX + cfg.sound) if ResourceLoader.exists(SFX + cfg.sound) else null
		var placed := 0
		var attempts := 0
		while placed < count and attempts < 4000:
			attempts += 1
			var p := _candidate(cfg, placed)
			if p == Vector3.INF or not _is_valid_spot(p, 0.22 if type != &"water_ice" else 0.4):
				continue
			if _too_close(p, 6.0):
				continue
			var dep := ResourceDeposit.new()
			var id := "%s_%02d" % [type, placed]
			var s := _rng.randf_range(cfg.scale[0], cfg.scale[1])
			dep.setup(id, type, model, s, float(cfg.radius))
			dep.name = id
			dep.yield_per_harvest = int(cfg.yield)
			dep.harvests = int(cfg.harvests)
			dep.collect_sound = sound
			dep.particle_color = cfg.color
			add_child(dep)
			dep.global_position = _region.snap_to_ground(p, -0.05)
			dep.rotation.y = _rng.randf() * TAU
			_align_to_ground(dep, 0.6)
			if type == &"iron":
				_ilmenite_look(dep)
			elif type == &"helium_3":
				_helium_look(dep)
			_deposits[id] = dep
			placed += 1


func _candidate(cfg: Dictionary, index: int = 0) -> Vector3:
	match String(cfg.rule):
		"veins":
			# las primeras 6 en la veta cercana; el resto, repartidas en las otras
			var c := _vein_centers[0] if index < 6 else _vein_centers[1 + _rng.randi() % (_vein_centers.size() - 1)]
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(4.0, 26.0)
			return c + Vector3(cos(a) * r, 0, sin(a) * r)
		"near_spawn", "plains":
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf_range(pow(cfg.min_r, 2.0), pow(cfg.max_r, 2.0)))
			return Vector3(cos(a) * r, 0, sin(a) * r)
		"crater_rims":
			var craters: Array = _region.features.get("craters", [])
			if craters.is_empty():
				return Vector3.INF
			var c: Dictionary = craters[_rng.randi() % craters.size()]
			var R := float(c.diameter_m) * 0.5
			var a := _rng.randf() * TAU
			var r := R * _rng.randf_range(1.05, 1.6)
			var p := Vector3(float(c.x) + cos(a) * r, 0, float(c.z) + sin(a) * r)
			return p if p.length() < play_radius else Vector3.INF
		"albor_floor":
			var albor := _find_crater("crater_albor")
			if albor.is_empty():
				return Vector3.INF
			var a := _rng.randf() * TAU
			var r := float(albor.diameter_m) * 0.5 * sqrt(_rng.randf()) * 0.3
			return Vector3(float(albor.x) + cos(a) * r, 0, float(albor.z) + sin(a) * r)
	return Vector3.INF


func _find_crater(id: String) -> Dictionary:
	for c: Dictionary in _region.features.get("craters", []):
		if c.get("id") == id:
			return c
	return {}


## Lugar transitable: dentro del mapa jugable y con pendiente moderada.
func _is_valid_spot(p: Vector3, max_slope_sin: float) -> bool:
	if Vector2(p.x, p.z).length() > play_radius:
		return false
	# fuera de los sectores de la colonia y de sus caminos señalizados
	if Colony.is_reserved(p, 1.0):
		return false
	var h := _region.get_height(p)
	if not is_finite(h):
		return false
	var n := _region.get_normal(p)
	return sqrt(1.0 - n.y * n.y) <= max_slope_sin * 2.2


func _too_close(p: Vector3, dist: float) -> bool:
	for d: ResourceDeposit in _deposits.values():
		if Vector2(d.global_position.x - p.x, d.global_position.z - p.z).length() < dist:
			return true
	return false


func _align_to_ground(node: Node3D, amount: float) -> void:
	var n := _region.get_normal(node.global_position).lerp(Vector3.UP, 1.0 - amount).normalized()
	var yaw := node.rotation.y
	var b := Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, yaw)
	node.global_basis = b.scaled(node.scale)


## La ilmenita se distingue a simple vista: roca negra con brillo metálico y
## cristales tabulares que reflejan el sol (no es una roca gris más).
func _ilmenite_look(dep: ResourceDeposit) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.24, 0.23, 0.25)
	dark.metallic = 0.4
	dark.roughness = 0.42
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.32, 0.34, 0.4)
	crystal.metallic = 0.6
	crystal.roughness = 0.18
	crystal.metallic_specular = 0.9
	crystal.emission_enabled = true # brillo tenue: se distinguen a distancia
	crystal.emission = Color(0.4, 0.45, 0.6)
	crystal.emission_energy_multiplier = 0.12
	for mi: MeshInstance3D in dep.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = CurvedWorld.convert_material(dark) if CurvedWorld.enabled else dark
	var holder: Node3D = dep.get("_model") if dep.get("_model") else dep
	var box := AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 0.6, 1))
	for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			box = mi.mesh.get_aabb()
			break
	for k in 9:
		var shard := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_rng.randf_range(0.05, 0.1), _rng.randf_range(0.1, 0.22), _rng.randf_range(0.02, 0.04)) * clampf(box.size.y, 0.5, 1.5)
		shard.mesh = bm
		shard.material_override = CurvedWorld.convert_material(crystal) if CurvedWorld.enabled else crystal
		# sobre la superficie de la roca (según el tamaño real del modelo)
		var a := _rng.randf() * TAU
		var rr := _rng.randf_range(0.2, 0.55)
		shard.position = Vector3(cos(a) * box.size.x * rr, box.end.y * _rng.randf_range(0.55, 0.9), sin(a) * box.size.z * rr)
		shard.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6))
		holder.add_child(shard)


## Regolito maduro rico en helio-3: tono dorado pálido y un brillo tenue (pista visual
## de juego: el helio-3 real es un gas atrapado en los granos, invisible a simple vista).
func _helium_look(dep: ResourceDeposit) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.72, 0.55)
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.4)
	m.emission_energy_multiplier = 0.22
	for mi: MeshInstance3D in dep.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = CurvedWorld.convert_material(m) if CurvedWorld.enabled else m


# --- Bloques de roca (con colisión) --------------------------------------------

func _spawn_boulders() -> void:
	# Todos los bloques de roca se pueden picar: dan regolito (roca triturada) y
	# los grandes dejan una muestra de brecha al agotarse.
	var scenes: Array[PackedScene] = [load(MODELS + "boulder_a.glb"), load(MODELS + "boulder_b.glb"), load(MODELS + "boulder_c.glb")]
	var shapes: Array[Shape3D] = []
	for sc in scenes:
		shapes.append(MoonMaterials.first_mesh(sc).create_convex_shape(true, true))
	var sound: AudioStream = load(SFX + "collect_rock.wav") if ResourceLoader.exists(SFX + "collect_rock.wav") else null
	var craters: Array = _region.features.get("craters", [])
	var placed := 0
	var attempts := 0
	while placed < boulder_count and attempts < boulder_count * 20:
		attempts += 1
		var p: Vector3
		if craters.size() > 0 and _rng.randf() < 0.65:
			# Bloques de eyecta alrededor de los cráteres
			var c: Dictionary = craters[_rng.randi() % craters.size()]
			var R := float(c.diameter_m) * 0.5
			var a := _rng.randf() * TAU
			p = Vector3(float(c.x) + cos(a) * R * _rng.randf_range(0.9, 2.0), 0, float(c.z) + sin(a) * R * _rng.randf_range(0.9, 2.0))
		else:
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * play_radius
			p = Vector3(cos(a) * r, 0, sin(a) * r)
		if p.length() < 25.0 or not _is_valid_spot(p, 0.45) or _too_close(p, 4.0):
			continue
		var k := _rng.randi() % scenes.size()
		var s := _rng.randf_range(0.5, 1.0) ** 2.0 * 2.6 + 0.35 # muchos chicos, pocos grandes
		var dep := ResourceDeposit.new()
		var id := "boulder_%03d" % placed
		dep.setup(id, &"regolith", scenes[k], s, 1.0, shapes[k])
		dep.name = id
		dep.yield_per_harvest = 3
		dep.harvests = clampi(int(round(s * 1.4)), 1, 4)
		dep.scannable = false
		dep.collect_sound = sound
		dep.particle_color = Color(0.62, 0.6, 0.56)
		if s > 1.6:
			dep.bonus_item = &"geo_sample"
			dep.bonus_amount = 1
		add_child(dep)
		dep.global_position = _region.snap_to_ground(p, -0.12 * s)
		if s < 0.9: # optimización: las rocas chicas no proyectan sombra
			for mi: MeshInstance3D in dep.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dep.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))
		_deposits[id] = dep
		placed += 1


# --- Pedregullo (MultiMesh por celdas) ----------------------------------------

func _spawn_pebbles() -> void:
	var meshes: Array[Mesh] = []
	for f in ["pebble_a.glb", "pebble_b.glb", "pebble_c.glb"]:
		meshes.append(MoonMaterials.first_mesh(load(MODELS + f)))
	var mat := MoonMaterials.get_material("MoonRock")
	var container := Node3D.new()
	container.name = "Pebbles"
	add_child(container)
	var cells := int(ceil(play_radius * 2.0 / pebble_cell_size))
	for cx in cells:
		for cz in cells:
			var origin := Vector3(-play_radius + (cx + 0.5) * pebble_cell_size, 0, -play_radius + (cz + 0.5) * pebble_cell_size)
			if Vector2(origin.x, origin.z).length() > play_radius + pebble_cell_size * 0.5:
				continue
			for m in meshes.size():
				_make_pebble_cell(container, origin, meshes[m], mat, pebbles_per_cell / meshes.size())


func _make_pebble_cell(parent: Node3D, origin: Vector3, mesh: Mesh, mat: Material, count: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xforms: Array[Transform3D] = []
	for i in count:
		var p := origin + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)) * pebble_cell_size
		var h := _region.get_height(p)
		if not is_finite(h):
			continue
		var s := _rng.randf_range(0.04, 0.32) * (1.0 + 2.0 * pow(_rng.randf(), 6.0))
		var b := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3.ONE * s)
		xforms.append(Transform3D(b, Vector3(p.x - origin.x, h - s * 0.25, p.z - origin.z)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.position = origin
	mmi.visibility_range_end = pebble_visibility
	mmi.visibility_range_end_margin = 15.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # optimización: el pedregullo no proyecta sombra
	parent.add_child(mmi)


# --- Protocolo Saveable -----------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var out := {}
	for id: String in _deposits:
		var d := _deposits[id]
		if d.remaining != d.harvests or d.discovered:
			out[id] = {"remaining": d.remaining, "discovered": d.discovered}
	return {"deposits": out, "seed": world_seed, "extra": _extra.duplicate(true)}


func load_state(data: Dictionary) -> void:
	if _deposits.is_empty():
		_pending_state = data
		return
	# partida de otro mundo: se regenera el reparto con su semilla
	var seed := int(data.get("seed", world_seed))
	if seed != world_seed and seed != 0:
		_clear_generated()
		world_seed = seed
		_generate()
	for e: Dictionary in data.get("extra", []):
		if not _deposits.has(String(e.get("id", ""))):
			var pp: Array = e.pos
			var dep := spawn_extra(StringName(e.type), Vector3(float(pp[0]), float(pp[1]), float(pp[2])), false)
			if dep:
				_deposits.erase(dep.name)
				dep.name = String(e.id)
				dep.deposit_id = String(e.id)
				_deposits[String(e.id)] = dep
				_extra.append(e)
	var saved: Dictionary = data.get("deposits", {})
	for id: String in _deposits:
		var d := _deposits[id]
		if saved.has(id):
			d.set_state(int(saved[id].get("remaining", d.harvests)), bool(saved[id].get("discovered", false)))
		else:
			d.set_state(d.harvests, false)
