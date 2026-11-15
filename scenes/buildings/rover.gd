@tool
class_name Rover
extends OutpostModule
## Six-wheeled science rover parked on a small pad: white hull, orange trim,
## cyan cab window, a mast camera and a solar wing. Bobs gently while parked.

const K := preload("res://scenes/buildings/building_kit.gd")

@export_range(1, 3) var level := 1:
	set(v):
		level = v
		if is_inside_tree():
			rebuild()

var _body: Node3D


func _build(root: Node3D) -> void:
	K.add(root, K.cylinder(1.9, 0.08, 40), &"panel", Vector3(0, 0.04, 0))
	for x in [-0.8, 0.0, 0.8]:
		for z in [-0.65, 0.65]:
			K.add(root, K.cylinder(0.28, 0.22, 20), &"dark", Vector3(x, 0.32, z), Vector3(90, 0, 0))
	_body = Node3D.new()
	_body.position = Vector3(0, 0.75, 0)
	root.add_child(_body)
	K.add(_body, K.box(Vector3(2.1, 0.5, 1.1)), &"hull")
	K.add(_body, K.box(Vector3(2.2, 0.1, 1.2)), &"trim", Vector3(0, -0.26, 0))
	K.add(_body, K.box(Vector3(0.6, 0.35, 0.9)), &"hull", Vector3(0.65, 0.4, 0))
	K.add(_body, K.box(Vector3(0.05, 0.22, 0.7)), &"window", Vector3(0.96, 0.42, 0))
	K.add(_body, K.cylinder(0.04, 0.8), &"dark", Vector3(-0.6, 0.65, 0.3))
	K.add(_body, K.box(Vector3(0.25, 0.18, 0.18)), &"trim", Vector3(-0.6, 1.1, 0.3))
	# Solar wing grows with level.
	K.add(_body, K.box(Vector3(0.9 + level * 0.3, 0.05, 0.8)), &"solar", Vector3(-0.3, 0.3, 0), Vector3(0, 0, -8))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	_body.position.y = 0.75 + sin(Time.get_ticks_msec() / 1000.0 * 1.7) * 0.02
