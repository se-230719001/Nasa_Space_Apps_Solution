extends Node3D
## Outpost scene root: reacts to HUD decisions by changing the 3D world.

@onready var _tile: MeshInstance3D = $World/PlacementTile


func _ready() -> void:
	$UI/OutpostHUD.build_confirmed.connect(_on_build_confirmed)
	Events.screen_changed.emit(&"outpost")


func _on_build_confirmed(module_id: StringName) -> void:
	if module_id != &"greenhouse":
		return
	var greenhouse := Greenhouse.new()
	greenhouse.position = Vector3(_tile.position.x, 0.0, _tile.position.z)
	greenhouse.scale = Vector3.ONE * 0.01
	$World.add_child(greenhouse)
	_tile.hide()
	# Construction flourish (style guide §12.2): grow tall, squash, settle,
	# with a dust puff. Resource changes are shown in the HUD, not in 3D.
	var pop := create_tween().set_ease(Tween.EASE_OUT)
	pop.tween_property(greenhouse, "scale", Vector3(0.85, 1.2, 0.85), 0.2).set_trans(Tween.TRANS_QUAD)
	pop.tween_property(greenhouse, "scale", Vector3(1.1, 0.9, 1.1), 0.12).set_trans(Tween.TRANS_SINE)
	pop.tween_property(greenhouse, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	_dust_puff(greenhouse.position)


func _dust_puff(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	dust.mesh = mesh
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 28
	dust.lifetime = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = 1.6
	dust.emission_ring_inner_radius = 1.0
	dust.emission_ring_height = 0.1
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -3, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.8, 0.9, 0.45))
	fade.set_color(1, Color(0.8, 0.8, 0.9, 0.0))
	dust.color_ramp = fade
	dust.position = at + Vector3(0, 0.2, 0)
	$World.add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)

