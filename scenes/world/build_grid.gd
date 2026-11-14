class_name BuildGrid
extends Node3D
## Square building plots inside the dome. In placement mode free cells glow and
## the hovered cell is highlighted; any tap on the ground (no drag) reports the
## cell, so tapping a building opens its panel.

signal cell_tapped(cell: Vector2i)

const SIZE := 12
const CELL := 4.0
const ORIGIN := Vector2(-24.0, -24.0)
const TILE_SHADER := preload("res://scenes/environment/placement_grid.gdshader")
const TAP_SLOP := 8.0

## Set by main.gd: func(cell) -> bool
var is_free: Callable = func(_c: Vector2i) -> bool: return false
var placing := false
var _tiles := {}
var _hover := Vector2i(-1, -1)
var _press_pos := Vector2.INF
var _mat_free := ShaderMaterial.new()
var _mat_hover := ShaderMaterial.new()


static func cell_center(cell: Vector2i) -> Vector3:
	var p := ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	return Vector3(p.x, 0.0, p.y)


static func cell_at(world: Vector3) -> Vector2i:
	var p := (Vector2(world.x, world.z) - ORIGIN) / CELL
	return Vector2i(floori(p.x), floori(p.y))


static func in_radius(cell: Vector2i, radius: float) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE or cell.y >= SIZE:
		return false
	var c := cell_center(cell)
	return Vector2(c.x, c.z).length() <= radius - CELL * 0.6


func _ready() -> void:
	for m in [_mat_free, _mat_hover]:
		m.shader = TILE_SHADER
		m.set_shader_parameter(&"cells", 1.0)
	_mat_hover.set_shader_parameter(&"color", Color("#FFE27A"))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * (CELL - 0.35)
	for x in SIZE:
		for y in SIZE:
			var t := MeshInstance3D.new()
			t.mesh = mesh
			t.material_override = _mat_free
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			t.position = cell_center(Vector2i(x, y)) + Vector3(0, 0.05, 0)
			t.visible = false
			add_child(t)
			_tiles[Vector2i(x, y)] = t


func show_free_cells() -> void:
	placing = true
	for cell in _tiles:
		_tiles[cell].visible = is_free.call(cell)
		_tiles[cell].material_override = _mat_free
	_hover = Vector2i(-1, -1)


func hide_cells() -> void:
	placing = false
	for t in _tiles.values():
		t.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and placing:
		_set_hover(_cell_under(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		elif _press_pos.distance_to(event.position) < TAP_SLOP:
			var cell := _cell_under(event.position)
			if cell.x >= 0:
				cell_tapped.emit(cell)


func _set_hover(cell: Vector2i) -> void:
	if cell == _hover:
		return
	if _tiles.has(_hover):
		_tiles[_hover].material_override = _mat_free
	_hover = cell
	if _tiles.has(cell) and is_free.call(cell):
		_tiles[cell].material_override = _mat_hover


func _cell_under(screen: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return Vector2i(-1, -1)
	var c := cell_at(from + dir * (-from.y / dir.y))
	return c if c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE else Vector2i(-1, -1)
