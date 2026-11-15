extends Control
## Outpost (Base) HUD laid around the 3D colony so the centre stays clear:
##   top-left   static mission clock        top edge  pull-down resource drawer
##   top-right  settings                    right     slide-in checklist
##   bottom-left astronaut helper           bottom-right Search / Explore / Build
## Demo flow: BUILD -> "Build Greenhouse?" card -> confirm -> bars animate, the
## health gauge, checklist and astronaut react (Observation -> Cause -> Next action).

signal build_confirmed(module_id: StringName)

const MASCOTS := {
	&"info": preload("res://assets/sprites/mascots/wave.png"),
	&"warning": preload("res://assets/sprites/mascots/think.png"),
	&"success": preload("res://assets/sprites/mascots/celebrate.png"),
}
const CHECK := preload("res://assets/sprites/icons/check.png")
const BOX := preload("res://assets/sprites/icons/box.png")
const CHEVRON_UP := preload("res://assets/sprites/icons/chevron_up.svg")
const CHEVRON_DOWN := preload("res://assets/sprites/icons/chevron_down.svg")

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
var _resources_open := true
var _checklist_open := false
var _done := {}
var _task_rows := {}
var _resource_tween: Tween
var _checklist_tween: Tween

@onready var _bars := {
	&"power": %Power as ResourceBar,
	&"water": %Water as ResourceBar,
	&"food": %Food as ResourceBar,
	&"oxygen": %Oxygen as ResourceBar,
}
@onready var _health: ResourceBar = %Health
@onready var _popup: Control = %BuildPopup
@onready var _resource_drawer: Control = %ResourceDrawer
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
	%ResourceHandle.pressed.connect(toggle_resources)
	%ChecklistTab.pressed.connect(toggle_checklist)
	resized.connect(_place_drawers.bind(false))
	_resource_drawer.resized.connect(_place_drawers.bind(false))
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

func toggle_resources() -> void:
	_resources_open = not _resources_open
	%ResourceHandle.icon = CHEVRON_UP if _resources_open else CHEVRON_DOWN
	%ResourceHandle.tooltip_text = "Hide resources" if _resources_open else "Show resources"
	_place_drawers(true)


func toggle_checklist() -> void:
	_checklist_open = not _checklist_open
	%ChecklistTab.tooltip_text = "Close checklist" if _checklist_open else "Open checklist"
	_place_drawers(true)


## Positions both drawers for their open/closed state. Recomputed on resize so
## the layout holds at any window size.
func _place_drawers(animate: bool) -> void:
	var res := _resource_drawer
	res.size = res.get_combined_minimum_size()
	var res_pos := Vector2(
		roundf((size.x - res.size.x) / 2.0),
		TOP if _resources_open else -%ResourcePanel.size.y)

	var list := _checklist_drawer
	list.size = list.get_combined_minimum_size()
	var list_pos := Vector2(
		size.x - list.size.x - MARGIN if _checklist_open else size.x - %ChecklistTab.size.x,
		TOP + 56.0 + 20.0)  # below the settings button

	if not animate:
		res.position = res_pos
		list.position = list_pos
		%ChecklistPanel.modulate.a = 1.0 if _checklist_open else 0.0
		return
	if _resource_tween:
		_resource_tween.kill()
	_resource_tween = _slide(res, res_pos)
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
	complete_task(&"greenhouse")
	Music.stinger(&"mission_complete")
	_update_health(targets)
	build_confirmed.emit(&"greenhouse")

	if _bars[&"power"].status != ResourceBar.Status.HEALTHY:
		_say(&"warning", "Need more power!",
			"Your greenhouse makes more food, but it also uses power. Try adding a solar panel.")
	else:
		_say(&"success", "Great balance!", "Your resources are well balanced!")


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
