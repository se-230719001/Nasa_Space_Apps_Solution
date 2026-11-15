@tool
class_name HabitatBase
extends OutpostModule
## Main outpost: a long habitat module, a domed command hub and a side module,
## on a landing pad. Rounded, toy-like 3D forms (style guide §2.3).

const K := preload("res://scenes/buildings/building_kit.gd")

@export_range(1, 3) var level := 1:
	set(v):
		level = v
		if is_inside_tree():
			rebuild()

var _dish: Node3D


func _init() -> void:
	# The pad is flat: a wide shadow halo around it reads as a drop shadow.
	shadow_spread = 0.5


func _build(root: Node3D) -> void:
	# Landing pad
	# Pad parts live on the ground's render layer (2) so the rim light, which
	# skips the ground, doesn't tint them blue either.
	for part in [
		K.add(root, K.box(Vector3(10.5, 0.12, 7.5)), &"panel", Vector3(-0.4, 0.06, -0.4)),
		K.add(root, K.box(Vector3(10.7, 0.06, 7.7)), &"trim", Vector3(-0.4, 0.03, -0.4)),
	]:
		part.material_override = K.flat(&"panel" if part.mesh.size.y > 0.1 else &"trim")
		part.layers = 2

	# Long habitat module along X
	var hab := Node3D.new()
	hab.position = Vector3(0.6, 1.45, 0.6)
	root.add_child(hab)
	K.add(hab, K.capsule(1.2, 6.0), &"hull", Vector3.ZERO, Vector3(0, 0, 90))
	for x in [-1.3, 1.3]:
		K.add(hab, K.torus(1.17, 1.3), &"trim", Vector3(x, 0, 0), Vector3(0, 0, 90))
	for x in [-2.0, -0.6, 0.6, 2.0]:
		for side in [1.0, -1.0]:
			K.add(hab, K.box(Vector3(0.55, 0.36, 0.06)), &"window", Vector3(x, 0.2, 1.18 * side))
	# Airlock with orange door
	K.add(hab, K.cylinder(0.72, 0.7), &"hull", Vector3(3.25, -0.15, 0), Vector3(0, 0, 90))
	K.add(hab, K.cylinder(0.58, 0.08), &"trim", Vector3(3.62, -0.15, 0), Vector3(0, 0, 90))
	K.add(hab, K.box(Vector3(0.04, 0.12, 0.5)), &"dark", Vector3(3.67, 0.1, 0))
	for i in level - 1:
		var x := -1.3 + i * 2.6
		K.add(hab, K.cylinder(0.06, 1.4), &"dark", Vector3(x, 1.8, 0))
		K.add(hab, K.sphere(0.16), &"lamp", Vector3(x, 2.55, 0))
	# Legs
	for x in [-2.2, 2.2]:
		for z in [-0.7, 0.7]:
			K.add(hab, K.box(Vector3(0.25, 0.9, 0.25)), &"dark", Vector3(x, -1.0, z))

	# Command hub with a glowing window band and roof dish
	var hub := Node3D.new()
	hub.position = Vector3(-3.7, 0.12, 0.2)
	root.add_child(hub)
	K.add(hub, K.cylinder(1.75, 1.7), &"hull", Vector3(0, 0.85, 0))
	K.add(hub, K.sphere(1.75, true), &"hull", Vector3(0, 1.7, 0))
	K.add(hub, K.cylinder(1.77, 0.34, 48), &"window", Vector3(0, 1.25, 0))
	K.add(hub, K.torus(1.72, 1.86), &"trim", Vector3(0, 0.1, 0))
	K.add(hub, K.box(Vector3(0.9, 1.2, 0.2)), &"trim", Vector3(0.7, 0.6, 1.62), Vector3(0, 25, 0))
	K.add(hub, K.cylinder(0.06, 1.1), &"dark", Vector3(0.2, 3.5, 0.0))
	_dish = Node3D.new()
	_dish.position = Vector3(0.2, 4.1, 0.0)
	hub.add_child(_dish)
	K.add(_dish, K.cylinder(0.75, 0.25, 32, 0.08), &"frame", Vector3.ZERO, Vector3(-35, 0, 15))
	K.add(_dish, K.sphere(0.12), &"lamp", Vector3(0, 0.2, 0))

	# Side module along Z, joined by a tunnel
	var side := Node3D.new()
	side.position = Vector3(1.4, 1.2, -2.6)
	root.add_child(side)
	K.add(side, K.capsule(0.95, 3.6), &"hull", Vector3.ZERO, Vector3(90, 0, 0))
	K.add(side, K.torus(0.92, 1.04), &"trim", Vector3(0, 0, 0.6), Vector3(90, 0, 0))
	for z in [-0.6, 0.2]:
		K.add(side, K.box(Vector3(0.06, 0.32, 0.5)), &"window", Vector3(0.94, 0.2, z))
	K.add(side, K.box(Vector3(1.2, 0.08, 0.7)), &"solar", Vector3(0, 1.05, -0.3), Vector3(0, 0, -18))
	for x in [-0.6, 0.6]:
		for z in [-1.0, 1.0]:
			K.add(side, K.box(Vector3(0.2, 0.75, 0.2)), &"dark", Vector3(x, -0.8, z))

	# Small lamp post
	K.add(root, K.cylinder(0.05, 2.2), &"dark", Vector3(4.6, 1.1, 2.6))
	K.add(root, K.sphere(0.14), &"lamp", Vector3(4.6, 2.25, 2.6))


## Idle life: the dish scans, its beacon blinks, windows glow softly.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var t := Time.get_ticks_msec() / 1000.0
	_dish.rotate_y(delta * 0.4)
	K.mat(&"lamp").emission_energy_multiplier = 4.0 if fmod(t, 1.6) < 0.2 else 0.5
	K.mat(&"window").emission_energy_multiplier = 1.8 + sin(t * 1.5) * 0.35
