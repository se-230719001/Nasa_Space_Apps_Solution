extends SceneTree
## Stage 8 rewards: stars for finishing / guessing / reflecting (never for
## speed or first-try), concept badges, milestone decorations, the Mission Log
## and the badge shelf. Nothing is ever taken away.
## Run: <godot> --headless --path . --script res://tools/tests/test_rewards.gd

const R := preload("res://scenes/core/rewards.gd")

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
			elif n is RichTextLabel and n.is_visible_in_tree():
				t += n.get_parsed_text() + "|"
	return t


func close_card() -> void:
	card().find_child("Choice0", true, false).pressed.emit()
	await frames(3)


func _initialize() -> void:
	unit()
	await scene_flow()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)


func unit() -> void:
	var s: Dictionary = root.get_node("Colony")._fresh_state()
	check("a star is given once per kind", R.give_star(s, &"greenhouse", "done") and not R.give_star(s, &"greenhouse", "done")
		and R.stars_for(s, &"greenhouse") == 1)
	R.give_star(s, &"greenhouse", "guessed")
	R.give_star(s, &"greenhouse", "reflected")
	check("max 3 stars a mission, counted in total", R.stars_for(s, &"greenhouse") == 3 and R.total_stars(s) == 3)
	check("no badge before its mission", R.claim_badges(s).is_empty())
	s.tasks_done[&"greenhouse"] = true
	check("Plant Keeper after the greenhouse mission, once", R.claim_badges(s) == [&"plant_keeper"] and R.claim_badges(s).is_empty())
	s.tasks_done[&"rover"] = true
	check("Rover Driver needs both rover missions", not R.badge_met(s, &"rover_driver"))
	s.player_placements = 3
	check("Base Architect after choosing 3 spots", R.badge_met(s, &"base_architect"))
	s.guesses[&"ice_drill"] = {"tries": 2, "solved": true, "hint_win": true}
	check("Never Give Up after a hint win", R.badge_met(s, &"never_give_up"))
	var f: Dictionary = root.get_node("Colony")._fresh_state()
	f.day = 4  # 3 of 8 days done
	check("full campaign: a decoration at 3/8 days", R.claim_decor(f) == [&"lamp"])
	f.day = 9
	check("then the other two by the end, never twice", R.claim_decor(f) == [&"antenna", &"moon_garden"] and R.claim_decor(f).is_empty())
	var l: Dictionary = root.get_node("Colony")._fresh_state()
	l.day = 4
	l.guesses = {&"greenhouse": {"tries": 1, "solved": true}, &"ice_drill": {"tries": 2, "solved": true, "hint_win": true},
		&"rover_blueprint": {"tries": 2, "solved": true, "hint_win": false}}
	var how := R.log_pages(l).map(func(p): return p.how)
	check("log says how you thought it through, kindly", how == ["You guessed NASA's fix on the first try.",
		"You found NASA's fix after a hint.", "You learned NASA's fix from the answer."])


func scene_flow() -> void:
	colony = root.get_node("Colony")
	colony.save_path = "user://test_rewards_save.txt"
	colony.delete_save()
	colony.session_chosen = true
	colony.tutorial_done = true
	colony.show_stories = false
	colony.state.campaign = &"apollo"  # 3 days: a decoration after day 1
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.4).timeout
	scene = current_scene
	hud = scene.find_child("OutpostHUD", true, false)
	var heard := []
	root.get_node("Events").badge_earned.connect(func(id): heard.append(id))

	# --- XP is visible: the star counter on top ---
	var counter: Label = hud.get_node("%StarCounter").get_node("Stars")
	check("star counter on screen from the start", hud.get_node("%StarCounter").is_visible_in_tree() and counter.text == "★ 0  Science stars")
	check("settings button is back", hud.get_node("%SettingsButton").is_visible_in_tree())
	hud.get_node("%SettingsButton").pressed.emit()
	await frames()
	check("settings: tutorial again / new mission / close", "Settings" in card_text() and "Tutorial" in card_text() and "New mission" in card_text())
	check("the robot steps aside while a card is open", not hud.get_node("%Helper").visible)
	var music: Button = card().find_child("MusicSwitch", true, false)
	var sfx: Button = card().find_child("SFXSwitch", true, false)
	check("settings: Music and Sound FX switches on top, then a divider", music != null and sfx != null
		and card().find_children("*", "HSeparator", true, false).size() == 1)
	sfx.button_pressed = false
	var cfg := ConfigFile.new()
	cfg.load(hud.SETTINGS_PATH)
	check("Sound FX off mutes the SFX bus and is remembered", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX"))
		and cfg.get_value("sound", &"SFX", true) == false and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")))
	sfx.button_pressed = true  # leave it on for the player
	check("and back on", not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")))
	card().find_child("Choice2", true, false).pressed.emit()  # Close
	await frames(3)
	check("and comes back when it closes", hud.get_node("%Helper").visible)

	# --- Day 1 done: debrief asks "why?" (a star either way) ---
	colony.research(&"rover_blueprint")
	await frames()
	check("finishing the mission is a star", R.stars_for(colony.state, &"rover_blueprint") == 1)
	check("finishing a mission is celebrated: flash + confetti, taps still pass", hud.has_node("Flash")
		and hud.get_children().filter(func(n): return n is CPUParticles2D).size() == 2
		and hud.get_node("Flash").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check("counter goes up with a '+1 ★' pop", counter.text == "★ 1  Science star"
		and hud.get_children().any(func(n): return n is Label and n.text == "+1 ★"))
	await create_timer(colony.AUTO_NEXT_DELAY + 0.9).timeout
	check("debrief has the why-question", "What did we learn today?" in card_text() and "Get it right for a star: Why does a rover help explorers?" in card_text())
	card().find_child("WhyOption1", true, false).pressed.emit()  # the wrong idea
	await frames()
	check("wrong idea: no star, but the explanation", "Not quite, no star this time. Here's why:" in card_text()
		and R.stars_for(colony.state, &"rover_blueprint") == 1)
	await close_card()

	# --- Milestone decoration (1 of 3 days) ---
	for i in 40:  # the rewards card comes a moment after the debrief
		if card() != null:
			break
		await create_timer(0.1).timeout
	check("one rewards card after the debrief", "Today's rewards!" in card_text() and "New decoration: Light Post!" in card_text())
	await close_card()
	hud._open_menu(&"build")
	check("the decoration is in Build now, the others not yet", hud.get_node("%Options").get_node_or_null("lamp") != null
		and hud.get_node("%Options").get_node_or_null("antenna") == null)
	hud._select(&"lamp")
	hud._confirm()
	check("decorations are placed like buildings (1x1)", scene.is_placing() and BaseGrid.size_of(&"lamp", 0) == Vector2i(1, 1))
	scene.confirm_placement()
	await frames()
	check("the light post stands in the base", scene._spawned.has(&"lamp") and scene._spawned[&"lamp"].kind == "lamp")

	# --- Mission Log + badge shelf ---
	hud.toggle_checklist()
	await frames()
	hud.get_node("%Tasks").find_child("LogButton", true, false).pressed.emit()
	await frames()
	check("Mission Log page: real event, idea, how you did, stars", "Day 1: Apollo 14 at Cone Crater  ★☆☆" in card_text()
		and "Idea: Scientists study samples" in card_text() and "You finished it." in card_text())
	await close_card()
	hud.get_node("%Tasks").find_child("BadgesButton", true, false).pressed.emit()
	await frames()
	check("badge shelf: what's earned and how to earn the rest", "○ Rover Driver: Build the rover and go on a field trip." in card_text())
	check("every badge has its symbol", card().find_children("Badge_*", "", true, false).size() == R.BADGES.size()
		and card().find_children("Symbol", "TextureRect", true, false).all(func(t): return t.texture != null))
	await close_card()

	# --- A badge: Rover Driver after both rover missions ---
	colony.build(&"rover")
	await create_timer(colony.AUTO_NEXT_DELAY + 0.9).timeout
	while card() != null:
		await close_card()
	colony.explore()
	await create_timer(colony.AUTO_NEXT_DELAY + 0.9).timeout
	var seen := ""
	for i in 8:  # debrief, badge, end card... (each opens after the last closes)
		await frames(3)
		if card() == null:
			continue
		seen += card_text()
		if "Mission Complete" in card_text():
			break  # don't press Play Again
		await close_card()
	check("badge card celebrates Rover Driver; Events told the audio side", "New badge: Rover Driver!" in seen and heard.has(&"rover_driver"))
	check("end card counts stars and badges", "Science stars:" in seen and "Badges:" in seen)
	check("stars and badges are never lost", Rewards.total_stars(colony.state) >= 3 and colony.state.badges.has(&"rover_driver"))
	colony.delete_save()
