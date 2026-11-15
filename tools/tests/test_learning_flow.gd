extends SceneTree
## Learning loop through the real scene: try (build card), debrief after the
## night (what happened, why from the sim's flows, like/unlike NASA), hint
## ladder, power switch, "Why?" card, and rescue instead of game over.
## Run: <godot> --headless --path . --script res://tools/tests/test_learning_flow.gd

const TEST_SAVE := "user://test_learning_save.txt"

var _fails := 0
var _count := 0
var scene: Node
var hud: Control
var colony: Node


func check(name: String, ok: bool) -> void:
	_count += 1
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name)


func frames(n := 2) -> void:
	for i in n:
		await process_frame


func settle() -> void:
	await create_timer(2.4).timeout
	scene = current_scene
	hud = scene.find_child("OutpostHUD", true, false)


func modal() -> Control:
	for c in get_nodes_in_group(&"hud_modal"):
		if not c.is_queued_for_deletion():
			return c
	return null


func modal_text() -> String:
	var t := ""
	var m := modal()
	if m:
		for l in m.find_children("*", "Label", true, false):
			t += l.text + "|"
	return t


func close_modal() -> void:
	modal().find_child("Choice0", true, false).pressed.emit()
	await frames()


func bubble() -> String:
	return hud.get_node("%Helper").get_node("%BubbleTitle").text + "|" + hud.get_node("%Helper").get_node("%BubbleText").text


func rows() -> Control:
	return hud.get_node("%Rows")


func _initialize() -> void:
	colony = root.get_node("Colony")
	colony.save_path = TEST_SAVE
	colony.show_rewards = false  # reward cards are checked in test_rewards.gd
	colony.show_stories = false  # story cards are checked in test_stories.gd
	colony.delete_save()
	colony.session_chosen = true  # skip the start cards and tutorial (tested elsewhere)
	colony.tutorial_done = true
	colony.state.resources = true  # tests the old resource game, kept dormant since Stage 6
	change_scene_to_file("res://scenes/main.tscn")
	await settle()

	# --- Brief names the idea and the current value ---
	check("morning brief: mission + science idea + food now", "Plants need light, water and power" in bubble() and "Food now: 45" in bubble())

	# --- Try: the build card no longer asks about resource bars ---
	hud._open_menu(&"build")
	hud._select(&"greenhouse")
	check("no old up/down resource guess on the build card", rows().get_node_or_null("Guess") == null)
	check("Tomorrow line always shown", rows().get_child(rows().get_child_count() - 1).visible)
	var before_food: float = colony.state.stores.food
	hud._confirm()
	if current_scene.is_placing():  # new buildings: pick parcels (base grid)
		current_scene.confirm_placement()
	await create_timer(colony.AUTO_NEXT_DELAY + 0.4).timeout

	# --- After: debrief = what happened, why, like / unlike NASA ---
	var report: Dictionary = colony.state.history[-1]
	var food_in := roundi(report.flows[&"food"]["in"]["greenhouse"])
	var t := modal_text()
	check("debrief after the night", "Mission debrief" in t)
	check("debrief: what happened in your base (sim result)", "In your base: food changed by" in t)
	check("debrief why uses the sim's numbers", ("Greenhouse +%d" % food_in) in t and "Crew −2" in t)
	check("debrief compares with NASA: same and different", "Like NASA: Plants need light, water and care" in t \
		and "Different: Veggie was on the Space Station" in t)
	await close_modal()

	# --- Why? card ---
	var why: Button = hud.get_node("%TodayCard").find_child("WhyButton", true, false)
	check("Why? button appears after a night", why.visible)
	why.pressed.emit()
	await frames()
	check("Why? card lists every store and today's idea", "Water:" in modal_text() and "Crew health:" in modal_text() and "Today's idea: Ice is frozen water" in modal_text())
	await close_modal()

	# --- Power switch on a built machine ---
	hud._open_menu(&"build")
	hud._select(&"greenhouse")
	var switch: Button = rows().get_node_or_null("PowerSwitch")
	check("built machine card has a power switch", switch != null and switch.text.begins_with("Power: ON"))
	switch.pressed.emit()
	await frames()
	check("switch turns the greenhouse off, card refreshes", colony.state.off.has(&"greenhouse") and rows().get_node("PowerSwitch").text.begins_with("Power: OFF"))
	check("switching doesn't pass the day", colony.state.day == 2)
	rows().get_node("PowerSwitch").pressed.emit()
	await frames()
	hud._close_menu()

	# --- Hint ladder: same problem twice -> clearer hint ---
	colony.state.stores.food = 0.0
	colony.state.off[&"greenhouse"] = true
	hud.get_node("%NextDayButton").pressed.emit()
	await frames()
	check("1st problem: small nudge", "The food is running low." in bubble())
	colony.state.stores.food = 0.0
	hud.get_node("%NextDayButton").pressed.emit()
	await frames()
	check("2nd problem: clear next step", "The Greenhouse needs light, water and power" in bubble())
	colony.state.off.erase(&"greenhouse")

	# --- Rescue instead of game over ---
	var day: int = colony.state.day
	colony.state.crew_health = 1.0
	colony.state.stores.water = 0.0
	colony.state.stores.food = 0.0
	hud.get_node("%NextDayButton").pressed.emit()
	await frames(3)
	check("no game over: rescue card", "Mission Control to the rescue!" in modal_text() and not colony.finished)
	check("rescue gives the clear tip for the cause", "Tip:" in modal_text())
	check("same day, crew back to at least 50", colony.state.day == day and colony.state.crew_health >= 50.0)
	await close_modal()
	await settle()
	check("world reloads, game goes on", hud != null and colony.state.day == day and modal() == null)

	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
