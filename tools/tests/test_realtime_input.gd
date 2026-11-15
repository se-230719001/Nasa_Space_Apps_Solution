extends SceneTree
## Real-time play with real input: mouse clicks at the buttons' places on
## screen and the Esc key, pushed through the viewport like a player would.
## Run it in a window to watch it play:
##   <godot> --path . --resolution 1024x576 --windowed --script res://tools/tests/test_realtime_input.gd
## (headless works too). Checks the ways back: ✕, tap outside, Esc.

var _fails := 0
var _count := 0
var colony: Node


func check(name: String, ok: bool) -> void:
	_count += 1
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name)


func wait(s := 0.35) -> void:
	await create_timer(s).timeout


func hud() -> Control:
	return current_scene.find_child("OutpostHUD", true, false)


func top_card() -> Control:
	var open := get_nodes_in_group(&"hud_modal").filter(func(m): return not m.is_queued_for_deletion())
	return open.back() if not open.is_empty() else null


func card_text() -> String:
	var t := ""
	if top_card():
		for n in top_card().find_children("*", "", true, false):
			if (n is Label or n is Button) and n.is_visible_in_tree():
				t += n.text + "|"
	return t


## A real left click (press + release) at a screen point.
func click_at(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		root.push_input(e, true)
		await process_frame
	await wait()


func click(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		print("  !! can't click: ", c)
		_fails += 1
		return
	await click_at(c.get_global_rect().get_center())


func click_in_card(name: String) -> void:
	await click(top_card().find_child(name, true, false) if top_card() else null)


func press_esc() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = pressed
		root.push_input(e, true)
		await process_frame
	await wait()


func _initialize() -> void:
	colony = root.get_node("Colony")
	colony.save_path = "user://test_realtime_save.txt"
	colony.delete_save()
	change_scene_to_file("res://scenes/main.tscn")
	await wait(2.6)
	var shots := OS.get_environment("SHOT")

	# --- Title -> campaign -> name -> flag -> briefing, all by clicks ---
	await click(hud().get_node("TitleScreen").find_child("NewButton", true, false))
	check("click New mission -> campaign picker", "Pick your training" in card_text())
	await click_at(Vector2(4, 300))  # tap outside a must-answer card
	check("must-answer cards don't close on an outside tap", "Pick your training" in card_text())
	await press_esc()
	check("... nor on Esc", "Pick your training" in card_text())
	await click_in_card("Choice0")  # Apollo Explorer
	await click_in_card("Choice0")  # Crater Camp
	await click_in_card("Choice0")  # red flag
	check("briefing card after name + flag", colony.state.campaign == &"apollo" and colony.state.base_name == "Crater Camp")
	await click_in_card("Choice0")  # Let's go
	for i in hud()._tutorial_steps().size():
		await click(hud().get_node("Tutorial/TutorialNext"))
	check("tutorial clicked through", colony.tutorial_done)

	# --- Mission Briefing: tap outside closes, Briefing reopens ---
	await wait(0.6)
	check("Mission Briefing is up", "Mission Briefing" in card_text())
	if shots != "":
		root.get_texture().get_image().save_png(shots + "_briefing.png")
	await click_at(Vector2(6, 560))
	check("tap outside closes an info card", top_card() == null)
	await click(hud().get_node("%TodayCard").find_child("StoryButton", true, false))
	check("Briefing button reopens it", "Mission Briefing" in card_text())
	var task: Dictionary = colony.today_tasks()[0]
	var right := 0
	for i in task.quiz.options.size():
		if task.quiz.options[i].correct:
			right = i
	await click_in_card("Option%d" % right)
	check("clicked the right idea: +1 star", "+1 star" in card_text() and Rewards.stars_for(colony.state, task.id) == 1)
	await click_in_card("CloseX")
	check("✕ closes it", top_card() == null)

	# --- Research card: Esc closes, outside tap closes, then do the mission ---
	await click(hud().get_node("%SearchButton"))
	check("Research card opens", hud().get_node("%BuildPopup").visible)
	await press_esc()
	check("Esc closes the Research card", not hud().get_node("%BuildPopup").visible)
	await click(hud().get_node("%SearchButton"))
	await click_at(Vector2(6, 300))
	check("tap outside closes the Research card", not hud().get_node("%BuildPopup").visible)
	await click(hud().get_node("%SearchButton"))
	await click(hud().get_node("%Options").get_node("rover_blueprint"))
	await click(hud().get_node("%ConfirmButton"))
	check("research done by clicks", colony.state.research_done.has(&"rover_blueprint"))
	await wait(colony.AUTO_NEXT_DELAY + 0.6)
	check("debrief after the night", "What did we learn today?" in card_text())
	await press_esc()
	check("Esc closes the debrief", top_card() == null or not "What did we learn" in card_text())
	for i in 3:  # rewards / next briefing come one after another, a moment apart
		await wait(1.0)
		while top_card() != null:
			await press_esc()

	# --- Info, Settings, Mission Days: every way back works ---
	await click(hud().get_node("%InfoButton"))
	check("Info opens", "Real Moon data" in card_text())
	if shots != "":
		root.get_texture().get_image().save_png(shots + "_info.png")
	await click_in_card("CloseX")
	check("Info closes with ✕", top_card() == null)
	await click(hud().get_node("%SettingsButton"))
	check("Settings opens", "Settings" in card_text())
	await press_esc()
	check("Settings closes with Esc", top_card() == null)
	await click(hud().get_node("%ChecklistTab"))
	await wait(0.4)
	check("Mission Days opens", hud()._checklist_open)
	await click_at(Vector2(500, 330))  # the base, outside the panel
	check("tap outside closes Mission Days", not hud()._checklist_open)
	await click(hud().get_node("%ChecklistTab"))
	await wait(0.4)
	await press_esc()
	check("Esc closes Mission Days too", not hud()._checklist_open)

	# --- Placement: Esc cancels, then build by clicking Build here ---
	await click(hud().get_node("%BuildButton"))
	await click(hud().get_node("%Options").get_node("rover"))
	await click(hud().get_node("%ConfirmButton"))
	check("placement mode by clicks", current_scene.is_placing())
	if shots != "":
		root.get_texture().get_image().save_png(shots + "_placing.png")
	await press_esc()
	check("Esc cancels placement, nothing built", not current_scene.is_placing() and not colony.state.modules.has(&"rover"))
	await click(hud().get_node("%BuildButton"))
	await click(hud().get_node("%Options").get_node("rover"))
	await click(hud().get_node("%ConfirmButton"))
	await click(hud().get_node("%PlacementBar").find_child("PlaceButton", true, false))
	check("Build here by click builds the rover", colony.state.modules.has(&"rover"))

	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
