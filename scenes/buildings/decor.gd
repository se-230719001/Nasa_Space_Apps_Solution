@tool
class_name Decor
extends OutpostModule
## Small base decorations unlocked at campaign milestones (Stage 8). Looks
## only: no game effect. One 1x1 parcel each.

const K := preload("res://scenes/buildings/building_kit.gd")

@export_enum("lamp", "antenna", "moon_garden") var kind := "lamp":
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()


func _build(root: Node3D) -> void:
	match kind:
		"lamp":
			K.add(root, K.cylinder(0.25, 0.15), &"panel", Vector3(0, 0.07, 0))
			K.add(root, K.cylinder(0.06, 2.0), &"dark", Vector3(0, 1.1, 0))
			K.add(root, K.sphere(0.2), &"lamp", Vector3(0, 2.15, 0))
		"antenna":
			K.add(root, K.box(Vector3(0.6, 0.3, 0.6)), &"panel", Vector3(0, 0.15, 0))
			K.add(root, K.cylinder(0.05, 1.6), &"frame", Vector3(0, 1.0, 0))
			K.add(root, K.cylinder(0.55, 0.12, 24, 0.1), &"trim", Vector3(0, 1.8, 0), Vector3(-40, 0, 0))
		_:
			for p in [Vector3(-0.3, 0.15, 0.2), Vector3(0.35, 0.12, -0.1), Vector3(0.0, 0.2, -0.35)]:
				K.add(root, K.sphere(0.22 + p.y * 0.5), &"dark", p)
			for p in [Vector3(0.3, 0.2, 0.35), Vector3(-0.35, 0.18, -0.3)]:
				K.add(root, K.sphere(0.14), &"plant", p)
