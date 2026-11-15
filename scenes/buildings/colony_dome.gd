@tool
class_name ColonyDome
extends Node3D
## Sci-fi glass dome over the whole play area: a frameless glass shell on a
## slim lit foundation ring, with two airlock gates. Built procedurally like
## the other modules (BuildingKit materials, toon outlines) but without a
## contact shadow: a 30 m blob would darken the entire base.

const K := preload("res://scenes/buildings/building_kit.gd")
const GLASS_SHADER := preload("res://scenes/environment/dome_glass.gdshader")

@export var radius := 15.5:
	set(v):
		radius = v
		if is_inside_tree():
			_rebuild()
## Height / radius: 0.55 gives a low, wide dome that keeps the base visible.
@export var squash := 0.55:
	set(v):
		squash = v
		if is_inside_tree():
			_rebuild()
const LAMPS := 24
const GATE_ANGLES := [110.0, 290.0]  # side-on to the camera, never in front of the HUD


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.free()

	# Glass shell, squashed into a low wide dome.
	var shell := Node3D.new()
	shell.scale = Vector3(1.0, squash, 1.0)
	add_child(shell)
	var glass_mat := ShaderMaterial.new()
	glass_mat.shader = GLASS_SHADER
	var glass := K.add(shell, K.sphere(radius, true, 64), &"glass")
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Foundation: slim hull ring, thin orange trim, and a row of cyan lamps.
	K.add(self, _ring(radius, 0.22), &"hull", Vector3(0, 0.1, 0))
	K.add(self, _ring(radius + 0.3, 0.08), &"trim", Vector3(0, 0.05, 0))
	for i in LAMPS:
		var ang := TAU * i / LAMPS
		K.add(self, K.sphere(0.1, false, 12), &"window",
				Vector3(cos(ang), 0, sin(ang)) * (radius + 0.25) + Vector3(0, 0.25, 0))

	for deg in GATE_ANGLES:
		_add_gate(deg_to_rad(deg))


## Airlock gate: a short tunnel through the dome wall with an orange door.
func _add_gate(angle: float) -> void:
	var gate := Node3D.new()
	gate.position = Vector3(cos(angle), 0, sin(angle)) * radius
	gate.rotation.y = -angle + PI / 2.0
	gate.scale = Vector3.ONE * 0.7  # small next to the frameless glass
	add_child(gate)
	K.add(gate, K.box(Vector3(2.6, 2.4, 2.4)), &"hull", Vector3(0, 1.2, 0))
	K.add(gate, K.box(Vector3(2.8, 0.3, 2.6)), &"trim", Vector3(0, 2.45, 0))
	K.add(gate, K.box(Vector3(1.5, 1.8, 0.1)), &"trim", Vector3(0, 0.95, 1.22))
	K.add(gate, K.box(Vector3(0.9, 0.12, 0.06)), &"window", Vector3(0, 2.05, 1.26))


static func _ring(r: float, thickness: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r - thickness
	m.outer_radius = r + thickness
	m.rings = 96
	m.ring_segments = 12
	return m
