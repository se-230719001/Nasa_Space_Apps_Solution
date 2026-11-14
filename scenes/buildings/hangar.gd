@tool
class_name Hangar
extends OutpostModule
## Hangar: arched hall with a big orange door and launch pad(s). Lv2 longer
## hall + control tower; Lv3 a second pad; Lv4 a radar dish. Parked craft are
## shown with set_crafts().

const K := preload("res://scenes/buildings/building_kit.gd")

var _pad: Node3D
var _crafts := 0


func _build(root: Node3D) -> void:
	var hall := K.add(root, K.cylinder(1.3, 2.8 + (0.8 if level >= 2 else 0.0), 32), &"hull", Vector3(0, 0.15, -0.5), Vector3(0, 0, 90))
	hall.scale = Vector3(1.0, 1.0, 1.25)
	if level >= 2:
		K.add(root, K.cylinder(0.25, 2.2), &"panel", Vector3(-1.7, 1.1, -1.3))
		K.add(root, K.cylinder(0.45, 0.5), &"window", Vector3(-1.7, 2.4, -1.3))
	if level >= 3:
		K.add(root, K.cylinder(0.75, 0.06, 32), &"dark", Vector3(-1.6, 0.03, 1.4))
		K.add(root, K.torus(0.65, 0.75), &"trim", Vector3(-1.6, 0.07, 1.4))
	if level >= 4:
		K.add(root, K.cylinder(0.05, 1.0), &"dark", Vector3(1.5, 1.6, -1.5))
		K.add(root, K.cylinder(0.6, 0.2, 32, 0.06), &"frame", Vector3(1.5, 2.15, -1.5), Vector3(-35, -30, 0))
	K.add(root, K.box(Vector3(2.8, 0.3, 3.2)), &"panel", Vector3(0, 0.15, -0.5))
	K.add(root, K.box(Vector3(1.6, 1.3, 0.08)), &"trim", Vector3(0, 0.75, 0.6))
	for x in [-0.4, 0.4]:
		K.add(root, K.box(Vector3(0.05, 1.2, 0.1)), &"dark", Vector3(x, 0.75, 0.66))
	K.add(root, K.box(Vector3(0.6, 0.15, 0.06)), &"window", Vector3(0, 1.55, 0.62))
	_pad = Node3D.new()
	_pad.position = Vector3(0, 0, 1.55)
	root.add_child(_pad)
	K.add(_pad, K.cylinder(0.9, 0.06, 32), &"dark", Vector3(0, 0.03, 0))
	K.add(_pad, K.torus(0.8, 0.9), &"trim", Vector3(0, 0.07, 0))
	set_crafts.call_deferred(_crafts)


## Shows up to `count` small rockets on the pad (busy ones are away).
func set_crafts(count: int) -> void:
	_crafts = count
	if _pad == null:
		return
	for c in _pad.get_children():
		if c.has_meta(&"rocket"):
			c.free()
	for i in count:
		var r := Node3D.new()
		r.set_meta(&"rocket", true)
		r.position = Vector3((i - (count - 1) / 2.0) * 0.55, 0.06, 0)
		_pad.add_child(r)
		K.add(r, K.cylinder(0.16, 0.9, 16), &"hull", Vector3(0, 0.5, 0))
		K.add(r, K.cylinder(0.01, 0.35, 16, 0.16), &"trim", Vector3(0, 1.12, 0))
		K.add(r, K.box(Vector3(0.45, 0.25, 0.05)), &"trim", Vector3(0, 0.15, 0))
		K.add(r, K.box(Vector3(0.12, 0.12, 0.04)), &"window", Vector3(0, 0.7, 0.15))
