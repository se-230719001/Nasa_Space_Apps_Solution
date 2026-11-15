extends Camera3D
## Mobile-style outpost camera: drag to pan (with glide), wheel / trackpad /
## two-finger pinch to zoom, and a slow idle sway so the scene never sits dead
## still. Orbits a focus point on the ground; keeps the editor-placed angle.

const PAN_LIMIT := 15.0  # metres from the outpost centre (the play area)
const ZOOM_MIN := 0.6
const ZOOM_MAX := 1.5
const GLIDE_DAMP := 6.0  # higher = glide stops sooner
const IDLE_DELAY := 2.5
const SWAY_YAW := 0.04  # radians
const SWAY_SPEED := 0.25

var _focus := Vector3.ZERO
var _offset: Vector3  # camera position relative to focus at zoom 1
var _zoom := 1.0
var _velocity := Vector3.ZERO
var _dragging := false
var _idle := 0.0
var _sway_t := 0.0
var _sway_w := 0.0
var _touches := {}  # index -> position, for pinch


func _ready() -> void:
	# Focus = where the camera currently looks at the ground (y = 0).
	var fwd := -global_basis.z
	_focus = global_position + fwd * (-global_position.y / fwd.y)
	_offset = global_position - _focus


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag and _touches.size() == 2:
		var other: Vector2 = _touches[_touches.keys().filter(func(k): return k != event.index)[0]]
		var before := other.distance_to(_touches[event.index])
		_touches[event.index] = event.position
		_zoom_by(before / maxf(other.distance_to(event.position), 1.0))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and _touches.size() < 2
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.1)
	elif event is InputEventMagnifyGesture:
		_zoom_by(1.0 / event.factor)
	elif event is InputEventPanGesture:
		_pan(-event.delta * 8.0)
	elif event is InputEventMouseMotion and _dragging and _touches.size() < 2:
		_pan(event.relative)
	else:
		return
	_idle = 0.0


## Moves the focus so the ground follows the pointer.
func _pan(screen_delta: Vector2) -> void:
	var right := global_basis.x
	var ahead := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()
	# World metres per screen pixel at the focus distance.
	var scale := 2.0 * (_offset * _zoom).length() * tan(deg_to_rad(fov) / 2.0) \
		/ get_viewport().get_visible_rect().size.y
	var move := (-right * screen_delta.x + ahead * screen_delta.y) * scale
	_move_focus(move)
	_velocity = move / maxf(get_process_delta_time(), 0.001)


func _zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)


func _move_focus(move: Vector3) -> void:
	_focus += move
	var flat := Vector2(_focus.x, _focus.z).limit_length(PAN_LIMIT)
	_focus = Vector3(flat.x, 0.0, flat.y)


func _process(delta: float) -> void:
	if not _dragging:
		_move_focus(_velocity * delta)
		_velocity *= exp(-GLIDE_DAMP * delta)
	_idle += delta
	# Sway eases in when idle and out on input, so the view never jumps.
	_sway_w = move_toward(_sway_w, 1.0 if _idle > IDLE_DELAY else 0.0, delta * 0.5)
	_sway_t += delta * _sway_w
	var yaw := sin(_sway_t * SWAY_SPEED) * SWAY_YAW * _sway_w
	global_position = _focus + (_offset * _zoom).rotated(Vector3.UP, yaw)
	look_at(_focus)
