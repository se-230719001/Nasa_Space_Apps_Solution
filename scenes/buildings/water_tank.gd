@tool
class_name WaterTank
extends OutpostModule
## Water storage/recycling unit: tank with a glowing water gauge and a pump.

const K := preload("res://scenes/buildings/building_kit.gd")


func _build(root: Node3D) -> void:
	for a in 3:
		var ang := TAU * a / 3.0
		K.add(root, K.box(Vector3(0.18, 0.6, 0.18)), &"dark", Vector3(cos(ang) * 0.55, 0.3, sin(ang) * 0.55))
	K.add(root, K.cylinder(0.85, 1.7, 40), &"hull", Vector3(0, 1.45, 0))
	K.add(root, K.sphere(0.85, true, 40), &"hull", Vector3(0, 2.3, 0))
	K.add(root, K.cylinder(0.87, 0.75, 40), &"water", Vector3(0, 1.3, 0))
	K.add(root, K.torus(0.83, 0.95), &"trim", Vector3(0, 0.62, 0))
	K.add(root, K.torus(0.83, 0.95), &"trim", Vector3(0, 2.28, 0))
	K.add(root, K.cylinder(0.12, 0.3), &"dark", Vector3(0, 3.25, 0))
	# Pump + pipe toward the base
	K.add(root, K.box(Vector3(0.7, 0.6, 0.6)), &"panel", Vector3(-1.3, 0.3, 0.3))
	K.add(root, K.box(Vector3(0.05, 0.12, 0.3)), &"window", Vector3(-0.93, 0.4, 0.3))
	K.add(root, K.cylinder(0.1, 2.4), &"frame", Vector3(-2.3, 0.18, 0.3), Vector3(0, 0, 90))
