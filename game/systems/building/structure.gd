class_name Structure
extends Node3D
## Instalación de la base (hábitat, panel solar, batería, generador de O2, extractor de agua...).
##
## Estados: en construcción (animación de ensamblado) -> operativa / sin energía.
## Cada función se resuelve según `def.role`. Las luces de estado indican el
## funcionamiento (cian = operativa, ámbar = sin energía o sin material).

signal state_changed

const SHELTER_RADIUS := 7.0
## Conversión del generador de O2: kg de oxígeno por kg de regolito procesado.
## El regolito contiene ~40-45 % de oxígeno en masa, pero ningún proceso real
## lo extrae todo: 0,15 es un VALOR DE JUEGO (ver docs/fuentes_y_licencias.md).
const O2_PER_KG_REGOLITH := 0.15
const O2_RATE_KG_PER_MIN := 0.05
## Litros de agua por unidad de hielo (2 kg de mezcla hielo + regolito; valor de juego).
const WATER_PER_ICE_UNIT := 1.2
const WATER_RATE_L_PER_MIN := 0.2

var def: BuildableDef
var structure_id: String = ""
var build_progress: float = 1.0
var powered: bool = true
## Material cargado para procesar (regolito o hielo, en unidades).
var stock: int = 0
var processed_partial: float = 0.0

var _model: Node3D
var _network: BaseNetwork
var _status_light: OmniLight3D
var _interactable: Interactable
var _panel_pivot: Node3D
## Polvo lunar electrostático sobre el panel (evento): rinde menos hasta limpiarlo.
signal dust_cleaned
const DUST_FACTOR := 0.55
var dusty: bool = false
var _clean_point: Interactable
## Inclinación máxima del seguidor solar de un eje (rad).
const PANEL_MAX_TILT := 1.0472 # 60°
var _sun_dir := Vector3(0.0, 1.0, 0.0)
var _in_sun := true
var _sun_check_acc := 0.0
var _hum: AudioStreamPlayer3D
## Instalación preinstalada de la colonia: la guarda y recrea `Colony`, no la red.
var fixture: bool = false
## Multiplicador de velocidad de proceso (mejoras del Taller: catalizador de O₂).
var rate_multiplier: float = 1.0
## Sector de la colonia cuando la definición es compartida (p. ej. paneles del sector Energía).
var sector_override: StringName = &""


func setup(d: BuildableDef, id: String, built: bool) -> void:
	def = d
	structure_id = id
	build_progress = 1.0 if built else 0.0


func _ready() -> void:
	add_to_group(&"structure")
	_model = _create_model()
	add_child(_model)
	if def.model:
		SurfaceMaterials.apply(_model)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 900.0 # más allá no se dibuja (HLOD simple)
		mi.visibility_range_end_margin = 30.0
	_panel_pivot = _model.find_child("Anim_Panel", true, false) as Node3D
	_build_collision()
	_build_lights()
	_build_interaction()
	_network = get_parent() as BaseNetwork
	if _network:
		_network.register(self)
	var sun := get_tree().get_first_node_in_group(&"sun") as DirectionalLight3D
	if sun:
		_sun_dir = sun.global_basis.z.normalized()
	if build_progress < 1.0:
		_play_construction()
	_update_status()


## Modelo de la estructura. Los módulos procedurales de la colonia lo sobrescriben.
func _create_model() -> Node3D:
	return def.model.instantiate() as Node3D


## ¿El punto está dentro del volumen presurizado? Por defecto, radio alrededor
## del centro (módulos GLB sin interior); los módulos con interior usan su volumen.
func contains_point(p: Vector3) -> bool:
	return global_position.distance_to(p) <= SHELTER_RADIUS


## Fracción de dosis que atraviesa el blindaje (1 = nada de blindaje).
func get_sector() -> StringName:
	return sector_override if sector_override != &"" else def.sector


func get_shield_factor() -> float:
	return def.shield_factor


func _exit_tree() -> void:
	if _network:
		_network.unregister(self)


func is_built() -> bool:
	return build_progress >= 1.0


func is_operational() -> bool:
	return is_built() and powered


func set_powered(on: bool) -> void:
	if on != powered:
		powered = on
		_update_status()
		state_changed.emit()


## Potencia actual (kW): los paneles dependen del sol y de las sombras.
func get_power_kw() -> float:
	if not is_built():
		return 0.0
	if def.role == BuildableDef.Role.SOLAR:
		return def.power_kw * get_solar_factor() * (DUST_FACTOR if dusty else 1.0)
	if def.role in [BuildableDef.Role.OXYGEN, BuildableDef.Role.WATER] and stock <= 0:
		return def.power_kw * 0.1 # en espera: consumo mínimo
	return def.power_kw


func set_dusty(on: bool) -> void:
	if on == dusty:
		return
	dusty = on
	if on:
		_clean_point = Interactable.new()
		_clean_point.action_key = "ACTION_CLEAN"
		_clean_point.display_name = tr("EV_DUST_POINT")
		_clean_point.max_distance = 3.0
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.2
		cs.shape = sp
		_clean_point.add_child(cs)
		_clean_point.position = Vector3(0, 1.2, 0)
		add_child(_clean_point)
		_clean_point.interacted.connect(func(by: Node) -> void:
			var p := by as Player
			if p:
				p.perform_action(&"Interact", func() -> void:
					set_dusty(false)
					EventBus.player_action.emit(&"clean"), 0.9))
	else:
		if is_instance_valid(_clean_point):
			_clean_point.queue_free()
		dust_cleaned.emit()
	_update_status()


## Fracción de luz solar que recibe el panel (0 si está en sombra).
## El panel sigue al sol: sin sombra rinde al máximo. En la Luna no hay
## atmósfera que atenúe la luz, pero el relieve puede tapar el sol (sol rasante).
func get_solar_factor() -> float:
	if _sun_dir.y <= 0.0:
		return 0.0
	return 1.0 if _in_sun else 0.0


func simulate(dt: float, net: BaseNetwork) -> void:
	var minutes := dt * BaseNetwork.GAME_MINUTES_PER_SECOND
	match def.role:
		BuildableDef.Role.OXYGEN:
			if stock > 0:
				processed_partial += O2_RATE_KG_PER_MIN * minutes * rate_multiplier
				var per_unit := O2_PER_KG_REGOLITH * _unit_mass(&"regolith")
				while processed_partial >= per_unit and stock > 0:
					processed_partial -= per_unit
					stock -= 1
					net.add_oxygen(per_unit)
		BuildableDef.Role.WATER:
			if stock > 0:
				processed_partial += WATER_RATE_L_PER_MIN * minutes * rate_multiplier
				while processed_partial >= WATER_PER_ICE_UNIT and stock > 0:
					processed_partial -= WATER_PER_ICE_UNIT
					stock -= 1
					net.add_water(WATER_PER_ICE_UNIT)
	_update_status()


func _process(delta: float) -> void:
	if def.role == BuildableDef.Role.SOLAR and is_built():
		_sun_check_acc -= delta
		if _sun_check_acc <= 0.0:
			_sun_check_acc = 2.0
			_check_sunlight()
		if _panel_pivot:
			# Seguidor de un eje: el panel gira sobre el eje X de su caballete hacia el
			# sol, con tope de ±60° (así nunca toca las patas ni el suelo).
			var sl := global_basis.orthonormalized().inverse() * _sun_dir
			var goal := clampf(atan2(sl.z, sl.y), -PANEL_MAX_TILT, PANEL_MAX_TILT)
			_panel_pivot.rotation = Vector3(lerp_angle(_panel_pivot.rotation.x, goal, 1.0 - exp(-1.5 * delta)), 0.0, 0.0)


func _check_sunlight() -> void:
	# Recorre el relieve hacia el sol: si una loma o un borde de cráter queda por
	# encima de la línea de visión, el panel está en sombra.
	var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
	if region == null:
		return
	var origin := global_position + Vector3(0, 2.8, 0)
	var was := _in_sun
	_in_sun = true
	var step := 6.0
	var d := step
	while d < 900.0:
		var p := origin + _sun_dir * d
		var h := region.get_height(p)
		if is_finite(h) and h > p.y:
			_in_sun = false
			break
		d += step
		step = minf(step * 1.08, 25.0)
	if was != _in_sun:
		_update_status()
		state_changed.emit()


# --- Interacción: cargar material / ver estado ---------------------------------

func _build_interaction() -> void:
	_interactable = Interactable.new()
	_interactable.display_name = def.get_display_name()
	_interactable.max_distance = def.footprint_radius + 2.2
	match def.role:
		BuildableDef.Role.OXYGEN:
			_interactable.action_key = "ACTION_LOAD_REGOLITH"
		BuildableDef.Role.WATER:
			_interactable.action_key = "ACTION_LOAD_ICE"
		BuildableDef.Role.SHELTER:
			_interactable.action_key = "ACTION_ENTER_CABIN"
		_:
			_interactable.action_key = "ACTION_INSPECT"
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = def.footprint_radius + 1.0
	shape.shape = sph
	shape.position.y = 1.0
	_interactable.add_child(shape)
	add_child(_interactable)
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null or not is_built():
		return
	var item: StringName = &""
	match def.role:
		BuildableDef.Role.OXYGEN:
			item = &"regolith"
		BuildableDef.Role.WATER:
			item = &"water_ice"
	if item != &"":
		var amount := player.inventory.get_amount(item)
		if amount <= 0:
			var d := DataRegistry.get_def(item)
			EventBus.notification_requested.emit(tr("HUD_NEED_ITEM") % (d.get_display_name() if d else String(item)), &"warning")
			return
		player.face_towards(global_position)
		player.perform_action(&"Interact", _load_material.bind(player, item, amount), 0.35)
	elif def.role == BuildableDef.Role.SHELTER and is_operational():
		var session := get_tree().get_first_node_in_group(&"game_session")
		if session and session.has_method("rest_in_cabin"):
			session.call("rest_in_cabin", self)
	else:
		EventBus.notification_requested.emit(get_status_text(), &"info")
		player.face_towards(global_position)
		player.perform_action(&"Interact")


func _load_material(player: Player, item: StringName, amount: int) -> void:
	if not player.inventory.remove(item, amount):
		return
	stock += amount
	EventBus.structure_loaded.emit(self, item, amount)
	var item_name := DataRegistry.get_def(item).get_display_name()
	EventBus.notification_requested.emit(tr("HUD_LOADED") % [amount, item_name, def.get_display_name()], &"info")
	_update_status()


func get_status_text() -> String:
	var s := def.get_display_name() + " · "
	if not is_built():
		return s + tr("STATUS_BUILDING")
	match def.role:
		BuildableDef.Role.SOLAR:
			return s + (tr("STATUS_SOLAR_OK") % def.power_kw if _in_sun else tr("STATUS_SOLAR_SHADOW"))
		BuildableDef.Role.BATTERY:
			return s + tr("STATUS_BATTERY") % [_network.stored_kwh, _network.capacity_kwh] if _network else s
		BuildableDef.Role.OXYGEN, BuildableDef.Role.WATER:
			if not powered:
				return s + tr("STATUS_NO_POWER")
			return s + tr("STATUS_STOCK") % stock
		_:
			return s + (tr("STATUS_OPERATIONAL") if powered else tr("STATUS_NO_POWER"))


# --- Visual ------------------------------------------------------------------

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 2 | 1 # estructuras + bloquea como terreno
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = def.footprint_radius * 0.85
	shape.height = 2.6
	cs.shape = shape
	cs.position.y = 1.3
	body.add_child(cs)
	add_child(body)


func _build_lights() -> void:
	_status_light = OmniLight3D.new()
	_status_light.omni_range = 4.0
	_status_light.light_energy = 1.2
	_status_light.position = Vector3(0, 1.6, 0)
	var marker := _model.find_child("Light_*", true, false) as Node3D
	if marker:
		_status_light.position = marker.position
	add_child(_status_light)
	if def.role == BuildableDef.Role.SHELTER:
		# Luz de trabajo frente a la entrada: la base se siente refugio (3500 K)
		var flood := SpotLight3D.new()
		flood.light_color = Color(1.0, 0.86, 0.68)
		flood.light_energy = 4.0
		flood.spot_range = 16.0
		flood.spot_angle = 50.0
		flood.position = _status_light.position + Vector3(0, 0.6, 0)
		flood.rotation = Vector3(deg_to_rad(-55.0), PI, 0)
		flood.shadow_enabled = false
		add_child(flood)
	_hum = AudioStreamPlayer3D.new()
	_hum.bus = &"Ambient"
	_hum.unit_size = 3.0
	_hum.max_distance = 18.0
	_hum.volume_db = -10.0
	if ResourceLoader.exists("res://assets/audio/sfx/suit_hum_loop.wav"):
		_hum.stream = load("res://assets/audio/sfx/suit_hum_loop.wav")
	add_child(_hum)


func _update_status() -> void:
	if _status_light == null:
		return
	var ok := is_operational()
	if def.role == BuildableDef.Role.SOLAR:
		ok = is_built() and _in_sun
	elif def.role in [BuildableDef.Role.OXYGEN, BuildableDef.Role.WATER]:
		ok = ok and stock > 0
	_status_light.light_color = SpatiumTheme.CYAN if ok else SpatiumTheme.AMBER
	_status_light.visible = is_built()
	if _hum.stream:
		var should := is_operational() and def.role != BuildableDef.Role.SOLAR
		if should and not _hum.playing:
			_hum.play()
		elif not should and _hum.playing:
			_hum.stop()


## Animación de construcción: las piezas "se despliegan" desde el suelo con chispas.
func _play_construction() -> void:
	_model.scale = Vector3(0.9, 0.02, 0.9)
	var tw := create_tween().set_parallel(false)
	tw.tween_property(_model, "scale", Vector3(0.95, 0.6, 0.95), def.build_time * 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_model, "scale", Vector3.ONE, def.build_time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw2 := create_tween()
	tw2.tween_property(self, "build_progress", 1.0, def.build_time)
	tw2.tween_callback(_on_built)
	_sparks()


func _on_built() -> void:
	if _network:
		_network.notify_built(self)
	_update_status()
	state_changed.emit()
	EventBus.structure_built.emit(self)


func _sparks() -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = def.footprint_radius
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, -1.62, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.75, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.25)
	m.emission_energy_multiplier = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = m
	p.process_material = pm
	p.draw_pass_1 = q
	p.amount = 90
	p.lifetime = 1.2
	p.position.y = 1.0
	add_child(p)
	p.emitting = true
	get_tree().create_timer(def.build_time).timeout.connect(func() -> void: p.emitting = false)
	get_tree().create_timer(def.build_time + 1.5).timeout.connect(p.queue_free)


func _unit_mass(id: StringName) -> float:
	var d := DataRegistry.get_def(id) as ItemDef
	return d.unit_mass_kg if d else 1.0


func is_shelter() -> bool:
	return def.role == BuildableDef.Role.SHELTER and is_operational()


func save_state() -> Dictionary:
	return {"id": structure_id, "def": String(def.id), "pos": SaveManager.vec3_to_arr(global_position),
		"yaw": rotation.y, "stock": stock, "progress": build_progress}
