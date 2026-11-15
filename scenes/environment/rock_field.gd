@tool
class_name RockField
extends Node3D
## Scatters irregular boulders around the outpost (kept off the build area).

const ROCK_SHADER := preload("res://scenes/environment/rock.gdshader")

@export var count := 40
@export var inner_radius := 11.0
@export var outer_radius := 70.0
@export var rng_seed := 3


func _ready() -> void:
	for c in get_children():
		c.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	for i in count:
		var ang := rng.randf() * TAU
		var r := lerpf(inner_radius, outer_radius, pow(rng.randf(), 1.6))
		var mat := ShaderMaterial.new()
		mat.shader = ROCK_SHADER
		mat.set_shader_parameter(&"seed", rng.randf() * 100.0)
		var rock := MeshInstance3D.new()
		rock.mesh = mesh
		rock.material_override = mat
		var s := rng.randf_range(0.3, 1.0) * lerpf(1.0, 3.5, (r - inner_radius) / outer_radius)
		rock.scale = Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.3))
		rock.rotation.y = rng.randf() * TAU
		rock.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		add_child(rock)
