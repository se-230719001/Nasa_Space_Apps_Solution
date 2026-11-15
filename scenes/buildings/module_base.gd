@tool
class_name OutpostModule
extends Node3D
## Base for procedural outpost modules: rebuilds its meshes in the editor too,
## so modules can be placed and previewed without imported 3D models.

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


## Override in subclasses.
func _build(_root: Node3D) -> void:
	pass
