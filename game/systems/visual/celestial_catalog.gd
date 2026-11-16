class_name CelestialCatalog
extends RefCounted
## Catálogo de cuerpos del cielo (data/sky/celestial_bodies.json): lo usan el cielo
## (direcciones y radios de los planetas) y la ficha de los binoculares.

const PATH := "res://data/sky/celestial_bodies.json"

static var _cache: Array = []


static func bodies() -> Array:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_cache = (data as Dictionary).get("bodies", [])
	return _cache


## az 0 = norte (-Z), 90 = este (+X); el = elevación (misma convención que el Sol).
static func dir_from(el_deg: float, az_deg: float) -> Vector3:
	var e := deg_to_rad(el_deg)
	var a := deg_to_rad(az_deg)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e)).normalized()


## Carga en el material del cielo las direcciones y radios de los planetas.
static func apply_to_sky(sky: ShaderMaterial) -> void:
	var dirs := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var radii := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var dist := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	for b: Dictionary in bodies():
		if not b.has("index"):
			continue
		var i := int(b.index)
		dirs[i] = dir_from(float(b.el), float(b.az))
		radii[i] = float(b.get("radius_rad", 0.002))
		dist[i] = float(b.get("dist_au", 1.0))
	sky.set_shader_parameter("body_dir", dirs)
	sky.set_shader_parameter("body_radius", radii)
	sky.set_shader_parameter("body_dist_au", dist)
