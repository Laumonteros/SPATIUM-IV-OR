extends Node
## Audio global: música con fundidos, sonidos de interfaz y "modo vacío".
##
## Buses (assets/audio/default_bus_layout.tres):
##   Master ─┬─ Music
##           ├─ UI
##           ├─ Suit      sonidos del traje: respiración, radio, alertas
##           └─ World ─┬─ SFX      herramientas, pasos, estructuras
##                     └─ Ambient  ambientes, maquinaria
## En el exterior lunar (sin atmósfera) `World` pasa por un filtro pasa-bajos
## y baja de volumen: lo que se oye llega "a través del traje" (sección 20).

const MUSIC_FADE_SECONDS := 2.5
const VACUUM_CUTOFF_HZ := 900.0
const AIR_CUTOFF_HZ := 20500.0
const VACUUM_WORLD_DB := -9.0

var in_vacuum: bool = false

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _world_bus := -1
var _lowpass: AudioEffectLowPassFilter
var _vacuum_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_active_music = _music_a
	_ui_player = _make_player(&"UI")
	_world_bus = AudioServer.get_bus_index(&"World")
	if _world_bus >= 0:
		for i in AudioServer.get_bus_effect_count(_world_bus):
			var fx := AudioServer.get_bus_effect(_world_bus, i)
			if fx is AudioEffectLowPassFilter:
				_lowpass = fx
	set_vacuum(false, true)


## Cambia la música con fundido cruzado. `null` la detiene.
func play_music(stream: AudioStream) -> void:
	var next := _music_b if _active_music == _music_a else _music_a
	var prev := _active_music
	if stream != null and prev.playing and prev.stream == stream:
		return
	var tw := create_tween().set_parallel(true)
	if prev.playing:
		tw.tween_property(prev, "volume_db", -60.0, MUSIC_FADE_SECONDS)
		tw.chain().tween_callback(prev.stop)
	if stream != null:
		next.stream = stream
		next.volume_db = -60.0
		next.play()
		tw.tween_property(next, "volume_db", 0.0, MUSIC_FADE_SECONDS)
		_active_music = next


func play_ui(stream: AudioStream) -> void:
	if stream:
		_ui_player.stream = stream
		_ui_player.play()


## Activa o desactiva el filtrado de vacío (exterior sin atmósfera).
func set_vacuum(enabled: bool, instant: bool = false) -> void:
	in_vacuum = enabled
	if _world_bus < 0:
		return
	var cutoff := VACUUM_CUTOFF_HZ if enabled else AIR_CUTOFF_HZ
	var vol := VACUUM_WORLD_DB if enabled else 0.0
	if _vacuum_tween:
		_vacuum_tween.kill()
	if instant or _lowpass == null:
		if _lowpass:
			_lowpass.cutoff_hz = cutoff
		AudioServer.set_bus_volume_db(_world_bus, vol)
		return
	_vacuum_tween = create_tween().set_parallel(true)
	_vacuum_tween.tween_property(_lowpass, "cutoff_hz", cutoff, 0.6)
	_vacuum_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(_world_bus, db),
		AudioServer.get_bus_volume_db(_world_bus), vol, 0.6)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p
