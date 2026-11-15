extends SceneTree
## Real NASA story cards: every mission day has one (original name, place/time,
## problem, what the real crew did, a NASA link), it shows once at the start of
## the day, waits for other cards, and the Today card can reopen it.
## Run: <godot> --headless --path . --script res://tools/tests/test_stories.gd

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


func open_cards() -> Array:
	var out := []
	for m in get_nodes_in_group(&"hud_modal"):
		if not m.is_queued_for_deletion():
			out.append(m)
	return out


## Text the player can see on open cards (hidden parts don't count).
func card_text() -> String:
	var t := ""
	for m in open_cards():
		for n in m.find_children("*", "", true, false):
			if (n is Label or n is Button or n is LinkButton) and n.is_visible_in_tree():
				t += n.text + "|"
	return t


func option(i: int) -> Button:
	return open_cards()[-1].find_child("Option%d" % i, true, false)


func close_card() -> void:
	open_cards()[-1].find_child("Choice0", true, false).pressed.emit()
	await frames(3)


func _initialize() -> void:
	# --- Data: one real, linked story per day ---
	var complete := true
	for day in OutpostSimulation.DAY_TASKS:
		var st: Dictionary = day[0].get("story", {})
		for key in ["name", "where", "problem", "did", "url"]:
			complete = complete and not String(st.get(key, "")).is_empty()
		complete = complete and String(st.get("url", "")).begins_with("https://") and ".nasa.gov/" in String(st.get("url", ""))
	check("all 8 days have a full story with a nasa.gov link", complete)
	var names := []
	for day in OutpostSimulation.DAY_TASKS:
		names.append(day[0].story.name)
	check("original names are used", "LCROSS" in names and "Apollo 15 Lunar Roving Vehicle" in names and "Veggie zinnias" in names)
	check("off-Moon stories say so", "Not on the Moon" in OutpostSimulation.DAY_TASKS[0][0].story.note)

	colony = root.get_node("Colony")
	colony.save_path = "user://test_story_save.txt"
	colony.show_rewards = false  # reward cards are checked in test_rewards.gd
	colony.delete_save()
	colony.session_chosen = true
	colony.tutorial_done = true
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.6).timeout
	hud = current_scene.find_child("OutpostHUD", true, false)

	# --- Day 1: before -> predict ---
	var heard := []
	root.get_node("Events").prediction_made.connect(func(ok): heard.append(ok))
	var t := card_text()
	check("day 1 opens with its real problem", "Mission Briefing" in t and "A real problem NASA faced" in t \
		and "Veggie zinnias" in t and "The problem:" in t)
	check("asks what you would do, with 3 ideas", "Mold is growing on the space flowers" in t and option(2) != null)
	check("NASA's fix and the go button stay hidden until you answer", not "What NASA did" in t and not "My turn!" in t)
	option(0).pressed.emit()  # "Give the plants lots more water"
	await frames()
	t = card_text()
	check("wrong idea: kind hint + try again, no lock", "Not quite. Mold loves wet places" in t and "Try again!" in t \
		and option(0).disabled and not option(1).disabled and not "What NASA did" in t)
	option(1).pressed.emit()  # the real fix
	await frames()
	t = card_text()
	check("right idea: NASA's real fix is shown", "✓ Yes! That is what NASA did." in t and "What NASA did: Astronaut Scott Kelly" in t)
	check("then your turn, link and made-up note", "Your turn: Build a Greenhouse." in t and "Read more at NASA" in t \
		and "This story is real" in t and "My turn!" in t)
	check("answer saved: solved in 2 tries; Events told twice", colony.state.guesses[&"greenhouse"].tries == 2 \
		and colony.state.guesses[&"greenhouse"].solved and heard == [false, true])
	await close_card()
	check("story closes with one tap", open_cards().is_empty())
	check("shown once per day (remembered)", colony.state.stories_seen.has(1))
	hud._announce_tasks()
	await frames()
	check("not shown again the same day", open_cards().is_empty())

	# --- Reopen from the Today card ---
	hud.get_node("%TodayCard").find_child("StoryButton", true, false).pressed.emit()
	await frames()
	check("Briefing reopens it already answered", "Veggie zinnias" in card_text() and "What NASA did" in card_text() and option(0) == null or not option(0).is_visible_in_tree())
	await close_card()

	# --- Next day: waits for the debrief, then shows day 2's story ---
	hud._open_menu(&"build")
	hud._select(&"greenhouse")
	hud._confirm()
	if current_scene.is_placing():  # new buildings: pick parcels (base grid)
		current_scene.confirm_placement()
	await create_timer(colony.AUTO_NEXT_DELAY + 4.2).timeout
	check("debrief comes first, alone", "What did we learn today?" in card_text() and not "LCROSS" in card_text())
	await close_card()
	await frames(3)
	check("then day 2's real problem (fix hidden)", "LCROSS" in card_text() and not "Your turn" in card_text())
	option(0).pressed.emit()  # "Wait for the Sun..." (hint uses NASA's sunlight map)
	await frames()
	check("hint ties to NASA's sunlight map", "about 1 in 10 spots near the pole stay dark" in card_text())
	option(1).pressed.emit()  # second miss
	await frames()
	check("two misses: no guess star (right answers only)", Rewards.stars_for(colony.state, &"ice_drill") == 0)
	check("first-try/after-hint right answer did earn it", colony.state.stars[&"greenhouse"].get("guessed", false))
	check("two misses: answer explained kindly, card opens up", "Good thinking! NASA's answer: Crash something in" in card_text() \
		and "Your turn: Build an Ice Drill." in card_text() and "My turn!" in card_text())
	await close_card()

	colony.delete_save()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
