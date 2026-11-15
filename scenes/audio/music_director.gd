extends Node
## Autoload "Music": looping background music with crossfades, plus one-shot
## stingers that briefly duck the music. Tracks live in assets/audio/.

const TRACKS := {
	&"intro": preload("res://assets/audio/music/intro_music_box.ogg"),
	&"outpost": preload("res://assets/audio/music/outpost_theme.ogg"),
	&"explore": preload("res://assets/audio/music/explore_theme.mp3"),
}
const STINGERS := {
	&"mission_complete": preload("res://assets/audio/sfx/elevenlabs/mission_complete.ogg"),
}
const FADE_TIME := 1.5
const SILENT_DB := -40.0
const MUSIC_DB := -6.0

var current: StringName = &""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _sfx := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_sfx.bus = &"SFX"
	add_child(_sfx)
	for key in TRACKS:
		var s: AudioStream = TRACKS[key]
		if "loop" in s:
			s.loop = true
	Events.screen_changed.connect(play)
	Events.task_completed.connect(func(_task): stinger(&"mission_complete"))


## Crossfades to a track; does nothing if it is already playing.
func play(track: StringName) -> void:
	if track == current or not TRACKS.has(track):
		return
	current = track
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	new.stream = TRACKS[track]
	new.volume_db = SILENT_DB
	new.play()
	var t := create_tween().set_parallel()
	t.tween_property(new, "volume_db", MUSIC_DB, FADE_TIME)
	t.tween_property(old, "volume_db", SILENT_DB, FADE_TIME)
	t.chain().tween_callback(old.stop)


## Plays a short stinger and ducks the music under it.
func stinger(id: StringName) -> void:
	if not STINGERS.has(id):
		return
	_sfx.stream = STINGERS[id]
	_sfx.play()
	var music := _players[_active]
	var t := create_tween()
	t.tween_property(music, "volume_db", MUSIC_DB - 12.0, 0.2)
	t.tween_interval(_sfx.stream.get_length() - 0.6)
	t.tween_property(music, "volume_db", MUSIC_DB, 0.8)
