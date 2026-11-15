extends Node3D
## Outpost scene root: reacts to HUD decisions by changing the 3D world.

@onready var _tile: MeshInstance3D = $World/PlacementTile


func _ready() -> void:
	$UI/OutpostHUD.build_confirmed.connect(_on_build_confirmed)
	Music.play(&"outpost")


func _on_build_confirmed(module_id: StringName) -> void:
	if module_id != &"greenhouse":
		return
	var greenhouse := Greenhouse.new()
	greenhouse.position = Vector3(_tile.position.x, 0.0, _tile.position.z)
	greenhouse.scale = Vector3.ONE * 0.01
	$World.add_child(greenhouse)
	_tile.hide()
	# Short construction flourish (style guide §12.2).
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(greenhouse, "scale", Vector3.ONE, 0.6)
