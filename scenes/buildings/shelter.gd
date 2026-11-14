@tool
class_name Shelter
extends OutpostModule
## Health Center. Lv1 dome; Lv2 + red-cross sign and a clinic annex; Lv3 + a
## gym wing with windows; Lv4 + a second dome (sick bay) and a green beacon.

const K := preload("res://scenes/buildings/building_kit.gd")


func _build(root: Node3D) -> void:
	_dome(root, Vector3(-0.3, 0, -0.2) if level >= 3 else Vector3.ZERO, 1.35)
	if level >= 2:
		K.add(root, K.box(Vector3(0.6, 0.18, 0.18)), &"red", Vector3(0, 2.2, 0))
		K.add(root, K.box(Vector3(0.18, 0.6, 0.18)), &"red", Vector3(0, 2.2, 0))
		K.add(root, K.box(Vector3(1.2, 0.9, 0.9)), &"hull", Vector3(1.35, 0.45, -0.6))
		K.add(root, K.box(Vector3(0.6, 0.25, 0.05)), &"window", Vector3(1.35, 0.6, -0.14))
	if level >= 3:
		var wing := K.add(root, K.capsule(0.5, 2.6), &"hull", Vector3(0.6, 0.5, 1.45), Vector3(0, 0, 90))
		wing.name = "Gym"
		for x in [-0.1, 0.6, 1.3]:
			K.add(root, K.box(Vector3(0.4, 0.2, 0.05)), &"window", Vector3(x, 0.6, 1.95))
	if level >= 4:
		_dome(root, Vector3(-1.4, 0, 1.4), 0.75)
		K.add(root, K.cylinder(0.04, 1.2), &"frame", Vector3(1.6, 1.0, 1.6))
		K.add(root, K.sphere(0.12), &"green_light", Vector3(1.6, 1.65, 1.6))


func _dome(root: Node3D, at: Vector3, r: float) -> void:
	K.add(root, K.cylinder(r + 0.05, 0.5, 40), &"panel", at + Vector3(0, 0.25, 0))
	K.add(root, K.sphere(r, true, 40), &"hull", at + Vector3(0, 0.5, 0))
	K.add(root, K.torus(r - 0.03, r + 0.11), &"trim", at + Vector3(0, 0.5, 0))
	K.add(root, K.box(Vector3(0.55, 0.8, 0.06)), &"dark", at + Vector3(0, 0.5, r + 0.02))
	for a in [-50.0, 50.0]:
		var p := Vector3(sin(deg_to_rad(a)), 0.0, cos(deg_to_rad(a))) * (r - 0.05)
		K.add(root, K.box(Vector3(0.32, 0.2, 0.05)), &"window", at + p + Vector3(0, 0.95, 0), Vector3(0, a, 0))
