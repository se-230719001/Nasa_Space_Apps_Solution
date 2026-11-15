class_name BuildingKit
extends RefCounted
## Shared materials and mesh helpers for the procedural MoonMinds modules.
## Palette follows the style guide (§2.3): white hulls, orange doors/trim,
## cyan windows, blue solar panels, transparent greenhouse domes.

const OUTLINE_SHADER := preload("res://scenes/environment/outline.gdshader")
## Materials drawn without a toon outline: see-through or tiny glowing parts,
## where a dark shell would show through or clutter the silhouette.
const NO_OUTLINE: Array[StringName] = [&"glass", &"window", &"water", &"lamp"]

static var _cache := {}
static var _outline: ShaderMaterial


## Shared toon outline pass (style guide: thick dark-navy silhouettes).
static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline


static func mat(id: StringName) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var m := StandardMaterial3D.new()
	match id:
		&"hull":
			m.albedo_color = Color("#E9EDF6")
			m.roughness = 0.38
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
		&"panel":
			m.albedo_color = Color("#A9B1C8")
			m.roughness = 0.5
			m.metallic = 0.3
		&"dark":
			m.albedo_color = Color("#3A4060")
			m.roughness = 0.6
			m.metallic = 0.4
		&"trim":
			m.albedo_color = Color("#FFB020")
			m.roughness = 0.35
		&"window":
			m.albedo_color = Color("#0B2A55")
			m.emission_enabled = true
			m.emission = Color("#00C6FF")
			m.emission_energy_multiplier = 1.8
			m.roughness = 0.1
		&"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.62, 0.9, 1.0, 0.22)
			m.roughness = 0.04
			m.metallic_specular = 1.0
			m.rim_enabled = true
			m.rim = 0.8
			m.rim_tint = 0.2
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"frame":
			m.albedo_color = Color("#D8DEEC")
			m.roughness = 0.3
			m.metallic = 0.6
		&"solar":
			m.albedo_color = Color("#2340C8")
			m.roughness = 0.18
			m.metallic = 0.7
			m.albedo_texture = _solar_cells()
		&"soil":
			m.albedo_color = Color("#5B3A26")
			m.roughness = 1.0
		&"plant":
			m.albedo_color = Color("#3CDB56")
			m.roughness = 0.7
		&"water":
			m.albedo_color = Color("#0A3C6E")
			m.emission_enabled = true
			m.emission = Color("#00C6FF")
			m.emission_energy_multiplier = 0.9
			m.roughness = 0.05
		&"lamp":
			m.albedo_color = Color.WHITE
			m.emission_enabled = true
			m.emission = Color("#FFE9B0")
			m.emission_energy_multiplier = 4.0
	if id not in NO_OUTLINE:
		m.next_pass = outline()
	_cache[id] = m
	return m


## Same material without the outline pass, for parts lying flat on the
## ground (landing pads): an outline at ground level reads as a gap underneath,
## making the part look like it floats.
static func flat(id: StringName) -> StandardMaterial3D:
	var key := StringName(String(id) + "_flat")
	if not _cache.has(key):
		var m: StandardMaterial3D = mat(id).duplicate()
		m.next_pass = null
		_cache[key] = m
	return _cache[key]


## Solar-cell grid texture (white gridlines on blue).
static func _solar_cells() -> ImageTexture:
	var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1))
	for y in 64:
		for x in 64:
			if x % 16 == 0 or y % 16 == 0:
				img.set_pixel(x, y, Color(0.75, 0.82, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func add(parent: Node3D, mesh: Mesh, material: StringName, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(material)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(radius: float, height: float, segments := 32, top := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top < 0.0 else top
	m.height = height
	m.radial_segments = segments
	return m


static func sphere(radius: float, hemisphere := false, segments := 32) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius if hemisphere else radius * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = segments
	m.rings = segments / 2
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 32
	m.rings = 8
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 48
	m.ring_segments = 10
	return m
