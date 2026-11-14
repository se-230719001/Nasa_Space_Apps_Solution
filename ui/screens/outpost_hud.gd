extends Control
## Outpost management HUD built from the MoonMinds sprite atlas (assets/sprites/).
## Demo flow: BUILD -> "Build Greenhouse?" card -> confirm -> bars animate, the
## status chip and mascot react (Observation -> Cause -> Next action).

signal build_confirmed(module_id: StringName)

const CHIPS := {
	ResourceBar.Status.HEALTHY: preload("res://assets/sprites/chips/healthy.png"),
	ResourceBar.Status.WARNING: preload("res://assets/sprites/chips/warning.png"),
	ResourceBar.Status.CRITICAL: preload("res://assets/sprites/chips/critical.png"),
}
const MASCOTS := {
	&"info": preload("res://assets/sprites/mascots/wave.png"),
	&"warning": preload("res://assets/sprites/mascots/think.png"),
	&"success": preload("res://assets/sprites/mascots/celebrate.png"),
}
const CHECK := preload("res://assets/sprites/icons/check.png")

## Greenhouse effect on resources, in percentage points.
const GREENHOUSE_DELTA := {&"power": -30.0, &"water": -20.0, &"food": 30.0}

var _greenhouse_built := false

@onready var _bars := {
	&"power": %Power as ResourceBar,
	&"water": %Water as ResourceBar,
	&"food": %Food as ResourceBar,
	&"shield": %Shield as ResourceBar,
}
@onready var _popup: Control = %BuildPopup


func _ready() -> void:
	%BuildButton.pressed.connect(_open_build_popup)
	%BuildButton.pressed.connect(Music.play.bind(&"outpost"))
	%ResearchButton.pressed.connect(_say.bind(&"info", "", "The research lab is coming soon. Build a greenhouse first!"))
	%ResearchButton.pressed.connect(Music.play.bind(&"outpost"))
	%ExploreButton.pressed.connect(_say.bind(&"info", "", "Exploring needs a rover. Let's grow food for the crew first!"))
	%ExploreButton.pressed.connect(Music.play.bind(&"explore"))
	%SettingsButton.pressed.connect(_say.bind(&"info", "", "Settings will live here."))
	%CloseButton.pressed.connect(_close_build_popup)
	%CancelButton.pressed.connect(_close_build_popup)
	%ConfirmButton.pressed.connect(_confirm_build)
	for key in _bars:
		_bars[key].status = _status_for(_bars[key].value)
	_update_status_chip()
	_play_splash()


func _unhandled_input(event: InputEvent) -> void:
	if _popup.visible and event.is_action_pressed(&"ui_cancel"):
		_close_build_popup()
		get_viewport().set_input_as_handled()


func _play_splash() -> void:
	var splash: Control = %Splash
	splash.show()
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(splash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(splash.hide)
	tween.tween_callback(%BuildButton.grab_focus)


func _open_build_popup() -> void:
	if _greenhouse_built:
		_say(&"info", "", "Your greenhouse is growing food! More modules are coming soon.")
		return
	_popup.visible = true
	_popup.modulate.a = 0.0
	create_tween().tween_property(_popup, "modulate:a", 1.0, 0.2)
	%ConfirmButton.grab_focus()


func _close_build_popup() -> void:
	_popup.visible = false
	%BuildButton.grab_focus()


func _confirm_build() -> void:
	_close_build_popup()
	_greenhouse_built = true
	for key in GREENHOUSE_DELTA:
		var bar: ResourceBar = _bars[key]
		var target := clampf(bar.value + GREENHOUSE_DELTA[key], 0.0, 100.0)
		bar.animate_to(target, _status_for(target))
	%Check.texture = CHECK
	Music.stinger(&"mission_complete")
	_update_status_chip()
	build_confirmed.emit(&"greenhouse")

	if _bars[&"power"].status != ResourceBar.Status.HEALTHY:
		_say(&"warning", "Need more power!",
			"Your greenhouse makes more food, but it also uses power. Try adding a solar panel.")
	else:
		_say(&"success", "Great balance!", "Your resources are well balanced!")


## Overall outpost state = the worst resource state ("Are we okay?" at a glance).
func _update_status_chip() -> void:
	var worst := ResourceBar.Status.HEALTHY
	for key in _bars:
		worst = maxi(worst, _bars[key].status) as ResourceBar.Status
	%StatusChip.texture = CHIPS[worst]
	%StatusChip.tooltip_text = "Outpost status: %s" % ResourceBar.Status.keys()[worst].capitalize()


## Mascot speech: pose + bubble colour + title, so meaning never relies on colour alone.
func _say(kind: StringName, title: String, text: String) -> void:
	%Mascot.texture = MASCOTS[kind]
	%Bubble.theme_type_variation = &"BubbleYellow" if kind == &"warning" else &"BubbleWhite"
	%BubbleTitle.text = title
	%BubbleTitle.visible = not title.is_empty()
	%BubbleText.text = text
	var bubble: Control = %Bubble
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.9, 0.9)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(bubble, "scale", Vector2.ONE, 0.25)


static func _status_for(value: float) -> ResourceBar.Status:
	if value <= 25.0:
		return ResourceBar.Status.CRITICAL
	if value <= 40.0:
		return ResourceBar.Status.WARNING
	return ResourceBar.Status.HEALTHY
