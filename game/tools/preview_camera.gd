extends Camera3D
## Cámara de vista previa para capturas automáticas (Movie Maker de Godot).
## Uso:
##   Godot.exe --path . res://tools/preview_moon.tscn --write-movie <salida.png> --fixed-fps 10 --quit-after 12 -- cam=x,y,z look=x,y,z
## Se coloca sobre el terreno (altura relativa) y mira al punto indicado.

func _ready() -> void:
	var cam := Vector3(0, 2.0, 6)
	var look := Vector3(0, 1.0, -20)
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		var v := kv[1].split(",")
		if v.size() != 3:
			continue
		var vec := Vector3(float(v[0]), float(v[1]), float(v[2]))
		if kv[0] == "cam":
			cam = vec
		elif kv[0] == "look":
			look = vec
	await get_tree().process_frame
	var region := get_tree().get_first_node_in_group(&"world_region")
	if region and region.has_method("snap_to_ground"):
		cam = region.call("snap_to_ground", cam, cam.y)
		look = region.call("snap_to_ground", look, look.y)
	look_at_from_position(cam, look)
