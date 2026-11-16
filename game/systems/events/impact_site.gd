class_name ImpactSite
extends Node3D
## Cráter fresco de un impacto reciente: suelo oscurecido, rayos de eyecta claros y
## rocas sueltas. Es un punto de interés (se ve en el minimapa como estrella).
## NASA observa estos destellos de impacto en la Luna desde la Tierra (Lunar Impact
## Monitoring, Marshall Space Flight Center).

var discovered := true


func _ready() -> void:
	add_to_group(&"poi")
	var b := ModuleBuilder.new(self)
	b.cyl(3.2, 0.04, Vector3(0, 0.02, 0), &"soil", Vector3.ZERO, &"", 24)
	b.cyl(2.2, 0.05, Vector3(0, 0.03, 0), &"frame", Vector3.ZERO, &"", 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0 + global_position.z * 7.0)
	for i in 10: # rayos de eyecta (material claro recién expuesto)
		var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
		var l := rng.randf_range(4.0, 9.0)
		b.box(Vector3(0.35, 0.02, l), Vector3(sin(a), 0, cos(a)) * (3.0 + l * 0.5) + Vector3(0, 0.015, 0), &"concrete", Vector3(0, a, 0))
	for i in 8:
		var a := rng.randf() * TAU
		b.sphere(rng.randf_range(0.1, 0.25), Vector3(sin(a), 0, cos(a)) * rng.randf_range(2.5, 5.0), &"rock_sample", Vector3(1, 0.7, 1))
	b.finalize()


## Destello del impacto (visible a distancia) y polvo balístico.
func flash() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.95, 0.85)
	l.light_energy = 40.0
	l.omni_range = 220.0
	l.position = Vector3(0, 6, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)
