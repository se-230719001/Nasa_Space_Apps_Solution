extends SceneTree
## Integration test through the real main scene + HUD: start of a sitting
## (session length, briefing, robot tutorial), one mission a day revealed one
## by one, auto next day, Wait, Next step + retry, save/continue, upgrades,
## the session break and the win card.
## Run: <godot> --headless --path . --script res://tools/tests/test_hud_flow.gd
## Uses its own save file, so the player's progress is never touched.

const TEST_SAVE := "user://test_flow_save.txt"

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


## Waits out a (re)load + splash, then grabs the new scene and HUD.
func settle() -> void:
	await create_timer(2.4).timeout
	scene = current_scene
	hud = scene.find_child("OutpostHUD", true, false)


func modal() -> Control:
	for c in get_nodes_in_group(&"hud_modal"):
		if not c.is_queued_for_deletion():
			return c
	return null


## Title, body and button texts of the open card.
func modal_text() -> String:
	var t := ""
	var m := modal()
	if m:
		for l in m.find_children("*", "Label", true, false):
			t += l.text + "|"
		for b in m.find_children("*", "Button", true, false):
			t += b.text + "|"
	return t


func press_choice(i: int) -> void:
	modal().find_child("Choice%d" % i, true, false).pressed.emit()
	await frames()


func bubble_title() -> String:
	return hud.get_node("%Helper").get_node("%BubbleTitle").text


func today(n: String) -> String:
	return hud.get_node("%TodayCard").get_child(0).get_node(n).text


func checklist_text() -> String:
	var t := ""
	for l in hud.get_node("%Tasks").find_children("*", "Label", true, false):
		t += l.text + "|"
	return t


func build_via_card(id: StringName) -> void:
	hud._open_menu(&"build")
	hud._select(id)
	hud._confirm()
	if current_scene.is_placing():  # new buildings: pick parcels (base grid)
		current_scene.confirm_placement()
	await frames()


## Waits out the automatic night, then closes the debrief card it brings.
func next_night() -> void:
	await create_timer(colony.AUTO_NEXT_DELAY + 0.8).timeout  # night + the list's fold animation
	while modal() != null and "Mission debrief" in modal_text():
		await press_choice(0)


func _initialize() -> void:
	colony = root.get_node("Colony")
	colony.save_path = TEST_SAVE
	colony.show_rewards = false  # reward cards are checked in test_rewards.gd
	colony.show_stories = false  # story cards are checked in test_stories.gd
	colony.delete_save()
	change_scene_to_file("res://scenes/main.tscn")
	await settle()

	# --- Start: pick a training campaign ---
	check("first launch asks for a training campaign", "Pick your training" in modal_text())
	check("three campaigns with days and real years", "Apollo Explorer\n3 days, 1971-1972" in modal_text()
		and "Moon Base Builder\n5 days, 1972-2022" in modal_text() and "Full Mission\n8 days, 1971-2022" in modal_text())
	check("no session-length picker any more", not "How long" in modal_text())
	await press_choice(2)  # Full Mission
	check("campaign stored in the run", colony.state.campaign == &"full")
	check("then: name your base (3 names + type your own)", "Name your base" in modal_text() and "Crater Camp" in modal_text()
		and modal().find_child("OwnName", true, false) != null)
	var own: LineEdit = modal().find_child("OwnName", true, false)
	own.text = "  Luna Labs  "
	modal().find_child("UseOwnName", true, false).pressed.emit()
	await frames()
	check("own name used (trimmed)", colony.state.base_name == "Luna Labs" and "Pick your flag" in modal_text())
	check("flag colours are named, not colour-only", "Red" in modal_text() and "Yellow" in modal_text())
	await press_choice(2)  # Green
	check("flag stored and painted", colony.state.flag == &"green"
		and scene._flag_cloth.material_override.albedo_color == colony.FLAGS[&"green"])
	check("briefing names the main mission and campaign", "South Pole Science Base" in modal_text() and "Full Mission: one mission a day, step 1 of 8" in modal_text())
	await press_choice(0)

	# --- Tutorial ---
	var tut: Control = hud.get_node_or_null("Tutorial")
	check("tutorial follows the briefing", tut != null and "Robo" in bubble_title())
	var next: Button = tut.get_node("TutorialNext")
	check("tutorial skips the hidden supplies/Wait steps", hud._tutorial_steps().size() == hud.TUTORIAL.size() - 2)
	for i in hud._tutorial_steps().size():
		next.pressed.emit()
		await frames()
	check("tutorial done, robot gives day 1 mission", colony.tutorial_done and bubble_title() == "Day 1 mission")

	# --- Goal / today / next step ---
	check("card shows main goal progress", today("TodayGoal") == "Goal: Full Mission 0/8")
	check("card shows the base's name", today("TodayBase") == "Luna Labs")
	check("card shows today's one mission", today("TodayTitle") == "☆ Today: Build a Greenhouse")
	check("card shows the next step", today("TodayNext") == "Next: tap Build, pick Greenhouse")
	var rows := checklist_text()
	check("only day 1 + a locked day 2 in the list", "Day 1: Build a Greenhouse" in rows and "Day 2: ???" in rows and not "Ice Drill" in rows)

	# --- No resource game on screen (Stage 6) ---
	check("no resource bars on top", not hud.get_node("%Power").is_visible_in_tree() and not hud.get_node("%Health").is_visible_in_tree())
	check("no Wait button, no Why? button", not hud.get_node("%NextDayButton").visible \
		and not hud.get_node("%TodayCard").find_child("WhyButton", true, false).visible)
	check("old resource game is off in this run", not OutpostSimulation.uses_resources(colony.state))

	# --- Built buildings that aren't today's mission can't be "upgraded" for nothing ---
	hud._open_menu(&"build")
	hud._select(&"solar")
	check("non-mission upgrade shows Built, disabled, and how to move it", hud.get_node("%ConfirmButton").disabled
		and hud.get_node("%ConfirmButton").text == "Built" and hud.get_node("%Options").get_node("solar").text == "Solar ✓")
	hud._close_menu()

	# --- Level system (code path; the 3D model reacts to levels) ---
	var solar: Node = scene._spawned[&"solar"]
	var panels_before: int = solar.find_children("*", "MeshInstance3D", true, false).size()
	await build_via_card(&"solar")
	check("solar L2 in sim and 3D", colony.state.levels.solar == 2 and solar.level == 2 \
		and solar.find_children("*", "MeshInstance3D", true, false).size() > panels_before)
	check("still day 1", colony.state.day == 1)

	# --- Mission done -> next day by itself ---
	var kits: float = colony.state.kits
	await build_via_card(&"greenhouse")
	check("building costs no kits now", colony.state.modules.has(&"greenhouse") and colony.state.kits >= kits)
	check("robot cheers the day", bubble_title() == "Day 1 complete!")
	await next_night()
	check("day 2 started by itself", colony.state.day == 2)
	check("goal moved to 1/8, day 2 shown, day 3 locked",
		today("TodayGoal") == "Goal: Full Mission 1/8" and "Ice Drill" in today("TodayTitle") and "Day 3: ???" in checklist_text())

	# --- Save + continue in a new app run (memory wiped, file kept) ---
	check("progress is saved", FileAccess.file_exists(TEST_SAVE))
	colony.session_chosen = false
	colony.save_offered = false
	colony.state = colony._fresh_state()
	reload_current_scene()
	await settle()
	check("new launch offers to continue", "Welcome back!" in modal_text())
	await press_choice(0)  # Continue -> reload
	await settle()
	check("continue restores day 2 and the greenhouse", colony.state.day == 2 and colony.state.modules.has(&"greenhouse")
		and scene.get_node("World").find_children("*", "Greenhouse", false, false).size() == 1)
	check("restored solar keeps level 2 in 3D", scene._spawned[&"solar"].level == 2)
	check("continue keeps the campaign and skips the picker", colony.state.campaign == &"full" and modal() == null)

	# --- Nothing can block a mission: extras are free, no retry needed ---
	await build_via_card(&"habitat")
	colony.state.kits = 0.0  # even with no kits left (they're not used any more)
	colony.changed.emit()
	check("extras don't block today's mission", today("TodayNext") == "Next: tap Build, pick Ice Drill" \
		and not hud.get_node("%TodayCard").find_child("RetryButton", true, false).visible)

	# --- The rest of the mission (no break cards any more) ---
	await build_via_card(&"ice_drill")
	await next_night()
	check("day 3 reached", colony.state.day == 3)
	colony.research(&"rover_blueprint")
	await next_night()
	check("day 4 (upgrade Solar) was done early", colony.state.day == 4 and colony.state.tasks_done.has(&"solar_upgrade"))
	await next_night()
	check("then day 4 moves on by itself, no break card", colony.state.day == 5 and modal() == null)
	colony.build(&"rover")
	await next_night()
	colony.explore()
	await next_night()
	colony.research(&"radiation_map")
	await next_night()
	colony.build(&"shield")
	await next_night()
	await frames(3)
	check("8 days done -> mission over, save cleared", colony.finished and not FileAccess.file_exists(TEST_SAVE))
	check("win card names the campaign and the NASA problems solved, no health stars", "Mission Complete!" in modal_text() \
		and "Luna Labs: Full Mission training done! You solved 8 real problems NASA faced." in modal_text() and not "★" in modal_text())

	# --- Play Again: pick a (shorter) campaign; its days only ---
	await press_choice(0)
	await settle()
	check("play again asks for a campaign", "Pick your training" in modal_text())
	await press_choice(0)  # Apollo Explorer
	await press_choice(0)  # base name: Crater Camp
	await press_choice(0)  # flag: red
	await press_choice(0)  # briefing
	check("Apollo day 1 is the rover plan, goal 0/3", colony.state.campaign == &"apollo"
		and today("TodayTitle") == "☆ Today: Research: Rover Plan" and today("TodayGoal") == "Goal: Apollo Explorer 0/3")
	colony.research(&"rover_blueprint")
	await next_night()
	colony.build(&"rover")
	await next_night()
	colony.explore()
	await next_night()
	await frames(3)
	check("3-day campaign ends after day 3", colony.finished and "Apollo Explorer training done" in modal_text())

	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
