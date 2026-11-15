extends SceneTree
## HUD UI checks: status words on the pills (exact numbers on tap), the real
## data Info panel, build option sounds via Events, and the Mission Days list
## scrolling instead of sliding behind the action buttons.
## Run: <godot> --headless --path . --script res://tools/tests/test_hud_ui.gd

var _fails := 0
var _count := 0
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


func modal_text() -> String:
	var t := ""
	for m in get_nodes_in_group(&"hud_modal"):
		if not m.is_queued_for_deletion():
			for n in m.find_children("*", "", true, false):
				if n is Label or n is Button or n is LinkButton:
					t += n.text + "|"
	return t


func close_modal() -> void:
	for m in get_nodes_in_group(&"hud_modal"):
		if not m.is_queued_for_deletion():
			m.find_child("Choice0", true, false).pressed.emit()
	await frames()


func _initialize() -> void:
	colony = root.get_node("Colony")
	colony.save_path = "user://test_ui_save.txt"
	colony.show_rewards = false  # reward cards are checked in test_rewards.gd
	colony.show_stories = false  # story cards are checked in test_stories.gd
	colony.delete_save()
	colony.session_chosen = true
	colony.tutorial_done = true
	colony.state.resources = true  # tests the old resource game, kept dormant since Stage 6
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.4).timeout
	hud = current_scene.find_child("OutpostHUD", true, false)

	# --- Pills: words, not numbers ---
	var words := true
	for bar in hud._bars.values():
		words = words and not "%" in bar.display_text and bar.display_text in ["Good", "Low", "Critical!"]
	check("pills show a status word, no percent", words)
	colony.rest()
	await frames()
	check("a trend arrow appears after a night", "↓" in hud._bars[&"food"].display_text)
	check("status icon + word, not colour alone, when low", true if hud._status_for(30.0) == ResourceBar.Status.WARNING and hud._pill_text(ResourceBar.Status.WARNING, 0) == "Low" else false)
	hud._bars[&"water"].pressed.emit()
	await frames()
	check("tap a pill: exact numbers", "Supplies" in modal_text() and ("Water: %d of 100" % roundi(colony.state.stores.water)) in modal_text() and "Build kits:" in modal_text())
	await close_modal()

	# --- Info panel ---
	hud.get_node("%InfoButton").pressed.emit()
	await frames()
	var info := modal_text()
	check("Info says which data is real and which is made up", "some real NASA data, and some practice numbers" in info and "Real fact:" in info)
	check("Info names both NASA sources with links", "https://svs.gsfc.nasa.gov/4930" in info and "https://pgda.gsfc.nasa.gov/products/69" in info)
	check("Info separates game-made numbers", "Made up for the game" in info)
	var scroll: ScrollContainer = null
	for m in get_nodes_in_group(&"hud_modal"):
		scroll = m.find_child("InfoScroll", true, false)
	check("Info text scrolls and fits the 576px screen", scroll != null and scroll.custom_minimum_size.y <= 326.0)
	await close_modal()
	check("Info closes", modal_text() == "")

	# --- Build option sounds go through Events ---
	var heard := []
	root.get_node("Events").button_pressed.connect(func(id): heard.append(id))
	hud._open_menu(&"build")
	hud.get_node("%Options").get_node("ice_drill").pressed.emit()
	check("build option tap emits Events.button_pressed", heard.has(&"ice_drill"))
	hud._select(&"greenhouse")
	var switch: Button = hud.get_node("%Rows").get_node_or_null("PowerSwitch")
	check("card has no old resource guess row", hud.get_node("%Rows").get_node_or_null("Guess") == null)
	hud._close_menu()

	# --- Mission Days list never goes behind the buttons ---
	colony.state.day = 8
	for d in range(1, 8):
		colony.state.tasks_done[OutpostSimulation.tasks_for(d)[0].id] = true
	hud._build_checklist()
	hud.toggle_checklist()
	await create_timer(0.6).timeout
	var panel_bottom: float = hud.get_node("%ChecklistPanel").get_global_rect().end.y
	var buttons_top: float = hud.get_node("%SearchButton").get_global_rect().position.y
	check("7 done days folded into one line, today's row big", hud.get_node("%Tasks").get_node("PastSummary").text.begins_with("✓ Days 1-7 done") \
		and not hud.get_node("%Tasks").get_node("PastDays").visible and hud._task_rows.has(&"shield"))
	check("list ends above Search/Explore", panel_bottom <= buttons_top)
	var task_scroll: ScrollContainer = hud.get_node("%TaskScroll")
	# Headless runs in a tall window; the 576px case is checked by screenshot.
	var content: float = hud.get_node("%Tasks").size.y
	check("list fits, or scrolls when taller than the room",
		task_scroll.size.y >= content - 1.0 or task_scroll.get_v_scroll_bar().max_value > task_scroll.size.y)
	var today_row: Control = hud._task_rows[&"shield"]
	check("today's row is in view", today_row.get_global_rect().end.y <= task_scroll.get_global_rect().end.y + 1.0)

	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
