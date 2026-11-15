extends Control
## Outpost (Base) HUD laid around the 3D colony so the centre stays clear:
##   top-left   static mission clock        top edge  fixed resource pills
##   top-right  settings                    right     slide-in checklist
##   bottom-left astronaut helper           bottom-right Search / Explore / Build
## Demo flow: BUILD -> "Build Greenhouse?" card -> confirm -> bars animate, the
## health gauge, checklist and astronaut react (Observation -> Cause -> Next action).

signal build_confirmed(module_id: StringName)

const CHECK := preload("res://assets/generated/moonminds/icon_check.png")
const BOX := preload("res://assets/generated/moonminds/icon_box.png")

## Greenhouse effect on resources, in percentage points.
const GREENHOUSE_DELTA := {&"power": -30.0, &"water": -20.0, &"food": 30.0}
## Health gauge wording per status (colour is never the only signal).
const HEALTH_TEXT := {
	ResourceBar.Status.HEALTHY: "Good",
	ResourceBar.Status.WARNING: "OK",
	ResourceBar.Status.CRITICAL: "Low",
}
## Example checklist content. `id` lets game events tick a task off.
const TASKS := [
	{"id": &"greenhouse", "text": "Build your first Greenhouse"},
	{"id": &"energy", "text": "Upgrade the Energy Center"},
	{"id": &"oxygen", "text": "Check the colony's oxygen"},
	{"id": &"explore", "text": "Prepare the first exploration"},
]

const MARGIN := 24.0
const TOP := 16.0
const SLIDE_TIME := 0.32

var _greenhouse_built := false
var _checklist_open := false
var _done := {}
var _task_rows := {}
var _checklist_tween: Tween

@onready var _bars := {
	&"power": %Power as ResourceBar,
	&"water": %Water as ResourceBar,
	&"food": %Food as ResourceBar,
	&"oxygen": %Oxygen as ResourceBar,
}
@onready var _health: ResourceBar = %Health
@onready var _popup: Control = %BuildPopup
@onready var _checklist_drawer: Control = %ChecklistDrawer


func _ready() -> void:
	%BuildButton.pressed.connect(_open_build_popup)
	%BuildButton.pressed.connect(Music.play.bind(&"outpost"))
	%SearchButton.pressed.connect(_say.bind(&"info", "", "The research lab is coming soon. Build a greenhouse first!"))
	%SearchButton.pressed.connect(Music.play.bind(&"outpost"))
	%ExploreButton.pressed.connect(_say.bind(&"info", "", "Exploring needs a rover. Let's grow food for the crew first!"))
	%ExploreButton.pressed.connect(Music.play.bind(&"explore"))
	%SettingsButton.pressed.connect(_say.bind(&"info", "", "Settings will live here."))
	%CloseButton.pressed.connect(_close_build_popup)
	%CancelButton.pressed.connect(_close_build_popup)
	%ConfirmButton.pressed.connect(_confirm_build)
	%ChecklistTab.pressed.connect(toggle_checklist)
	resized.connect(_place_drawers.bind(false))
	_checklist_drawer.resized.connect(_place_drawers.bind(false))

	for key in _bars:
		_bars[key].status = _status_for(_bars[key].value)
	_update_health()
	_build_checklist()
	_place_drawers.call_deferred(false)
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


# --- Drawers ---------------------------------------------------------------

func toggle_checklist() -> void:
	_checklist_open = not _checklist_open
	%ChecklistTab.tooltip_text = "Close checklist" if _checklist_open else "Open checklist"
	_place_drawers(true)


## Positions the checklist drawer for its open/closed state. Recomputed on resize so
## the layout holds at any window size.
func _place_drawers(animate: bool) -> void:
	var list := _checklist_drawer
	list.size = list.get_combined_minimum_size()
	var list_pos := Vector2(
		size.x - list.size.x - MARGIN if _checklist_open else size.x - %ChecklistTab.size.x,
		TOP + 56.0 + 28.0)  # below the settings button

	if not animate:
		list.position = list_pos
		%ChecklistPanel.modulate.a = 1.0 if _checklist_open else 0.0
		return
	if _checklist_tween:
		_checklist_tween.kill()
	_checklist_tween = _slide(list, list_pos)
	_checklist_tween.parallel().tween_property(%ChecklistPanel, "modulate:a",
			1.0 if _checklist_open else 0.0, SLIDE_TIME)


func _slide(node: Control, to: Vector2) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", to, SLIDE_TIME)
	return tween


# --- Checklist -------------------------------------------------------------

func _build_checklist() -> void:
	for task in TASKS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var box := TextureRect.new()
		box.custom_minimum_size = Vector2(26, 26)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label := Label.new()
		label.text = task.text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(box)
		row.add_child(label)
		%Tasks.add_child(row)
		_task_rows[task.id] = row
		_refresh_task(task.id)
	_refresh_task_count()


## Ticks a checklist task off (called by game events).
func complete_task(id: StringName) -> void:
	if _done.get(id, false) or not _task_rows.has(id):
		return
	_done[id] = true
	_refresh_task(id)
	_refresh_task_count()
	var row: Control = _task_rows[id]
	row.pivot_offset = row.size / 2
	row.scale = Vector2(1.06, 1.06)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(row, "scale", Vector2.ONE, 0.3)


func _refresh_task(id: StringName) -> void:
	var row: Control = _task_rows[id]
	var done: bool = _done.get(id, false)
	var box: TextureRect = row.get_child(0)
	var label: Label = row.get_child(1)
	box.texture = CHECK if done else BOX
	label.theme_type_variation = &"Caption" if done else &""
	label.modulate.a = 0.75 if done else 1.0
	label.tooltip_text = "Done!" if done else "To do"
	label.mouse_filter = Control.MOUSE_FILTER_PASS


func _refresh_task_count() -> void:
	var count := 0
	for id in _done:
		count += int(_done[id])
	%ChecklistTab.text = "%d/%d" % [count, TASKS.size()]


# --- Build flow ------------------------------------------------------------

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
	var targets := {}
	for key in GREENHOUSE_DELTA:
		var bar: ResourceBar = _bars[key]
		targets[key] = clampf(bar.value + GREENHOUSE_DELTA[key], 0.0, 100.0)
		bar.animate_to(targets[key], _status_for(targets[key]))
		_show_delta(bar, GREENHOUSE_DELTA[key])
	complete_task(&"greenhouse")
	Music.stinger(&"mission_complete")
	_update_health(targets)
	build_confirmed.emit(&"greenhouse")

	if _bars[&"power"].status != ResourceBar.Status.HEALTHY:
		_say(&"warning", "Need more power!",
			"Your greenhouse makes more food, but it also uses power. Try adding a solar panel.")
	else:
		_say(&"success", "Great balance!", "Your resources are well balanced!")


## Bounces a resource pill and pops its change ("+30" / "-20") just below it.
func _show_delta(bar: ResourceBar, amount: float) -> void:
	bar.pivot_offset = bar.size / 2
	bar.scale = Vector2(1.15, 1.15)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(bar, "scale", Vector2.ONE, 0.35)
	var label := Label.new()
	label.theme_type_variation = &"HudValue"
	label.text = "%+d" % amount
	label.add_theme_color_override(&"font_color", Color("#3CDB56") if amount > 0 else Color("#FF4961"))
	label.add_theme_font_size_override(&"font_size", 34)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.size = label.get_combined_minimum_size()  # not laid out until next frame
	label.pivot_offset = label.size / 2
	label.global_position = bar.global_position + Vector2((bar.size.x - label.size.x) / 2.0, bar.size.y - 4)
	# Pop in with a springy overshoot, hold, then drift up while fading.
	label.scale = Vector2(0.3, 0.3)
	label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(label, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(label, "position:y", label.position.y - 14, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	t.tween_callback(label.queue_free)


## Colony health = the weakest resource ("Are we okay?" at a glance). Uses the
## same green / yellow / red status scale as every other gauge. `targets` holds
## the values bars are animating towards, since their `value` lags behind.
func _update_health(targets := {}) -> void:
	var lowest := 100.0
	for key in _bars:
		lowest = minf(lowest, targets.get(key, _bars[key].value))
	var status := _status_for(lowest)
	_health.display_text = HEALTH_TEXT[status]
	_health.animate_to(lowest, status)


## Mascot speech: pose + bubble colour + title, so meaning never relies on colour alone.
func _say(kind: StringName, title: String, text: String) -> void:
	%Helper.say(kind, title, text)


static func _status_for(value: float) -> ResourceBar.Status:
	if value <= 25.0:
		return ResourceBar.Status.CRITICAL
	if value <= 40.0:
		return ResourceBar.Status.WARNING
	return ResourceBar.Status.HEALTHY
