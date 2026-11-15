extends Node3D
## Outpost scene root: mirrors the Colony simulation in the 3D world.

## Where each buildable module appears. The greenhouse uses the green
## placement tile; the others have fixed lots inside the dome.
const LOTS := {
	&"greenhouse": Vector3(0.5, 0, 3.5),
	&"shield": Vector3(-5.5, 0, 6.0),
	&"rover": Vector3(9.0, 0, -8.5),
}
const SCENES := {
	&"greenhouse": preload("res://scenes/buildings/greenhouse.gd"),
	&"shield": preload("res://scenes/buildings/shield_generator.gd"),
	&"rover": preload("res://scenes/buildings/rover.gd"),
}

@onready var _tile: MeshInstance3D = $World/PlacementTile
var _spawned := {}


func _ready() -> void:
	# Modules that start in the scene, so upgrades can react on them too.
	_spawned = {&"habitat": $World/HabitatBase, &"solar": $World/SolarArray, &"water_tank": $World/WaterTank}
	Colony.module_changed.connect(_on_module_changed)
	Events.screen_changed.emit(&"outpost")


func _on_module_changed(module_id: StringName, level: int) -> void:
	if _spawned.has(module_id):
		var existing: Node3D = _spawned[module_id]
		if "level" in existing:
			existing.level = level
		_pop(existing)
		return
	if not SCENES.has(module_id):
		return
	var module: Node3D = SCENES[module_id].new()
	module.position = LOTS[module_id]
	$World.add_child(module)
	_spawned[module_id] = module
	if module_id == &"greenhouse":
		_tile.hide()
	_pop(module)


## Construction flourish (style guide §12.2): grow tall, squash, settle, with a
## dust puff. Resource changes are shown in the HUD, not in 3D.
func _pop(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.01
	var pop := create_tween().set_ease(Tween.EASE_OUT)
	pop.tween_property(node, "scale", Vector3(0.85, 1.2, 0.85), 0.2).set_trans(Tween.TRANS_QUAD)
	pop.tween_property(node, "scale", Vector3(1.1, 0.9, 1.1), 0.12).set_trans(Tween.TRANS_SINE)
	pop.tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	_dust_puff(node.position)


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

