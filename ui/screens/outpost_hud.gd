extends Control
## Outpost (Base) HUD laid around the 3D colony so the centre stays clear:
##   top-left   mission day + sunlight     top edge  resource pills
##   top-right  settings                   right     slide-in checklist
##   bottom-left astronaut helper          bottom-right Search / Explore / Build
## Shows the Colony simulation; never computes game numbers itself. Build,
## Search and Explore share one action card: pick an option, read its cost and
## tomorrow's forecast, confirm. Search/Explore end the day; Build does not.

const CHECK := preload("res://assets/generated/moonminds/icon_check.png")
const BOX := preload("res://assets/generated/moonminds/icon_box.png")
const ART := "res://assets/generated/moonminds/%s.png"

## Health gauge wording per status (colour is never the only signal).
const HEALTH_TEXT := {
	ResourceBar.Status.HEALTHY: "Good",
	ResourceBar.Status.WARNING: "OK",
	ResourceBar.Status.CRITICAL: "Low",
}
## Checklist text for OutpostSimulation.GOALS (the sim decides when each is done).
const TASKS := [
	{"id": &"greenhouse", "text": "Build a Greenhouse"},
	{"id": &"rover_blueprint", "text": "Search: Rover Blueprint"},
	{"id": &"rover", "text": "Build the Rover"},
	{"id": &"explore", "text": "Explore with the Rover"},
]
const LOSS_TEXT := {
	"water": "The colony ran out of water. An Ice Drill turns ice into water every day.",
	"food": "The crew ran out of food. A Greenhouse grows food when it has light, water and power.",
	"oxygen": "The crew ran out of oxygen. Greenhouse plants make oxygen.",
	"radiation": "Space radiation was too strong. A Shield protects the crew.",
}
const RESOURCES := [&"power", &"water", &"food", &"oxygen"]
const RESOURCE_NAMES := {&"power": "Energy", &"water": "Water", &"food": "Food", &"oxygen": "Oxygen"}
const RESOURCE_ICONS := {&"power": "icon_energy", &"water": "icon_water", &"food": "icon_food", &"oxygen": "icon_oxygen"}
## Player-facing text for every option. `art` is a generated asset name.
## shortcut: shield reuses the health icon, no dedicated art yet.
const INFO := {
	&"greenhouse": {"name": "Greenhouse", "art": "building_greenhouse", "text": "Grows food and oxygen. Needs light, water and power."},
	&"shield": {"name": "Shield", "art": "icon_health", "text": "Blocks some radiation to keep the crew healthy. Uses power."},
	&"rover": {"name": "Rover", "art": "icon_explore", "text": "Drives out to collect science samples and ice."},
	&"ice_drill": {"name": "Ice Drill", "art": "icon_water", "text": "Turns buried ice into water every day. Needs lots of power."},
	&"solar": {"name": "Solar", "art": "building_solar_panel", "text": "Turns sunlight into power. Less sun, less power."},
	&"water_tank": {"name": "Recycler", "art": "building_water_system", "text": "Gets back part of the water the crew uses. Needs power."},
	&"habitat": {"name": "Habitat", "art": "building_habitat", "text": "The crew's home. Upgrades need less power every day."},
	&"rover_blueprint": {"name": "Rover Plan", "art": "building_research_lab", "text": "Study your sample to design a rover."},
	&"radiation_map": {"name": "Radiation Map", "art": "building_research_lab", "text": "Map the radiation. Unlocks the shield and brings 8 kits."},
	&"emergency": {"name": "Cargo", "art": "icon_critical", "text": "One-time Mission Control supply drop for emergencies."},
	&"explore": {"name": "Field Trip", "art": "icon_explore", "text": "The rover drives out and brings back science samples."},
}
const MENUS := {
	&"build": [&"greenhouse", &"ice_drill", &"rover", &"shield", &"solar", &"water_tank", &"habitat"],
	&"search": [&"rover_blueprint", &"radiation_map", &"emergency"],
	&"explore": [&"explore"],
}

const MARGIN := 24.0
const TOP := 16.0
const SLIDE_TIME := 0.32

var _checklist_open := false
var _done := {}
var _task_rows := {}
var _checklist_tween: Tween
var _mode: StringName = &""
var _selected: StringName = &""

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
	%BuildButton.pressed.connect(_open_menu.bind(&"build"))
	%SearchButton.pressed.connect(_open_menu.bind(&"search"))
	%ExploreButton.pressed.connect(_open_menu.bind(&"explore"))
	%ExploreButton.pressed.connect(Events.screen_changed.emit.bind(&"explore"))
	for button in find_children("*", "BaseButton", true, false):
		button.pressed.connect(Events.button_pressed.emit.bind(StringName(button.name)))
	%SettingsButton.pressed.connect(_say.bind(&"info", "", "Settings will live here."))
	%CloseButton.pressed.connect(_close_menu)
	%CancelButton.pressed.connect(_close_menu)
	%ConfirmButton.pressed.connect(_confirm)
	%ChecklistTab.pressed.connect(toggle_checklist)
	resized.connect(_place_drawers.bind(false))
	_checklist_drawer.resized.connect(_place_drawers.bind(false))
	Colony.day_finished.connect(_on_day_finished)
	Colony.changed.connect(_refresh_goals)
	Colony.mission_ended.connect(_show_mission_end, CONNECT_DEFERRED)

	_sync(false)
	_build_checklist()
	_place_drawers.call_deferred(false)
	_play_splash()


func _unhandled_input(event: InputEvent) -> void:
	if _popup.visible and event.is_action_pressed(&"ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _play_splash() -> void:
	var splash: Control = %Splash
	splash.show()
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(splash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(splash.hide)
	tween.tween_callback(%BuildButton.grab_focus)


# --- Simulation -> HUD -------------------------------------------------------

## Pushes the current Colony state into the pills, health gauge and day card.
func _sync(animate := true) -> void:
	var state: Dictionary = Colony.state
	for key in RESOURCES:
		var v := float(state.stores[key])
		if animate:
			_bars[key].animate_to(v, _status_for(v))
		else:
			_bars[key].value = v
			_bars[key].status = _status_for(v)
	var health := float(state.crew_health)
	var status := _status_for(health)
	_health.display_text = HEALTH_TEXT[status]
	if animate:
		_health.animate_to(health, status)
	else:
		_health.value = health
		_health.status = status
	%TimeDisplay.show_day(int(state.day), Colony.sun_word())


## End of a mission day: animate every change, then explain it
## (observation -> cause -> next step, GAME_ARCHITECTURE.md).
func _on_day_finished(report: Dictionary, before: Dictionary) -> void:
	_sync()
	for key in RESOURCES:
		var delta := roundf(float(report.stores[key]) - float(before[key]))
		if delta != 0.0:
			_show_delta(_bars[key], delta)
			Events.resource_changed.emit(key, delta)
	if float(report.health_loss) > 0.0:
		_show_delta(_health, -float(report.health_loss))
	_explain_day(report)


func _explain_day(report: Dictionary) -> void:
	var short := []
	for key in report.unmet_crew_needs:
		if float(report.unmet_crew_needs[key]) > 0.0:
			short.append(RESOURCE_NAMES[key].to_lower())
	if not short.is_empty():
		_say(&"warning", "Not enough %s!" % " and ".join(short),
			"The crew ran short and got weaker. Build or upgrade something that makes %s." % short[0])
	elif float(report.health_loss) > 0.0:
		_say(&"warning", "Radiation!", "Space radiation hurt the crew a little. A shield would protect them.")
	elif float(report.generated_power) < 12.0:
		_say(&"info", "Low sun today", "Solar panels only made %d power. Machines slow down when power is low." % roundi(report.generated_power))
	else:
		var extra := ""
		if float(report.food_made) > 0.0:
			extra += " The greenhouse grew %d food." % roundi(report.food_made)
		if float(report.water_mined) > 0.0:
			extra += " The drill made %d water." % roundi(report.water_mined)
		_say(&"success", "Day %d done!" % (int(report.day) - 1), "Solar panels made %d power.%s" % [roundi(report.generated_power), extra])


# --- Action card -------------------------------------------------------------

func _open_menu(mode: StringName) -> void:
	_mode = mode
	_selected = &""
	for child in %Options.get_children():
		child.free()
	var group := ButtonGroup.new()
	var first: StringName = &""
	for id in MENUS[mode]:
		var b := Button.new()
		b.name = String(id)
		b.text = INFO[id].name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = &"IconButton"
		b.add_theme_font_size_override(&"font_size", 15)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_select.bind(id))
		%Options.add_child(b)
		# Open on the first option the player can actually take.
		if first == &"" and bool(_preview(id).allowed):
			first = id
	if first == &"":
		first = MENUS[mode][0]
	%Options.get_node(String(first)).button_pressed = true
	%Options.visible = MENUS[mode].size() > 1
	%Title.text = {&"build": "Build", &"search": "Search", &"explore": "Explore"}[mode]
	_select(first)
	_popup.visible = true
	Events.build_popup_opened.emit(_selected)
	_popup.modulate.a = 0.0
	create_tween().tween_property(_popup, "modulate:a", 1.0, 0.2)
	%ConfirmButton.grab_focus()


func _close_menu(cancelled := true) -> void:
	if cancelled and _popup.visible:
		Events.build_cancelled.emit(_selected)
	if _mode == &"explore":
		Events.screen_changed.emit(&"outpost")
	_popup.visible = false
	%BuildButton.grab_focus()


func _preview(id: StringName) -> Dictionary:
	match _mode:
		&"build":
			return Colony.preview_build(id)
		&"search":
			return Colony.preview_emergency() if id == &"emergency" else Colony.preview_research(id)
		_:
			return Colony.preview_explore()


## Fills the card for one option: art, cost, what tomorrow looks like.
func _select(id: StringName) -> void:
	_selected = id
	var info: Dictionary = INFO[id]
	var p := _preview(id)
	%Illustration.texture = load(ART % info.art)
	%Explanation.text = info.text
	for child in %Rows.get_children():
		child.free()
	var confirm: Button = %ConfirmButton
	confirm.disabled = not p.allowed
	if not p.allowed:
		_row("icon_critical", p.reason)
		confirm.text = "Locked"
		return
	match _mode:
		&"build":
			var upgrading := String(p.action) == "upgrade"
			confirm.text = "Upgrade" if upgrading else "Build"
			if upgrading:
				_row("icon_add", "Level %d → %d" % [p.from_level, p.next_level])
			_row("icon_build", "%d build kits (you have %d)" % [p.cost_kits, Colony.state.kits])
		&"search":
			if id == &"emergency":
				confirm.text = "Call"
				_row("icon_add", "Adds supplies to every bar")
			else:
				confirm.text = "Research"
				_row("icon_search", "Uses %d sample + %d energy" % [p.science_cost, p.power_cost])
			_row("icon_clock", "Takes the rest of the day")
		&"explore":
			confirm.text = "Go!"
			var costs := []
			for key in p.cost:
				costs.append("%d %s" % [p.cost[key], RESOURCE_NAMES[key].to_lower()])
			_row("icon_explore", "Uses " + ", ".join(costs))
			_row("icon_search", "Finds %d science sample%s" % [p.science, "" if int(p.science) == 1 else "s"])
			_row("icon_water", "Brings back ice: +%d water" % p.ice)
			_row("icon_clock", "Takes the rest of the day")
	_forecast_row(p.forecast)


## "Tomorrow" line: one small icon+number per resource that will change.
func _forecast_row(forecast: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 6)
	var label := Label.new()
	label.text = "Tomorrow:"
	label.theme_type_variation = &"DarkCaption"
	line.add_child(label)
	for key in RESOURCES:
		var change := roundi(float(forecast.next_day_store_change[key]))
		if change != 0:
			_signed(line, RESOURCE_ICONS[key], change)
	var health := roundi(float(forecast.health_change))
	if health != 0:
		_signed(line, "icon_health", health)
	%Rows.add_child(line)


func _signed(line: Control, icon: String, value: int) -> void:
	line.add_child(_icon(icon, 22))
	var v := Label.new()
	v.text = "%+d" % value
	v.theme_type_variation = &"DarkCaption"
	v.add_theme_color_override(&"font_color", Color("#1E9E3A") if value > 0 else Color("#D6334A"))
	line.add_child(v)


func _row(icon: String, text: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	line.add_child(_icon(icon, 24))
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DarkCaption"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(label)
	%Rows.add_child(line)


func _icon(art: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(ART % art)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _confirm() -> void:
	var id := _selected
	var mode := _mode
	_close_menu(false)
	var result: Dictionary
	match mode:
		&"build":
			result = Colony.build(id)
			if result.ok:
				Events.build_confirmed.emit(id)
				var level := int(Colony.state.levels[id])
				_say(&"success", "%s %s!" % [INFO[id].name, "built" if level == 1 else "upgraded to level %d" % level],
					"It starts working tomorrow. %s" % INFO[id].text)
		&"search":
			result = Colony.emergency_supply() if id == &"emergency" else Colony.research(id)
		&"explore":
			result = Colony.explore()
			if result.ok:
				_say(&"success", "Samples found!", "The rover brought back %d science sample%s and %d water from ice." \
					% [result.science_found, "" if int(result.science_found) == 1 else "s", result.ice_found])
	if not result.ok:
		_say(&"warning", "Not yet", result.reason)


## Ticks off every goal the simulation reports as done.
func _refresh_goals() -> void:
	var done := OutpostSimulation.goals_done(Colony.state)
	for id in done:
		if done[id]:
			complete_task(id)


## Mission over: a modal card that says what happened and offers a replay.
func _show_mission_end(result: Dictionary) -> void:
	_close_menu(false)
	var won: bool = result.status == &"won"
	var state: Dictionary = Colony.state
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 6
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var card := PanelContainer.new()
	card.theme_type_variation = &"PopupCard"
	card.custom_minimum_size = Vector2(440, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	card.add_child(col)
	var title := Label.new()
	title.theme_type_variation = &"H1"
	title.text = "Mission Complete!" if won else "Mission Failed"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var art := TextureRect.new()
	art.texture = load(ART % ("mascot_celebrate" if won else "mascot_think"))
	art.custom_minimum_size = Vector2(0, 130)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.material = load("res://ui/theme/sticker.tres")
	col.add_child(art)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if won:
		body.text = "Your colony is running! The crew lived %d days with %d%% health." % [int(state.day) - 1, roundi(state.crew_health)]
	else:
		body.text = LOSS_TEXT.get(String(result.cause), LOSS_TEXT.radiation)
	col.add_child(body)
	var again := Button.new()
	again.text = "Play Again"
	again.theme_type_variation = &"PrimaryButton"
	again.custom_minimum_size = Vector2(0, 64)
	again.pressed.connect(func() -> void:
		Colony.reset()
		get_tree().reload_current_scene())
	col.add_child(again)
	again.grab_focus()


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


## Ticks a checklist task off (ids that aren't tasks are ignored).
func complete_task(id: StringName) -> void:
	if _done.get(id, false) or not _task_rows.has(id):
		return
	_done[id] = true
	Events.task_completed.emit(id)
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


# --- Feedback --------------------------------------------------------------

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


## Mascot speech: pose + bubble colour + title, so meaning never relies on colour alone.
func _say(kind: StringName, title: String, text: String) -> void:
	%Helper.say(kind, title, text)


static func _status_for(value: float) -> ResourceBar.Status:
	if value <= 25.0:
		return ResourceBar.Status.CRITICAL
	if value <= 40.0:
		return ResourceBar.Status.WARNING
	return ResourceBar.Status.HEALTHY
