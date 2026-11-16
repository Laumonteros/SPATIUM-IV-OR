class_name CrewMember
extends ColonyWalker
## Astronauta compañero (NPC). Usa el mismo modelo y animaciones del jugador, con
## franja de color en el casco y nombre visible de cerca. Vive en su monoblock y
## trabaja en su sector. Al hablarle (E) informa el estado real de su área.

const MODEL := "res://assets/models/characters/astronaut/astronaut.glb"

var role: StringName = &"" # botanist | engineer
var accent: Color = Color(0.3, 0.85, 0.4)
var home_id: StringName = &""

var _ap: AnimationPlayer
var _current_anim: StringName = &""
var _name_tag: Label3D


func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	visual.add_child(model)
	SurfaceMaterials.apply(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 160.0
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_ap = aps[0] as AnimationPlayer
		for a in [&"Idle", &"Walk"]:
			if _ap.has_animation(a):
				_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	# franja identificatoria (código de color de la tripulación) sobre la mochila
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.06, 0.32)
	band.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = accent
	m.roughness = 0.7 # franja de tela pintada, sin brillo
	band.material_override = m
	band.position = Vector3(0, 1.62, -0.18)
	visual.add_child(band)
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.position.y = 2.15
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.pixel_size = 0.0035
	_name_tag.font_size = 28
	_name_tag.modulate = accent.lightened(0.4)
	_name_tag.outline_size = 6
	_name_tag.visibility_range_end = 9.0
	add_child(_name_tag)


func _set_anim(anim: StringName, _moving_now: bool) -> void:
	if _ap == null:
		return
	if anim == &"Interact" and _ap.has_animation(anim):
		# trabajo: repetir la animación de manipulación con pausas
		if _current_anim != &"Interact" or not _ap.is_playing():
			_ap.play(&"Interact", 0.3)
			_current_anim = &"Interact"
		return
	if anim != _current_anim and _ap.has_animation(anim):
		_ap.play(anim, 0.3)
		_current_anim = anim


func _on_talk(by: Node) -> void:
	var p := by as Player
	if p:
		p.face_towards(global_position)
	var c := get_tree().get_first_node_in_group(&"colony") as Colony
	var line := c.crew_report(self) if c else display_name
	EventBus.notification_requested.emit("%s: %s" % [display_name, line], &"info")
