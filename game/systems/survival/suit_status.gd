class_name SuitStatus
extends Node
## Soporte vital del traje: oxígeno, agua, alimento, energía e integridad.
##
## Afuera, los consumibles bajan con el tiempo (más rápido al correr y con las
## luces encendidas). Dentro del radio de un refugio con energía se recargan
## desde las reservas de la base. Si el oxígeno se agota, el control de misión
## ordena el regreso de emergencia al refugio (se pierde parte de la carga).
## Los ritmos son VALORES DE JUEGO (comprimidos); ver docs/fuentes_y_licencias.md.

signal vitals_changed
signal sheltered_changed(sheltered: bool)

const SAVE_ID := "suit_status"
const VITALS := [&"oxygen", &"energy", &"water", &"food"]

## Porcentaje por minuto real afuera (valores de juego).
@export var oxygen_rate: float = 11.0 # ~9 min de autonomía
@export var energy_rate: float = 6.0
@export var water_rate: float = 3.5
@export var food_rate: float = 2.2
@export var run_multiplier: float = 1.6
@export var light_energy_cost: float = 4.0

var values: Dictionary[StringName, float] = {&"oxygen": 100.0, &"energy": 100.0, &"water": 100.0, &"food": 100.0}
var integrity: float = 100.0
var sheltered: bool = false

var _alert_level: Dictionary[StringName, int] = {}
var _alarm: AudioStreamPlayer
var _acc := 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	_alarm = AudioStreamPlayer.new()
	_alarm.bus = &"Suit"
	if ResourceLoader.exists("res://assets/audio/sfx/ui_deny.wav"):
		_alarm.stream = load("res://assets/audio/sfx/ui_deny.wav")
	add_child(_alarm)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.25:
		return
	var dt := _acc
	_acc = 0.0
	var player := owner as Player
	if not player.input_enabled:
		return # intro o menú: el tiempo de la misión todavía no corre
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	# Refugio = estar dentro del volumen presurizado de un módulo con energía
	var shelter: Structure = net.find_shelter_at(player.global_position) if net else null
	var inside := shelter != null and shelter.is_operational()
	if inside != sheltered:
		sheltered = inside
		sheltered_changed.emit(sheltered)
		if sheltered:
			EventBus.player_action.emit(&"shelter")
		AudioManager.set_vacuum(not sheltered)
	player.camera_rig.set_interior(shelter is ColonyModule) # cámara más cerca en interiores
	var minutes := dt / 60.0
	if player.vehicle != null:
		vitals_changed.emit() # cabina presurizada: el traje no consume
		return
	if sheltered:
		_refill(net, minutes)
	else:
		var hv := Vector2(player.velocity.x, player.velocity.z).length()
		var run := run_multiplier if hv > player.walk_speed * 1.2 else 1.0
		values[&"oxygen"] -= oxygen_rate * run * minutes
		values[&"water"] -= water_rate * minutes
		values[&"food"] -= food_rate * minutes
		values[&"energy"] -= (energy_rate * run + (light_energy_cost if player.flashlight_on else 0.0)) * minutes
	for k: StringName in VITALS:
		values[k] = clampf(values[k], 0.0, 100.0)
	if values[&"energy"] <= 0.0 and player.flashlight_on:
		player.set_flashlight(false)
	_check_alerts()
	if values[&"oxygen"] <= 0.0:
		_emergency_return()
	vitals_changed.emit()


func _refill(net: BaseNetwork, minutes: float) -> void:
	# ~40 %/min de recarga, limitada por las reservas de la base
	var step := 40.0 * minutes
	var need_o2 := minf(step, 100.0 - values[&"oxygen"])
	values[&"oxygen"] += net.take_oxygen(need_o2 * 0.01) * 100.0
	var need_w := minf(step, 100.0 - values[&"water"])
	values[&"water"] += net.take_water(need_w * 0.02) * 50.0
	var need_e := minf(step, 100.0 - values[&"energy"])
	values[&"energy"] += net.take_energy_kwh(need_e * 0.01) * 100.0
	if values[&"food"] < 60.0 and net.take_ration():
		values[&"food"] = minf(100.0, values[&"food"] + 40.0)


func get_value(vital: StringName) -> float:
	return values.get(vital, 0.0)


func _check_alerts() -> void:
	for k: StringName in VITALS:
		var lvl := 0
		if values[k] <= 10.0:
			lvl = 2
		elif values[k] <= 25.0:
			lvl = 1
		var prev: int = _alert_level.get(k, 0)
		if lvl > prev:
			EventBus.vital_alert.emit(k, &"critical" if lvl == 2 else &"low")
			if _alarm.stream:
				_alarm.play()
		_alert_level[k] = lvl


func _emergency_return() -> void:
	var player := owner as Player
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	var shelter: Structure = net.find_nearest_shelter(player.global_position) if net else null
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	# Se pierde la mitad de la carga: el traje la descarta para volver más rápido
	for id: StringName in player.inventory.get_all():
		player.inventory.remove(id, player.inventory.get_amount(id) / 2)
	if colony and colony.get_player_home():
		# Rescate: el equipo de la colonia lo lleva de vuelta a su monoblock
		player.global_position = colony.get_player_home().spawn_point() + Vector3(0, 0.2, 0)
		player.velocity = Vector3.ZERO
	elif shelter:
		var region := get_tree().get_first_node_in_group(&"world_region") as MoonRegion
		var p := shelter.global_position + Vector3(0, 0, Structure.SHELTER_RADIUS * 0.5)
		player.global_position = region.snap_to_ground(p, 0.3) if region else p
		player.velocity = Vector3.ZERO
	values[&"oxygen"] = 35.0
	values[&"energy"] = maxf(values[&"energy"], 30.0)
	EventBus.player_rescued.emit()


# --- Saveable ---------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var out := {}
	for k: StringName in VITALS:
		out[String(k)] = values[k]
	out["integrity"] = integrity
	return out


func load_state(data: Dictionary) -> void:
	for k: StringName in VITALS:
		values[k] = float(data.get(String(k), 100.0))
	integrity = float(data.get("integrity", 100.0))
	vitals_changed.emit()
