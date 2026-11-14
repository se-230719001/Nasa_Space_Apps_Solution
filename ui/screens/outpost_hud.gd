extends Control
## Colony HUD for the real-time model in scenes/sim/colony_sim.gd
## (design: docs/game_systems_design.md).
## Top centre: the 5 main indicators. Tap the bar to unfold it: the circles
## stack vertically with their numbers and causes next to them.
## Bottom: BUILD / RESEARCH / EXPLORE. Tapping a building on the map opens its
## panel. main.gd owns the model and the 3D world; the HUD only asks it to act.

signal place_requested(building_id: String)
signal place_cancelled
signal build_confirmed(building_id: String, cell: Vector2i)   ## cell = (-1,-1) for upgrades
signal research_requested(card_id: String)
signal craft_requested(craft_type: String)
signal launch_requested(dest_id: String)
signal toggle_requested(setting: String)
signal end_day_requested

const MASCOTS := {
	&"info": preload("res://assets/sprites/mascots/wave.png"),
	&"warning": preload("res://assets/sprites/mascots/think.png"),
	&"success": preload("res://assets/sprites/mascots/celebrate.png"),
}
const CHECK := preload("res://assets/sprites/icons/check.png")
const WARN := preload("res://assets/sprites/icons/warning.png")
const INFO_ICON := preload("res://assets/sprites/icons/info.png")
const ADD_ICON := preload("res://assets/sprites/icons/add.png")
const REMOVE_ICON := preload("res://assets/sprites/icons/remove.png")
const ART := {
	"greenhouse": preload("res://assets/sprites/buildings/greenhouse.png"),
	"solar_panel": preload("res://assets/sprites/buildings/solar_panel.png"),
	"water_system": preload("res://assets/sprites/buildings/water_system.png"),
	"research_lab": preload("res://assets/sprites/buildings/research_lab.png"),
	"habitat": preload("res://assets/sprites/buildings/habitat.png"),
	"main_base": preload("res://assets/sprites/buildings/main_base.png"),
	"hangar": preload("res://assets/sprites/icons/rocket.svg"),
}
const ICONS := {
	"health": preload("res://assets/sprites/icons/health.svg"),
	"food": preload("res://assets/sprites/icons/food.png"),
	"water": preload("res://assets/sprites/icons/water.png"),
	"energy": preload("res://assets/sprites/icons/power.png"),
	"oxygen": preload("res://assets/sprites/icons/oxygen.svg"),
	"shield": preload("res://assets/sprites/icons/shield.png"),
	"rocket": preload("res://assets/sprites/icons/rocket.svg"),
}
const STATUS_COLORS := [Color("#3CDB56"), Color("#F7C948"), Color("#FF4961")]
const KEYS := ["health", "food", "water", "energy", "oxygen"]
const NAMES := {"health": "Colony Health", "food": "Food", "water": "Water", "energy": "Energy", "oxygen": "Oxygen"}
const RING_SIZE := 58
const COMPACT_RING_SIZE := 48
const COLLAPSE_DELAY := 0.35
## Doc A tables as kid-friendly "goes up / goes down / strategy" for each icon.
const INFO := {
	"health": {
		"up": ["Enough oxygen, water and food (the needs)", "Sleep and exercise programs (Health Center)", "A higher Health Center level raises the limit"],
		"down": ["Missing oxygen, water or food", "Radiation on unprotected people", "Too much CO2 (above 70)"],
		"tips": ["Health doesn't grow forever: it follows how well needs are met.", "Before a storm, a Radiation Lab shelter keeps everyone safe."]},
	"food": {
		"up": ["Greenhouse (needs light + water + CO2 together)", "Nutrition tracking and research"],
		"down": ["Every person eats", "Exercise makes people hungrier", "Solar storms slow plant growth"],
		"tips": ["Upgrade the Greenhouse before new crew arrive.", "If power is short, the greenhouse gets power after life support."]},
	"water": {
		"up": ["Water Recycling (70-95 %) and moon ice", "Missions to icy places (Shackleton, Europa)", "Drip irrigation saves greenhouse water"],
		"down": ["People drink and wash", "Plants", "Electrolysis splits water into oxygen"],
		"tips": ["Recycling is never 100 %: a little water is always lost.", "Radiation never spoils stored water."]},
	"energy": {
		"up": ["Energy Center panels (more in sunlight)", "Panel cleaning research"],
		"down": ["Every working building", "Lunar night and solar storms (less sunlight)", "Spacecraft fuel"],
		"tips": ["The battery STORES energy, it doesn't make it.", "When power is short: life support first, the hangar last."]},
	"oxygen": {
		"up": ["Electrolysis in Life Support (water + power -> oxygen)", "Plants in the Greenhouse"],
		"down": ["Every person breathes it", "Exercise", "Missions take oxygen with them"],
		"tips": ["Watch the dome rim: green = plenty, blue = OK, red = danger.", "Electrolysis doesn't remove CO2: the CO2 filter and plants do."]},
}

var sim: ColonySim
var expanded := false
var _pending_id := ""
var _pending_cell := Vector2i(-1, -1)
var _icons := {}
var _ring_tex: Texture2D
var _outside_time := 0.0
var _compact_layout := false
var _narrow_layout := false
var _layout_initialized := false


static func uses_compact_layout(viewport_width: float) -> bool:
	return viewport_width < 960.0


func _ready() -> void:
	_ring_tex = _make_ring_texture()
	for key in KEYS:
		%ResourceIcons.add_child(_make_resource_row(key))
	%ResourceBar.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle_bar())
	%BuildButton.pressed.connect(show_build_menu)
	%ResearchButton.pressed.connect(show_research)
	%ExploreButton.pressed.connect(show_hangar)
	%ExploreButton.pressed.connect(Music.play.bind(&"explore"))
	%EndDayButton.pressed.connect(func() -> void: end_day_requested.emit())
	%HintButton.pressed.connect(show_hint)
	%StormChip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			show_problem())
	%CloseButton.pressed.connect(_close_build_popup)
	%CancelButton.pressed.connect(_close_build_popup)
	%ConfirmButton.pressed.connect(_confirm_build)
	%PlaceCancel.pressed.connect(cancel_placement)
	_set_expanded(false)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_play_splash()


## --- Refresh ----------------------------------------------------------------------

func refresh() -> void:
	var lv := sim.levels_view()
	var delta: Dictionary = sim.last_report.get("delta", {})
	for key in KEYS:
		var st := sim.status_of(key)
		var row: Dictionary = _icons[key]
		create_tween().tween_property(row.ring, "value", lv[key], 0.5)
		row.ring.tint_progress = STATUS_COLORS[st]
		row.value.text = "%d %%" % roundi(lv[key])
		row.value.add_theme_color_override(&"font_color", STATUS_COLORS[st].lightened(0.3))
		row.change.text = "%+.1f / day" % delta.get(key, 0.0)
		row.detail.text = _detail(key)
		row.button.tooltip_text = "%s: %d %%" % [NAMES[key], roundi(lv[key])]
	%DayLabel.text = "Day %d" % sim.day
	%CrewLabel.text = "Crew %d/%d" % [sim.population, sim.housing()]
	%MaterialsLabel.text = "Materials %d" % floori(sim.materials)
	%ScienceLabel.text = "Science %d" % floori(sim.science)
	var g := sim.current_goal()
	%GoalTitle.text = g.get("title", "All goals done!")
	%GoalText.text = g.get("text", "You built a Moon city. Keep it balanced!")
	if g.get("type", "") == "streak":
		%GoalText.text += "  (%d/%d)" % [sim.goal_streak, g.days]
	%GoalGood.text = g.get("good", "")
	%GoalBad.text = g.get("bad", "")
	%GoalGood.visible = g.has("good")
	%GoalBad.visible = g.has("bad")
	var d := sim.days_to_problem()
	%StormChip.visible = true
	%StormChip.theme_type_variation = &"WarningBubble" if d <= 2 else &"InfoBubble"
	%StormText.text = "Day %d problem: %s  ·  %s" % [sim.problem_day, sim.problem.title,
		"TOMORROW" if d == 1 else "in %d days" % d]


## Production / use / capacity for the unfolded bar (doc F.2).
func _detail(key: String) -> String:
	var r := sim.last_report
	if r.is_empty():
		return "Waiting for the first day..."
	match key:
		"health":
			return "Limit %d · crew %d · radiation %d" % [sim.health_cap(), sim.population, r.exposure]
		"food":
			return "Grown %.0f · eaten %.0f" % [r.food_made, r.food_used]
		"water":
			return "Recycling %d %% · %.0f / %.0f L" % [r.recycle_rate * 100.0, sim.stock.water, ColonySim.CAPACITY.water]
		"energy":
			return "Made %.0f · used %.0f · battery %.0f/%.0f" % [r.energy_produced, r.energy_demand, sim.stock.energy, sim.battery_capacity()]
		"oxygen":
			return "Made %.0f · breathed %.0f · CO2 %d" % [r.o2_made, r.o2_used, sim.co2]
	return ""


## --- Resource bar (folds open) ---------------------------------------------------

func toggle_bar() -> void:
	_set_expanded(not expanded)


## The unfolded bar closes when the mouse leaves it (after a short moment)
## or when the player taps anywhere outside it.
func _process(delta: float) -> void:
	if not expanded or %Overlay.visible:
		_outside_time = 0.0
		return
	var inside: bool = %ResourceBar.get_global_rect().grow(8.0).has_point(get_global_mouse_position())
	_outside_time = 0.0 if inside else _outside_time + delta
	if _outside_time >= COLLAPSE_DELAY and not DisplayServer.is_touchscreen_available():
		_set_expanded(false)


func _input(event: InputEvent) -> void:
	if not expanded or %Overlay.visible:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and not %ResourceBar.get_global_rect().has_point(event.position):
		_set_expanded(false)


func _set_expanded(on: bool) -> void:
	expanded = on
	(%ResourceIcons as BoxContainer).vertical = on
	for key in _icons:
		for part in ["name", "value", "change", "detail", "more"]:
			_icons[key][part].visible = on
	%ResourceBar.tooltip_text = "Tap to close" if on else "Tap to see details"


func _make_resource_row(key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ring := TextureProgressBar.new()
	ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	ring.texture_under = _ring_tex
	ring.texture_progress = _ring_tex
	ring.tint_under = Color(1, 1, 1, 0.15)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ring)
	var icon := TextureRect.new()
	icon.texture = ICONS[key]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.pressed.connect(func() -> void:
		if expanded:
			show_resource_info(key)
		else:
			toggle_bar())
	row.add_child(b)
	var text := VBoxContainer.new()
	text.custom_minimum_size.x = 330
	text.add_theme_constant_override(&"separation", 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := HBoxContainer.new()
	var name_l := _label(NAMES[key], &"H3")
	name_l.custom_minimum_size.x = 140
	var value_l := _label("—", &"H3")
	value_l.custom_minimum_size.x = 64
	var change_l := _label("", &"Caption", 14)
	top.add_child(name_l)
	top.add_child(value_l)
	top.add_child(change_l)
	text.add_child(top)
	var detail_l := _label("", &"Caption", 13)
	text.add_child(detail_l)
	row.add_child(text)
	var more := Button.new()
	more.text = "?"
	more.tooltip_text = "What changes %s?" % NAMES[key]
	more.custom_minimum_size = Vector2(40, 40)
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	more.pressed.connect(show_resource_info.bind(key))
	row.add_child(more)
	_icons[key] = {"ring": ring, "button": b, "name": text, "value": value_l, "change": change_l,
		"detail": detail_l, "more": more}
	return row


static func _make_ring_texture() -> Texture2D:
	var n := RING_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) / 2.0
	var r := n / 2.0 - 4.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(1.0 - absf(d - r) / 3.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.0, 0.7, a)))
	return ImageTexture.create_from_image(img)


func show_resource_info(key: String) -> void:
	var info: Dictionary = INFO[key]
	var body := _open_overlay("%s: %d %%" % [NAMES[key], roundi(sim.levels_view()[key])])
	_add_text(body, _detail(key), &"Caption")
	_add_list(body, "Goes UP with", info.up, ADD_ICON)
	_add_list(body, "Goes DOWN with", info.down, REMOVE_ICON)
	_add_list(body, "Strategy", info.tips, INFO_ICON)
	_add_button("GOT IT", close_overlay, true)


## --- BUILD ---------------------------------------------------------------------------

func show_build_menu() -> void:
	var body := _open_overlay("Build & Upgrade")
	_add_text(body, "Every building has 4 levels and changes its look at each one. Building is instant. You have %d materials." % floori(sim.materials), &"Caption")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	for id: String in ColonySim.BUILDINGS:
		grid.add_child(_building_card(id))
	body.add_child(grid)
	_add_button("CLOSE", close_overlay, true)


func _building_card(id: String) -> Control:
	var def: Dictionary = ColonySim.BUILDINGS[id]
	var level := sim.lv(id)
	var why := sim.why_not_build(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(300, 92)
	var style := get_theme_stylebox(&"panel", &"CardPanel")
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		card.add_theme_stylebox_override(state, style)
	card.modulate = Color.WHITE if why == "" else Color(0.65, 0.65, 0.75)
	card.tooltip_text = def.blurb if why == "" else why
	card.pressed.connect(_on_building_card.bind(id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	card.add_child(row)
	var art := TextureRect.new()
	art.texture = ART[def.art]
	art.custom_minimum_size = Vector2(70, 0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 0)
	row.add_child(col)
	col.add_child(_label("%s  ·  %s" % [def.name, ("Lv %d/4" % level) if level > 0 else "not built"], &"H3", 16))
	var action := ""
	if level >= 4:
		action = "Top level reached"
	else:
		action = "%s: %s" % ["Build" if level == 0 else "Lv %d" % (level + 1), def.unlocks[level]]
	var a := _label(action, &"Caption", 13)
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(a)
	if level < 4:
		col.add_child(_label("%d materials · ready right away" % sim.upgrade_cost(id), &"ChipLabel", 12))
	return card


func _on_building_card(id: String) -> void:
	var why := sim.why_not_build(id)
	if why != "":
		_say(&"warning", "Not yet", why)
		return
	close_overlay()
	_pending_id = id
	if sim.lv(id) == 0:
		%PlaceText.text = "Tap a green square to place the %s" % ColonySim.BUILDINGS[id].name
		%PlaceBanner.show()
		place_requested.emit(id)
		_say(&"info", "", "Where should the %s go? You decide!" % ColonySim.BUILDINGS[id].name)
	else:
		_open_build_popup(id, Vector2i(-1, -1))


## main.gd calls this after the player tapped a free cell.
func confirm_placement(cell: Vector2i) -> void:
	%PlaceBanner.hide()
	_open_build_popup(_pending_id, cell)


func _open_build_popup(id: String, cell: Vector2i) -> void:
	_pending_id = id
	_pending_cell = cell
	var def: Dictionary = ColonySim.BUILDINGS[id]
	var level := sim.lv(id)
	%Title.text = ("Build %s?" % def.name) if level == 0 else ("Upgrade to Lv %d?" % (level + 1))
	%Illustration.texture = ART[def.art]
	var diff := sim.preview_upgrade(id)
	var uses := []
	var improves := []
	for key in KEYS:
		var d: float = diff.get(key, 0.0)
		if d <= -0.3:
			uses.append([key, d])
		elif d >= 0.3:
			improves.append([key, d])
	uses.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	improves.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	_fill_effects(%UsesList, uses)
	_fill_effects(%ImprovesList, improves)
	%BuildTimeText.text = "Right away (no waiting)"
	%Explanation.text = "%s Costs %d materials (once)." % [def.unlocks[level], sim.upgrade_cost(id)]
	%BuildPopup.show()
	%ConfirmButton.grab_focus()


func _fill_effects(list: HBoxContainer, items: Array) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	if items.is_empty():
		list.add_child(_label("—", &"DarkCaption"))
		return
	for item in items.slice(0, 3):
		var icon := TextureRect.new()
		icon.texture = ICONS[item[0]]
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		list.add_child(icon)
		list.add_child(_label("%+.1f/day" % item[1], &"DarkCaption", 12))


func cancel_placement() -> void:
	%PlaceBanner.hide()
	_pending_id = ""
	place_cancelled.emit()


func _close_build_popup() -> void:
	%BuildPopup.hide()
	if _pending_cell.x >= 0:
		place_cancelled.emit()
	_pending_id = ""
	_pending_cell = Vector2i(-1, -1)


func _confirm_build() -> void:
	%BuildPopup.hide()
	build_confirmed.emit(_pending_id, _pending_cell)
	_pending_id = ""
	_pending_cell = Vector2i(-1, -1)


## Panel for a building tapped on the map.
func show_building(id: String) -> void:
	var def: Dictionary = ColonySim.BUILDINGS[id]
	var level := sim.lv(id)
	var body := _open_overlay("%s · Lv %d" % [def.name, level])
	_add_row(body, ART[def.art], def.blurb)
	for i in 4:
		var mark := CHECK if i < level else INFO_ICON
		_add_row(body, mark, "Lv %d: %s" % [i + 1, def.unlocks[i]])
	match id:
		"health_center":
			if level >= 1:
				_add_toggle(body, "Exercise program (+health, +5 % water & food)", "exercise", sim.exercise_on)
			if level >= 2:
				_add_toggle(body, "Sleep program (+health)", "sleep", sim.sleep_on)
		"life_support":
			if level >= 2:
				_add_toggle(body, "CO2 filter (off = more CO2 for plants, saves power)", "co2_filter", sim.co2_filter_on)
	if level < 4:
		var b := _add_button("UPGRADE (%d)" % sim.upgrade_cost(id), func() -> void:
			close_overlay()
			_on_building_card(id))
		b.disabled = sim.why_not_build(id) != ""
		b.tooltip_text = sim.why_not_build(id)
	_add_button("CLOSE", close_overlay, true)


func _add_toggle(box: Control, text: String, setting: String, on: bool) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(func(_v: bool) -> void: toggle_requested.emit(setting))
	box.add_child(c)


## --- RESEARCH -------------------------------------------------------------------------

func show_research() -> void:
	var body := _open_overlay("Research · %d science points" % floori(sim.science))
	_add_text(body, "Find research cards on missions, then study them here. The Radiation Lab and missions give science points.", &"Caption")
	for id: String in ColonySim.CARDS:
		var c: Dictionary = ColonySim.CARDS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var found := id in sim.cards_found
		col.add_child(_label(c.name if found else "??? (not found yet)", &"H3", 16))
		if found:
			col.add_child(_label("%s  ·  %d science  ·  needs %s Lv %d" % [c.text, c.science,
				ColonySim.BUILDINGS[c.needs[0]].name, c.needs[1]], &"Caption", 13))
		row.add_child(col)
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if sim.has_card(id):
			b.text = "DONE"
			b.disabled = true
		else:
			var why := sim.why_not_research(id)
			b.text = "RESEARCH" if why == "" else "LOCKED"
			b.disabled = why != ""
			b.tooltip_text = why
			b.pressed.connect(func() -> void: research_requested.emit(id))
		row.add_child(b)
		body.add_child(row)
	_add_button("CLOSE", close_overlay, true)


## --- EXPLORE / HANGAR -------------------------------------------------------------------

func show_hangar() -> void:
	var hl := sim.lv("hangar")
	var body := _open_overlay("Hangar · Lv %d" % hl)
	var free := sim.crafts.filter(func(c: Dictionary) -> bool: return not c.busy).size()
	_add_text(body, "Spacecraft: %d ready, %d on missions, %d being built (room for %d)." % [free,
		sim.crafts.size() - free, sim.craft_builds.size(), int(sim.stat("hangar", "crafts"))], &"Label")
	for m in sim.missions:
		_add_row(body, ICONS.rocket, "On the way: %s — back in %d day(s)." % [ColonySim.DESTINATIONS[m.dest].name, m.days_left])
	var crafts := HBoxContainer.new()
	crafts.add_theme_constant_override(&"separation", 10)
	for type: String in ColonySim.CRAFTS:
		var c: Dictionary = ColonySim.CRAFTS[type]
		var why := sim.why_not_craft(type)
		var b := Button.new()
		b.text = "%s\n%d materials · %d days" % [c.name, c.cost, c.days]
		b.custom_minimum_size = Vector2(180, 60)
		b.disabled = why != ""
		b.tooltip_text = why
		b.pressed.connect(func() -> void: craft_requested.emit(type))
		crafts.add_child(b)
	body.add_child(_label("Build a spacecraft", &"H3"))
	body.add_child(crafts)
	body.add_child(_label("Missions", &"H3"))
	for id: String in ColonySim.DESTINATIONS:
		var d: Dictionary = ColonySim.DESTINATIONS[id]
		var why := sim.why_not_launch(id)
		var need := sim.mission_needs(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label("%s · %s" % [d.name, d.body], &"H3", 16))
		var line := _label("%d days · uses %d fuel, %d O2, %d food · brings science, materials%s" % [
			sim.mission_days(id), need.energy, need.oxygen, need.food, ", water" if d.has("water") else ""], &"Caption", 13)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 400
		col.add_child(line)
		row.add_child(col)
		var b := Button.new()
		b.text = "LAUNCH" if why == "" else "LOCKED"
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else d.lesson
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: launch_requested.emit(id))
		row.add_child(b)
		body.add_child(row)
	if hl < 4:
		var b := _add_button("UPGRADE HANGAR (%d)" % sim.upgrade_cost("hangar"), func() -> void:
			close_overlay()
			_on_building_card("hangar"))
		b.disabled = sim.why_not_build("hangar") != ""
		b.tooltip_text = sim.why_not_build("hangar")
	_add_button("BACK TO BASE", func() -> void:
		close_overlay()
		Music.play(&"outpost"), true)


func show_mission_report(e: Dictionary) -> void:
	var body := _open_overlay("Back from %s!" % e.name)
	var loot := "%d materials, %d science points" % [e.materials, e.science]
	if e.has("water"):
		loot += ", %d water" % e.water
	_add_row(body, ICONS.rocket, "The crew brought %s." % loot)
	if e.has("minerals"):
		_add_row(body, ADD_ICON, "The sensors found a valuable mineral (+40 materials)!")
	for c in e.cards:
		_add_row(body, INFO_ICON, "New research card: %s — %s" % [ColonySim.CARDS[c].name, ColonySim.CARDS[c].text])
	if e.get("suit_warning", false):
		_add_row(body, WARN, "Deep space radiation made the crew a bit tired. Better suits (Radiation Lab Lv 4) would protect them.")
	_add_row(body, INFO_ICON, "Did you know? %s" % e.lesson)
	_add_button("GREAT!", close_overlay, true)
	Music.stinger(&"mission_complete")


## --- Mascot, speed ------------------------------------------------------------------------

func show_advice(advice: Dictionary) -> void:
	_say(advice.kind, advice.title, advice.text)


func _say(kind: StringName, title: String, text: String) -> void:
	%Mascot.texture = MASCOTS[kind]
	%Bubble.theme_type_variation = &"BubbleYellow" if kind == &"warning" else &"BubbleWhite"
	%BubbleTitle.text = title
	%BubbleTitle.visible = not title.is_empty()
	%BubbleText.text = text


## --- Hint, problem, day report, tutorial -----------------------------------------------

func show_hint() -> void:
	show_advice(sim.hint())
	var b: Control = %Bubble
	b.pivot_offset = Vector2(0, b.size.y)
	b.scale = Vector2(0.92, 0.92)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "scale", Vector2.ONE, 0.25)


func show_problem() -> void:
	var p := sim.problem
	var d := sim.days_to_problem()
	var body := _open_overlay("Day %d: %s" % [sim.problem_day, p.title])
	_add_row(body, WARN, "%s (%s)" % [p.text, "tomorrow" if d == 1 else "in %d days" % d])
	var unit := "" if p.key == "co2" else " %"
	var goal := ("at least %d" % p.min) if p.has("min") else ("at most %d" % p.max)
	_add_row(body, INFO_ICON, "To be safe, %s should be %s%s at the end of that day (now %d%s)." % [
		p.key.to_upper() if p.key == "co2" else NAMES.get(p.key, p.key), goal, unit, roundi(sim.value_of(p.key)), unit])
	_add_row(body, ADD_ICON, "Prepare: %s" % p.prepare)
	_add_row(body, CHECK, "If you are ready: %s" % p.good)
	_add_row(body, REMOVE_ICON, "If not: %s" % p.bad)
	_add_button("GOT IT", close_overlay, true)


## End-of-day output: problem result, biggest changes and their causes, news.
func show_day_report(r: Dictionary) -> void:
	var body := _open_overlay("End of day %d" % (r.day - 1))
	for ev in r.events:
		if ev is Dictionary and ev.type == "problem":
			var p: Dictionary = ev.problem
			_add_row(body, CHECK if ev.passed else WARN, "%s — %s%s" % [p.title, ev.text,
				"  (+%d materials)" % ev.reward if ev.passed else ""])
			_add_row(body, INFO_ICON, "Did you know? %s" % ev.lesson)
	var changes := HBoxContainer.new()
	changes.alignment = BoxContainer.ALIGNMENT_CENTER
	changes.add_theme_constant_override(&"separation", 22)
	for k in KEYS:
		var item := HBoxContainer.new()
		var ic := TextureRect.new()
		ic.texture = ICONS[k]
		ic.custom_minimum_size = Vector2(26, 26)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.add_child(ic)
		var dv: float = r.delta.get(k, 0.0)
		var l := _label("%+.1f" % dv, &"H3")
		l.add_theme_color_override(&"font_color", STATUS_COLORS[0] if dv >= 0.0 else STATUS_COLORS[2])
		item.add_child(l)
		changes.add_child(item)
	body.add_child(changes)
	for k in KEYS:
		_add_text(body, "%s: %s" % [NAMES[k], _detail(k)], &"Caption")
	var news := {"arrival": "A new crew member arrived!", "supply": "A supply rocket brought 15 materials.",
		"emergency": "Earth sent emergency food, water and oxygen."}
	for ev in r.events:
		if ev is String and news.has(ev):
			_add_row(body, ICONS.rocket, news[ev])
		elif ev is Dictionary and ev.type == "goal":
			_add_row(body, CHECK, "Goal done: %s (+%d materials). %s" % [ev.goal.title, ev.goal.reward, ev.goal.lesson])
		elif ev is Dictionary and ev.type == "craft":
			_add_row(body, ICONS.rocket, "%s is ready in the hangar." % ColonySim.CRAFTS[ev.craft].name)
	var tip: Dictionary = r.advice
	_add_row(body, MASCOTS[tip.kind], "%s %s" % [tip.title, tip.text])
	_add_text(body, "Next problem: %s on day %d." % [sim.problem.title, sim.problem_day], &"Caption")
	_add_button("NEXT DAY", close_overlay, true)


const TUTORIAL := [
	["Welcome, Commander!", "I'm your robot helper. You run a colony on the Moon. Your job: keep the crew safe and help the colony grow.", "info"],
	["5 things to watch", "At the top: Health, Food, Water, Energy and Oxygen. A green ring means OK, yellow means careful, red means danger. Tap the bar to open it and see what makes each one go up or down.", "info"],
	["Everything is connected", "Good example: a Greenhouse makes food AND oxygen. But it also uses water, power and CO2. Bad example: build it without enough power, and it stops working. Every choice is a trade-off!", "warning"],
	["Build and upgrade", "Press BUILD. You choose where each building goes. Every building has 4 levels, and each level unlocks something new. Building is instant, but it costs materials.", "info"],
	["You decide when the day ends", "Make your choices, then press END DAY. I'll show you what changed and why. Nothing happens until you are ready.", "info"],
	["A problem every 5 days", "Dust storms, solar storms, leaks... You always know the next problem in advance (top of the screen). Prepare for it! There is no punishment, only a lesson.", "warning"],
	["Research and explore", "RESEARCH uses science points to make the colony better. EXPLORE opens the hangar: build spacecraft and visit Moon craters, Mars and more.", "info"],
	["Need help?", "Press TAKE HINT any time and I'll tell you the best next step. Drag to move, right-drag to turn, scroll to zoom. Let's start with a Greenhouse!", "success"],
]


func show_tutorial(page := 0) -> void:
	var t: Array = TUTORIAL[page]
	var body := _open_overlay("%s  (%d/%d)" % [t[0], page + 1, TUTORIAL.size()])
	_add_row(body, MASCOTS[StringName(t[2])], t[1])
	if page > 0:
		_add_button("BACK", show_tutorial.bind(page - 1))
	_add_button("SKIP", close_overlay)
	if page < TUTORIAL.size() - 1:
		_add_button("NEXT", show_tutorial.bind(page + 1), true)
	else:
		_add_button("LET'S GO!", func() -> void:
			close_overlay()
			show_hint(), true)


## --- Overlay helpers -------------------------------------------------------------------------

func _open_overlay(title: String) -> VBoxContainer:
	%OverlayTitle.text = title
	for box: Control in [%OverlayBody, %OverlayButtons]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	%Overlay.show()
	return %OverlayBody


func close_overlay() -> void:
	%Overlay.hide()


func is_busy() -> bool:
	return %Overlay.visible or %BuildPopup.visible or %PlaceBanner.visible


func _add_text(box: Control, text: String, variation: StringName) -> Label:
	var l := _label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	box.add_child(l)
	return l


func _add_row(box: Control, icon_tex: Texture2D, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var l := _label(text, &"Label", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	row.add_child(l)
	box.add_child(row)


func _add_list(box: Control, heading: String, items: Array, icon_tex: Texture2D) -> void:
	box.add_child(_label(heading, &"H3"))
	for item in items:
		_add_row(box, icon_tex, item)


func _add_button(text: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 52)
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(action)
	%OverlayButtons.add_child(b)
	return b


func _label(text: String, variation: StringName, size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	return l


## --- Platform ---------------------------------------------------------------------------------

func _apply_responsive_layout() -> void:
	_apply_responsive_layout_for_width(get_viewport_rect().size.x)


func _apply_responsive_layout_for_width(viewport_width: float) -> void:
	var compact := uses_compact_layout(viewport_width)
	var narrow := viewport_width <= 360.0
	if compact == _compact_layout and narrow == _narrow_layout and _layout_initialized:
		return
	_compact_layout = compact
	_narrow_layout = narrow
	_layout_initialized = true
	var top_center: Control = $TopCenter
	var top_right: Control = $TopRight
	var goal_panel: Control = $GoalPanel
	var mascot_area: Control = $MascotArea
	var bottom_bar: Control = $BottomBar
	var popup_dock: Control = $PopupDock
	top_center.anchor_left = 0.0 if compact else 0.5
	top_center.anchor_right = 1.0 if compact else 0.5
	top_center.offset_left = 16.0 if compact else -260.0
	top_center.offset_right = -16.0 if compact else 260.0
	(%ResourceIcons as BoxContainer).add_theme_constant_override(&"separation", 0 if narrow else 10)
	for key in _icons:
		_icons[key].button.custom_minimum_size = Vector2(COMPACT_RING_SIZE if narrow else RING_SIZE, COMPACT_RING_SIZE if narrow else RING_SIZE)
	top_right.visible = true
	%CrewLabel.visible = not compact
	%MaterialsLabel.visible = not compact
	%ScienceLabel.visible = not compact
	goal_panel.offset_left = 16.0 if compact else 24.0
	goal_panel.offset_top = 96.0 if compact else 12.0
	goal_panel.offset_right = 272.0 if compact else 304.0
	goal_panel.offset_bottom = 246.0 if compact else 240.0
	mascot_area.visible = not compact
	bottom_bar.anchor_left = 0.0 if compact else 0.5
	bottom_bar.anchor_right = 1.0 if compact else 0.5
	bottom_bar.offset_left = 16.0 if compact else -330.0
	bottom_bar.offset_right = -16.0 if compact else 330.0
	bottom_bar.offset_top = -150.0 if compact else -78.0
	bottom_bar.offset_bottom = -16.0 if compact else -20.0
	popup_dock.anchor_left = 0.5 if compact else 1.0
	popup_dock.anchor_right = 0.5 if compact else 1.0
	popup_dock.offset_left = -180.0 if compact else -364.0
	popup_dock.offset_right = 180.0 if compact else -24.0
	popup_dock.offset_top = -180.0 if compact else -220.0
	popup_dock.offset_bottom = 180.0 if compact else 220.0


## Keeps the HUD clear of rounded corners and the home indicator on iPad/iPhone.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or safe.size.x <= 0.0:
		return
	var to_ui := get_viewport_rect().size / screen
	position = safe.position * to_ui
	size = safe.size * to_ui


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if %Overlay.visible:
		close_overlay()
	elif %BuildPopup.visible:
		_close_build_popup()
	elif %PlaceBanner.visible:
		cancel_placement()
	elif expanded:
		_set_expanded(false)
	else:
		return
	get_viewport().set_input_as_handled()


func _play_splash() -> void:
	var splash: Control = %Splash
	splash.show()
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(splash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(splash.hide)
