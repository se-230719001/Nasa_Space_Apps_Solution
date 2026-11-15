extends SceneTree
## Unit tests for OutpostSimulation: the rules in GAME_ARCHITECTURE.md
## ("Doğrulama planı"), the level system and the day tasks.
## Run: <godot> --headless --path . --script res://tools/tests/test_simulation.gd
## Exit code 0 = all passed.

const Sim := preload("res://scenes/core/outpost_simulation.gd")
const SUN := {"sunlight": 1.0, "radiation": 2.0}
const DARK := {"sunlight": 0.0, "radiation": 2.0}

var _fails := 0
var _count := 0


func check(name: String, ok: bool) -> void:
	_count += 1
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name)


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _initialize() -> void:
	start_state()
	solar_and_power()
	crew_and_greenhouse()
	water()
	shield()
	search_and_explore()
	previews_match()
	bounds_over_many_days()
	levels()
	day_tasks()
	learning()
	campaigns()
	resources_off()
	outcomes()
	strategies()
	nasa_bundle()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)


func start_state() -> void:
	var s := Sim.new_state()
	check("start: habitat, solar, water tank built at L1",
		s.modules.keys().size() == 3 and s.levels.habitat == 1 and s.levels.solar == 1 and s.levels.water_tank == 1)
	check("start: day 1, 18 kits, 100 health", s.day == 1 and s.kits == 18.0 and s.crew_health == 100.0)


func solar_and_power() -> void:
	for pair in [[0.0, 0.0], [0.5, 12.0], [1.0, 24.0]]:
		var s := Sim.new_state()
		var r := Sim.advance_day(s, {"sunlight": pair[0], "radiation": 0.0})
		check("solar L1 at sun %.1f makes %d" % [pair[0], pair[1]], near(r.generated_power, pair[1]))
	# Power shortage: habitat first, optional machines share the rest equally.
	var s := Sim.new_state()
	s.stores.power = 0.0
	s.modules[&"ice_drill"] = 1
	s.levels[&"ice_drill"] = 1
	var r := Sim.advance_day(s, DARK)
	check("no power: habitat gets nothing, health drops", r.power_support == 0.0 and r.health_loss > 0.0)
	check("no power: drill mines no water", r.water_mined == 0.0)
	s = Sim.new_state()
	s.stores.power = 9.0  # 4 habitat + 5 for drill(10) + recycler(2) -> factor 5/12
	s.modules[&"ice_drill"] = 1
	s.levels[&"ice_drill"] = 1
	r = Sim.advance_day(s, DARK)
	check("habitat is served before machines", r.power_support == 1.0)
	check("drill output scales with its power share", near(r.water_mined, 6.0 * 5.0 / 12.0))
	s = Sim.new_state()
	s.stores.power = 99.0
	r = Sim.advance_day(s, SUN)
	check("power over 100 is reported as spilled", r.spilled_power > 0.0 and s.stores.power == 100.0)


func crew_and_greenhouse() -> void:
	var s := Sim.new_state()
	var before: Dictionary = s.stores.duplicate()
	Sim.advance_day(s, SUN)
	check("crew of 2 eats 2 food a day", near(before.food - s.stores.food, 2.0))
	s = Sim.new_state()
	s.stores.food = 1.0
	var r := Sim.advance_day(s, SUN)
	check("missing food is reported as unmet", near(r.unmet_crew_needs.food, 1.0) and r.health_loss > 0.0)
	for cond in [["no light", DARK, 65.0, 70.0], ["no water", SUN, 0.0, 70.0], ["no power", DARK, 65.0, 0.0]]:
		s = Sim.new_state()
		Sim.build(s, &"greenhouse")
		s.stores.water = cond[2]
		s.stores.power = cond[3]
		r = Sim.advance_day(s, cond[1])
		check("greenhouse with %s grows nothing" % cond[0], r.food_made == 0.0)
	s = Sim.new_state()
	Sim.build(s, &"greenhouse")
	r = Sim.advance_day(s, {"sunlight": 0.5, "radiation": 0.0})
	check("greenhouse at half sun grows half (6 of 12)", near(r.food_made, 6.0))


func water() -> void:
	var s := Sim.new_state()
	var r := Sim.advance_day(s, SUN)
	check("recycler returns 50% of the 2 water the crew used", near(r.water_recovered, 1.0))
	s = Sim.new_state()
	s.stores.water = 0.0
	r = Sim.advance_day(s, SUN)
	check("recycler creates nothing when no water was used", r.water_recovered == 0.0)
	s = Sim.new_state()
	Sim.build(s, &"ice_drill")
	r = Sim.advance_day(s, SUN)
	check("drill L1 mines 6 water with full power", near(r.water_mined, 6.0))


func shield() -> void:
	var s := Sim.new_state()
	s.unlocks[&"shield"] = true
	Sim.build(s, &"shield")
	var r := Sim.advance_day(s, {"sunlight": 1.0, "radiation": 6.0})
	check("shield L1 lowers radiation 6 -> 4 but not to 0", near(r.radiation_after_shield, 4.0))


func search_and_explore() -> void:
	var s := Sim.new_state()
	check("explore needs a rover", not Sim.preview_explore(s).allowed)
	var r := Sim.research(s, &"rover_blueprint", SUN)
	check("research spends the sample and unlocks the rover", r.ok and s.science == 0 and s.unlocks.rover)
	check("research does not end the day", s.day == 1)
	s.science = 1
	check("research runs only once", not Sim.research(s, &"rover_blueprint", SUN).ok)
	s.kits = 20.0
	Sim.build(s, &"rover")
	var power := float(s.stores.power)
	var e := Sim.explore(s, SUN)
	check("trip gives 1 science and ice, counts once", e.ok and s.science == 2 and s.trips == 1 and e.ice_found == 6.0)
	check("trip pays its power at once, day stays", near(power - 8.0, s.stores.power) and s.day == 1)
	check("one trip a day", not Sim.explore(s, SUN).ok)
	Sim.advance_day(s, SUN)
	check("rover is ready again the next day", Sim.preview_explore(s).allowed)


func previews_match() -> void:
	var s := Sim.new_state()
	var p := Sim.preview_build(s, &"greenhouse", SUN)
	var copy: Dictionary = s.duplicate(true)
	Sim.build(copy, &"greenhouse")
	var before: Dictionary = copy.stores.duplicate()
	Sim.advance_day(copy, SUN)
	var same := true
	for key in Sim.CAPACITY:
		same = same and near(p.forecast.next_day_store_change[key], copy.stores[key] - before[key])
	check("build forecast equals the real next day", same)
	check("preview does not change state", s.kits == 18.0 and not s.modules.has(&"greenhouse"))


func bounds_over_many_days() -> void:
	var s := Sim.new_state()
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 40:
		var env := {"sunlight": rng.randf(), "radiation": rng.randf_range(0, 8)}
		match rng.randi() % 4:
			0: Sim.build(s, [&"greenhouse", &"ice_drill", &"solar", &"habitat"][rng.randi() % 4])
			1: Sim.research(s, &"rover_blueprint", env)
			2: Sim.explore(s, env)
		Sim.advance_day(s, env)
		for key in Sim.CAPACITY:
			ok = ok and s.stores[key] >= 0.0 and s.stores[key] <= 100.0
		ok = ok and s.kits >= 0.0 and s.kits <= 30.0 and s.crew_health >= 0.0 and s.crew_health <= 100.0
	check("40 random days: stores 0-100, kits 0-30, health 0-100", ok)


func levels() -> void:
	var s := Sim.new_state()
	var p := Sim.preview_build(s, &"solar")
	check("built module asks for upgrade, not build", not p.allowed)
	p = Sim.preview_upgrade(s, &"solar", SUN)
	check("solar upgrade L1->L2 costs 4 kits", p.allowed and p.from_level == 1 and p.next_level == 2 and p.cost_kits == 4.0)
	Sim.upgrade(s, &"solar", SUN)
	check("upgrade spends kits, keeps the day", s.levels.solar == 2 and s.kits == 14.0 and s.day == 1)
	var r := Sim.advance_day(s, SUN)
	check("solar L2 makes 32 in full sun", near(r.generated_power, 32.0))
	check("L2->L3 costs 6", Sim.upgrade(s, &"solar", SUN).ok and s.levels.solar == 3 and s.kits == 9.0)
	check("L3 is the max", Sim.preview_upgrade(s, &"solar").reason == "Maximum level reached")
	check("unbuilt module cannot upgrade", not Sim.preview_upgrade(s, &"greenhouse").allowed)
	s = Sim.new_state()
	s.kits = 3.0
	check("upgrade needs enough kits", not Sim.upgrade(s, &"habitat").ok and s.levels.habitat == 1)
	s = Sim.new_state()
	Sim.build(s, &"greenhouse")
	s.kits = 30.0
	Sim.upgrade(s, &"greenhouse")
	r = Sim.advance_day(s, SUN)
	check("greenhouse L2 grows 17 food", near(r.food_made, 17.0))


func day_tasks() -> void:
	var single := true
	for day in Sim.DAY_TASKS:
		single = single and day.size() == 1 and Sim.TASK_ACTIONS.has(day[0].id)
	check("8 mission days, exactly one mission each, each with a way to do it", Sim.DAY_TASKS.size() == 8 and single)
	check("tasks_for out of range is empty", Sim.tasks_for(0).is_empty() and Sim.tasks_for(9).is_empty())
	var s := Sim.new_state()
	check("day can't end before its tasks", not Sim.next_day(s, SUN).ok and s.day == 1)
	Sim.build(s, &"ice_drill")  # day 2's task, done early
	check("tomorrow's task done early is not claimed today", Sim.claim_tasks(s).is_empty())
	Sim.build(s, &"greenhouse")
	var kits := float(s.kits)
	var got := Sim.claim_tasks(s)
	check("today's task pays 2 kits", got.size() == 1 and got[0].id == &"greenhouse" and s.kits == kits + 2.0)
	check("a task pays only once", Sim.claim_tasks(s).is_empty() and s.kits == kits + 2.0)
	check("all tasks done -> day cleared", Sim.day_cleared(s))
	check("next_day moves to day 2", Sim.next_day(s, SUN).ok and s.day == 2)
	check("early work counts on its own day", Sim.claim_tasks(s).size() == 1 and Sim.day_cleared(s))
	s = Sim.new_state()
	var w := Sim.wait_night(s, SUN)
	check("waiting keeps the mission day, uses supplies, sends a kit",
		w.ok and s.day == 1 and s.stores.food < 45.0 and s.kits == 19.0 and s.nights_waited == 1)
	s = Sim.new_state()
	var step := Sim.next_step(s, SUN)
	check("next step on day 1: Build > Greenhouse, possible", step.menu == &"build" and step.option == &"greenhouse" and step.ok)
	s.kits = 2.0
	step = Sim.next_step(s, SUN)
	check("next step blocked says why (kits)", not step.ok and "kits" in step.reason)
	s = Sim.new_state()
	s.day = 4
	check("day 4 next step is upgrading Solar", Sim.next_step(s, SUN).option == &"solar")
	Sim.build(s, &"greenhouse")
	s.tasks_done[&"solar_upgrade"] = true
	check("no next step once today's mission is done", Sim.next_step(s, SUN).is_empty())


## Package 2: power switches, the night's flows, prediction targets.
func learning() -> void:
	var s := Sim.new_state()
	Sim.build(s, &"ice_drill")
	Sim.build(s, &"greenhouse")
	s.stores.power = 0.0
	var dark := {"sunlight": 0.3, "radiation": 0.0}
	var shared: Dictionary = Sim.advance_day(s.duplicate(true), dark)
	check("too little power: machines share it (<100%)", shared.machine_share < 1.0)
	var p := Sim.preview_power(s, &"ice_drill", false, dark)
	check("switch preview: drill off gives the others a bigger share", p.allowed and p.forecast.machine_share > shared.machine_share)
	check("switching is free and keeps the day", Sim.set_power(s, &"ice_drill", false).ok and s.kits == 6.0 and s.day == 1)
	var before: Dictionary = s.stores.duplicate()
	var r := Sim.advance_day(s, dark)
	check("off drill takes no power and mines nothing", r.water_mined == 0.0)
	check("preview_power matched the real night", near(r.machine_share, p.forecast.machine_share))
	check("unbuilt / unknown machines can't be switched", not Sim.set_power(s, &"shield", false).ok and not Sim.set_power(s, &"habitat", false).ok)
	Sim.set_power(s, &"ice_drill", true)
	check("switch back on", not s.off.has(&"ice_drill"))
	# Flows explain each store's change exactly (no caps hit here).
	s = Sim.new_state()
	Sim.build(s, &"ice_drill")
	Sim.build(s, &"greenhouse")
	before = s.stores.duplicate()
	r = Sim.advance_day(s, SUN)
	var exact := true
	for key in Sim.CAPACITY:
		var flow: Dictionary = r.flows[key]
		var sum := 0.0
		for k in flow.in:
			sum += flow.in[k]
		for k in flow.out:
			sum -= flow.out[k]
		exact = exact and near(sum, s.stores[key] - before[key])
	check("night flows add up to every store's real change", exact)
	var watched := true
	for day in Sim.DAY_TASKS:
		var w: Variant = day[0].watch
		watched = watched and (w == null or w == &"health" or Sim.CAPACITY.has(w)) and not String(day[0].idea).is_empty()
	check("every mission has a science idea and a valid thing to predict", watched)
	var shaped := true
	for day in Sim.DAY_TASKS:
		var t: Dictionary = day[0]
		for q in [t.quiz, t.get("why", {})]:
			shaped = shaped and q.has("question") and q.options.filter(func(o): return o.correct).size() == 1
		for o in t.quiz.options + t.why.options:
			shaped = shaped and not o.has("why") and not o.has("quiz")  # data in the right place
	check("every mission: quiz + why-question, each with exactly one right idea", shaped)


func outcomes() -> void:
	var s := Sim.new_state()
	check("fresh run is playing", Sim.outcome(s).status == &"playing")
	s.crew_health = 0.0
	s.history.append({"unmet_crew_needs": {&"water": 2.0, &"food": 0.0, &"oxygen": 0.0}})
	var o := Sim.outcome(s)
	check("health 0 loses, cause = water", o.status == &"lost" and o.cause == "water")
	s = Sim.new_state()
	s.day = 9
	s.crew_health = 85.0
	o = Sim.outcome(s)
	check("finishing day 8 wins", o.status == &"won")
	check("stars by crew health: 85->3, 60->2, 30->1", o.stars == 3 \
		and Sim.star_rating({"crew_health": 60.0}) == 2 and Sim.star_rating({"crew_health": 30.0}) == 1)


## Plays the scenario like Colony does: act, claim, end the day once cleared
## (or wait a night). Gives up after 40 nights.
func play(plan: Dictionary, campaign: StringName = &"full") -> Dictionary:
	var scenario := [
		{"sunlight": 1.0, "radiation": 3.0}, {"sunlight": 0.8, "radiation": 4.0},
		{"sunlight": 0.5, "radiation": 4.0}, {"sunlight": 0.2, "radiation": 5.0},
		{"sunlight": 0.6, "radiation": 4.0}, {"sunlight": 0.9, "radiation": 4.0},
		{"sunlight": 1.0, "radiation": 3.0}, {"sunlight": 0.9, "radiation": 6.0},
	]
	var s := Sim.new_state()
	s.campaign = campaign
	for night in 40:
		if Sim.outcome(s).status != &"playing":
			break
		var day := int(s.day)
		var env: Dictionary = scenario[day - 1]
		for step in plan.get(day, []):
			match step:
				&"explore": Sim.explore(s, env)
				&"rover_blueprint", &"radiation_map": Sim.research(s, step, env)
				_:
					if s.modules.get(step, 0) > 0:
						Sim.upgrade(s, step, env)
					else:
						Sim.build(s, step, env)
			Sim.claim_tasks(s)
		if Sim.day_cleared(s):
			Sim.next_day(s, env)
		else:
			Sim.wait_night(s, env)
		Sim.claim_tasks(s)
	return s


func strategies() -> void:
	var s := play({
		1: [&"greenhouse"], 2: [&"ice_drill"], 3: [&"rover_blueprint"], 4: [&"solar"],
		5: [&"rover"], 6: [&"explore"], 7: [&"radiation_map"], 8: [&"shield"],
	})
	print("  intended: day=%d health=%d kits=%d waited=%d" % [s.day, s.crew_health, s.kits, s.get("nights_waited", 0)])
	check("intended plan: 8 days in 8 nights, no waiting", s.day == 9 and int(s.get("nights_waited", 0)) == 0)
	check("intended plan wins with 3 stars", Sim.outcome(s).status == &"won" and Sim.star_rating(s) == 3)
	s = play({})
	check("doing nothing never leaves day 1", s.day == 1 and Sim.outcome(s).status != &"won")
	# Kits spent on extras first: waiting nights must still unlock the rover.
	s = play({1: [&"greenhouse", &"habitat", &"water_tank"], 2: [&"ice_drill"], 3: [&"rover_blueprint"],
		4: [&"solar"], 5: [&"rover"], 6: [&"explore"], 7: [&"radiation_map"], 8: [&"shield"]})
	print("  overspent: day=%d health=%d waited=%d" % [s.day, s.crew_health, s.get("nights_waited", 0)])
	check("overspending costs waiting nights, but the run still finishes", Sim.outcome(s).status == &"won")


## Every campaign: real-date span shown, ids valid, and playable start to
## end with just each day's own mission action (prerequisites in order).
func campaigns() -> void:
	var ids := {}
	for m in Sim.DAY_TASKS:
		ids[m[0].id] = true
	for id in Sim.CAMPAIGNS:
		var c: Dictionary = Sim.CAMPAIGNS[id]
		check("campaign %s: name, years and valid days" % id, not String(c.name).is_empty() \
			and String(c.years).length() == 9 and c.days.all(func(d): return ids.has(d)))
		var plan := {}
		for i in c.days.size():
			var how: Array = Sim.TASK_ACTIONS[c.days[i]]
			plan[i + 1] = [how[1]]
		var s := play(plan, id)
		print("  %s: day=%d health=%d kits=%d waited=%d" % [id, s.day, s.crew_health, s.kits, s.get("nights_waited", 0)])
		check("campaign %s: %d days, no waiting, won" % [id, c.days.size()],
			Sim.outcome(s).status == &"won" and s.day == c.days.size() + 1 and int(s.get("nights_waited", 0)) == 0)
	var s := Sim.new_state()
	s.campaign = &"apollo"
	check("day 1 of Apollo Explorer is the rover plan", Sim.tasks_for(1, &"apollo")[0].id == &"rover_blueprint" \
		and Sim.next_step(s, SUN).option == &"rover_blueprint" and Sim.campaign_length(s) == 3)


## Stage 6: runs without the resource game. Nothing costs, nothing is lost,
## and every campaign can be finished with zero kits and empty stores.
func resources_off() -> void:
	var s := Sim.new_state()
	s.resources = false
	s.kits = 0.0
	for key in Sim.CAPACITY:
		s.stores[key] = 0.0
	check("off: building costs nothing", Sim.build(s, &"greenhouse").ok and s.kits == 0.0)
	check("off: upgrades cost nothing", Sim.upgrade(s, &"solar").ok and s.levels.solar == 2)
	check("off: research needs no power", Sim.research(s, &"rover_blueprint").ok)
	Sim.build(s, &"rover")
	check("off: a trip needs no power, water or oxygen", Sim.explore(s).ok and s.trips == 1)
	s.crew_health = 0.0
	check("off: the crew can't be lost", Sim.outcome(s).status == &"playing")
	for id in Sim.CAMPAIGNS:
		var plan := {}
		for i in Sim.CAMPAIGNS[id].days.size():
			plan[i + 1] = [Sim.TASK_ACTIONS[Sim.CAMPAIGNS[id].days[i]][1]]
		var r := play_off(plan, id)
		check("off: campaign %s finishes with no kits and no waiting" % id,
			Sim.outcome(r).status == &"won" and int(r.get("nights_waited", 0)) == 0)


func play_off(plan: Dictionary, campaign: StringName) -> Dictionary:
	var s := Sim.new_state()
	s.resources = false
	s.campaign = campaign
	s.kits = 0.0
	for night in 20:
		if Sim.outcome(s).status != &"playing":
			break
		for step in plan.get(int(s.day), []):
			match step:
				&"explore": Sim.explore(s)
				&"rover_blueprint", &"radiation_map": Sim.research(s, step)
				_:
					if s.modules.get(step, 0) > 0:
						Sim.upgrade(s, step)
					else:
						Sim.build(s, step)
			s.kits = 0.0  # mission rewards don't matter either
			Sim.claim_tasks(s)
		if Sim.day_cleared(s):
			Sim.next_day(s, {"sunlight": 0.0, "radiation": 9.0})  # worst night: still fine
		else:
			Sim.wait_night(s, {})
	return s


func nasa_bundle() -> void:
	var good := {"schema_version": 1, "location": {"lat": -89.9, "lon": 0.0},
		"provenance": {"dataset_id": "x", "title": "t", "provider": "NASA", "version": "1", "retrieved_utc": "2026", "citation_url": "u"},
		"variables": {"sunlight": [{"value": 0.7, "unit": "fraction", "timestamp": "2026-01-01T00:00Z"}]}}
	check("valid NASA bundle accepted", NasaEnvironmentData.validate_bundle(good).valid)
	var bad: Dictionary = good.duplicate(true)
	bad.variables.sunlight[0].value = 1.5
	check("sunlight outside 0-1 rejected", not NasaEnvironmentData.validate_bundle(bad).valid)
	bad = good.duplicate(true)
	bad.provenance.erase("citation_url")
	check("missing provenance rejected", not NasaEnvironmentData.validate_bundle(bad).valid)
