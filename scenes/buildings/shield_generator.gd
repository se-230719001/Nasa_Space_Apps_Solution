@tool
class_name ShieldGenerator
extends OutpostModule
## Radiation shield generator: a squat base, a mast, and a glowing emitter with
## a slowly spinning field ring. Higher levels add more ring segments.

const K := preload("res://scenes/buildings/building_kit.gd")

@export_range(1, 3) var level := 1:
	set(v):
		level = v
		if is_inside_tree():
			rebuild()

var _ring: Node3D


func _build(root: Node3D) -> void:
	K.add(root, K.cylinder(1.0, 0.5, 32), &"hull", Vector3(0, 0.25, 0))
	K.add(root, K.torus(0.95, 1.08), &"trim", Vector3(0, 0.5, 0))
	K.add(root, K.cylinder(0.18, 2.2), &"dark", Vector3(0, 1.6, 0))
	K.add(root, K.sphere(0.42), &"window", Vector3(0, 2.9, 0))
	_ring = Node3D.new()
	_ring.position = Vector3(0, 2.9, 0)
	root.add_child(_ring)
	for i in level:
		K.add(_ring, K.torus(0.75 + i * 0.22, 0.85 + i * 0.22), &"frame", Vector3.ZERO, Vector3(70 - i * 25, i * 60.0, 0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ring == null:
		return
	_ring.rotate_y(delta * 0.8)
