@tool
class_name ColonyDome
extends Node3D
## Glass dome over the whole colony. The rim light and glass tint follow the
## oxygen level (green = plenty, blue = OK, red = low) and the glass gets hazy
## as CO2 rises. Call set_air() after every simulated year.

const GLASS_SHADER := preload("res://scenes/environment/dome_glass.gdshader")
const COLORS := {"good": Color("#3CDB56"), "ok": Color("#00C6FF"), "low": Color("#FF4961")}

@export var radius := 17.5
@export var height_scale := 0.62

var _glass := ShaderMaterial.new()
var _danger := 0.0  # 0..1, how low oxygen is (drives the alarm pulse)
var _rim := StandardMaterial3D.new()
var _color := COLORS.good


func _ready() -> void:
	for c in get_children():
		c.free()
	_glass.shader = GLASS_SHADER
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius
	sphere.is_hemisphere = true
	sphere.radial_segments = 96
	sphere.rings = 32
	dome.mesh = sphere
	dome.material_override = _glass
	dome.scale = Vector3(1.0, height_scale, 1.0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)

	_rim.emission_enabled = true
	_rim.emission_energy_multiplier = 2.2
	_rim.roughness = 0.3
	_rim.metallic = 0.5
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.35
	torus.outer_radius = radius + 0.35
	torus.rings = 128
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = _rim
	ring.scale = Vector3(1.0, 0.6, 1.0)
	add_child(ring)
	_apply(_color, 0.0)


## Grows (or shrinks) the dome so it covers the colony: a bigger colony gets a
## bigger oxygen bubble.
func set_radius(new_radius: float, animate := true) -> void:
	var target := new_radius / radius
	if not animate or not is_inside_tree():
		scale = Vector3.ONE * target
	else:
		create_tween().set_trans(Tween.TRANS_SINE).tween_property(self, "scale", Vector3.ONE * target, 1.5)


## o2_level and co2 are 0..100. The colour is a smooth gradient
## (red 0 % -> blue 40 % -> green 75 %), not three fixed steps.
func set_air(o2_level: float, co2: float, animate := true) -> void:
	var target := air_color(o2_level)
	var haze := clampf((co2 - 40.0) / 50.0, 0.0, 1.0)
	_danger = clampf((30.0 - o2_level) / 30.0, 0.0, 1.0)
	if not animate or not is_inside_tree():
		_apply(target, haze)
		return
	var from := _color
	var from_haze: float = _glass.get_shader_parameter(&"haze")
	create_tween().tween_method(func(t: float) -> void:
		_apply(from.lerp(target, t), lerpf(from_haze, haze, t)), 0.0, 1.0, 0.8)


static func air_color(o2_level: float) -> Color:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.75, 1.0])
	g.colors = PackedColorArray([COLORS.low, COLORS.low, COLORS.ok, COLORS.good, COLORS.good])
	return g.sample(clampf(o2_level / 100.0, 0.0, 1.0))


## Low oxygen makes the rim pulse like an alarm light.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pulse := 1.0 + _danger * 1.4 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
	_rim.emission_energy_multiplier = 2.2 * pulse


static func status_name(o2_level: float) -> String:
	return "good" if o2_level >= 60.0 else ("ok" if o2_level >= 30.0 else "low")


func _apply(c: Color, haze: float) -> void:
	_color = c
	_glass.set_shader_parameter(&"air_color", c)
	_glass.set_shader_parameter(&"haze", haze)
	_rim.albedo_color = c.darkened(0.3)
	_rim.emission = c
