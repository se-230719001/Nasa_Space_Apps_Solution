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
## One short word per status on every pill (colour is never the only signal).
const STATUS_TEXT := {
	ResourceBar.Status.HEALTHY: "Good",
	ResourceBar.Status.WARNING: "Low",
	ResourceBar.Status.CRITICAL: "Critical!",
}
## The robot's first-time tutorial: one idea per step, then day 1 starts.
## `focus` is the node that glows above the dim (by unique name).
## Steps whose focus node is hidden (e.g. the old resource bars) are skipped.
const TUTORIAL := [
	{"focus": &"Helper", "title": "Hi! I'm Robo!", "text": "Each day we solve a real problem NASA faced, here at our Moon base."},
	{"focus": &"Resources", "title": "Your supplies", "text": "Energy, water, food, oxygen. The crew uses some every day. The heart is crew health."},
	{"focus": &"TodayCard", "title": "Today's mission", "text": "This card shows your goal, today's mission and what to do next. Briefing tells the real NASA story."},
	{"focus": &"Actions", "title": "Build, Search, Explore", "text": "Use these buttons to do the mission in your own base."},
	{"focus": &"ChecklistDrawer", "title": "Mission Days", "text": "Your progress lives here. Tap a finished day to read it again."},
	{"focus": &"NextDayButton", "title": "Stuck?", "text": "Wait one night for 1 more kit. But the crew still eats!"},
]
## Hint ladder per problem: [small nudge, clear next step].
const HINTS := {
	"power": ["Machines are slowing down. Is there enough power?",
		"Upgrade Solar, or open a machine's card and switch it off, so the others get more power."],
	"water": ["The water is running low.", "Build or upgrade the Ice Drill. The Recycler also gives water back."],
	"food": ["The food is running low.", "The Greenhouse needs light, water and power. Check all three, or upgrade it."],
	"oxygen": ["The air is getting thin.", "Greenhouse plants make oxygen. Keep them growing."],
	"radiation": ["Space radiation hurt the crew.", "Build or upgrade the Shield, and keep it powered."],
}
## Names for the sim's flow keys (report.flows) in the debrief.
const FLOW_NAMES := {"sun": "Sun", "habitat": "Habitat", "machines": "Machines", "drill": "Ice Drill",
	"recycler": "Recycler", "crew": "Crew", "greenhouse": "Greenhouse"}

const RESOURCES := [&"power", &"water", &"food", &"oxygen"]
const RESOURCE_NAMES := {&"power": "Energy", &"water": "Water", &"food": "Food", &"oxygen": "Oxygen"}
const RESOURCE_ICONS := {&"power": "icon_energy", &"water": "icon_water", &"food": "icon_food", &"oxygen": "icon_oxygen"}
## Player-facing text for every option. `art` is a generated asset name.
## shortcut: shield reuses the health icon, no dedicated art yet.
const INFO := {
	&"greenhouse": {"name": "Greenhouse", "art": "building_greenhouse", "text": "Grows food and makes oxygen. Plants need light and water.", "trade": "Gain food + oxygen. Pay power + water."},
	&"shield": {"name": "Shield", "art": "icon_health", "text": "Blocks some space radiation to keep the crew safe.", "trade": "Gain crew safety. Pay power every day."},
	&"rover": {"name": "Rover", "art": "icon_explore", "text": "Drives out to collect science samples and ice.", "trade": "Gain trips for science + ice. Pay 8 kits."},
	&"ice_drill": {"name": "Ice Drill", "art": "icon_water", "text": "Turns buried ice into water.", "trade": "Gain water. Pay lots of power."},
	&"solar": {"name": "Solar", "art": "building_solar_panel", "text": "Turns sunlight into power. More panels catch more light.", "trade": "Gain more power. Pay kits."},
	&"water_tank": {"name": "Recycler", "art": "building_water_system", "text": "Cleans used water so the crew can use it again.", "trade": "Gain water back. Pay power."},
	&"habitat": {"name": "Habitat", "art": "building_habitat", "text": "The crew's home on the Moon.", "trade": "Gain power savings. Pay kits."},
	&"lander": {"name": "Apollo Lander", "art": "icon_explore", "text": "A replica of NASA's Apollo Lunar Module for your base. It doesn't fly.", "trade": ""},
	&"lamp": {"name": "Light Post", "art": "icon_build", "text": "A light for your base. You unlocked it with your progress!", "trade": ""},
	&"antenna": {"name": "Antenna", "art": "icon_build", "text": "A radio antenna for your base. You unlocked it with your progress!", "trade": ""},
	&"moon_garden": {"name": "Rock Garden", "art": "icon_build", "text": "Moon rocks and tiny plants. You unlocked it with your progress!", "trade": ""},
	&"rover_blueprint": {"name": "Rover Plan", "art": "building_research_lab", "text": "Study your sample to design a rover.", "trade": "Gain the rover plan. Pay a sample + power."},
	&"radiation_map": {"name": "Radiation Map", "art": "building_research_lab", "text": "Map the radiation. Unlocks the shield and brings 8 kits.", "trade": "Gain the shield plan + 8 kits. Pay a sample + power."},
	&"emergency": {"name": "Cargo", "art": "icon_critical", "text": "One-time Mission Control supply drop for emergencies.", "trade": "Gain supplies once. Only in an emergency."},
	&"explore": {"name": "Field Trip", "art": "icon_explore", "text": "The rover drives out and brings back science samples.", "trade": "Gain science + ice. Pay power, water, oxygen. Once a day."},
}
## What each game building is based on. Only events already checked against
## NASA pages (see DAY_TASKS stories / nasa_db) are named; the rest say plainly
## that they are game buildings.
const INSPIRED := {
	&"greenhouse": "Inspired by NASA's Veggie plant garden, which was on the Space Station (not the Moon).",
	&"ice_drill": "Inspired by LCROSS, which found ice in a dark crater at the Moon's south pole. The drill itself is a game idea.",
	&"rover": "Inspired by the Apollo Lunar Roving Vehicle, driven on the Moon in 1971-1972.",
	&"shield": "Inspired by the storm shelter plan for NASA's Orion capsule.",
	&"solar": "Inspired by the roll-out solar arrays added to the Space Station in 2021.",
	&"water_tank": "A game building.",
	&"habitat": "A game building: the crew's home.",
	&"lander": "Real: the Apollo Lunar Module landed 12 astronauts on the Moon in six landings, 1969-1972. 3D model: NASA/Michael D. Carbajal. Yours is a replica.",
}
const MENUS := {
	&"build": [&"greenhouse", &"ice_drill", &"rover", &"shield", &"solar", &"water_tank", &"habitat", &"lander",
		&"lamp", &"antenna", &"moon_garden"],
	&"search": [&"rover_blueprint", &"radiation_map", &"emergency"],
	&"explore": [&"explore"],
}

const MENU_NAMES := {&"build": "Build", &"search": "Research", &"explore": "Explore"}
const MARGIN := 24.0
const TOP := 16.0
const SLIDE_TIME := 0.32

var _checklist_open := false
var _done := {}
var _task_rows := {}
## Mission Days: finished days are folded into one line until tapped open.
var _past_open := false
## The outpost scene (base grid placement); null when the HUD runs alone.
var _world: Node
var _moved_last := false  # the current placement moves a built building
var _checklist_tween: Tween
var _mode: StringName = &""
var _selected: StringName = &""

## Last night's direction per store (+1 / 0 / -1), shown as ↑ / ↓ on the pill.
var _trend := {}

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
	%NextDayButton.pressed.connect(Colony.rest)
	for bar in _bars.values() + [_health]:
		bar.pressed.connect(_show_supplies)
		bar.pressed.connect(Events.button_pressed.emit.bind(&"ResourcePill"))
	_add_info_button()
	_build_placement_bar()
	if owner and owner.has_signal(&"placement_started"):
		_world = owner
		_world.placement_started.connect(_on_placement_started)
		_world.placement_updated.connect(_on_placement_updated)
		_world.placement_ended.connect(_on_placement_ended)
		_world.building_tapped.connect(_on_building_tapped)
	if not _bars_on():
		%Power.get_parent().hide()  # top resource pills (incl. health)
		%NextDayButton.hide()       # Wait: nothing can block a mission now
		%InfoButton.position.x = MARGIN
	_make_task_list_scroll()
	_build_today_card()
	for button in find_children("*", "BaseButton", true, false):
		var say := Events.button_pressed.emit.bind(StringName(button.name))
		if not button.pressed.is_connected(say):  # some build their own wiring
			button.pressed.connect(say)
	%SettingsButton.hide()  # no settings yet: a button that does nothing confuses kids
	%CloseButton.pressed.connect(_close_menu)
	%CancelButton.pressed.connect(_close_menu)
	%ConfirmButton.pressed.connect(_confirm)
	%ChecklistTab.pressed.connect(toggle_checklist)
	resized.connect(_place_drawers.bind(false))
	_checklist_drawer.resized.connect(_place_drawers.bind(false))
	Colony.day_finished.connect(_on_day_finished)
	Colony.changed.connect(_refresh_goals)
	Colony.changed.connect(_sync)  # daytime costs (trips, research) show at once
	Colony.base_changed.connect(_refresh_today)
	Colony.badge_earned.connect(_queue_reward.bind("badge"))
	Colony.decor_unlocked.connect(_queue_reward.bind("decor"))
	Colony.task_completed.connect(_on_task_completed)
	Colony.day_cleared.connect(_on_day_cleared)
	# After the last debrief is closed, so the cards don't pile up.
	Colony.mission_ended.connect(func(result: Dictionary) -> void: _after_modals(_show_mission_end.bind(result)),
		CONNECT_DEFERRED)
	Colony.crew_rescued.connect(_show_rescue, CONNECT_DEFERRED)

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
	tween.tween_callback(_start_flow)


# --- Simulation -> HUD -------------------------------------------------------

## The old resource game (bars, costs, Wait, hints) is shown only when this
## run uses it; new runs don't (Stage 6). The sim keeps running quietly.
static func _bars_on() -> bool:
	return OutpostSimulation.uses_resources(Colony.state)

## "Good ↓": the status word plus last night's direction.
static func _pill_text(status: ResourceBar.Status, trend: int) -> String:
	return STATUS_TEXT[status] + {1: " ↑", -1: " ↓"}.get(trend, "")


## Tap on any pill: the exact numbers, kept out of the HUD itself.
func _show_supplies() -> void:
	var lines := []
	for key in RESOURCES:
		var v := roundi(Colony.state.stores[key])
		lines.append("%s: %d of 100, %s" % [RESOURCE_NAMES[key], v, _pill_text(_status_for(v), int(_trend.get(key, 0))).to_lower()])
	var h := roundi(Colony.state.crew_health)
	lines.append("Crew health: %d of 100, %s" % [h, _pill_text(_status_for(h), int(_trend.get(&"health", 0))).to_lower()])
	lines.append("Build kits: %d   Science samples: %d" % [roundi(Colony.state.kits), int(Colony.state.science)])
	lines.append("↑ / ↓ = went up / down last night. Low = 40 or less, Critical = 25 or less.")
	var m := _modal("Supplies", "", "\n".join(lines), [["Close", func() -> void: pass]])
	m.find_child("Body", true, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

## Pushes the current Colony state into the pills, health gauge and day card.
func _sync(animate := true) -> void:
	var state: Dictionary = Colony.state
	for key in RESOURCES:
		var v := float(state.stores[key])
		_bars[key].display_text = _pill_text(_status_for(v), int(_trend.get(key, 0)))
		if animate:
			_bars[key].animate_to(v, _status_for(v))
		else:
			_bars[key].value = v
			_bars[key].status = _status_for(v)
	var health := float(state.crew_health)
	var status := _status_for(health)
	_health.display_text = _pill_text(status, int(_trend.get(&"health", 0)))
	if animate:
		_health.animate_to(health, status)
	else:
		_health.value = health
		_health.status = status
	# The sun word comes from practice numbers; without the resource game it's hidden.
	%TimeDisplay.show_day(int(state.day), Colony.sun_word() if _bars_on() else "")
	_refresh_today()


## End of a mission day: animate every change, then explain it
## (observation -> cause -> next step, GAME_ARCHITECTURE.md).
func _on_day_finished(report: Dictionary, before: Dictionary) -> void:
	if not _bars_on():
		_sync()
		_explain_day(report)
		var finished := OutpostSimulation.tasks_for(int(report.day) - 1, Colony.state.campaign)
		if not finished.is_empty():
			_debrief(report, before, finished[0])
		return
	for key in RESOURCES:
		_trend[key] = signi(roundi(float(report.stores[key]) - float(before[key])))
	_trend[&"health"] = -signi(roundi(float(report.health_loss)))
	_sync()
	for key in RESOURCES:
		var delta := roundf(float(report.stores[key]) - float(before[key]))
		if delta != 0.0:
			_show_delta(_bars[key], delta)
			Events.resource_changed.emit(key, delta)
	if float(report.health_loss) > 0.0:
		_show_delta(_health, -float(report.health_loss))
	_explain_day(report)
	if not bool(report.get("waited", false)):
		var done := OutpostSimulation.tasks_for(int(report.day) - 1, Colony.state.campaign)
		if not done.is_empty():
			_debrief(report, before, done[0])


func _explain_day(report: Dictionary) -> void:
	if not bool(report.get("waited", false)):
		_fold_finished_day()
		get_tree().create_timer(3.5).timeout.connect(_announce_tasks)
	if not _bars_on():
		var finished := OutpostSimulation.tasks_for(int(report.day) - 1, Colony.state.campaign)
		_say(&"success", "Day %d done!" % (int(report.day) - 1),
			"%s: done. A new mission is coming!" % finished[0].text if not finished.is_empty() else "Great work!")
		return
	var short := []
	for key in report.unmet_crew_needs:
		if float(report.unmet_crew_needs[key]) > 0.0:
			short.append(RESOURCE_NAMES[key].to_lower())
	var kind := &"success"
	var title := "Day %d done!" % (int(report.day) - 1)
	var text := ""
	var cause := _problem(report)
	if cause != "":
		# Hint ladder: a small nudge first, a clear next step if it happens again.
		var level := Colony.bump_hint()
		kind = &"warning"
		title = {"power": "Machines slowed down", "radiation": "Radiation!"}.get(cause,
			"Not enough %s!" % " and ".join(short))
		text = HINTS[cause][level - 1]
	elif float(report.generated_power) < 12.0:
		kind = &"info"
		title = "Low sun today"
		text = "Solar panels only made %d power. Machines slow down when power is low." % roundi(report.generated_power)
	else:
		text = "Solar panels made %d power." % roundi(report.generated_power)
		if float(report.food_made) > 0.0:
			text += " The greenhouse grew %d food." % roundi(report.food_made)
		if float(report.water_mined) > 0.0:
			text += " The drill made %d water." % roundi(report.water_mined)
	if bool(report.get("waited", false)):
		# Waiting never moves the day on; say so first, then what the night did.
		text = "Still day %d. Mission Control sent 1 kit. %s" % [int(report.day), text]
		title = "One night passed"
		kind = &"warning" if kind == &"warning" else &"info"
	_say(kind, title, text)


## The main problem of a night ("" if none): a crew shortage, radiation
## damage, or machines that got less power than they needed.
func _problem(report: Dictionary) -> String:
	var worst := ""
	var amount := 0.0
	for key in report.unmet_crew_needs:
		if float(report.unmet_crew_needs[key]) > amount:
			amount = float(report.unmet_crew_needs[key])
			worst = String(key)
	if worst != "":
		return worst
	if float(report.get("power_support", 1.0)) < 1.0:
		return "power"  # the habitat itself was short of power
	# The small daily dose (1-2) is normal before a shield exists; only a big
	# one is a problem worth a warning and a hint.
	if float(report.health_loss) >= 3.0:
		return "radiation"
	if float(report.get("machine_need", 0.0)) > 0.0 and float(report.get("machine_share", 1.0)) < 0.99:
		return "power"
	return ""


## After a mission night: what happened in your base, why (the sim's own
## numbers), and how it is like / unlike what NASA really did.
func _debrief(report: Dictionary, before: Dictionary, task: Dictionary) -> void:
	var watch: Variant = task.get("watch") if _bars_on() else null
	var lines := []
	if watch == &"health":
		lines.append("In your base: crew health changed by %+d tonight." % -roundi(float(report.health_loss)))
		lines.append("Why: " + _why(report, watch))
	elif watch != null:
		lines.append("In your base: %s changed by %+d tonight." % [RESOURCE_NAMES[watch].to_lower(),
			roundi(float(report.stores[watch]) - float(before[watch]))])
		lines.append("Why: " + _why(report, watch))
	else:
		lines.append("In your base: you did it! %s." % task.text)
	lines.append("Like NASA: " + task.quiz.same)
	lines.append("Different: " + task.quiz.different)
	var m := _modal("Mission debrief", "", "\n".join(lines), [["OK", func() -> void: pass]])  # no art: it fits 576 px
	m.find_child("Body", true, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if task.has("why"):
		_why_question(m, task)


## "Why did it work?" with two ideas. Any answer earns the reflection star;
## a wrong one gets the explanation (never a "fail").
func _why_question(m: Control, task: Dictionary) -> void:
	var col: VBoxContainer = m.find_child("Body", true, false).get_parent()
	var box := VBoxContainer.new()
	box.name = "Why"
	box.add_theme_constant_override(&"separation", 6)
	col.add_child(box)
	col.move_child(box, col.get_child_count() - 2)  # above OK
	_info_label(box, "One more star: " + task.why.question, 17, true)
	var feedback := Label.new()
	feedback.name = "WhyFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size = Vector2(420, 0)
	feedback.add_theme_font_size_override(&"font_size", 15)
	for i in task.why.options.size():
		var opt: Dictionary = task.why.options[i]
		var b := Button.new()
		b.name = "WhyOption%d" % i
		b.text = opt.text
		b.theme_type_variation = &"IconButton"
		b.custom_minimum_size = Vector2(420, 44)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override(&"font_size", 15)
		b.pressed.connect(Events.button_pressed.emit.bind(StringName(b.name)))
		b.pressed.connect(func() -> void:
			Colony.answer_why(task.id, opt.correct)
			feedback.text = ("✓ Yes! +1 star. " if opt.correct else "Good thinking, +1 star! Here's why: ") + task.why.explain
			for other in box.get_children():
				if other is Button:
					other.disabled = true)
		box.add_child(b)
	box.add_child(feedback)


## One short "why" sentence for a store's (or health's) change last night.
func _why(report: Dictionary, watch: StringName) -> String:
	if watch == &"health":
		return "Radiation was %d. The shield blocked %d." % [roundi(report.radiation), roundi(report.protection)]
	var parts := []
	var flow: Dictionary = report.flows[watch]
	for k in flow.in:
		if roundi(flow.in[k]) != 0:
			parts.append("%s +%d" % [FLOW_NAMES[k], roundi(flow.in[k])])
	for k in flow.out:
		if roundi(flow.out[k]) != 0:
			parts.append("%s −%d" % [FLOW_NAMES[k], roundi(flow.out[k])])
	var text := ", ".join(parts) + "." if not parts.is_empty() else "Nothing changed it."
	if watch == &"power" and float(report.machine_need) > 0.0 and float(report.machine_share) < 0.99:
		text += " Machines got only %d%% of the power they needed, so they slowed down." % roundi(report.machine_share * 100.0)
	return text


# --- Action card -------------------------------------------------------------

func _open_menu(mode: StringName) -> void:
	_mode = mode
	_selected = &""
	for child in %Options.get_children():
		child.free()
	var group := ButtonGroup.new()
	var first: StringName = &""
	for id in MENUS[mode]:
		if id == &"emergency" and not _bars_on():
			continue  # supply cargo only makes sense with the resource game
		if Rewards.DECOR.any(func(d): return d.id == id) and not Colony.state.unlocks.get(id, false):
			continue  # decorations appear once a milestone unlocks them
		var b := Button.new()
		b.name = String(id)
		b.text = INFO[id].name
		if mode == &"build" and int(Colony.state.modules.get(id, 0)) > 0:
			b.text += " Lv%d" % int(Colony.state.levels[id]) if _bars_on() else " ✓"
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = &"IconButton"
		b.add_theme_font_size_override(&"font_size", 15)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_select.bind(id))
		b.pressed.connect(Events.button_pressed.emit.bind(StringName(b.name)))  # made after _ready's wiring
		%Options.add_child(b)
		# Open on the first option the player can actually take.
		if first == &"" and bool(_preview(id).allowed):
			first = id
	if first == &"":
		first = MENUS[mode][0]
	%Options.get_node(String(first)).button_pressed = true
	%Options.visible = MENUS[mode].size() > 1
	%Title.text = MENU_NAMES[mode]
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
	if _bars_on() and _mode == &"build" and OutpostSimulation.SWITCHABLE.has(id) and int(Colony.state.modules.get(id, 0)) > 0:
		_power_row(id)
	if not p.allowed:
		_row("icon_critical", p.reason)
		confirm.text = "Locked"
		return
	var step := Colony.next_step()
	if not step.is_empty() and step.menu == _mode and step.option == id:
		_row("icon_check", "This is today's mission!")
	if INSPIRED.has(id):
		_row("icon_info", INSPIRED[id])
		if id != &"lander":
			_row("icon_build", "Game building: simpler than the real thing.")
	if not _bars_on() and p.get("action") == "upgrade" and (step.is_empty() or step.option != id):
		confirm.disabled = true
		confirm.text = "Built"
		_row("icon_check", "Already in your base. Tap it there to move or turn it.")
		return
	if not _bars_on():
		confirm.text = {&"build": "Upgrade" if p.get("action") == "upgrade" else "Build",
			&"search": "Research", &"explore": "Go!"}[_mode]
		if p.get("action") == "upgrade":
			_row("icon_add", "Level %d → %d" % [p.from_level, p.next_level])
		if _mode == &"explore":
			_row("icon_search", "Finds %d science sample%s and some ice" % [p.science, "" if int(p.science) == 1 else "s"])
		return
	_row("icon_info", info.trade)
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
		&"explore":
			confirm.text = "Go!"
			var costs := []
			for key in p.cost:
				costs.append("%d %s" % [p.cost[key], RESOURCE_NAMES[key].to_lower()])
			_row("icon_explore", "Uses " + ", ".join(costs))
			_row("icon_search", "Finds %d science sample%s" % [p.science, "" if int(p.science) == 1 else "s"])
			_row("icon_water", "Brings back ice: +%d water" % p.ice)
	if float(p.forecast.get("machine_share", 1.0)) < 0.99:
		_row("icon_warning", "Not enough power: machines will work at %d%%." % roundi(p.forecast.machine_share * 100.0))
	_forecast_row(p.forecast)


## On/off switch for a built machine; flipping it refreshes the card so the
## Tomorrow line shows the new power sharing.
func _power_row(id: StringName) -> void:
	var on: bool = not Colony.state.off.has(id)
	var b := Button.new()
	b.name = "PowerSwitch"
	b.text = "Power: ON  (tap to switch off)" if on else "Power: OFF  (tap to switch on)"
	b.theme_type_variation = &"IconButton"
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override(&"font_size", 15)
	b.pressed.connect(func() -> void:
		Colony.set_power(id, not on)
		Events.button_pressed.emit(&"PowerSwitch")
		_select.call_deferred(id))  # this button is freed by the refresh
	%Rows.add_child(b)


## "Tomorrow" line: one small icon+number per resource that will change.
func _forecast_row(forecast: Dictionary) -> Control:
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
	return line


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
			# A new building: the player picks its parcels first (base grid).
			if _world and BaseGrid.SIZE.has(id) and int(Colony.state.modules.get(id, 0)) == 0:
				_world.begin_placement(id)
				return
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


## Ticks off every task the simulation has paid out.
func _refresh_goals() -> void:
	for id in Colony.state.tasks_done:
		complete_task(id)


## Card bounce + cheer. Deferred so it lands after the "built!" line.
func _on_task_completed(task: Dictionary) -> void:
	_refresh_goals()
	_refresh_today()
	_bounce(%TodayCard)
	_say.call_deferred(&"success", "Task done!", "%s. You earned %d build kits!" \
		% [task.text, int(OutpostSimulation.TASK_KITS)] if _bars_on() else "%s. Great work!" % task.text)


## All of today's tasks are done: say so; Colony starts the night shortly.
func _on_day_cleared(day: int) -> void:
	_bounce(%TodayCard)
	var last := day >= OutpostSimulation.campaign_length(Colony.state)
	# After the per-task cheer (also deferred) so this one stays on screen.
	_say.call_deferred(&"success", "Day %d complete!" % day,
		"Great work! The mission is almost done..." if last else "All tasks done. Night is coming, then day %d starts!" % (day + 1))


func _bounce(node: Control) -> void:
	node.pivot_offset = node.size / 2
	node.scale = Vector2(1.15, 1.15)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(node, "scale", Vector2.ONE, 0.4)


# --- Today card ----------------------------------------------------------------

## Small card under Wait: the main goal, today's mission with its trade-off
## tip, and the next step (from the sim's previews). When the next step is
## blocked it also offers to start the day again.
func _build_today_card() -> void:
	var card := PanelContainer.new()
	card.name = "TodayCard"
	card.unique_name_in_owner = true
	card.theme_type_variation = &"HudPill"
	card.position = Vector2(MARGIN, 150)
	card.custom_minimum_size = Vector2(250, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	card.owner = self
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	card.add_child(col)
	for n in [&"TodayBase", &"TodayGoal", &"TodayTitle", &"TodayTip", &"TodayNext"]:
		var l := Label.new()
		l.name = n
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		l.add_theme_font_size_override(&"font_size", 17 if n == &"TodayTitle" else 13)
		col.add_child(l)
	col.get_node("TodayGoal").modulate.a = 0.85
	col.get_node("TodayTip").modulate.a = 0.85
	col.get_node("TodayNext").add_theme_color_override(&"font_color", Color("#FFC94A"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 6)
	col.add_child(buttons)
	var retry_row := HBoxContainer.new()  # own row: only shown when stuck
	col.add_child(retry_row)
	for b in [["StoryButton", "Briefing", _show_story], ["WhyButton", "Why?", _show_why],
			["RetryButton", "Start today again", _confirm_retry]]:
		var button := Button.new()
		button.name = b[0]
		button.text = b[1]
		button.theme_type_variation = &"IconButton"
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 15)
		button.pressed.connect(b[2])  # Events.button_pressed is wired in _ready
		(retry_row if b[0] == "RetryButton" else buttons).add_child(button)


func _refresh_today() -> void:
	var col: Control = %TodayCard.get_child(0)
	var goal: Label = col.get_node("TodayGoal")
	col.get_node("TodayBase").text = String(Colony.state.get("base_name", ""))
	col.get_node("TodayBase").visible = col.get_node("TodayBase").text != ""
	var title: Label = col.get_node("TodayTitle")
	var tip: Label = col.get_node("TodayTip")
	var next: Label = col.get_node("TodayNext")
	var retry: Button = col.find_child("RetryButton", true, false)
	col.find_child("WhyButton", true, false).visible = _bars_on() and not Colony.state.history.is_empty()
	var total := OutpostSimulation.campaign_length(Colony.state)
	var days_done := mini(int(Colony.state.day) - 1, total)
	goal.text = "Goal: %s %d/%d" % [OutpostSimulation.CAMPAIGNS[Colony.state.campaign].name, days_done, total]
	var tasks := Colony.today_tasks()
	retry.visible = false
	if tasks.is_empty():
		title.text = "Mission done!"
		tip.text = ""
		next.text = ""
		return
	var lines := []
	var next_tip := ""
	for task in tasks:
		var done: bool = Colony.state.tasks_done.get(task.id, false)
		lines.append("%s Today: %s" % ["★" if done else "☆", task.text])
		if not done and next_tip.is_empty():
			next_tip = task.tip
	title.text = "\n".join(lines)
	tip.text = next_tip if not next_tip.is_empty() else "All done! Night is coming..."
	tip.visible = _bars_on() or next_tip.is_empty()  # the tips talk about power/water costs
	var step := Colony.next_step()
	if step.is_empty():
		next.text = ""
	elif step.ok:
		next.text = "Next: tap %s, pick %s" % [MENU_NAMES[step.menu], INFO[step.option].name]
	else:
		next.text = "Not yet: %s. You can Wait a night." % step.reason
		retry.visible = _bars_on()


## Morning brief: the robot reads out today's open tasks.
func _announce_tasks() -> void:
	if Colony.finished:
		return
	for task in Colony.today_tasks():
		if Colony.state.tasks_done.get(task.id, false):
			continue
		var now := ""
		if not _bars_on():
			pass
		elif task.watch == &"health":
			now = " Crew health now: %d." % roundi(Colony.state.crew_health)
		elif task.watch != null:
			now = " %s now: %d." % [RESOURCE_NAMES[task.watch], roundi(Colony.state.stores[task.watch])]
		_say(&"info", "Day %d mission" % int(Colony.state.day), "%s. %s%s" % [task.text, task.idea, now])
		_after_modals(_story_once)
		return


# --- Tutorial ----------------------------------------------------------------

var _tutorial: Control
var _lifted := []


## Shows tutorial step `i`: dim the HUD, lift the step's focus node and the
## robot above it, and wait for "Next". Only Next is clickable meanwhile.
func _tutorial_step(i: int) -> void:
	if _tutorial == null:
		_tutorial = Control.new()
		_tutorial.name = "Tutorial"
		_tutorial.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tutorial.z_index = 5
		add_child(_tutorial)
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.03, 0.1, 0.72)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tutorial.add_child(dim)
		var next := Button.new()
		next.name = "TutorialNext"
		next.theme_type_variation = &"PrimaryButton"
		next.custom_minimum_size = Vector2(180, 64)
		next.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		next.offset_left = 20  # right of the robot's bubble
		next.offset_right = 200
		next.offset_top = -92
		next.offset_bottom = -28
		next.z_index = 2
		_tutorial.add_child(next)
		next.pressed.connect(func() -> void: _tutorial_step(int(next.get_meta(&"step")) + 1))
		next.pressed.connect(Events.button_pressed.emit.bind(&"TutorialNext"))
	for node in _lifted:
		node.z_index = 0
	_lifted.clear()
	var next: Button = _tutorial.get_node("TutorialNext")
	while i < TUTORIAL.size() and not _focus_node(TUTORIAL[i].focus).is_visible_in_tree():
		i += 1  # e.g. no resource bars in this run
	if i >= TUTORIAL.size():
		_tutorial.queue_free()
		_tutorial = null
		Colony.tutorial_done = true
		%BuildButton.grab_focus()
		_announce_tasks()
		return
	var step: Dictionary = TUTORIAL[i]
	next.set_meta(&"step", i)
	next.text = "Start!" if step == _tutorial_steps().back() else "Next"
	for node in [%Helper, _focus_node(step.focus)]:
		node.z_index = 6
		_lifted.append(node)
	_say(&"info", step.title, step.text)
	next.grab_focus()


## The tutorial steps this run will actually show.
func _tutorial_steps() -> Array:
	return TUTORIAL.filter(func(st): return _focus_node(st.focus).is_visible_in_tree())


func _focus_node(id: StringName) -> CanvasItem:
	match id:
		&"Resources":
			return %Power.get_parent()
		&"Actions":
			return %BuildButton.get_parent()
	return get_node("%" + String(id))


## Mission over: a modal card that says what happened and offers a replay.
func _show_mission_end(result: Dictionary) -> void:
	_close_menu(false)
	var won: bool = result.status == &"won"
	var state: Dictionary = Colony.state
	var body := ""
	if won and not _bars_on():
		# No resource game, so no health-based stars (Stage 8 designs the new rewards).
		body = "%s: %s training done! You solved %d real problems NASA faced.\nScience stars: %d. Badges: %d." % [
			state.get("base_name", "Your base"), OutpostSimulation.CAMPAIGNS[state.campaign].name,
			OutpostSimulation.campaign_length(state), Rewards.total_stars(state), state.get("badges", {}).size()]
	elif won:
		body = "%s\n%s training done! The crew finished with %d%% health. Nights waited: %d." % [
			"★".repeat(int(result.stars)) + "☆".repeat(3 - int(result.stars)),
			OutpostSimulation.CAMPAIGNS[state.campaign].name, roundi(state.crew_health), int(state.get("nights_waited", 0))]
	_modal("Mission Complete!" if won else "Mission Failed", "mascot_celebrate" if won else "mascot_think", body,
		[["Play Again", func() -> void:
			Colony.reset()
			Colony.session_chosen = false  # a new mission: pick a campaign again
			get_tree().reload_current_scene()]])


## Centered card over a dim backdrop: title, mascot art, body text and big
## buttons (`buttons` = [[text, callable], ...]; the first one is primary).
## Any button closes the card before running its action.
func _modal(title_text: String, art_name: String, body_text: String, buttons: Array) -> Control:
	var overlay := Control.new()
	overlay.name = "Modal"
	overlay.add_to_group(&"hud_modal")  # names clash while the last one frees
	overlay.tree_exited.connect(_next_card)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 6
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var card := PanelContainer.new()
	card.theme_type_variation = &"PopupCard"
	card.custom_minimum_size = Vector2(460, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	card.add_child(col)
	var title := Label.new()
	title.theme_type_variation = &"H1"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if art_name != "":
		var art := TextureRect.new()
		art.texture = load(ART % art_name)
		art.custom_minimum_size = Vector2(0, 110)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.material = load("res://ui/theme/sticker.tres")
		col.add_child(art)
	var body := Label.new()
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(420, 0)
	body.text = body_text
	col.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	col.add_child(row)
	for i in buttons.size():
		var b := Button.new()
		b.name = "Choice%d" % i
		b.text = buttons[i][0]
		b.theme_type_variation = &"PrimaryButton" if i == 0 else &"Button"
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Events.button_pressed.emit.bind(StringName(b.name)))
		b.pressed.connect(overlay.queue_free)
		b.pressed.connect(buttons[i][1])
		row.add_child(b)
	row.get_child(0).grab_focus()
	return overlay


# --- Start of a sitting ------------------------------------------------------

## After the splash: continue a saved mission? which training campaign? the
## mission briefing, then (first time) the robot tutorial and today's mission.
func _start_flow() -> void:
	if Colony.session_chosen:  # retried a day / reloaded mid-sitting
		_begin_day()
	elif not Colony.save_offered and Colony.has_save():
		Colony.save_offered = true
		_modal("Welcome back!", "mascot_wave", "Your Moon base is saved. Do you want to go on with it?", [
			["Continue", func() -> void:
				# The save holds its campaign, so a loaded run skips the picker.
				Colony.session_chosen = Colony.load_save()
				if not Colony.session_chosen:
					Colony.reset()
				get_tree().reload_current_scene()],
			["New mission", func() -> void:
				Colony.reset()
				get_tree().reload_current_scene()]])
	else:
		Colony.save_offered = true
		_ask_campaign()


## Picks the training: each card names its days and the years of the real
## NASA events it is built on (the events' dates, not data for those dates).
func _ask_campaign() -> void:
	var lines := []
	var buttons := []
	for id in OutpostSimulation.CAMPAIGNS:
		var c: Dictionary = OutpostSimulation.CAMPAIGNS[id]
		lines.append("%s: %s" % [c.name, c.text])
		buttons.append(["%s\n%d days, %s" % [c.name, c.days.size(), c.years], func() -> void:
			Colony.start_campaign(id)
			_build_checklist()
			_sync(false)
			_ask_base_name()])
	var m := _modal("Pick your training", "", "Every day is a real problem NASA faced in those years.\n" + "\n".join(lines), buttons)
	m.find_child("Body", true, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for b in m.find_children("Choice*", "Button", true, false):
		b.add_theme_font_size_override(&"font_size", 17)
		b.custom_minimum_size = Vector2(170, 72)


## Personal touch: the player names the base (pick one or type one) and then
## picks its flag. The name stays on this device.
func _ask_base_name() -> void:
	var names := ["Crater Camp", "Moonbeam Base", "Shackleton Station"]
	var buttons := []
	for n in names:
		buttons.append([n, func() -> void:
			Colony.set_base(n)
			_ask_flag()])
	var m := _modal("Name your base", "mascot_wave", "Pick a name, or type your own. It stays on this device.", buttons)
	var col: VBoxContainer = m.find_child("Body", true, false).get_parent()
	var own := HBoxContainer.new()
	own.add_theme_constant_override(&"separation", 10)
	var edit := LineEdit.new()
	edit.name = "OwnName"
	edit.placeholder_text = "My own name"
	edit.max_length = Colony.NAME_MAX
	edit.custom_minimum_size = Vector2(260, 52)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own.add_child(edit)
	var use := Button.new()
	use.name = "UseOwnName"
	use.text = "✓ Use it"
	use.theme_type_variation = &"IconButton"
	use.custom_minimum_size = Vector2(130, 52)
	use.pressed.connect(func() -> void:
		if edit.text.strip_edges() == "":
			edit.grab_focus()
			return
		Colony.set_base(edit.text)
		m.queue_free()
		_ask_flag())
	use.pressed.connect(Events.button_pressed.emit.bind(&"UseOwnName"))
	own.add_child(use)
	col.add_child(own)
	col.move_child(own, col.get_child_count() - 2)  # above the preset buttons
	for b in m.find_children("Choice*", "Button", true, false):
		b.add_theme_font_size_override(&"font_size", 17)


func _ask_flag() -> void:
	var buttons := []
	for id in Colony.FLAGS:
		buttons.append([String(id).capitalize(), func() -> void:
			Colony.set_base("", id)
			_briefing()])
	var m := _modal("Pick your flag", "", "Your flag flies next to the habitat. Which colour?", buttons)
	var i := 0
	for id in Colony.FLAGS:
		var b: Button = m.find_child("Choice%d" % i, true, false)
		b.theme_type_variation = &"IconButton"
		b.add_theme_color_override(&"font_color", Colony.FLAGS[id])  # the name says the colour too
		i += 1


func _briefing() -> void:
	var m := OutpostSimulation.MAIN_MISSION
	var c: Dictionary = OutpostSimulation.CAMPAIGNS[Colony.state.campaign]
	_modal(m.title, "mascot_wave", "%s\n%s: one mission a day, step %d of %d." % [
		m.text, c.name, int(Colony.state.day), c.days.size()], [["Let's go!", _begin_day]])


func _begin_day() -> void:
	if not Colony.tutorial_done:
		_tutorial_step(0)
	else:
		_announce_tasks()


## Crew health hit 0: no game over. Colony already rewound today; say what
## happened kindly, give the clear hint, and reload the world.
func _show_rescue() -> void:
	_close_menu(false)
	var cause := "radiation"
	if not Colony.rescue_report.is_empty() and _problem(Colony.rescue_report) != "":
		cause = _problem(Colony.rescue_report)
	_modal("Mission Control to the rescue!", "mascot_think",
		"The crew got too weak, so Mission Control helped them rest. Today starts again.\nTip: %s" % HINTS[cause][1],
		[["Try again", get_tree().reload_current_scene]])


## "Why?" on the Today card: last night's numbers for every store, plus
## today's science idea. Optional detail; the game never requires it.
func _show_why() -> void:
	if Colony.state.history.is_empty():
		return
	var report: Dictionary = Colony.state.history[-1]
	var lines := []
	for key in RESOURCES:
		lines.append("%s: %s" % [RESOURCE_NAMES[key], _why(report, key)])
	lines.append("Crew health: " + _why(report, &"health"))
	var tasks := Colony.today_tasks()
	if not tasks.is_empty():
		lines.append("Today's idea: " + tasks[0].idea)
	_modal("Why did it change?", "mascot_think", "\n".join(lines), [["Got it", func() -> void: pass]])


## Asks before rewinding today (stores, kits and buildings go back to morning).
func _confirm_retry() -> void:
	_modal("Start today again?", "mascot_think",
		"Your base goes back to how it was this morning. Then you can try a new plan.", [
		["Yes, try again", func() -> void:
			Colony.retry_day()
			get_tree().reload_current_scene()],
		["No", func() -> void: pass]])


# --- Base grid placement -----------------------------------------------------

## Bottom bar while placing: what's wrong (or how to move it), and big
## Turn / Cancel / Build-here buttons. Moving and turning are free.
func _build_placement_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "PlacementBar"
	bar.unique_name_in_owner = true
	bar.theme_type_variation = &"PopupCard"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bar.offset_left = -520
	bar.offset_top = -170
	bar.offset_right = -MARGIN
	bar.offset_bottom = -MARGIN
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.hide()
	add_child(bar)
	bar.owner = self
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	bar.add_child(col)
	var hint := Label.new()
	hint.name = "PlaceHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(460, 0)
	hint.add_theme_font_size_override(&"font_size", 17)  # light text on the dark card
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	col.add_child(row)
	for b in [["TurnButton", "↻ Turn", &"IconButton"], ["CancelPlace", "✕ Cancel", &"DangerButton"],
			["PlaceButton", "✓ Build here", &"PrimaryButton"]]:
		var button := Button.new()
		button.name = b[0]
		button.text = b[1]
		button.theme_type_variation = b[2]
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 20)
		button.pressed.connect(Events.button_pressed.emit.bind(StringName(b[0])))
		row.add_child(button)
	row.get_node("TurnButton").pressed.connect(func() -> void: _world.rotate_ghost())
	row.get_node("CancelPlace").pressed.connect(func() -> void: _world.cancel_placement())
	row.get_node("PlaceButton").pressed.connect(func() -> void: _world.confirm_placement())


func _on_placement_started(id: StringName) -> void:
	_moved_last = int(Colony.state.modules.get(id, 0)) > 0  # moving, not building
	_close_menu(false)
	%BuildButton.get_parent().hide()
	%PlacementBar.show()
	%PlacementBar.find_child("PlaceButton", true, false).text = \
		"✓ Move here" if int(Colony.state.modules.get(id, 0)) > 0 else "✓ Build here"


func _on_placement_updated(ok: bool, reason: String) -> void:
	%PlacementBar.find_child("PlaceButton", true, false).disabled = not ok
	%PlacementBar.find_child("PlaceHint", true, false).text = \
		"Drag to pick a spot. Green squares are free. Moving and turning are free." if ok else "Not here: %s." % reason


func _on_placement_ended(id: StringName, placed: bool) -> void:
	%PlacementBar.hide()
	%BuildButton.get_parent().show()
	if placed and not _moved_last:
		Events.build_confirmed.emit(id)
		_say.call_deferred(&"success", "%s built!" % INFO[id].name, "It's on the spot you chose. %s" % INFO[id].text)
	_moved_last = false


## Tap on a building: move it or turn it (free). The habitat stays put.
func _on_building_tapped(id: StringName) -> void:
	if _world.is_placing() or not get_tree().get_nodes_in_group(&"hud_modal").is_empty():
		return
	if id == &"habitat":
		_say(&"info", "The habitat", "This is the crew's home. It stays right here.")
		return
	_modal(INFO[id].name, "", "Move it to a new spot or turn it. It's free!", [
		["Move", func() -> void: _world.begin_placement(id, true)],
		["Turn", func() -> void:
			var r: Dictionary = _world.rotate_building(id)
			if not r.ok:
				_say(&"warning", "Can't turn here", r.reason + ".")],
		["Close", func() -> void: pass]])


# --- Rewards (Stage 8) ---------------------------------------------------------

## Mission Log: one page per finished day (photo, real event, the day's idea,
## how you thought it through, stars). Reread any time.
func _show_log() -> void:
	var pages := Rewards.log_pages(Colony.state)
	var m := _modal("Mission Log", "", "Your discoveries so far. Science stars: %d." % Rewards.total_stars(Colony.state) \
		if not pages.is_empty() else "Finish a mission to write your first page!", [["Close", func() -> void: pass]])
	var col: VBoxContainer = m.find_child("Body", true, false).get_parent()
	var scroll := ScrollContainer.new()
	scroll.name = "LogScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, minf(300.0, size.y - 240.0)) if not pages.is_empty() else Vector2.ZERO
	col.add_child(scroll)
	col.move_child(scroll, col.get_child_count() - 2)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(list)
	for page in pages:
		var task: Dictionary = page.task
		var row := HBoxContainer.new()
		row.name = "Page%d" % page.day
		row.add_theme_constant_override(&"separation", 10)
		list.add_child(row)
		var pic := NasaDb.mission_image(task.id)
		if not pic.is_empty():
			var tex := TextureRect.new()
			tex.texture = pic.texture
			tex.custom_minimum_size = Vector2(84, 64)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		_info_label(text, "Day %d: %s  %s" % [page.day, task.story.name, "★".repeat(page.stars) + "☆".repeat(3 - page.stars)], 16, true)
		_info_label(text, "Idea: " + task.idea, 14)
		_info_label(text, page.how, 14)
		for l in text.get_children():
			l.custom_minimum_size.x = 440


## Badge shelf: earned badges, and how to earn the others.
func _show_badges() -> void:
	var lines := []
	for id in Rewards.BADGES:
		var b: Dictionary = Rewards.BADGES[id]
		var where := ""
		if b.has("missions"):
			var names := []
			for c in OutpostSimulation.CAMPAIGNS.values():
				if b.missions.all(func(m): return c.days.has(m)):
					names.append(c.name)
			where = " (in %s)" % " or ".join(names)
		lines.append(("✓ %s" % b.name) if Colony.state.get("badges", {}).has(id) else ("○ %s: %s%s" % [b.name, b.how, where]))
	var m := _modal("Badges", "mascot_celebrate", "\n".join(lines), [["Close", func() -> void: pass]])
	m.find_child("Body", true, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## New badges and decorations are collected and shown together on one card
## after the other cards, so a day never ends with a pile of pop-ups.
var _new_rewards := []


func _queue_reward(id: StringName, kind: String) -> void:
	if not Colony.show_rewards:
		return
	_new_rewards.append([kind, id])
	if _new_rewards.size() == 1:
		# After the night: the debrief (what you learned) comes first, rewards last.
		get_tree().create_timer(Colony.AUTO_NEXT_DELAY + 0.5).timeout.connect(func() -> void:
			_after_modals(_show_rewards))


func _show_rewards() -> void:
	if _new_rewards.is_empty():
		return
	var lines := []
	for r in _new_rewards:
		if r[0] == "badge":
			lines.append("New badge: %s! %s" % [Rewards.BADGES[r[1]].name, Rewards.BADGES[r[1]].how])
		else:
			lines.append("New decoration: %s! Find it in Build. It's free." % INFO[r[1]].name)
	_new_rewards.clear()
	var m := _modal("Today's rewards!", "mascot_celebrate", "\n".join(lines), [["Yay!", func() -> void: pass]])
	m.find_child("Body", true, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


# --- Real NASA stories -------------------------------------------------------

## Runs `then` now, or once the open cards (debrief, story...) are closed, so
## cards never pile up. A plain queue: connecting several bound callables of
## one method to the same signal counts as one connection and drops the rest.
var _card_queue: Array[Callable] = []


func _after_modals(then: Callable) -> void:
	if _modal_open():
		_card_queue.append(then)
	else:
		then.call()


func _modal_open() -> bool:
	return get_tree().get_nodes_in_group(&"hud_modal").any(func(m): return not m.is_queued_for_deletion())


## A card closed: show the next queued one (each opens after the last closes).
func _next_card() -> void:
	while not _card_queue.is_empty() and not _modal_open():
		_card_queue.pop_front().call()


## Today's real story, the first time this day is reached (remembered in the save).
func _story_once() -> void:
	var day := int(Colony.state.day)
	if not Colony.show_stories or Colony.finished or Colony.today_tasks().is_empty():
		return
	# Seen and answered: done. Seen but closed before answering (e.g. the app
	# was quit): show it again, so the guess step is never skipped.
	var solved: bool = Colony.state.guesses.get(Colony.today_tasks()[0].id, {}).get("solved", false)
	if Colony.state.stories_seen.has(day) and solved:
		return
	Colony.state.stories_seen[day] = true
	Colony.save()
	_show_story()


## "Mission Briefing": the real NASA problem first, then "what would you
## do?" with three ideas. A wrong pick gets a kind hint and another try; after
## two misses the answer is explained. Only then is NASA's real fix shown,
## with the player's turn, the link and what MoonMinds made up.
func _show_story(task := {}, review := false) -> void:
	if task.is_empty():
		var tasks := Colony.today_tasks()
		if tasks.is_empty():
			return
		task = tasks[0]
	var story: Dictionary = task.story
	var m := _modal("Mission Briefing", "", story.name, [["Close" if review else "My turn!", func() -> void: pass]])
	var body: Label = m.find_child("Body", true, false)
	body.add_theme_font_size_override(&"font_size", 22)
	body.add_theme_color_override(&"font_color", Color("#FFC94A"))
	var col: VBoxContainer = body.get_parent()
	var scroll := ScrollContainer.new()
	scroll.name = "StoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, minf(290.0, size.y - 250.0))
	col.add_child(scroll)
	col.move_child(scroll, body.get_index() + 1)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(list)
	_mission_photo(list, task.id)
	_info_label(list, "A real problem NASA faced. " + story.where, 15)
	if story.note != "":
		_info_label(list, story.note, 15)
	_info_label(list, "The problem: " + story.problem, 17)

	var reveal := VBoxContainer.new()
	reveal.name = "Reveal"
	reveal.add_theme_constant_override(&"separation", 6)
	_info_label(reveal, "What NASA did: " + story.did, 17)
	_info_label(reveal, ("You did it: " if review else "Your turn: ") + task.text + ".", 18, true)
	_nasa_link(reveal, "Read more at NASA", story.url)
	_info_label(reveal, "This story is real. In MoonMinds, the base, its numbers and Robo are made up.", 13)
	reveal.get_child(-1).modulate.a = 0.75

	var actions: Control = m.find_child("Choice0", true, false).get_parent()
	var quiz := VBoxContainer.new()
	quiz.name = "Quiz"
	quiz.add_theme_constant_override(&"separation", 6)
	list.add_child(quiz)
	list.add_child(reveal)
	var open_up := func() -> void:
		reveal.visible = true
		actions.visible = true
		scroll.ensure_control_visible.call_deferred(reveal)
	if review or Colony.state.guesses.get(task.id, {}).get("solved", false):
		quiz.visible = false
		return
	reveal.visible = false
	actions.visible = false  # the answer comes first; it can't get stuck (2 tries max)
	_info_label(quiz, task.quiz.question, 18, true)
	# Feedback sits right under the question, so a hint is never scrolled away.
	var feedback := Label.new()
	feedback.name = "QuizFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size = Vector2(530, 0)
	feedback.add_theme_font_size_override(&"font_size", 16)
	feedback.add_theme_color_override(&"font_color", Color("#FFC94A"))
	quiz.add_child(feedback)
	for i in task.quiz.options.size():
		var opt: Dictionary = task.quiz.options[i]
		var b := Button.new()
		b.name = "Option%d" % i
		b.text = opt.text
		b.theme_type_variation = &"IconButton"
		b.custom_minimum_size = Vector2(530, 48)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override(&"font_size", 16)
		b.pressed.connect(Events.button_pressed.emit.bind(StringName(b.name)))
		b.pressed.connect(func() -> void:
			var tries := Colony.record_guess(task.id, opt.correct)
			if opt.correct:
				feedback.text = "✓ Yes! That is what NASA did."
			elif tries >= 2:
				feedback.text = "Good thinking! NASA's answer: %s." % _correct_option(task.quiz)
			else:
				feedback.text = "Not quite. %s Try again!" % opt.hint
				b.disabled = true
				return
			for other in quiz.get_children():
				if other is Button:
					other.disabled = true
					if other.text == _correct_option(task.quiz):
						other.text = "✓ " + other.text  # the answer, marked without colour
			open_up.call())
		quiz.add_child(b)


## The day's NASA picture with what it is, who took it, its NASA ID and why it
## belongs here, all from nasa_db/manifest.csv. No manifest row, no picture.
func _mission_photo(parent: Control, mission_id: StringName) -> void:
	var pic := NasaDb.mission_image(mission_id)
	if pic.is_empty():
		return
	var tex := TextureRect.new()
	tex.name = "MissionPhoto"
	tex.texture = pic.texture
	tex.custom_minimum_size = Vector2(0, 160)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(tex)
	var row: Dictionary = pic.row
	var kind: String = row.content_type
	_info_label(parent, "%s · %s · %s" % [kind.left(1).to_upper() + kind.substr(1), row.credit, row.asset_id], 13)
	_info_label(parent, row.relevance, 13)
	parent.get_child(-1).name = "PhotoNote"


## A link to a NASA page. Kids get a "ask a grown-up" card before the browser opens.
func _nasa_link(parent: Control, text: String, url: String) -> void:
	var link := LinkButton.new()
	link.text = text
	link.add_theme_font_size_override(&"font_size", 15)
	link.pressed.connect(Events.button_pressed.emit.bind(&"NasaLink"))
	link.pressed.connect(func() -> void:
		_modal("Open a NASA web page?", "mascot_think", "This opens your web browser. Ask a grown-up first!", [
			["Open it", func() -> void: OS.shell_open(url)], ["Not now", func() -> void: pass]]))
	parent.add_child(link)


static func _correct_option(quiz: Dictionary) -> String:
	for opt in quiz.options:
		if opt.correct:
			return opt.text
	return ""


# --- Data info -----------------------------------------------------------------

## Real NASA data vs. the game's own numbers. The sunlight facts are read from
## nasa_db (processed from NASA's LOLA/PGDA map); see nasa_db/manifest.csv.
const DATA_INFO := {
	"status": "MoonMinds uses some real NASA data, and some practice numbers made up for the game. Here is which is which.",
	"sources": [
		{"name": "Lunar Polar Illumination map (real data, used)",
			"by": "NASA Goddard, LRO's LOLA laser team (Mazarico et al., 2011)",
			"measures": "How often each spot near the Moon's south pole sees the Sun, averaged over 18.6 years. Dark craters that never see the Sun show up black.",
			"in_game": "The sunlight facts on this card and in mission hints.",
			"image": "res://nasa_db/processed/images/south_pole_sunlight_map.png",
			"url": "https://pgda.gsfc.nasa.gov/products/69"},
		{"name": "Illumination at the Moon's South Pole, 2023 to 2030 (not used yet)",
			"by": "NASA Scientific Visualization Studio",
			"measures": "Pictures and movies of sunlight and shadow near the south pole, every 2 hours.",
			"in_game": "Not used: it is pictures, not numbers the game can read for each day.",
			"url": "https://svs.gsfc.nasa.gov/4930"},
	],
	"game_only": "Made up for the game (not NASA measurements): the Moon base and its buildings, Robo, the daily missions, and how fast things work in the game.",
}


## One kid-sized sentence from the real sunlight bands ("" if the file is missing).
static func _sunlight_fact() -> String:
	var b := NasaDb.sunlight_bands()
	if b.is_empty():
		return ""
	var never: float = b.get("never (permanent shadow)", 0.0)
	var under_40: float = never + b.get("under 20% of the time", 0.0) + b.get("20-40%", 0.0)
	return "Near the south pole, %d%% of the ground sees the Sun less than 40%% of the time, and %d%% never sees it. Even the sunniest spot is dark %d%% of the time." \
		% [roundi(under_40), roundi(never), roundi(100.0 - b.get("best_spot_sunlit_percent", 0.0))]


func _add_info_button() -> void:
	var b := Button.new()
	b.name = "InfoButton"
	b.unique_name_in_owner = true
	b.tooltip_text = "Where do the numbers come from?"
	b.theme_type_variation = &"IconButton"
	b.icon = load(ART % "icon_info")
	b.add_theme_constant_override(&"icon_max_width", 32)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(52, 52)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Next to Wait, under the day card that shows the sunlight it explains.
	b.position = Vector2(MARGIN + 168, 86)
	add_child(b)
	b.owner = self
	b.pressed.connect(_show_data_info)  # Events.button_pressed is wired in _ready


## The data panel: what is real NASA data, what the game made up, and links.
## Scrolls on small screens; any tap on Close shuts it.
func _show_data_info() -> void:
	var m := _modal("Real Moon data", "", DATA_INFO.status, [["Close", func() -> void: pass]])
	var body: Label = m.find_child("Body", true, false)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var col: VBoxContainer = body.get_parent()
	var scroll := ScrollContainer.new()
	scroll.name = "InfoScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, minf(300.0, size.y - 250.0))
	scroll.follow_focus = true
	col.add_child(scroll)
	col.move_child(scroll, body.get_index() + 1)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(list)
	for src in DATA_INFO.sources:
		_info_label(list, "NASA data: " + src.name, 18, true)
		if src.has("image") and ResourceLoader.exists(src.image):
			var tex := TextureRect.new()
			tex.texture = load(src.image)
			tex.custom_minimum_size = Vector2(0, 140)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			list.add_child(tex)
			_info_label(list, "Map made by MoonMinds from NASA's data: black = never sunlit, white = almost always.", 13)
			var fact := _sunlight_fact()
			if fact != "":
				_info_label(list, "Real fact: " + fact, 16)
		_info_label(list, "From: " + src.by, 15)
		_info_label(list, "What it measures: " + src.measures, 15)
		_info_label(list, "In the game: " + src.in_game, 15)
		_nasa_link(list, src.url, src.url)
	_info_label(list, "Game numbers", 18, true)
	_info_label(list, DATA_INFO.game_only, 15)


func _info_label(parent: Control, text: String, px: int, heading := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(530, 0)
	l.add_theme_font_size_override(&"font_size", px)
	if heading:
		l.add_theme_color_override(&"font_color", Color("#FFC94A"))
	parent.add_child(l)


# --- Drawers ---------------------------------------------------------------

func toggle_checklist() -> void:
	_checklist_open = not _checklist_open
	if _checklist_open:
		_show_today_row()
	%ChecklistTab.tooltip_text = "Close checklist" if _checklist_open else "Open checklist"
	_place_drawers(true)


## Puts the Mission Days rows in a scroll box, so a long list never slides
## behind the action buttons. Wheel, touch drag and the arrow keys scroll it.
func _make_task_list_scroll() -> void:
	var tasks: Control = %Tasks
	var scroll := ScrollContainer.new()
	scroll.name = "TaskScroll"
	scroll.unique_name_in_owner = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	var parent := tasks.get_parent()
	parent.add_child(scroll)
	scroll.owner = self
	parent.move_child(scroll, tasks.get_index())
	tasks.reparent(scroll)
	tasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		var step := 0
		if event.is_action_pressed(&"ui_down"):
			step = 40
		elif event.is_action_pressed(&"ui_up"):
			step = -40
		if step != 0:
			scroll.scroll_vertical += step
			scroll.accept_event())


## Positions the checklist drawer for its open/closed state. Recomputed on resize so
## the layout holds at any window size.
func _place_drawers(animate: bool) -> void:
	var list := _checklist_drawer
	# The list may grow only down to just above Search/Explore.
	var scroll: ScrollContainer = %TaskScroll
	var top := TOP + 56.0 + 28.0
	var room: float = %SearchButton.get_global_rect().position.y - global_position.y - top - 12.0
	var chrome: float = %ChecklistPanel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	scroll.custom_minimum_size.y = clampf(%Tasks.get_combined_minimum_size().y, 0.0, maxf(60.0, room - chrome))
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

## Mission Days: the campaign and its progress on top, finished days folded
## into one summary line (tap to look back; tap a day to reread its briefing),
## today's mission big, and the next day locked as "???".
func _build_checklist() -> void:
	for child in %Tasks.get_children():
		child.free()
	_task_rows.clear()
	var campaign: Dictionary = OutpostSimulation.CAMPAIGNS[Colony.state.campaign]
	var total := OutpostSimulation.campaign_length(Colony.state)
	var done_days := mini(int(Colony.state.day) - 1, total)
	var header := Label.new()
	header.name = "Progress"
	header.text = "%s: %d of %d days done" % [campaign.name, done_days, total]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override(&"font_size", 16)
	%Tasks.add_child(header)
	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.theme_type_variation = &"BarHealthy"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = total
	bar.value = done_days
	%Tasks.add_child(bar)
	var extras := HBoxContainer.new()
	extras.name = "Extras"
	extras.add_theme_constant_override(&"separation", 8)
	%Tasks.add_child(extras)
	for e in [["LogButton", "Mission Log", _show_log], ["BadgesButton", "Badges %d/%d" % [
			Colony.state.get("badges", {}).size(), Rewards.BADGES.size()], _show_badges]]:
		var b := Button.new()
		b.name = e[0]
		b.text = e[1]
		b.theme_type_variation = &"IconButton"
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", 15)
		b.pressed.connect(e[2])
		b.pressed.connect(Events.button_pressed.emit.bind(StringName(e[0])))
		extras.add_child(b)
	if done_days > 0:
		var summary := Button.new()
		summary.name = "PastSummary"
		summary.text = ("✓ Day 1 done" if done_days == 1 else "✓ Days 1-%d done" % done_days) \
			+ ("  (hide)" if _past_open else "  (look back)")
		summary.theme_type_variation = &"IconButton"
		summary.custom_minimum_size = Vector2(0, 44)
		summary.add_theme_font_size_override(&"font_size", 15)
		summary.pressed.connect(func() -> void:
			_past_open = not _past_open
			_build_checklist.call_deferred())  # this button is freed by the rebuild
		summary.pressed.connect(Events.button_pressed.emit.bind(&"PastSummary"))
		%Tasks.add_child(summary)
		var past := VBoxContainer.new()
		past.name = "PastDays"
		past.visible = _past_open
		%Tasks.add_child(past)
		for day in range(1, done_days + 1):
			var task: Dictionary = OutpostSimulation.tasks_for(day, Colony.state.campaign)[0]
			var b := Button.new()
			b.name = "Past%d" % day
			b.text = "✓ Day %d: %s" % [day, task.text]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.flat = true
			b.custom_minimum_size = Vector2(0, 44)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.tooltip_text = "Read this day's Mission Briefing again"
			b.pressed.connect(_show_story.bind(task, true))
			b.pressed.connect(Events.button_pressed.emit.bind(StringName(b.name)))
			past.add_child(b)
	if int(Colony.state.day) <= total:
		var task: Dictionary = Colony.today_tasks()[0]
		var row := _checklist_row("Day %d: %s" % [int(Colony.state.day), task.text])
		row.name = "Today"
		row.get_child(1).add_theme_font_size_override(&"font_size", 19)
		_task_rows[task.id] = row
		_refresh_task(task.id)
	if int(Colony.state.day) < total:
		var locked := _checklist_row("Day %d: ???" % (int(Colony.state.day) + 1))
		locked.get_child(0).texture = load(ART % "icon_critical")
		locked.modulate.a = 0.5
	_refresh_task_count()
	_place_drawers.call_deferred(false)
	_show_today_row.call_deferred()


## A day just ended: its row folds away calmly, then the list is rebuilt with
## that day inside the "done" summary.
func _fold_finished_day() -> void:
	var rows := _task_rows.values()
	if rows.is_empty():
		_build_checklist()
		return
	var row: Control = rows[0]
	row.pivot_offset = Vector2(row.size.x / 2.0, 0.0)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(row, "scale:y", 0.0, 0.4)
	t.parallel().tween_property(row, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void:
		_build_checklist()
		var summary: Control = %Tasks.get_node_or_null("PastSummary")
		if summary:
			_bounce(summary))


## Keeps today's mission row in view (the list scrolls as days are added).
func _show_today_row() -> void:
	await get_tree().process_frame  # rows need a layout pass before scrolling
	await get_tree().process_frame
	var today := Colony.today_tasks()
	if not today.is_empty() and _task_rows.has(today[0].id):
		%TaskScroll.ensure_control_visible(_task_rows[today[0].id])


func _checklist_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var box := TextureRect.new()
	box.custom_minimum_size = Vector2(26, 26)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.texture = BOX
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(box)
	row.add_child(label)
	%Tasks.add_child(row)
	return row


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


## Tab shows the campaign's progress in days ("3/8").
func _refresh_task_count() -> void:
	var total := OutpostSimulation.campaign_length(Colony.state)
	%ChecklistTab.text = "%d/%d" % [mini(int(Colony.state.day) - 1, total), total]


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
