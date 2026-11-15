@tool
class_name IceDrill
extends OutpostModule
## Ice drill: a braced derrick over a borehole, a spinning drill head, and a
## glowing water tank on the side. Higher levels add tank rings.

const K := preload("res://scenes/buildings/building_kit.gd")

@export_range(1, 3) var level := 1:
	set(v):
		level = v
		if is_inside_tree():
			rebuild()

var _bit: Node3D


func _build(root: Node3D) -> void:
	K.add(root, K.cylinder(1.3, 0.25, 32), &"panel", Vector3(0, 0.12, 0))
	# Derrick: four legs leaning in to a top block.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg := K.add(root, K.cylinder(0.07, 3.0), &"frame", Vector3(corner.x * 0.45, 1.6, corner.y * 0.45))
		leg.rotation = Vector3(-corner.y * 0.18, 0, corner.x * 0.18)
	K.add(root, K.box(Vector3(0.7, 0.35, 0.7)), &"trim", Vector3(0, 3.1, 0))
	_bit = Node3D.new()
	_bit.position = Vector3(0, 1.4, 0)
	root.add_child(_bit)
	K.add(_bit, K.cylinder(0.1, 2.4), &"dark")
	K.add(_bit, K.cylinder(0.28, 0.5, 16, 0.05), &"hull", Vector3(0, -1.2, 0), Vector3(180, 0, 0))
	# Water tank fed by the drill.
	K.add(root, K.cylinder(0.55, 1.4, 32), &"hull", Vector3(1.35, 0.8, 0))
	K.add(root, K.cylinder(0.57, 0.55, 32), &"water", Vector3(1.35, 0.75, 0))
	for i in level:
		K.add(root, K.torus(0.52, 0.62), &"trim", Vector3(1.35, 0.25 + i * 0.5, 0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _bit == null:
		return
	_bit.rotate_y(delta * 2.5)
