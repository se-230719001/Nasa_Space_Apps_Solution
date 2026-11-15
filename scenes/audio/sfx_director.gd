extends Node
## Autoload "Sfx": turns gameplay Events into sound effects. Owned by the
## audio side: to change what something sounds like, edit SOUNDS below (or add
## a handler); gameplay code never needs to change.

## Event key -> sound. Keys match the handlers in _ready(). A missing entry is
## silent, so sounds can be added one by one.
var SOUNDS := {
	&"button_pressed": preload("res://assets/audio/sfx/elevenlabs/button_pressed.ogg"),
	&"build_popup_opened": preload("res://assets/audio/sfx/elevenlabs/build_popup_opened.ogg"),
	&"build_cancelled": preload("res://assets/audio/sfx/elevenlabs/build_cancelled.ogg"),
	&"build_confirmed": preload("res://assets/audio/sfx/elevenlabs/build_confirmed.ogg"),
	&"resource_up": preload("res://assets/audio/sfx/elevenlabs/resource_up.ogg"),
	&"resource_down": preload("res://assets/audio/sfx/elevenlabs/resource_down.ogg"),
	&"mascot_info": preload("res://assets/audio/sfx/elevenlabs/mascot_info.ogg"),
	&"mascot_warning": preload("res://assets/audio/sfx/elevenlabs/mascot_warning.ogg"),
	&"mascot_success": preload("res://assets/audio/sfx/elevenlabs/mascot_success.ogg"),
	&"mascot_typed": preload("res://assets/audio/sfx/elevenlabs/mascot_typed.ogg"),
}
const POOL_SIZE := 6

var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	Events.button_pressed.connect(func(_id): play(&"button_pressed"))
	Events.build_popup_opened.connect(func(_m): play(&"build_popup_opened"))
	Events.build_cancelled.connect(func(_m): play(&"build_cancelled"))
	Events.build_confirmed.connect(func(_m): play(&"build_confirmed"))
	Events.resource_changed.connect(func(_r, d): play(&"resource_up" if d > 0 else &"resource_down"))
	Events.mascot_said.connect(func(kind): play(StringName("mascot_" + kind)))
	Events.mascot_typed.connect(func(): play(&"mascot_typed", -14.0, randf_range(0.9, 1.15)))


## Plays a sound by key on the next free player (overlapping sounds are fine).
func play(key: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream = SOUNDS.get(key)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
