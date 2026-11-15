extends SceneTree
## Mission cards + Mission Days chart: every briefing shows its NASA photo
## with the manifest's own caption, the Info panel's sunlight fact matches the
## processed CSV, and finished days fold into one summary that can be opened
## and reread.
## Run: <godot> --headless --path . --script res://tools/tests/test_mission_cards.gd

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


func card() -> Control:
	for m in get_nodes_in_group(&"hud_modal"):
		if not m.is_queued_for_deletion():
			return m
	return null


func card_text() -> String:
	var t := ""
	var m := card()
	if m:
		for n in m.find_children("*", "", true, false):
			if (n is Label or n is Button or n is LinkButton) and n.is_visible_in_tree():
				t += n.text + "|"
	return t


func close_card() -> void:
	card().find_child("Choice0", true, false).pressed.emit()
	await frames(3)


func tasks() -> Control:
	return hud.get_node("%Tasks")


func _initialize() -> void:
	colony = root.get_node("Colony")
	colony.save_path = "user://test_cards_save.txt"
	colony.show_rewards = false  # reward cards are checked in test_rewards.gd
	colony.delete_save()
	colony.session_chosen = true
	colony.tutorial_done = true
	colony.show_stories = false
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.4).timeout
	hud = current_scene.find_child("OutpostHUD", true, false)

	# --- Every mission card: photo + caption straight from the manifest ---
	var all_ok := true
	for mission in OutpostSimulation.DAY_TASKS:
		var task: Dictionary = mission[0]
		hud._show_story(task, true)
		await frames()
		var row: Dictionary = NasaDb.rows().get("processed/images/%s.jpg" % task.id, {})
		var photo: TextureRect = card().find_child("MissionPhoto", true, false)
		var t := card_text()
		var ok: bool = not row.is_empty() and photo != null and photo.texture != null \
			and row.credit in t and row.asset_id in t and row.relevance in t
		if not ok:
			print("  card missing photo/caption: ", task.id)
		all_ok = all_ok and ok
		await close_card()
	check("all 8 briefings show their NASA photo with credit, NASA ID and why it fits", all_ok)
	hud._show_story(OutpostSimulation.DAY_TASKS[6][0], true)
	await frames()
	check("the example photo says it is not the 1972 storm", "NOT the August 1972 storm" in card_text())
	check("review mode: answer shown, no quiz, 'You did it'", "What NASA did" in card_text() and "You did it:" in card_text() \
		and card().find_child("Option0", true, false) == null)
	await close_card()

	# --- Info panel: the real sunlight fact equals the processed CSV ---
	hud.get_node("%InfoButton").pressed.emit()
	await frames()
	var b := NasaDb.sunlight_bands()
	var under := roundi(b["never (permanent shadow)"] + b["under 20% of the time"] + b["20-40%"])
	check("Info fact uses the real numbers (%d%% / %d%%)" % [under, roundi(b["never (permanent shadow)"])],
		("%d%% of the ground sees the Sun less than 40%%" % under) in card_text() \
		and ("%d%% never sees it" % roundi(b["never (permanent shadow)"])) in card_text())
	check("Info shows the sunlight map and says MoonMinds made it from NASA data", card().find_children("*", "TextureRect", true, false).size() >= 1 \
		and "Map made by MoonMinds from NASA's data" in card_text())
	check("Info marks the unused SVS movies honestly", "(not used yet)" in card_text())
	await close_card()

	# --- Mission Days chart: progress on top, finished days fold away ---
	check("day 1: progress 0 of 8, no summary yet", "Full Mission: 0 of 8 days done" in tasks().get_node("Progress").text \
		and tasks().get_node_or_null("PastSummary") == null and hud.get_node("%ChecklistTab").text == "0/8")
	colony.build(&"greenhouse")
	await create_timer(colony.AUTO_NEXT_DELAY + 0.9).timeout
	for m in get_nodes_in_group(&"hud_modal"):
		m.queue_free()  # the debrief; checked in test_learning_flow
	await frames()
	var summary: Button = tasks().get_node_or_null("PastSummary")
	check("finished day folded into one line", summary != null and summary.text.begins_with("✓ Day 1 done") \
		and not tasks().get_node("PastDays").visible)
	check("progress and tab moved to 1 of 8", "1 of 8 days done" in tasks().get_node("Progress").text \
		and tasks().get_node("ProgressBar").value == 1 and hud.get_node("%ChecklistTab").text == "1/8")
	check("today's mission row is big and the next day locked", tasks().get_node("Today") != null \
		and "Day 2: Build an Ice Drill" in tasks().get_node("Today").get_child(1).text)
	summary.pressed.emit()
	await frames()
	check("tap the summary: finished days open again", tasks().get_node("PastDays").visible \
		and tasks().get_node("PastDays").get_node("Past1").text == "✓ Day 1: Build a Greenhouse")
	check("tap targets are at least 44px", tasks().get_node("PastSummary").custom_minimum_size.y >= 44 \
		and tasks().get_node("PastDays").get_node("Past1").custom_minimum_size.y >= 44)
	tasks().get_node("PastDays").get_node("Past1").pressed.emit()
	await frames()
	check("tap a finished day: its briefing opens to reread", "Veggie zinnias" in card_text() and "You did it: Build a Greenhouse." in card_text())
	await close_card()
	tasks().get_node("PastSummary").pressed.emit()
	await frames()
	check("tap again: folded back", not tasks().get_node("PastDays").visible)

	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
