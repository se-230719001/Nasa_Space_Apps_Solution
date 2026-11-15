@tool
class_name Greenhouse
extends OutpostModule
## Transparent greenhouse dome with framed ribs and rows of crops inside.

const K := preload("res://scenes/buildings/building_kit.gd")
const R := 1.6


func _build(root: Node3D) -> void:
	K.add(root, K.cylinder(R + 0.12, 0.5, 48), &"hull", Vector3(0, 0.25, 0))
	K.add(root, K.torus(R + 0.06, R + 0.18), &"trim", Vector3(0, 0.5, 0))
	K.add(root, K.cylinder(R - 0.05, 0.06, 48), &"soil", Vector3(0, 0.52, 0))
	# Crops: neat rows of round plants, a few taller ones
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var p := Vector2(ix, iz) * 0.38
			if p.length() > R - 0.3:
				continue
			var s := rng.randf_range(0.14, 0.22)
			K.add(root, K.sphere(s, false, 12), &"plant", Vector3(p.x, 0.55 + s * 0.8, p.y))
	K.add(root, K.capsule(0.12, 0.9), &"plant", Vector3(0, 1.0, 0))
	# Glass dome + ribs
	K.add(root, K.sphere(R, true, 48), &"glass", Vector3(0, 0.5, 0))
	for i in 4:
		K.add(root, K.torus(R - 0.02, R + 0.04), &"frame", Vector3(0, 0.5, 0), Vector3(90, i * 45.0, 0))
	var lat := R * cos(deg_to_rad(42.0))
	K.add(root, K.torus(lat - 0.02, lat + 0.04), &"frame", Vector3(0, 0.5 + R * sin(deg_to_rad(42.0)), 0))
	K.add(root, K.sphere(0.12), &"frame", Vector3(0, 0.5 + R, 0))
	# Airlock door
	K.add(root, K.box(Vector3(0.7, 0.9, 0.5)), &"hull", Vector3(0, 0.45, R + 0.2))
	K.add(root, K.box(Vector3(0.5, 0.7, 0.06)), &"trim", Vector3(0, 0.42, R + 0.46))
