@tool
class_name ResearchLab
extends OutpostModule
## Radiation Lab. Lv1 lab with a glowing dome; Lv2 + a dish antenna; Lv3 + a
## regolith-covered storm shelter; Lv4 + a space-suit tower.

const K := preload("res://scenes/buildings/building_kit.gd")


func _build(root: Node3D) -> void:
	var at := Vector3(-0.4, 0, -0.4) if level >= 3 else Vector3.ZERO
	K.add(root, K.box(Vector3(2.0, 1.4, 1.7)), &"hull", at + Vector3(0, 0.7, 0))
	K.add(root, K.box(Vector3(2.1, 0.12, 1.8)), &"trim", at + Vector3(0, 1.42, 0))
	K.add(root, K.cylinder(0.6, 0.3), &"panel", at + Vector3(0, 1.62, 0))
	var glow := K.add(root, K.sphere(0.55, true), &"glass", at + Vector3(0, 1.77, 0))
	glow.material_override = K.mat(&"lab_glow")
	K.add(root, K.box(Vector3(0.7, 0.9, 0.08)), &"trim", at + Vector3(-0.45, 0.5, 0.87))
	K.add(root, K.box(Vector3(0.5, 0.26, 0.06)), &"window", at + Vector3(0.5, 0.9, 0.87))
	if level >= 2:
		K.add(root, K.cylinder(0.05, 1.0), &"dark", at + Vector3(0.8, 1.9, -0.5))
		K.add(root, K.cylinder(0.55, 0.2, 32, 0.06), &"frame", at + Vector3(0.8, 2.45, -0.5), Vector3(-40, 30, 0))
	if level >= 3:
		K.add(root, K.sphere(1.0, true, 32), &"regolith", Vector3(1.2, 0, 1.2))
		K.add(root, K.box(Vector3(0.5, 0.6, 0.3)), &"trim", Vector3(1.2, 0.3, 2.15))
	if level >= 4:
		K.add(root, K.cylinder(0.25, 1.8), &"panel", Vector3(-1.5, 0.9, 1.5))
		for y in [0.6, 1.2]:
			K.add(root, K.capsule(0.14, 0.5), &"hull", Vector3(-1.5, y, 1.78))
		K.add(root, K.sphere(0.1), &"green_light", Vector3(-1.5, 1.9, 1.5))
