@tool
class_name SpriteButton
extends TextureButton
## Button drawn from a MoonMinds atlas sprite (label is baked into the art).
## Adds the interaction states the art doesn't include: hover brighten, press
## squash, greyed disabled, and a glow ring for keyboard/controller focus.

const HOVER_TINT := Color(1.12, 1.12, 1.12)
const DISABLED_TINT := Color(0.55, 0.55, 0.65, 0.8)

var _hovered := false
var _focus_ring := StyleBoxFlat.new()


func _init() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_focus_ring.draw_center = false
	_focus_ring.set_border_width_all(4)
	_focus_ring.border_color = Color("#FFF3B0")
	_focus_ring.set_expand_margin_all(3)
	_focus_ring.shadow_color = Color("#FFE27A", 0.55)
	_focus_ring.shadow_size = 10
	_focus_ring.anti_aliasing = true


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_squash.bind(0.94))
	button_up.connect(_squash.bind(1.0))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(func() -> void: pivot_offset = size / 2)
	pivot_offset = size / 2
	_update_tint()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENABLED or what == NOTIFICATION_DISABLED:
		_update_tint()


func _draw() -> void:
	if has_focus() and not Engine.is_editor_hint():
		var r := _art_rect()
		_focus_ring.set_corner_radius_all(int(r.size.y / 2))
		draw_style_box(_focus_ring, r)


## Where the texture is actually drawn with KEEP_ASPECT_CENTERED.
func _art_rect() -> Rect2:
	if texture_normal == null:
		return Rect2(Vector2.ZERO, size)
	var tex := texture_normal.get_size()
	var s := minf(size.x / tex.x, size.y / tex.y)
	var drawn := tex * s
	return Rect2((size - drawn) / 2, drawn)


func _update_tint() -> void:
	if disabled and texture_disabled == null:
		self_modulate = DISABLED_TINT
	elif _hovered and not disabled:
		self_modulate = HOVER_TINT
	else:
		self_modulate = Color.WHITE


func _set_hovered(value: bool) -> void:
	_hovered = value
	_update_tint()


func _squash(to: float) -> void:
	create_tween().tween_property(self, "scale", Vector2.ONE * to, 0.08)
