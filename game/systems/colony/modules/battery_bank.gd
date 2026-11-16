class_name BatteryBank
extends ColonyModule
## Banco de baterías del sector Energía: seis gabinetes de ion-litio, transformador
## y caja de conexiones con los bornes de los cables (paneles → banco → base).
##
## Las barras de LED de cada gabinete muestran el estado de carga real de la red.
## Instalación exterior: no tiene interior presurizado.

const CABINETS := 6
const SEGMENTS := 5

var _leds: Array[MeshInstance3D] = []
## Bornes de conexión (posiciones locales): entradas de paneles y salida a la base.
const CONNECTORS := {
	"in_0": Vector3(-3.6, 0.6, 0.9),
	"in_1": Vector3(-3.6, 0.6, -0.9),
	"out_base": Vector3(3.9, 0.6, 0.0),
}


func _build_module(b: ModuleBuilder) -> void:
	b.box(Vector3(9.0, 0.3, 4.2), Vector3(0, -0.15, 0), &"concrete", Vector3.ZERO, &"shell")
	var drop := -ground_drop + 0.3
	b.box(Vector3(9.0, drop, 4.2), Vector3(0, -0.3 - drop * 0.5, 0), &"concrete")
	for i in CABINETS:
		var x := -2.6 + i * 1.04
		b.box(Vector3(0.95, 1.9, 1.2), Vector3(x, 0.95, 0.2), &"hull_panel", Vector3.ZERO, &"shell")
		b.box(Vector3(0.9, 1.8, 0.02), Vector3(x, 0.95, 0.81), &"hull", Vector3.ZERO)
		b.box(Vector3(0.6, 0.05, 0.03), Vector3(x, 1.7, 0.82), &"stripe_amber")
		for k in 4:
			b.box(Vector3(0.5, 0.02, 0.01), Vector3(x, 0.3 + k * 0.06, 0.83), &"frame")
		for s in SEGMENTS:
			var led := ModuleBuilder.mark_dynamic(b.box(Vector3(0.12, 0.08, 0.02), Vector3(x - 0.3, 0.75 + s * 0.12, 0.83), &"light_green")) as MeshInstance3D
			_leds.append(led)
		b.box(Vector3(0.95, 0.08, 1.25), Vector3(x, 1.94, 0.2), &"frame")
	# transformador con aletas de disipación
	b.box(Vector3(1.4, 1.5, 1.4), Vector3(3.6, 0.75, -0.6), &"armor", Vector3.ZERO, &"shell")
	for k in 6: # aletas de disipación del lado este
		b.box(Vector3(0.04, 1.2, 1.2), Vector3(4.33 + k * 0.08, 0.75, -0.6), &"frame")
	b.cyl(0.08, 0.5, Vector3(3.3, 1.75, -0.6), &"plastic", Vector3.ZERO, &"", 10)
	b.cyl(0.08, 0.5, Vector3(3.9, 1.75, -0.6), &"plastic", Vector3.ZERO, &"", 10)
	# caja de conexiones de entrada (paneles) y salida (base)
	b.box(Vector3(0.6, 1.0, 2.4), Vector3(-3.6, 0.5, 0.0), &"frame", Vector3.ZERO, &"shell")
	for k: String in CONNECTORS:
		var p: Vector3 = CONNECTORS[k]
		b.cyl(0.12, 0.25, p, &"stripe_amber", Vector3(0, 0, PI * 0.5), &"", 10)
	b.box(Vector3(0.5, 1.0, 0.6), Vector3(3.9, 0.5, 0.6), &"frame", Vector3.ZERO, &"shell")
	# vallado perimetral bajo (no corta el paso hacia el frente)
	for x: float in [-4.4, 4.4]:
		for z: float in [-2.0, 2.0]:
			b.cyl(0.04, 1.1, Vector3(x, 0.55, z), &"stripe_amber", Vector3.ZERO, &"furniture", 6)
	b.pipe(Vector3(-4.4, 1.0, -2.0), Vector3(4.4, 1.0, -2.0), 0.025, &"stripe_amber")
	b.box(Vector3(0.8, 0.5, 0.03), Vector3(0, 1.4, -2.02), &"stripe_amber")
	b.label("⚡ 400 V CC", Vector3(-0.35, 1.5, -2.04), Vector3(0, PI, 0), 0.008, Color(0.1, 0.1, 0.1), 200.0)
	screens.append(b.terminal(Vector3(-1.0, 0, 1.7), 0.0, "", &"light_amber", true))
	sign_plate(b, Vector3(0.0, 2.6, 0.85), 0.0, tr("COLONY_BATTERY_BANK").to_upper(), tr("COLONY_SECTOR_ENERGY"))
	b.omni(Vector3(0, 2.8, 2.2), Color(1.0, 0.85, 0.55), 1.6, 7.0)
	var it := b.interactable(Vector3(-1.0, 1.1, 2.3), "ACTION_USE_TERMINAL", tr("POWER_TITLE"), 0.6, 2.0)
	it.interacted.connect(func(by: Node) -> void:
		var col := colony()
		if col:
			col.open_terminal(&"power", self, by))


func status_light_position() -> Vector3:
	return Vector3(0, 2.4, 0.3)


func contains_point(_p: Vector3) -> bool:
	return false


func connector_global(id: String) -> Vector3:
	return global_transform * (CONNECTORS.get(id, Vector3.ZERO) as Vector3)


func _update_screens() -> void:
	if _network == null:
		return
	var soc := _network.stored_kwh / maxf(_network.capacity_kwh, 0.01)
	var lit := int(round(soc * SEGMENTS))
	for i in _leds.size():
		var seg := i % SEGMENTS
		_leds[i].material_override = ModuleBuilder.mat(&"light_green" if seg < lit and soc > 0.25 else (&"light_amber" if seg < lit else &"frame"))
	if screens.is_empty():
		return
	var es_ := es()
	var c := colony()
	var t := ("BANCO DE BATERÍAS\nCarga %3d %%  %.1f / %.1f kWh\n" if es_ else "BATTERY BANK\nCharge %3d %%  %.1f / %.1f kWh\n") % [int(soc * 100.0), _network.stored_kwh, _network.capacity_kwh]
	t += ("Producción %.1f kW · Consumo %.1f kW\n" if es_ else "Output %.1f kW · Load %.1f kW\n") % [_network.production_kw, _network.supplied_kw]
	if c:
		t += c.cable_status_line()
	screens[0].text = t


func get_status_text() -> String:
	if _network == null:
		return def.get_display_name()
	return tr("STATUS_BATTERY") % [_network.stored_kwh, _network.capacity_kwh] + " · " + def.get_display_name()
