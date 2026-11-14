extends Node3D
## Outpost scene root: reacts to HUD decisions by changing the 3D world.

const GREENHOUSE := preload("res://assets/sprites/buildings/greenhouse.png")

@onready var _tile: MeshInstance3D = $World/PlacementTile


func _ready() -> void:
	$UI/OutpostHUD.build_confirmed.connect(_on_build_confirmed)


func _on_build_confirmed(module_id: StringName) -> void:
	if module_id != &"greenhouse":
		return
	var sprite := Sprite3D.new()
	sprite.texture = GREENHOUSE
	sprite.pixel_size = 0.022
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = _tile.position + Vector3(0, GREENHOUSE.get_height() * sprite.pixel_size / 2, 0)
	sprite.scale = Vector3.ONE * 0.01
	$World.add_child(sprite)
	_tile.hide()
	# Short construction flourish (style guide §12.2).
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(sprite, "scale", Vector3.ONE, 0.5)
