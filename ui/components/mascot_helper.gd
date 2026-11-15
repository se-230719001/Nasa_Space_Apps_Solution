extends HBoxContainer
## Astronaut helper (bottom-left): mascot portrait badge + dialogue card.
## Breathes while idle, squash-swaps into each new pose, types messages out
## (announcing each beat on Events so the audio layer can blip), reacts to taps, and tucks itself away when it has nothing to
## say. Reactions are layered on top of the breathing (never replace it), so
## motion never jumps between animations.

const POSES := {
	&"info": preload("res://assets/generated/moonminds/mascot_wave.png"),
	&"warning": preload("res://assets/generated/moonminds/mascot_think.png"),
	&"success": preload("res://assets/generated/moonminds/mascot_celebrate.png"),
}
const TIPS := [
	"Tap BUILD to add a new module!",
	"Every module uses something. Watch your bars!",
	"Solar panels make energy for the whole colony.",
	"Drag the ground to look around your base.",
]
const TYPE_SPEED := 45.0  # characters per second
const HIDE_AFTER := 9.0  # seconds without a new message
const PEEK := 0.5  # fraction of the portrait left visible while tucked away

@onready var _mascot: TextureRect = %Mascot
@onready var _bubble: Control = %Bubble
@onready var _text: Label = %BubbleText
@onready var _title: Label = %BubbleTitle

## Reaction layer, multiplied onto the breathing every frame.
var react_scale := Vector2.ONE
var react_rot := 0.0
var _react_tween: Tween
var _tuck_tween: Tween
var _hidden := false
var _shift := 0.0  # how far the helper is currently tucked down
var _idle := 0.0
var _last_char := 0


func _ready() -> void:
	_mascot.mouse_filter = Control.MOUSE_FILTER_STOP
	_mascot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mascot.gui_input.connect(_on_mascot_input)
	_mascot.resized.connect(func() -> void: _mascot.pivot_offset = Vector2(_mascot.size.x / 2, _mascot.size.y))
	_bubble.resized.connect(func() -> void: _bubble.pivot_offset = Vector2(0, _bubble.size.y / 2))


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var b := sin(t * 2.4)
	_mascot.scale = Vector2(1.0 - b * 0.012, 1.0 + b * 0.025) * react_scale
	_mascot.rotation = sin(t * 1.1) * 0.03 + react_rot
	_idle += delta
	if not _hidden and _idle > HIDE_AFTER:
		_tuck(true)


## Shows a message. `kind` picks the pose and card colour (info/warning/success).
func say(kind: StringName, title: String, text: String) -> void:
	_idle = 0.0
	if _hidden:
		_tuck(false)
	_bubble.theme_type_variation = &"DialogCardWarn" if kind == &"warning" else &"DialogCard"
	_title.text = title
	_title.visible = not title.is_empty()
	_text.text = text
	var pop := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(_bubble, "scale", Vector2(1.04, 1.04), 0.08)
	pop.tween_property(_bubble, "scale", Vector2.ONE, 0.18)
	# Typewriter; every couple of letters is announced for the audio layer.
	_text.visible_characters = 0
	_last_char = 0
	create_tween().tween_method(_type_to, 0, text.length(), text.length() / TYPE_SPEED)
	_react(kind)
	Events.mascot_said.emit(kind)


func _type_to(count: int) -> void:
	_text.visible_characters = count
	if count - _last_char >= 2 and _text.text.substr(count - 1, 1) != " ":
		_last_char = count
		Events.mascot_typed.emit()


## Squash, swap the pose at the squash's peak, spring back, then a
## pose-specific beat: hop (success) or head shake (warning).
func _react(kind: StringName) -> void:
	if _react_tween:
		_react_tween.kill()
	var t := create_tween()
	_react_tween = t
	t.tween_property(self, "react_scale", Vector2(1.12, 0.82), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "react_rot", 0.0, 0.09)
	t.tween_callback(func() -> void: _mascot.texture = POSES[kind])
	t.tween_property(self, "react_scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match kind:
		&"success":
			t.tween_property(self, "react_scale", Vector2(0.92, 1.12), 0.12).set_trans(Tween.TRANS_SINE)
			t.tween_property(self, "react_scale", Vector2(1.06, 0.94), 0.1).set_trans(Tween.TRANS_SINE)
			t.tween_property(self, "react_scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
		&"warning":
			for r in [0.1, -0.1, 0.06, 0.0]:
				t.tween_property(self, "react_rot", r, 0.08).set_trans(Tween.TRANS_SINE)


func _on_mascot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		say(&"info", "", TIPS.pick_random())


## Slides the helper down so only the top of the portrait peeks out (or back).
## Moves both offsets, so the anchored bottom edge survives text-size changes.
func _tuck(hide_it: bool) -> void:
	_hidden = hide_it
	var target: float = $Portrait.size.y * (1.0 - PEEK) if hide_it else 0.0
	if _tuck_tween:
		_tuck_tween.kill()
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN if hide_it else Tween.EASE_OUT)
	_tuck_tween = t
	t.tween_method(_set_shift, _shift, target, 0.4)
	t.parallel().tween_property(_bubble, "modulate:a", 0.0 if hide_it else 1.0, 0.2)


func _set_shift(value: float) -> void:
	offset_top += value - _shift
	offset_bottom += value - _shift
	_shift = value

