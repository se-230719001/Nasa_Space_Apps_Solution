@tool
class_name SolarArray
extends OutpostModule
## Two rows of tilted solar panels on struts.

const K := preload("res://scenes/buildings/building_kit.gd")
@export var columns := 3:
	set(v):
		columns = v
		if is_inside_tree():
			rebuild()


var _panels: Array[Node3D] = []


func _build(root: Node3D) -> void:
	_panels.clear()
	for row in 2:
		for col in columns:
			var p := Vector3((col - (columns - 1) / 2.0) * 1.25, 0, row * 1.7 - 0.85)
			K.add(root, K.cylinder(0.05, 0.9), &"dark", p + Vector3(0, 0.45, 0))
			var panel := Node3D.new()
			panel.position = p + Vector3(0, 0.95, 0)
			panel.rotation_degrees = Vector3(32, 0, 0)
			root.add_child(panel)
			_panels.append(panel)
			K.add(panel, K.box(Vector3(1.12, 0.05, 1.45)), &"solar")
			K.add(panel, K.box(Vector3(1.18, 0.04, 1.51)), &"frame", Vector3(0, -0.03, 0))
	K.add(root, K.box(Vector3(columns * 1.25, 0.12, 0.18)), &"dark", Vector3(0, 0.12, 0))
	K.add(root, K.box(Vector3(0.5, 0.45, 0.4)), &"panel", Vector3(-columns * 0.62 - 0.3, 0.22, 0))
	K.add(root, K.box(Vector3(0.3, 0.06, 0.04)), &"window", Vector3(-columns * 0.62 - 0.3, 0.32, 0.21))


## Idle life: panels slowly re-angle as if tracking the sun.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var tilt := deg_to_rad(32.0 + sin(Time.get_ticks_msec() / 1000.0 * 0.3) * 8.0)
	for panel in _panels:
		panel.rotation.x = tilt
