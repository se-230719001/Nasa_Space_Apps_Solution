@tool
class_name WaterTank
extends OutpostModule
## Water Recycling Center. Lv1 one tank + pump; Lv2 + a second tank; Lv3 + an
## ice processor; Lv4 + a third tank and a condenser on top.

const K := preload("res://scenes/buildings/building_kit.gd")


func _build(root: Node3D) -> void:
	var tanks := [Vector3.ZERO]
	if level >= 2:
		tanks = [Vector3(-0.55, 0, -0.4), Vector3(0.75, 0, 0.5)]
	if level >= 4:
		tanks.append(Vector3(-0.6, 0, 1.25))
	var r := 0.85 if level == 1 else 0.62
	for t in tanks:
		_tank(root, t, r)
	K.add(root, K.box(Vector3(0.7, 0.6, 0.6)), &"panel", Vector3(-1.4, 0.3, 0.3) if level == 1 else Vector3(1.3, 0.3, -1.2))
	K.add(root, K.cylinder(0.1, 2.4), &"frame", Vector3(-2.3, 0.18, 0.3), Vector3(0, 0, 90))
	if level >= 3:
		K.add(root, K.box(Vector3(1.0, 0.8, 0.8)), &"hull", Vector3(0.9, 0.4, -1.3))
		K.add(root, K.box(Vector3(0.6, 0.25, 0.05)), &"water", Vector3(0.9, 0.55, -0.88))
		K.add(root, K.cylinder(0.08, 1.4), &"frame", Vector3(0.2, 0.15, -0.8), Vector3(0, 40, 90))
	if level >= 4:
		K.add(root, K.cylinder(0.35, 0.5), &"panel", Vector3(0.75, 2.45, 0.5))
		K.add(root, K.sphere(0.1), &"green_light", Vector3(0.75, 2.8, 0.5))


func _tank(root: Node3D, at: Vector3, r: float) -> void:
	var h := r * 2.0
	for a in 3:
		var ang := TAU * a / 3.0
		K.add(root, K.box(Vector3(0.15, 0.6, 0.15)), &"dark", at + Vector3(cos(ang) * r * 0.65, 0.3, sin(ang) * r * 0.65))
	K.add(root, K.cylinder(r, h, 40), &"hull", at + Vector3(0, 0.6 + h / 2.0, 0))
	K.add(root, K.sphere(r, true, 40), &"hull", at + Vector3(0, 0.6 + h, 0))
	K.add(root, K.cylinder(r + 0.02, h * 0.45, 40), &"water", at + Vector3(0, 0.6 + h * 0.45, 0))
	K.add(root, K.torus(r - 0.02, r + 0.1), &"trim", at + Vector3(0, 0.62, 0))
	K.add(root, K.torus(r - 0.02, r + 0.1), &"trim", at + Vector3(0, 0.6 + h, 0))
