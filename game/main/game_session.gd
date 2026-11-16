class_name GameSession
extends Node
## Sesión de juego: carga la región del cuerpo celeste, ubica al astronauta,
## conecta la interfaz y administra pausa y captura del mouse.

@export var region_scene: PackedScene
@export var player_scene: PackedScene

var region: Node3D
var player: Player
var _resting := false


func _ready() -> void:
	add_to_group(&"game_session")
	add_child(InventoryScreen.new())
	add_child(RadioPanel.new())
	add_child(EventDirector.new())
	region = region_scene.instantiate() as Node3D
	add_child(region)
	player = player_scene.instantiate() as Player
	region.add_child(player)
	var spawn := region.get("player_spawn") as Marker3D
	var pos := spawn.global_position if spawn else Vector3(0, 2, 0)
	if region.has_method("snap_to_ground"):
		pos = region.call("snap_to_ground", pos, 0.1)
	player.global_position = pos
	# Empezar dentro del monoblock propio, en el sector residencial de la colonia
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	var colony := get_tree().get_first_node_in_group(&"colony") as Colony
	var lander := net.get_lander() if net else null
	var home := colony.get_player_home() if colony else null
	if home:
		player.global_position = home.spawn_point()
		player.visual.rotation.y = home.rotation.y
		player.camera_rig.yaw = home.rotation.y + PI
		var rover := Rover.new()
		rover.name = "Rover"
		region.add_child(rover)
		rover.global_transform = colony.rover_transform()
	elif lander and region.has_method("snap_to_ground"):
		var ladder := lander.global_position + lander.global_basis * Vector3(0.6, 0, 3.4)
		player.global_position = region.call("snap_to_ground", ladder, 0.1)
		player.visual.rotation.y = lander.rotation.y + PI
		player.camera_rig.yaw = lander.rotation.y
		# Rover presurizado estacionado junto al módulo
		var rover := Rover.new()
		rover.name = "Rover"
		region.add_child(rover)
		var rp: Vector3 = region.call("snap_to_ground", lander.global_position + lander.global_basis * Vector3(7.5, 0, 6.5), 0.9)
		rover.global_position = rp
		rover.rotation.y = lander.rotation.y + 0.6
	# La colisión dinámica del terreno se genera alrededor del astronauta
	var terrain := region.get("terrain") as Terrain3D
	if terrain:
		terrain.set_collision_target(player)
		terrain.set_camera(player.camera_rig.get_camera())
	GameState.new_game()
	get_tree().paused = false
	if _should_play_intro():
		_set_ui_visible(false)
		var intro := IntroDirector.new()
		add_child(intro)
		intro.finished.connect(_on_intro_finished)
		intro.begin.call_deferred(self)
	else:
		_start_gameplay(&"new")


## Arranca el juego: conecta la interfaz y las misiones.
func _start_gameplay(mode: StringName) -> void:
	# Curvatura del planeta (estilo Astroneer): la intro se ve plana, el juego curvo
	CurvedWorld.curve_terrain(region.get("terrain") as Node)
	CurvedWorld.set_enabled(true)
	if mode == &"evaluator":
		_apply_evaluator_mode()
	_capture_mouse(true)
	_set_ui_visible(true)
	if ResourceLoader.exists("res://assets/audio/music/exploration_loop.wav"):
		AudioManager.play_music(load("res://assets/audio/music/exploration_loop.wav"))
	for ui in get_tree().get_nodes_in_group(&"session_ui"):
		if ui.has_method("bind_session"):
			ui.call("bind_session", self)


func _on_intro_finished(mode: StringName) -> void:
	_start_gameplay(mode)


## La intro solo se reproduce al ejecutar el juego normalmente (no en tests ni capturas).
func _should_play_intro() -> bool:
	if Array(OS.get_cmdline_user_args()).has("intro"):
		return true
	return get_tree().current_scene == self and not _is_demo_capture() and DisplayServer.get_name() != "headless"


func _set_ui_visible(on: bool) -> void:
	for ui in get_tree().get_nodes_in_group(&"session_ui"):
		if ui is CanvasLayer and not (ui is PauseMenu) and not (ui is Encyclopedia) and not (ui is InventoryScreen):
			(ui as CanvasLayer).visible = on


## Modo evaluador: materiales iniciales y consumo reducido para recorrer
## todos los sistemas en pocos minutos (se indica en pantalla).
func _apply_evaluator_mode() -> void:
	GameState.unlock(&"evaluator_mode")
	var inv := player.inventory
	inv.add(&"iron", 30)
	inv.add(&"regolith", 40)
	inv.add(&"water_ice", 4)
	inv.add(&"geo_sample", 1)
	var suit := player.get_node("SuitStatus") as SuitStatus
	suit.oxygen_rate *= 0.4
	suit.energy_rate *= 0.4
	EventBus.notification_requested.emit("MODO EVALUADOR: materiales iniciales y consumo de O₂ reducido" if TranslationServer.get_locale().begins_with("es") else "EVALUATOR MODE: starting materials and reduced O₂ use", &"warning")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not get_tree().paused and not _is_demo_capture():
		set_paused(true)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_capture_mouse(not paused)
	EventBus.pause_changed.emit(paused)


## Capturas automáticas (modo autopilot de depuración): no pausar al perder el foco.
func _is_demo_capture() -> bool:
	return OS.is_debug_build() and Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("autopilot=") or a == "capture")


func _capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


## Entrar a la cabina presurizada (módulo o hábitat): comer una ración, recargar
## el traje con las reservas de la base y guardar la partida.
func rest_in_cabin(shelter: Structure) -> void:
	if _resting:
		return
	_resting = true
	player.input_enabled = false
	var es := TranslationServer.get_locale().begins_with("es")
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	layer.add_child(fade)
	var label := SpatiumTheme.label("", 22, &"body", 500, Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -480
	label.offset_right = 480
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(label)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	await tw.finished
	var net := get_tree().get_first_node_in_group(&"base_network") as BaseNetwork
	var suit := player.get_node("SuitStatus") as SuitStatus
	var ate := net.take_ration()
	if ate:
		suit.values[&"food"] = minf(100.0, suit.values[&"food"] + 60.0)
	for i in 40:
		suit._refill(net, 0.25)
	SaveManager.save_slot(SaveManager.AUTOSAVE_SLOT)
	var name := shelter.def.get_display_name()
	if es:
		label.text = "Dentro de %s.\n%s\nRecargaste oxígeno, agua y energía con las reservas de la base.\nPartida guardada." % [name,
			("Comiste una ración (quedan %d)." % net.rations) if ate else "No quedan raciones: hace falta producir alimento."]
	else:
		label.text = "Inside the %s.\n%s\nYou recharged oxygen, water and power from the base reserves.\nGame saved." % [name,
			("You ate a ration (%d left)." % net.rations) if ate else "No rations left: food production is needed."]
	await get_tree().create_timer(3.2).timeout
	var tw2 := create_tween()
	tw2.tween_property(label, "modulate:a", 0.0, 0.4)
	tw2.tween_property(fade, "color:a", 0.0, 0.8)
	await tw2.finished
	layer.queue_free()
	player.input_enabled = true
	_resting = false
	EventBus.player_action.emit(&"rest")
