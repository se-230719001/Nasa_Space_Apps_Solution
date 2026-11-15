extends Node3D
## Outpost scene root: mirrors the Colony simulation in the 3D world, and runs
## the base grid: the player chooses each building's parcels (BaseGrid), with
## a see-through "ghost", green/red parcels and a reason when a spot is wrong.

## A building is being placed (new or moved).
signal placement_started(module_id: StringName)
## The ghost moved/turned: can it go here, and if not, why.
signal placement_updated(ok: bool, reason: String)
## Placement mode closed; `placed` is false when cancelled.
signal placement_ended(module_id: StringName, placed: bool)
## The player tapped a building on the base (to move or turn it).
signal building_tapped(module_id: StringName)

const SCENES := {
	&"greenhouse": preload("res://scenes/buildings/greenhouse.gd"),
	&"shield": preload("res://scenes/buildings/shield_generator.gd"),
	&"rover": preload("res://scenes/buildings/rover.gd"),
	&"ice_drill": preload("res://scenes/buildings/ice_drill.gd"),
	&"solar": preload("res://scenes/buildings/solar_array.gd"),
	&"water_tank": preload("res://scenes/buildings/water_tank.gd"),
	## NASA 3D Resources model (see nasa_db/manifest.csv), decoded from Draco.
	&"lander": preload("res://nasa_db/processed/models/apollo_lunar_module.glb"),
	&"lamp": preload("res://scenes/buildings/decor.gd"),
	&"antenna": preload("res://scenes/buildings/decor.gd"),
	&"moon_garden": preload("res://scenes/buildings/decor.gd"),
}
## Parcel colours. Blocked parcels also get a white cross (not colour alone).
const FREE := Color(0.35, 0.95, 0.55, 0.22)
const TAKEN := Color(0.95, 0.3, 0.3, 0.35)
const PATH_COLOR := Color(1.0, 0.8, 0.2, 0.4)
const GOOD := Color(0.35, 1.0, 0.5, 0.7)
const BAD := Color(1.0, 0.25, 0.25, 0.7)
const TAP_SLOP := 12.0  # px a press may move and still count as a tap

@onready var _tile: MeshInstance3D = $World/PlacementTile
@onready var _camera: Camera3D = $Camera3D
var _spawned := {}
var _placing: StringName = &""
var _moving := false
var _ghost: Node3D
var _ghost_cell := Vector2i.ZERO
var _ghost_rot := 0
var _grid_mesh: MeshInstance3D
var _foot_mesh: MeshInstance3D
var _press_at := Vector2.ZERO
var _pressed := false


func _ready() -> void:
	# Modules that start in the scene, so upgrades can react on them too.
	_spawned = {&"habitat": $World/HabitatBase, &"solar": $World/SolarArray, &"water_tank": $World/WaterTank}
	_tile.hide()  # the grid replaces the old single placement tile
	Colony.module_changed.connect(_on_module_changed)
	Colony.placement_changed.connect(func(id: StringName) -> void:
		if _spawned.has(id):
			_apply_placement(id, _spawned[id]))
	# A loaded save or a retried day: show what is already built, no flourish.
	for id in Colony.state.levels:
		_place(id, int(Colony.state.levels[id]))
	for id in [&"solar", &"water_tank"]:
		_apply_placement(id, _spawned[id])
	_build_flag()
	Colony.base_changed.connect(_paint_flag)
	Colony.resume()
	Events.screen_changed.emit(&"outpost")


func _on_module_changed(module_id: StringName, level: int) -> void:
	var node := _place(module_id, level)
	if node:
		_pop(node)


## Puts `module_id` in the world at `level` (spawning it if needed), on its parcels.
func _place(module_id: StringName, level: int) -> Node3D:
	if _spawned.has(module_id):
		var existing: Node3D = _spawned[module_id]
		if "level" in existing and existing.level != level:
			existing.level = level
		return existing
	if not SCENES.has(module_id):
		return null
	var module := _make(module_id)
	if "level" in module:
		module.level = level
	$World.add_child(module)
	_spawned[module_id] = module
	_apply_placement(module_id, module)
	return module


## A new instance of a building: procedural script or imported model.
static func _make(module_id: StringName) -> Node3D:
	var src: Variant = SCENES[module_id]
	var node: Node3D = src.instantiate() if src is PackedScene else src.new()
	if "kind" in node:
		node.kind = String(module_id)  # decorations share one script
	return node


func _apply_placement(module_id: StringName, node: Node3D) -> void:
	var p := Colony.placement(module_id)
	if not p.is_empty():
		node.transform = BaseGrid.world_transform(module_id, p.cell, p.rot)


# --- The player's flag ----------------------------------------------------------

var _flag_cloth: MeshInstance3D


## A flagpole on the habitat's pad (fixed parcels, so it never blocks building).
func _build_flag() -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 3.2
	pole.mesh = cyl
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("#D9DEE8")
	pole.material_override = grey
	pole.position = Vector3(-9.0, 1.6, -0.9)
	$World.add_child(pole)
	_flag_cloth = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.8, 0.04)
	_flag_cloth.mesh = box
	_flag_cloth.material_override = StandardMaterial3D.new()
	_flag_cloth.position = Vector3(0.65, 1.15, 0.0)
	pole.add_child(_flag_cloth)
	_paint_flag()


func _paint_flag() -> void:
	_flag_cloth.material_override.albedo_color = Colony.FLAGS.get(Colony.state.get("flag", &"blue"), Color.WHITE)


# --- Placement mode -------------------------------------------------------------

func is_placing() -> bool:
	return _placing != &""


## Starts choosing parcels for a new building, or moving a built one.
func begin_placement(module_id: StringName, moving := false) -> void:
	if is_placing():
		cancel_placement()
	var spot := Colony.placement(module_id) if moving else BaseGrid.suggest(Colony.state.placements, module_id)
	if spot.is_empty():
		spot = {"cell": BaseGrid.cell_at(Vector3.ZERO), "rot": 0}
	_placing = module_id
	_moving = moving
	_ghost_cell = spot.cell
	_ghost_rot = spot.rot
	_ghost = _make(module_id)
	if "level" in _ghost:
		_ghost.level = maxi(1, int(Colony.state.levels.get(module_id, 1)))
	$World.add_child(_ghost)
	for gi in _ghost.find_children("*", "GeometryInstance3D", true, false):
		gi.transparency = 0.45
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if moving and _spawned.has(module_id):
		_spawned[module_id].hide()
	_grid_mesh = _overlay(_grid_cells(module_id))
	_camera.input_locked = true
	placement_started.emit(module_id)
	_update_ghost()


func move_ghost_to(cell: Vector2i) -> void:
	_ghost_cell = cell
	_update_ghost()


func rotate_ghost() -> void:
	_ghost_rot = (_ghost_rot + 1) % 4
	_update_ghost()


## Places the ghost if the spot is allowed. A new building is built here.
func confirm_placement() -> bool:
	var id := _placing
	if id == &"" or not Colony.set_placement(id, _ghost_cell, _ghost_rot).ok:
		return false
	var moving := _moving
	_end_placement()
	placement_ended.emit(id, true)  # first, so "built!" comes before the day's cheer
	if not moving:
		Colony.build(id)
	return true


func cancel_placement() -> void:
	var id := _placing
	_end_placement()
	if id != &"":
		placement_ended.emit(id, false)


## Turns a built building in place, if its new shape fits. Returns {ok, reason}.
func rotate_building(module_id: StringName) -> Dictionary:
	var p := Colony.placement(module_id)
	if p.is_empty():
		return {"ok": false, "reason": "This one can't turn"}
	return Colony.set_placement(module_id, p.cell, (int(p.rot) + 1) % 4)


func _end_placement() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	for m in [_grid_mesh, _foot_mesh]:
		if m:
			m.queue_free()
	_grid_mesh = null
	_foot_mesh = null
	if _moving and _spawned.has(_placing):
		_spawned[_placing].show()
	_camera.input_locked = false
	_placing = &""
	_moving = false


func _update_ghost() -> void:
	_ghost.transform = BaseGrid.world_transform(_placing, _ghost_cell, _ghost_rot)
	var check := BaseGrid.check(Colony.state.placements, _placing, _ghost_cell, _ghost_rot)
	var cells := []
	for c in BaseGrid.cells(_placing, _ghost_cell, _ghost_rot):
		var blocked: bool = not BaseGrid.in_dome(c) or BaseGrid.occupant(Colony.state.placements, c, _placing) != &""
		cells.append([c, BAD if blocked or not check.ok else GOOD, blocked])
	if _foot_mesh:
		_foot_mesh.queue_free()
	_foot_mesh = _overlay(cells, 0.09, true)
	placement_updated.emit(check.ok, check.reason)


## Every parcel in the dome, coloured by what is on it (the moving building's
## own parcels count as free).
func _grid_cells(ignore: StringName) -> Array:
	var out := []
	for x in range(-BaseGrid.HALF, BaseGrid.HALF):
		for z in range(-BaseGrid.HALF, BaseGrid.HALF):
			var c := Vector2i(x, z)
			if not BaseGrid.in_dome(c):
				continue
			var who := BaseGrid.occupant(Colony.state.placements, c, ignore)
			if who == &"":
				out.append([c, FREE, false])
			elif who == &"path":
				out.append([c, PATH_COLOR, false])
			else:
				out.append([c, TAKEN, true])
	return out


## A flat mesh of parcels: [[cell, colour, crossed], ...] just above the ground.
## `on_top`: drawn over everything, so the ghost's red parcels show even on
## top of the habitat's landing pad.
func _overlay(cells: Array, height := 0.06, on_top := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in cells:
		var center := BaseGrid.cell_center(item[0])
		var h := BaseGrid.CELL / 2.0 - 0.12
		_quad(st, center, Vector2(h, h), 0.0, item[1], height)
		if item[2]:
			for angle in [PI / 4.0, -PI / 4.0]:
				_quad(st, center, Vector2(h * 1.2, 0.07), angle, Color(1, 1, 1, 0.8), height + 0.005)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = on_top
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$World.add_child(mi)
	return mi


static func _quad(st: SurfaceTool, center: Vector2, half: Vector2, angle: float, color: Color, y: float) -> void:
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var v := []
	for c in corners:
		var p: Vector2 = center + c.rotated(angle)
		v.append(Vector3(p.x, y, p.y))
	st.set_color(color)
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(v[i])


## Pointer on the ground (y = 0), or null when looking at the sky.
func _ground_at(screen: Vector2) -> Variant:
	var from := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	return from + dir * t if t > 0.0 else null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_at = event.position
			if is_placing():
				_drag_ghost(event.position)
		else:
			if _pressed and not is_placing() and event.position.distance_to(_press_at) < TAP_SLOP:
				_tap(event.position)
			_pressed = false
	elif event is InputEventMouseMotion and _pressed and is_placing():
		_drag_ghost(event.position)


## The ghost follows the pointer, centred on it.
func _drag_ghost(screen: Vector2) -> void:
	var hit: Variant = _ground_at(screen)
	if hit == null:
		return
	var cell := BaseGrid.cell_at(hit) - BaseGrid.size_of(_placing, _ghost_rot) / 2
	if cell != _ghost_cell:
		move_ghost_to(cell)


## A tap on a building (or the habitat) asks the HUD to offer move / turn.
func _tap(screen: Vector2) -> void:
	var hit: Variant = _ground_at(screen)
	if hit == null:
		return
	var who := BaseGrid.occupant(Colony.state.placements, BaseGrid.cell_at(hit))
	if who != &"" and who != &"path":
		building_tapped.emit(who)


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

