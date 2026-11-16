class_name Monoblock
extends ColonyModule
## Monoblock habitacional: vivienda individual (1 por tripulante).
##
## 6,4 × 9 m, una planta de 2,9 m. Esclusa de doble puerta al frente con
## casilleros de traje; ambiente principal con cama, escritorio y terminal,
## cocina compacta, mesa, estantes con objetos personales y ventanas reales.
## Cama (E): descansar, comer, recargar y guardar (solo la propia o una de reserva).
## Escritorio (E): terminal de estado de la colonia.

const W := 6.4
const D := 9.0
const H := 2.9
const T := 0.25
const AIRLOCK_Z := 2.55 # tabique interior de la esclusa

var _bed_spot: Interactable
var _desk_spot: Interactable


func _build_module(b: ModuleBuilder) -> void:
	foundation(b, Vector2(W, D))
	b.slab(Vector3(W + T, 0.2, D + T), Vector3.ZERO, &"floor")
	b.box(Vector3(W + T, 0.25, D + T), Vector3(0, H + 0.125, 0), &"hull", Vector3.ZERO, &"shell")
	perimeter(b, W, D, H, T, {
		&"front": [Vector4(0, ModuleDoor.WIDTH + 0.3, 0, ModuleDoor.HEIGHT + 0.15)],
		&"left": [Vector4(1.2, 1.2, 1.0, 0.9)], # ventana junto a la cama
		&"right": [Vector4(-0.3, 1.2, 1.0, 0.9)], # ventana de la mesa
		&"back": [Vector4(-0.2, 1.0, 1.05, 0.8)], # ventana sobre el escritorio
	})
	hull_ribs(b, W, D, H, T)
	regolith_shield(b, W - 0.2, D - 0.4, H + 0.25, 2)
	add_door(b, Vector3(0, 0, D * 0.5), 0.0, T)
	door_ramp(b, Vector3(0, 0, D * 0.5 + T * 0.5 + 0.05), Vector3(0, 0, 1))
	_exterior_details(b)
	_airlock(b)
	_main_room(b)
	interior_volumes = [AABB(Vector3(-W * 0.5, 0.0, -D * 0.5), Vector3(W, H, D - 0.1))]


func _exterior_details(b: ModuleBuilder) -> void:
	var title := "MONOBLOCK %02d" % plate_number
	var who := occupant_name if occupant_name != "" else (tr("COLONY_RESERVE"))
	sign_plate(b, Vector3(-2.0, 2.55, D * 0.5 + T * 0.5 + 0.06), 0.0, title, who)
	# franjas naranjas (familia visual del Hábitat Spatium)
	for y: float in [0.45, H - 0.25]:
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(0.06, 0.16, D + 0.1), Vector3(s * (W * 0.5 + T * 0.5 + 0.1), y, 0), &"paint_orange")
		b.box(Vector3(W + 0.1, 0.16, 0.06), Vector3(0, y, -D * 0.5 - T * 0.5 - 0.1), &"paint_orange")
		if y > 1.0:
			b.box(Vector3(W + 0.1, 0.16, 0.06), Vector3(0, y, D * 0.5 + T * 0.5 + 0.1), &"paint_orange")
	# luces de acceso a cada lado de la puerta
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.12, 0.3, 0.08), Vector3(s * 1.05, 2.1, D * 0.5 + T * 0.5 + 0.05), &"light_cyan")
	b.omni(Vector3(0, 2.6, D * 0.5 + 1.0), Color(1.0, 0.88, 0.7), 1.6, 6.0)
	# radiador lateral, antena y caja eléctrica con su conducto
	b.box(Vector3(0.08, 1.6, 3.0), Vector3(W * 0.5 + T + 0.35, 1.6, -1.5), &"hull_panel", Vector3.ZERO, &"shell")
	b.collider(Vector3(0.5, 2.4, 3.0), Vector3(W * 0.5 + T + 0.3, 1.2, -1.5)) # radiador y su soporte
	for i in 6:
		b.box(Vector3(0.1, 1.5, 0.04), Vector3(W * 0.5 + T + 0.38, 1.6, -2.8 + i * 0.52), &"frame")
	b.pipe(Vector3(W * 0.5 + T * 0.5, 1.0, -1.5), Vector3(W * 0.5 + T + 0.33, 1.0, -1.5), 0.05, &"metal")
	b.pipe(Vector3(-1.8, H + 0.7, -3.0), Vector3(-1.8, H + 2.2, -3.0), 0.03, &"metal")
	b.sphere(0.06, Vector3(-1.8, H + 2.25, -3.0), &"light_red")
	b.box(Vector3(0.5, 0.7, 0.25), Vector3(-W * 0.5 - T * 0.5 - 0.13, 0.8, 2.0), &"frame", Vector3.ZERO, &"shell")
	b.box(Vector3(0.3, 0.05, 0.02), Vector3(-W * 0.5 - T * 0.5 - 0.26, 1.05, 2.0), &"light_amber", Vector3(0, -PI * 0.5, 0))


func _airlock(b: ModuleBuilder) -> void:
	# Tabique de la esclusa con segunda puerta (no hay aire afuera: dos puertas)
	var hw := W * 0.5
	var ops: Array[Vector4] = [Vector4(hw - (ModuleDoor.WIDTH + 0.3) * 0.5, ModuleDoor.WIDTH + 0.3, 0, ModuleDoor.HEIGHT + 0.15)]
	b.wall(Vector3(-hw, 0, AIRLOCK_Z), Vector3(hw, 0, AIRLOCK_Z), H, 0.15, ops, &"interior_trim", &"interior_wall")
	add_door(b, Vector3(0, 0, AIRLOCK_Z), 0.0, 0.15)
	b.detail = true
	# casilleros de traje, banco y cartel de procedimiento
	b.locker(Vector3(-2.6, 0, 3.55), PI * 0.5, 2)
	b.box(Vector3(0.45, 0.45, 1.4), Vector3(2.85, 0.23, 3.5), &"interior_trim", Vector3.ZERO, &"furniture")
	b.box(Vector3(0.45, 0.06, 1.4), Vector3(2.85, 0.48, 3.5), &"fabric_blue")
	b.box(Vector3(0.04, 0.8, 1.1), Vector3(W * 0.5 - 0.02, 1.6, 3.5), &"interior_trim")
	b.label(tr("COLONY_AIRLOCK_STEPS"), Vector3(W * 0.5 - 0.05, 1.95, 3.0), Vector3(0, -PI * 0.5, 0), 0.0035, Color(1.0, 0.85, 0.5), 300.0).font_size = 22
	b.box(Vector3(0.3, 0.5, 0.2), Vector3(-0.9, 1.7, AIRLOCK_Z + 0.18), &"pipe_white") # manómetro
	b.cyl(0.08, 0.02, Vector3(-0.9, 1.8, AIRLOCK_Z + 0.29), &"screen_cyan", Vector3(PI * 0.5, 0, 0), &"", 12)
	b.box(Vector3(W - 0.3, 0.02, 1.7), Vector3(0, 0.02, 3.5), &"stripe_amber")
	b.ceiling_light(Vector3(0, H - 0.05, 3.55), Color(1.0, 0.95, 0.88), 0.9, 4.0)
	b.detail = false


func _main_room(b: ModuleBuilder) -> void:
	b.detail = true
	var hw := W * 0.5
	var hd := D * 0.5
	# Cama (contra la pared izquierda, bajo la ventana)
	b.bed(Vector3(-hw + 0.6, 0, -hd + 1.25), 0.0)
	b.shelf(Vector3(-hw + 0.2, 0, 0.4), PI * 0.5, 1.4, 3, true)
	b.box(Vector3(0.6, 0.5, 0.45), Vector3(-hw + 0.45, 0.25, -hd + 2.6), &"interior_trim", Vector3.ZERO, &"furniture") # mesa de luz
	b.box(Vector3(0.14, 0.03, 0.08), Vector3(-hw + 0.45, 0.52, -hd + 2.55), &"screen_dark")
	# Escritorio con terminal personal y pantalla de telemetría (pared del fondo)
	b.desk(Vector3(1.6, 0, -hd + 0.5), 0.0, 1.6)
	b.chair(Vector3(1.6, 0, -hd + 1.25), 0.0)
	screens.append(b.wall_screen(Vector3(1.6, 1.55, -hd + 0.14), 0.0, Vector2(1.3, 0.7)))
	b.rack(Vector3(hw - 0.35, 0, -hd + 0.45), -PI * 0.5, 1.6)
	# Casillero personal y cocina (pared derecha)
	b.locker(Vector3(hw - 0.3, 0, -1.4), -PI * 0.5, 2)
	b.kitchenette(Vector3(hw - 0.32, 0, 1.1), -PI * 0.5)
	# Mesa común con dos bancos
	b.table(Vector3(-1.2, 0, 0.9), 0.0, Vector2(1.1, 0.75), 2) # fuera del pasillo central
	# Ropa y objetos de la vida cotidiana
	b.box(Vector3(0.5, 0.06, 0.4), Vector3(-hw + 0.55, 0.66, -hd + 2.0), &"fabric_orange", Vector3(0, 0.3, 0)) # remera doblada
	b.box(Vector3(2.2, 0.02, 1.4), Vector3(0.2, 0.02, -1.6), &"fabric_gray")
	b.cyl(0.1, 0.5, Vector3(hw - 0.3, 2.6, 2.3), &"pipe_blue", Vector3(PI * 0.5, 0, 0), &"", 12) # depósito de agua
	# Servicios del techo y luces
	b.ceiling_services(Vector3(-hw + 0.6, H - 0.25, hd - 2.2), Vector3(-hw + 0.6, H - 0.25, -hd + 0.3))
	b.ceiling_services(Vector3(hw - 0.6, H - 0.25, -hd + 0.3), Vector3(hw - 0.6, H - 0.25, hd - 2.2))
	b.ceiling_light(Vector3(0, H - 0.05, -2.6), Color(1.0, 0.9, 0.78), 1.5, 6.0)
	b.ceiling_light(Vector3(0, H - 0.05, 0.8), Color(1.0, 0.9, 0.78), 1.3, 6.0)
	b.omni(Vector3(-hw + 0.6, 1.2, -hd + 0.6), Color(1.0, 0.75, 0.5), 0.5, 2.5) # luz de lectura
	# Zócalo con luces guía (salida de emergencia)
	for z: float in [-3.5, -1.5, 0.5, 2.0]:
		b.box(Vector3(0.02, 0.04, 0.3), Vector3(-hw + 0.14, 0.12, z), &"light_green")
	b.detail = false
	_bed_spot = b.interactable(Vector3(-hw + 0.6, 0.7, -hd + 1.3), "ACTION_REST", tr("COLONY_BED"), 0.7, 2.0)
	_bed_spot.interacted.connect(_on_bed)
	_desk_spot = b.interactable(Vector3(1.6, 1.0, -hd + 0.9), "ACTION_USE_TERMINAL", tr("COLONY_TERMINAL_STATUS"), 0.6, 2.0)
	_desk_spot.interacted.connect(_on_desk)


func _on_bed(by: Node) -> void:
	if occupant != &"" and occupant != &"player":
		EventBus.notification_requested.emit(tr("COLONY_BED_TAKEN") % occupant_name, &"info")
		return
	if not is_operational():
		EventBus.notification_requested.emit(tr("STATUS_NO_POWER"), &"warning")
		return
	var session := get_tree().get_first_node_in_group(&"game_session")
	if session and session.has_method("rest_in_cabin"):
		session.call("rest_in_cabin", self)
	elif by is Player:
		(by as Player).perform_action(&"Interact")


func _on_desk(by: Node) -> void:
	var c := colony()
	if c:
		c.open_terminal(&"status", self, by)


func _update_screens() -> void:
	if screens.is_empty() or _network == null:
		return
	var c := colony()
	var n := _network
	var es_ := es()
	var txt := ("MONOBLOCK · %s\n" % (occupant_name if occupant_name != "" else tr("COLONY_RESERVE")))
	txt += ("ENERGÍA  %.1f/%.1f kWh  (%+.1f kW)\n" if es_ else "POWER  %.1f/%.1f kWh  (%+.1f kW)\n") % [n.stored_kwh, n.capacity_kwh, n.production_kw - n.supplied_kw]
	txt += ("O₂ %.1f kg · AGUA %.0f L · RACIONES %d\n" if es_ else "O₂ %.1f kg · WATER %.0f L · RATIONS %d\n") % [n.oxygen_kg, n.water_l, n.rations]
	if c:
		txt += c.short_status_line()
	txt += ("\nESTADO: %s" % (tr("STATUS_OPERATIONAL") if is_operational() else tr("STATUS_NO_POWER")))
	screens[0].text = txt


func get_status_text() -> String:
	return "%s · %s" % [def.get_display_name(), occupant_name if occupant_name != "" else tr("COLONY_RESERVE")]


## Consumo: ocupado = soporte vital completo; reserva = mantenimiento mínimo.
func get_power_kw() -> float:
	if not is_built():
		return 0.0
	return def.power_kw if occupant != &"" else def.power_kw * 0.2


## Punto de aparición dentro del monoblock (junto a la cama, mirando a la puerta).
func spawn_point() -> Vector3:
	return global_transform * Vector3(0.4, 0.05, -1.0)
