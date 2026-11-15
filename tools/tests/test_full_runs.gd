extends SceneTree
## End-to-end: all three campaigns played through the real screens, with
## stories, quizzes, grid placement, debrief "why" questions and reward cards
## on. Day after day: Mission Briefing -> answer -> do the mission (placing new
## buildings) -> night -> debrief -> rewards, until the end card. The Moon
## Base Builder run is saved and continued in the middle.
## Run: <godot> --headless --path . --script res://tools/tests/test_full_runs.gd

var _fails := 0
var _count := 0
var colony: Node


func check(name: String, ok: bool) -> void:
	_count += 1
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name)


func frames(n := 2) -> void:
	for i in n:
		await process_frame


func hud() -> Control:
	return current_scene.find_child("OutpostHUD", true, false) if current_scene else null


func card() -> Control:
	for m in get_nodes_in_group(&"hud_modal"):
		if not m.is_queued_for_deletion():
			return m
	return null


func card_text() -> String:
	var t := ""
	if card():
		for n in card().find_children("*", "", true, false):
			if (n is Label or n is Button) and n.is_visible_in_tree():
				t += n.text + "|"
	return t


func press(name: String) -> void:
	var b: Node = card().find_child(name, true, false) if card() else null
	if b == null:
		print("  !! no '%s' on card: %s" % [name, card_text().left(160)])
		_fails += 1
		return
	b.pressed.emit()
	await frames(3)


## Waits up to `seconds` for a card whose text contains `text`.
func wait_card(text: String, seconds := 8.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if text in card_text():
			return true
		await create_timer(0.1).timeout
	return false


static func right_option(options: Array) -> int:
	for i in options.size():
		if options[i].correct:
			return i
	return -1


func _initialize() -> void:
	colony = root.get_node("Colony")
	colony.save_path = "user://test_full_save.txt"
	colony.delete_save()
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.4).timeout
	hud().get_node("TitleScreen").find_child("NewButton", true, false).pressed.emit()
	await frames(3)
	var index := 0
	for id in OutpostSimulation.CAMPAIGNS:
		await play(id, index, index == 0)
		index += 1
	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)


func play(id: StringName, index: int, first: bool) -> void:
	var c: Dictionary = OutpostSimulation.CAMPAIGNS[id]
	check("%s: picker shown" % c.name, await wait_card("Pick your training"))
	await press("Choice%d" % index)
	await press("Choice1")  # name: Moonbeam Base
	await press("Choice0")  # flag: red
	await press("Choice0")  # briefing: Let's go
	if first:
		var tut: Control = hud().get_node("Tutorial")
		for i in hud()._tutorial_steps().size():
			tut.get_node("TutorialNext").pressed.emit()
			await frames()
	var ok := true
	for day in range(1, c.days.size() + 1):
		var task: Dictionary = OutpostSimulation.tasks_for(day, id)[0]
		# Before: the Mission Briefing asks first.
		ok = ok and await wait_card("Mission Briefing")  # also after Continue, if not answered yet
		await press("Option%d" % right_option(task.quiz.options))
		ok = ok and "✓ Yes! That is what NASA did." in card_text()
		await press("Choice0")  # My turn!
		# Try: do the mission in the base.
		var how: Array = OutpostSimulation.TASK_ACTIONS[task.id]
		hud()._open_menu(how[0])
		hud()._select(how[1])
		ok = ok and not hud().get_node("%ConfirmButton").disabled
		hud()._confirm()
		if current_scene.is_placing():
			current_scene.confirm_placement()
		# After: debrief (answer "why"), then the rewards card, in that order.
		var seen := await after_mission(task)
		ok = ok and seen.begins_with("debrief")
		if day == 2 and id == &"base":
			await save_and_continue()
	check("%s: %d days, each briefing -> guess -> do -> debrief" % [c.name, c.days.size()], ok)
	check("%s: all science stars earned (3 a day)" % c.name, Rewards.total_stars(colony.state) == 3 * c.days.size())
	check("%s: end card with name, stars and badges" % c.name, await wait_card("Mission Complete!")
		and ("Moonbeam Base: %s training done!" % c.name) in card_text() and ("Science stars: %d." % (3 * c.days.size())) in card_text())
	await press("Choice0")  # Play Again
	await create_timer(2.4).timeout


## Handles the cards after a mission until the next day's briefing / the end
## card. Returns the order seen, e.g. "debrief,rewards,".
func after_mission(task: Dictionary) -> String:
	var seen := ""
	for i in 60:
		await create_timer(0.15).timeout
		var t := card_text()
		if "What did we learn today?" in t and card().find_child("WhyOption0", true, false).disabled == false:
			await press("WhyOption%d" % right_option(task.why.options))
			await press("Choice0")
			seen += "debrief,"
		elif "Today's rewards!" in t:
			await press("Choice0")
			seen += "rewards,"
		elif "Mission Briefing" in t or "Mission Complete!" in t:
			break
		elif t == "" and seen != "" and i > 40:
			break
	return seen


## A new app run in the middle of the campaign: Continue brings it all back.
func save_and_continue() -> void:
	var before: Dictionary = colony.state.duplicate(true)
	colony.session_chosen = false
	colony.save_offered = false
	colony.state = colony._fresh_state()
	reload_current_scene()
	await create_timer(2.4).timeout
	var title: Control = hud().get_node_or_null("TitleScreen")
	check("mid-run: title screen offers Continue", title != null and title.find_child("ContinueButton", true, false) != null)
	title.find_child("ContinueButton", true, false).pressed.emit()
	await create_timer(2.4).timeout
	check("mid-run: day, parcels, stars and badges restored", colony.state.day == before.day
		and colony.state.placements == before.placements and colony.state.stars == before.stars
		and colony.state.badges == before.badges and colony.state.base_name == before.base_name)
