extends Camera3D
## Free colony camera (mouse, keyboard and touch). Orbits a ground point:
##   mouse: left-drag pans, right/middle-drag rotates, wheel zooms
##   keys:  WASD / arrows pan, Q / E rotate, +/- zoom
##   touch: one finger pans, two fingers pinch-zoom and twist-rotate
## Taps (no movement) are left for the build grid. The scene's camera
## transform is the starting view.

@export var min_distance := 12.0
@export var max_distance := 85.0
@export var min_pitch := 12.0
@export var max_pitch := 78.0
@export var pan_limit := 34.0
const DRAG_SLOP := 6.0

var _pivot := Vector3.ZERO
var _yaw := 0.0
var _pitch := 30.0
var _distance := 30.0
var _drag_button := 0
var _press_pos := Vector2.ZERO
var _dragging := false
var _touches := {}


func _ready() -> void:
	var fwd := -global_basis.z
	var t := -global_position.y / fwd.y if absf(fwd.y) > 0.01 else 20.0
	_pivot = global_position + fwd * t
	var off := global_position - _pivot
	_distance = off.length()
	_pitch = rad_to_deg(asin(off.y / _distance))
	_yaw = rad_to_deg(atan2(off.x, off.z))
	_apply()


func _process(delta: float) -> void:
	var move := Vector2(Input.get_axis(&"ui_left", &"ui_right"), Input.get_axis(&"ui_up", &"ui_down"))
	if Input.is_key_pressed(KEY_A): move.x -= 1
	if Input.is_key_pressed(KEY_D): move.x += 1
	if Input.is_key_pressed(KEY_W): move.y -= 1
	if Input.is_key_pressed(KEY_S): move.y += 1
	var rot := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	var zoom := float(Input.is_key_pressed(KEY_MINUS)) - float(Input.is_key_pressed(KEY_EQUAL))
	if move != Vector2.ZERO or rot != 0.0 or zoom != 0.0:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		_pan_world(move.normalized() * _distance * 0.9 * delta)
		_yaw += rot * 70.0 * delta
		_distance = clampf(_distance * (1.0 + zoom * 1.2 * delta), min_distance, max_distance)
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.1)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_drag_button = event.button_index
					_press_pos = event.position
					_dragging = false
				elif event.button_index == _drag_button:
					if _dragging:
						get_viewport().set_input_as_handled()
					_drag_button = 0
					_dragging = false
	elif event is InputEventMouseMotion and _drag_button != 0 and not _touches.size() > 0:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_SLOP:
			_dragging = true
		if _dragging:
			if _drag_button == MOUSE_BUTTON_LEFT:
				_pan_screen(event.relative)
			else:
				_rotate(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / event.factor)
	elif event is InputEventPanGesture:
		_pan_screen(-event.delta * 12.0)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var before: Dictionary = _touches.duplicate()
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var k := _touches.keys()
			var a0: Vector2 = before[k[0]]
			var b0: Vector2 = before[k[1]]
			var a1: Vector2 = _touches[k[0]]
			var b1: Vector2 = _touches[k[1]]
			if a0.distance_to(b0) > 1.0 and a1.distance_to(b1) > 1.0:
				_zoom(a0.distance_to(b0) / a1.distance_to(b1))
				_yaw -= rad_to_deg((b1 - a1).angle() - (b0 - a0).angle())
				_apply()
			get_viewport().set_input_as_handled()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, min_distance, max_distance)
	_apply()


func _rotate(rel: Vector2) -> void:
	_yaw -= rel.x * 0.3
	_pitch = clampf(_pitch + rel.y * 0.25, min_pitch, max_pitch)
	_apply()


## Drag in screen pixels: the ground under the cursor follows it.
func _pan_screen(rel: Vector2) -> void:
	var meters_per_px := 2.0 * _distance * tan(deg_to_rad(fov) / 2.0) / get_viewport().get_visible_rect().size.y
	_pan_world(-rel * meters_per_px)


## x = right, y = forward on the ground plane (screen-aligned).
func _pan_world(v: Vector2) -> void:
	var yaw := deg_to_rad(_yaw)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	_pivot += right * v.x + back * v.y
	var flat := Vector2(_pivot.x, _pivot.z).limit_length(pan_limit)
	_pivot = Vector3(flat.x, 0.0, flat.y)
	_apply()


func _apply() -> void:
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _distance
	look_at_from_position(_pivot + off, _pivot, Vector3.UP)


func focus_on(point: Vector3) -> void:
	_pivot = Vector3(point.x, 0.0, point.z)
	_apply()
