class_name RadiationSystem
extends Node
## Radiación espacial (sección 12): fondo constante + evento solar basado en datos reales.
##
## - Fondo (dato real): Chang'e 4 midió ~1369 µSv/día en la superficie lunar.
## - Evento: recreación de la tormenta solar del 10-11 de mayo de 2024 (NASA DONKI).
##   La hora real entre la fulguración y la llegada de protones >100 MeV se convierte
##   en 60 s de aviso (1 s real = 1 min de juego). La intensidad del pico y los
##   factores de blindaje son VALORES DE JUEGO; el juego lo indica en pantalla.
## El blindaje protege en parte, no por completo (hábitat con sacos de regolito: 85 %).

signal phase_changed(phase: StringName)
signal dose_changed(total_msv: float, rate_usv_h: float)

const DATA := "res://data/science/space_weather_may2024.json"
const SAVE_ID := "radiation"
## Factores de transmisión (fracción de dosis que pasa). Valores de juego.
const SHIELD_HABITAT := 0.15
const SHIELD_LANDER := 0.45
## Multiplicador del pico del evento sobre el fondo (valor de juego).
const STORM_MULTIPLIER := 400.0
const STORM_DURATION := 150.0

var data: Dictionary = {}
var phase: StringName = &"calm" # calm, warning, storm, over
var total_msv: float = 0.0
var rate_usv_h: float = 0.0
var countdown: float = 0.0
var storm_left: float = 0.0
var event_done: bool = false
var peak_dose_msv: float = 0.0
## Multiplicador de dosis dentro de un refugio (0,5 si se reforzó el blindaje).
var shield_boost: float = 1.0
## Fulguración real (DONKI) del evento en curso.
var flare: Dictionary = {}

var _player: Player
var _elapsed := 0.0
var _trigger_after: float = 480.0
var _geiger: AudioStreamPlayer
var _acc := 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(&"radiation_system")
	add_to_group(&"session_ui")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary:
		data = parsed
	_geiger = AudioStreamPlayer.new()
	_geiger.bus = &"Suit"
	if ResourceLoader.exists("res://assets/audio/sfx/geiger_loop.wav"):
		_geiger.stream = load("res://assets/audio/sfx/geiger_loop.wav")
	add_child(_geiger)


func bind_session(session: GameSession) -> void:
	_player = session.player
	if GameState.is_unlocked(&"evaluator_mode"):
		_trigger_after = 150.0


func background_usv_per_hour() -> float:
	return float(data.get("background_dose", {}).get("value_usv_per_day", 1369.0)) / 24.0


func flare_delay_minutes() -> float:
	return float(data.get("derived", {}).get("flare_to_protons_minutes", 60.0))


func shield_factor() -> float:
	if _player == null:
		return 1.0
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	var s: Structure = net.find_shelter_at(_player.global_position) if net else null
	if s:
		if s.def.id == &"habitat":
			return SHIELD_HABITAT * shield_boost
		if s.def.id == &"lander":
			return SHIELD_LANDER * shield_boost
		return s.get_shield_factor() * shield_boost
	return 1.0


## Dispara el evento (lo usan las misiones, el modo evaluador y los tests).
func start_event(force := false, flare_data: Dictionary = {}) -> void:
	if phase in [&"warning", &"storm"] or (event_done and not force):
		return
	flare = flare_data
	phase = &"warning"
	countdown = flare_delay_minutes() / BaseNetwork.GAME_MINUTES_PER_SECOND # minutos de juego -> s reales
	phase_changed.emit(phase)
	var es := TranslationServer.get_locale().begins_with("es")
	EventBus.radiation_event.emit(&"warning",
		"ALERTA SOLAR · Fulguración detectada. Protones de alta energía en camino: llegan en %d s. Buscá refugio en el hábitat." % int(countdown) if es
		else "SOLAR ALERT · Flare detected. High-energy protons inbound: arrival in %d s. Take shelter in the habitat." % int(countdown))


func _process(delta: float) -> void:
	if _player == null or not _player.input_enabled or get_tree().paused:
		return
	_elapsed += delta
	if phase == &"calm" and not event_done and _elapsed >= _trigger_after:
		start_event()
	match phase:
		&"warning":
			countdown -= delta
			if countdown <= 0.0:
				phase = &"storm"
				storm_left = STORM_DURATION
				peak_dose_msv = 0.0
				phase_changed.emit(phase)
				EventBus.radiation_event.emit(&"storm", "")
				if _geiger.stream:
					_geiger.play()
		&"storm":
			storm_left -= delta
			if storm_left <= 0.0:
				phase = &"over"
				event_done = true
				_geiger.stop()
				phase_changed.emit(phase)
				EventBus.radiation_event.emit(&"over", _debrief())
				RadioPanel.say("flare_clear")
				EventBus.player_action.emit(&"storm_over")
				shield_boost = 1.0
	_acc += delta
	if _acc >= 0.25:
		_integrate(_acc)
		_acc = 0.0


func _integrate(dt: float) -> void:
	var mult := 1.0
	if phase == &"storm":
		# Perfil del evento: subida rápida y caída lenta
		var t := 1.0 - storm_left / STORM_DURATION
		mult = 1.0 + STORM_MULTIPLIER * minf(t * 6.0, 1.0) * pow(1.0 - t, 1.5)
	rate_usv_h = background_usv_per_hour() * mult * shield_factor()
	var game_hours := dt * BaseNetwork.GAME_MINUTES_PER_SECOND / 60.0
	var add := rate_usv_h * game_hours / 1000.0
	total_msv += add
	if phase == &"storm":
		peak_dose_msv += add
		if _geiger.playing:
			_geiger.volume_db = linear_to_db(clampf(rate_usv_h / 3000.0, 0.08, 1.0))
	dose_changed.emit(total_msv, rate_usv_h)


func _debrief() -> String:
	var es := TranslationServer.get_locale().begins_with("es")
	var sheltered := peak_dose_msv < 1.0
	if not flare.is_empty() and String(flare.get("id", "")) != "2024-05-11":
		return (tr("RAD_DEBRIEF_GENERIC") % [peak_dose_msv, tr("RAD_DEBRIEF_OK") if sheltered else tr("RAD_DEBRIEF_BAD"),
			String(flare.get("class", "")), String(flare.get("date", "")), String(flare.get("note_es" if es else "note_en", ""))])
	if es:
		return ("Pasó la tormenta. Dosis recibida durante el evento: %.2f mSv (simulada). %s\n" +
			"Basado en hechos reales: el 11 de mayo de 2024 una fulguración (01:10 UTC) fue seguida, una hora después, " +
			"por protones de más de 100 MeV detectados por el satélite GOES; la tormenta geomagnética llegó a Kp 9 " +
			"(fuente: NASA DONKI). La Luna no tiene atmósfera ni campo magnético que frenen estas partículas: " +
			"el blindaje (como el regolito) reduce la dosis, pero no la elimina.") % [peak_dose_msv,
			"Buen trabajo: te protegiste a tiempo." if sheltered else "Te expusiste demasiado: en una misión real, el equipo médico evaluaría tu salud."]
	return ("The storm has passed. Dose received during the event: %.2f mSv (simulated). %s\n" +
		"Based on real events: on 11 May 2024 a flare (01:10 UTC) was followed one hour later by >100 MeV protons " +
		"detected by the GOES satellite; the geomagnetic storm reached Kp 9 (source: NASA DONKI). The Moon has no " +
		"atmosphere or magnetic field to stop these particles: shielding such as regolith reduces the dose but does not remove it.") % [peak_dose_msv,
		"Well done: you took shelter in time." if sheltered else "You were overexposed: in a real mission the medical team would assess your health."]


# --- Saveable ---------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"total_msv": total_msv, "event_done": event_done or phase != &"calm", "elapsed": _elapsed}


func load_state(d: Dictionary) -> void:
	total_msv = float(d.get("total_msv", 0.0))
	event_done = bool(d.get("event_done", false))
	_elapsed = float(d.get("elapsed", 0.0))
	phase = &"over" if event_done else &"calm"
	_geiger.stop()
