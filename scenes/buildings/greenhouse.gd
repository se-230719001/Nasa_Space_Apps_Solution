@tool
class_name Greenhouse
extends OutpostModule
## Greenhouse. Lv1 one glass dome; Lv2 + a second dome; Lv3 + purple LED grow
## lights and a third dome; Lv4 + hydroponic water tanks and a sensor mast.

const K := preload("res://scenes/buildings/building_kit.gd")


func _build(root: Node3D) -> void:
	var s := 1.0 if level == 1 else 0.78
	_dome(root, Vector3(0, 0, 0) if level == 1 else Vector3(-0.3, 0, -0.3), 1.6 * s, true)
	if level >= 2:
		_dome(root, Vector3(1.25, 0, 1.0), 0.85, false)
		K.add(root, K.capsule(0.28, 1.4), &"hull", Vector3(0.55, 0.32, 0.45), Vector3(90, 50, 0))
	if level >= 3:
		_dome(root, Vector3(-1.3, 0, 1.2), 0.8, false)
		K.add(root, K.torus(1.0, 1.1), &"grow_light", Vector3(-0.3, 1.25, -0.3))
	if level >= 4:
		for p in [Vector3(1.4, 0, -1.2), Vector3(0.9, 0, -1.6)]:
			K.add(root, K.cylinder(0.25, 0.9), &"water", p + Vector3(0, 0.45, 0))
		K.add(root, K.cylinder(0.04, 1.4), &"frame", Vector3(1.6, 1.2, 1.6))
		K.add(root, K.sphere(0.1), &"green_light", Vector3(1.6, 1.95, 1.6))


func _dome(root: Node3D, at: Vector3, r: float, door: bool) -> void:
	K.add(root, K.cylinder(r + 0.12, 0.5, 48), &"hull", at + Vector3(0, 0.25, 0))
	K.add(root, K.torus(r + 0.06, r + 0.18), &"trim", at + Vector3(0, 0.5, 0))
	K.add(root, K.cylinder(r - 0.05, 0.06, 48), &"soil", at + Vector3(0, 0.52, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 100)
	var step := 0.38 * r / 1.6 + 0.12
	for ix in range(-4, 5):
		for iz in range(-4, 5):
			var p := Vector2(ix, iz) * step
			if p.length() > r - 0.3:
				continue
			var sz := rng.randf_range(0.11, 0.2) * clampf(r / 1.2, 0.7, 1.2)
			K.add(root, K.sphere(sz, false, 10), &"plant", at + Vector3(p.x, 0.55 + sz * 0.8, p.y))
	K.add(root, K.sphere(r, true, 40), &"glass", at + Vector3(0, 0.5, 0))
	for i in 4:
		K.add(root, K.torus(r - 0.02, r + 0.04), &"frame", at + Vector3(0, 0.5, 0), Vector3(90, i * 45.0, 0))
	if door:
		K.add(root, K.box(Vector3(0.7, 0.9, 0.5)), &"hull", at + Vector3(0, 0.45, r + 0.2))
		K.add(root, K.box(Vector3(0.5, 0.7, 0.06)), &"trim", at + Vector3(0, 0.42, r + 0.46))
