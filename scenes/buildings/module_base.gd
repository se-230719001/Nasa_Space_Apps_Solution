@tool
class_name OutpostModule
extends Node3D
## Base for procedural outpost modules: rebuilds its meshes in the editor too,
## so modules can be placed and previewed without imported 3D models.
## Every module also gets a soft contact shadow sized to its footprint.

const BLOB_SHADER := preload("res://scenes/environment/blob_shadow.gdshader")
## How far the contact shadow reaches past the footprint, in metres.
## Modules sitting on a flat pad use a tighter value.
var shadow_spread := 1.6
## Just above the ground so it doesn't z-fight.
const SHADOW_Y := 0.03

func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c in get_children():
		if c.has_meta(&"generated"):
			c.free()
	var root := Node3D.new()
	root.set_meta(&"generated", true)
	add_child(root)
	_build(root)
	_add_contact_shadow(root)


func _add_contact_shadow(root: Node3D) -> void:
	var box := AABB()
	var first := true
	var to_local := global_transform.affine_inverse()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (to_local * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var footprint := Vector2(box.size.x, box.size.z)
	var plane := PlaneMesh.new()
	plane.size = footprint + Vector2.ONE * shadow_spread * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = BLOB_SHADER
	var ratio := footprint / plane.size
	mat.set_shader_parameter(&"inner", minf(ratio.x, ratio.y))
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = plane
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := box.get_center()
	shadow.position = Vector3(c.x, SHADOW_Y, c.z)
	root.add_child(shadow)


## Override in subclasses.
func _build(_root: Node3D) -> void:
	pass
