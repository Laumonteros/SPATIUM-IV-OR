class_name ColonyModule
extends Structure
## Módulo preinstalado de la colonia con interior recorrible (sin pantallas de carga).
##
## Se arma por código con `ModuleBuilder` (no hay FBX en la rama Godot): exterior,
## interior decorado, puertas con piezas móviles, cimentación sobre el relieve y
## rampas. El origen local es el centro del piso terminado; +Z es el frente.
##
## Funciona como cualquier `Structure` de la red: consume energía según su rol,
## se apaga si falta suministro (las luces pasan a emergencia) y es refugio
## presurizado solo dentro de su volumen interior (`interior_volumes`).

## Desplazamiento (m, negativo) desde el piso hasta el punto más bajo del terreno
## bajo la huella: lo calcula `Colony` y se usa para el zócalo.
var ground_drop: float = -0.3
## Ocupante (id de tripulante) para los monoblocks; "" = reserva.
var occupant: StringName = &""
var occupant_name: String = ""
## Número visible en la placa (orden de instalación).
var plate_number: int = 0
## Blindaje mejorado por el Taller (-1 = usar el de la definición).
var shield_override: float = -1.0
## Volúmenes presurizados en coordenadas locales.
var interior_volumes: Array[AABB] = []
## Pantallas con telemetría que se actualizan cada segundo.
var screens: Array[Label3D] = []

var builder: ModuleBuilder
var _lights: Array[OmniLight3D] = []
var _light_base: Dictionary = {}
var _screen_acc := 0.0
var _lights_powered := true


func _create_model() -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	builder = ModuleBuilder.new(model)
	_build_module(builder)
	builder.finalize()
	for l: OmniLight3D in model.find_children("*", "OmniLight3D", true, false):
		_lights.append(l)
		_light_base[l] = [l.light_energy, l.light_color]
	return model


## Lo implementa cada módulo: exterior, interior y piezas interactivas.
func _build_module(_b: ModuleBuilder) -> void:
	pass


func _build_collision() -> void:
	pass # el kit crea colisiones ajustadas a cada pieza


func _build_interaction() -> void:
	pass # cada módulo crea sus propios puntos de uso


func _build_lights() -> void:
	_status_light = OmniLight3D.new()
	_status_light.omni_range = 4.0
	_status_light.light_energy = 1.0
	_status_light.position = status_light_position()
	add_child(_status_light)
	_hum = AudioStreamPlayer3D.new()
	_hum.bus = &"Ambient"
	_hum.unit_size = 3.0
	_hum.max_distance = 14.0
	_hum.volume_db = -14.0
	if ResourceLoader.exists("res://assets/audio/sfx/suit_hum_loop.wav"):
		_hum.stream = load("res://assets/audio/sfx/suit_hum_loop.wav")
	add_child(_hum)


func status_light_position() -> Vector3:
	return Vector3(0, 3.2, 0)


func get_shield_factor() -> float:
	return shield_override if shield_override >= 0.0 else def.shield_factor


## Punto de aparición dentro del módulo (lo redefinen los módulos habitables).
func spawn_point() -> Vector3:
	return global_transform * Vector3(0, 0.05, 0)


func contains_point(p: Vector3) -> bool:
	var lp := global_transform.affine_inverse() * p
	for v in interior_volumes:
		if v.has_point(lp):
			return true
	return false


func _process(delta: float) -> void:
	super._process(delta)
	_screen_acc -= delta
	if _screen_acc <= 0.0:
		_screen_acc = 1.0
		if _lights_powered != is_operational():
			_apply_light_state()
		_update_screens()


## Sin energía: luces de emergencia (rojas, tenues). Con energía: normales.
func _apply_light_state() -> void:
	_lights_powered = is_operational()
	for l in _lights:
		if not is_instance_valid(l):
			continue
		var base: Array = _light_base[l]
		l.light_energy = float(base[0]) if _lights_powered else float(base[0]) * 0.18
		l.light_color = base[1] if _lights_powered else Color(1.0, 0.25, 0.2)


## Cada módulo escribe su telemetría real en `screens`.
func _update_screens() -> void:
	pass


func es() -> bool:
	return TranslationServer.get_locale().begins_with("es")


func colony() -> Colony:
	return get_tree().get_first_node_in_group(&"colony") as Colony


func network() -> BaseNetwork:
	return _network


# --- Construcción común ------------------------------------------------------

## Zócalo/plataforma: la base del módulo apoya en el terreno aunque haya desnivel.
func foundation(b: ModuleBuilder, size: Vector2, margin := 0.4) -> void:
	var h := -ground_drop + 0.35
	b.box(Vector3(size.x + margin * 2.0, h, size.y + margin * 2.0), Vector3(0, -h * 0.5 - 0.2, 0), &"concrete", Vector3.ZERO, &"shell")
	b.box(Vector3(size.x + margin * 2.0 + 0.1, 0.08, size.y + margin * 2.0 + 0.1), Vector3(0, -0.24, 0), &"frame")
	# patas de apoyo regulables en las esquinas
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(Vector3(0.35, h + 0.2, 0.35), Vector3(sx * (size.x * 0.5 + margin), -h * 0.5 - 0.2, sz * (size.y * 0.5 + margin)), &"frame")


## Rampa desde una puerta (posición local en el borde exterior, a nivel del piso)
## hasta el terreno, con pendiente máxima de 14°. `out` = dirección hacia afuera.
func door_ramp(b: ModuleBuilder, at: Vector3, out: Vector3, width := 1.9) -> void:
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	var rise := 0.25
	if region:
		var g := global_transform * (at + out * 2.0)
		var h := region.get_height(g)
		if is_finite(h):
			rise = maxf(global_position.y + at.y - h, 0.05)
	var length := maxf(rise / tan(deg_to_rad(14.0)), 1.0)
	var yaw := atan2(out.x, out.z)
	var angle := atan2(rise, length)
	var hyp := sqrt(length * length + rise * rise)
	var center := at + out * (length * 0.5) + Vector3(0, -rise * 0.5 - 0.06, 0)
	var ramp := b.box(Vector3(width, 0.12, hyp + 0.1), Vector3.ZERO, &"floor", Vector3.ZERO, &"")
	ramp.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
	ramp.position = center
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.12, hyp + 0.1)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = ramp.transform
	b.shell.add_child(cs)
	# barandas laterales (no bloquean el paso)
	var side := Basis(Vector3.UP, yaw) * Vector3(width * 0.5, 0, 0)
	for s: float in [-1.0, 1.0]:
		var a := at + side * s + Vector3(0, 0.95, 0)
		var e := at + out * length + side * s + Vector3(0, 0.95 - rise, 0)
		b.pipe(a, e, 0.03, &"stripe_amber")
		b.pipe(a - Vector3(0, 0.95, 0), a, 0.03, &"frame")
		b.pipe(e - Vector3(0, 0.95, 0), e, 0.03, &"frame")
		# baranda sólida: no se puede caer ni atravesar por el costado de la rampa
		var mid := (a + e) * 0.5 - Vector3(0, 0.45, 0)
		b.collider(Vector3(0.08, 0.9, length), mid, &"shell", Vector3(-angle, yaw, 0))


## Perímetro rectangular de muros con aberturas por lado.
## `openings`: {&"front": [...], &"back": [...], &"left": [...], &"right": [...]},
## cada abertura Vector4(desplazamiento desde el centro del lado, ancho, y inferior, alto).
## Frente = +Z, izquierda = -X (mirando desde adentro hacia el frente, la izquierda es -X).
func perimeter(b: ModuleBuilder, w: float, d: float, h: float, t: float, openings: Dictionary, outer: StringName = &"hull", inner: StringName = &"interior_wall") -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	# lados recorridos en sentido horario visto desde arriba: el revestimiento interior queda adentro
	var sides := {
		&"front": [Vector3(hw + t * 0.5, 0, hd), Vector3(-hw - t * 0.5, 0, hd)],
		&"left": [Vector3(-hw, 0, hd - t * 0.5), Vector3(-hw, 0, -hd + t * 0.5)],
		&"back": [Vector3(-hw - t * 0.5, 0, -hd), Vector3(hw + t * 0.5, 0, -hd)],
		&"right": [Vector3(hw, 0, -hd + t * 0.5), Vector3(hw, 0, hd - t * 0.5)],
	}
	for k: StringName in sides:
		var a: Vector3 = sides[k][0]
		var e: Vector3 = sides[k][1]
		var length := a.distance_to(e)
		var ops: Array[Vector4] = []
		for o: Vector4 in openings.get(k, []):
			# desplazamiento desde el centro -> distancia desde `a`
			ops.append(Vector4(length * 0.5 + o.x - o.y * 0.5, o.y, o.z, o.w))
		b.wall(a, e, h, t, ops, outer, inner)


## Ranuras verticales y nervios del revestimiento exterior.
func hull_ribs(b: ModuleBuilder, w: float, d: float, h: float, t: float, spacing := 1.5, skip: Array = []) -> void:
	for side: float in [-1.0, 1.0]:
		var n := int(d / spacing)
		for i in n + 1:
			var z := -d * 0.5 + i * d / n
			if skip.has(Vector2(side, z)):
				continue
			b.box(Vector3(0.08, h, 0.12), Vector3(side * (w * 0.5 + t * 0.5 + 0.03), h * 0.5, z), &"frame")
		var m := int(w / spacing)
		for i in m + 1:
			var x := -w * 0.5 + i * w / m
			if absf(x) > 1.2 or side < 0.0: # el frente deja libre la puerta
				b.box(Vector3(0.12, h, 0.08), Vector3(x, h * 0.5, side * (d * 0.5 + t * 0.5 + 0.03)), &"frame")
	b.box(Vector3(w + t + 0.2, 0.14, d + t + 0.2), Vector3(0, h + 0.07, 0), &"frame")


## Escudo de regolito: sacos sobre el techo (MultiMesh, una sola llamada de dibujo).
func regolith_shield(b: ModuleBuilder, w: float, d: float, y: float, layers := 2) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bag := BoxMesh.new()
	bag.size = Vector3(0.62, 0.22, 0.42)
	mm.mesh = bag
	var nx := int(w / 0.64)
	var nz := int(d / 0.44)
	mm.instance_count = nx * nz * layers
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0 + global_position.z * 7.0)
	var i := 0
	for l in layers:
		for ix in nx:
			for iz in nz:
				var p := Vector3(-w * 0.5 + 0.32 + ix * 0.64 + (0.16 if l % 2 else 0.0), y + 0.11 + l * 0.2, -d * 0.5 + 0.22 + iz * 0.44)
				var bs := Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)).scaled(Vector3(rng.randf_range(0.9, 1.05), rng.randf_range(0.8, 1.1), 1.0))
				mm.set_instance_transform(i, Transform3D(bs, p))
				i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ModuleBuilder.mat(&"regolith_bag")
	mmi.visibility_range_end = 600.0
	b.root.add_child(mmi)


## Puerta automática en una posición local, mirando hacia `yaw` (frente = +Z local de la puerta).
func add_door(b: ModuleBuilder, pos: Vector3, yaw: float, t := 0.25) -> ModuleDoor:
	var door := ModuleBuilder.mark_dynamic(ModuleDoor.new(t)) as ModuleDoor
	door.name = "Door"
	door.position = pos
	door.rotation.y = yaw
	b.root.add_child(door)
	return door


## Cartel exterior con el nombre del módulo (código cian = información).
func sign_plate(b: ModuleBuilder, pos: Vector3, yaw: float, title: String, subtitle := "") -> Label3D:
	var g := b.group(pos, yaw, "Sign")
	b.box(Vector3(2.2, 0.55, 0.05), Vector3.ZERO, &"frame", Vector3.ZERO, &"", g)
	b.box(Vector3(2.2, 0.04, 0.06), Vector3(0, -0.25, 0), &"light_cyan", Vector3.ZERO, &"", g)
	var l := b.label(title + ("\n" + subtitle if subtitle != "" else ""), Vector3(-1.02, 0.23, 0.03), Vector3.ZERO, 0.0052, Color(0.75, 0.97, 1.0), 390.0, g)
	l.font_size = 26
	l.visibility_range_end = 60.0
	return l
