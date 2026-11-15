@tool
class_name RockField
extends Node3D
## Scatters irregular boulders around the outpost (kept off the build area).

const ROCK_SHADER := preload("res://scenes/environment/rock.gdshader")
const OUTLINE_SHADER := preload("res://scenes/environment/rock_outline.gdshader")

@export var count := 40
@export var inner_radius := 18.0
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
		var rock_seed := rng.randf() * 100.0
		mat.set_shader_parameter(&"seed", rock_seed)
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter(&"seed", rock_seed)
		mat.next_pass = outline
		var rock := MeshInstance3D.new()
		rock.mesh = mesh
		rock.material_override = mat
		var s := rng.randf_range(0.3, 1.0) * lerpf(1.0, 3.5, (r - inner_radius) / outer_radius)
		rock.scale = Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.3))
		rock.rotation.y = rng.randf() * TAU
		rock.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		add_child(rock)
