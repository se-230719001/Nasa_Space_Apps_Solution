extends SceneTree
## Checks the rules of docs/game_systems_design.md against ColonySim.
##   godot --headless --path . --script res://tools/test_colony_sim.gd

const Sim := preload("res://scenes/sim/colony_sim.gd")
var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func fresh(seed_value := 5):
	var s = Sim.new(seed_value)
	s.problem_day = 999999
	return s


func _init() -> void:
	print("sharing:")
	var g := Sim.allocate(30.0, [{"id": "a", "amount": 10.0, "priority": 0},
		{"id": "b", "amount": 20.0, "priority": 1}, {"id": "c", "amount": 20.0, "priority": 1}])
	check(is_equal_approx(g.a, 10.0) and is_equal_approx(g.b, 10.0) and is_equal_approx(g.c, 10.0), "priority first, then proportional")

	print("science rules (doc C):")
	var a = fresh()
	a.co2_filter_on = false
	var co2_before: float = a.co2
	a.step_day()
	var crew_co2: float = a.population * Sim.PER_PERSON.co2
	check(is_equal_approx(a.co2 - co2_before, crew_co2), "electrolysis alone doesn't change CO2 (only people add it)")

	var b = fresh()
	var c = fresh()
	c.problem = c.problem_for(2)   # solar storm
	c.problem_day = c.day + 1
	b.step_day()
	c.step_day()
	check(is_equal_approx(b.stock.water, c.stock.water) and is_equal_approx(b.stock.oxygen, c.stock.oxygen) \
		and is_equal_approx(b.stock.food, c.stock.food), "radiation never deletes stored water / O2 / food")
	check(c.health < b.health, "radiation lowers health of unprotected crew")

	var d = fresh()
	d.levels.erase("energy_center")
	d.stock.energy = 50.0
	d.step_day()
	check(d.last_report.energy_produced == 0.0 and d.stock.energy < 50.0, "the battery only stores: no panels, no production")

	var e = fresh()
	e.levels["health_center"] = 1
	e.levels["greenhouse"] = 2
	e.levels["energy_center"] = 3
	e.health = 79.0
	e.exercise_on = true
	e.sleep_on = true
	e.stock.food = 150.0
	e.stock.water = 200.0
	e.stock.oxygen = 100.0
	for i in 30:
		e.step_day()
	check(e.health <= 80.01 and e.health > 74.0, "health rises toward the Health Center cap but never past it (%.1f)" % e.health)

	var f = fresh()
	f.levels["greenhouse"] = 1
	f.co2 = 5.0
	var low: float = f.photo_factor()
	f.co2 = 45.0
	check(low < 0.6 and f.photo_factor() > 1.0, "too little CO2 slows photosynthesis")

	print("power shortage priority:")
	var p = fresh()
	p.levels["greenhouse"] = 1
	p.levels["radiation_lab"] = 1
	p.stock.energy = 0.0
	p.levels.erase("energy_center")
	p.levels["energy_center"] = 1
	p.sunlight = 1.0
	p.day = 12   # lunar night: little sun
	p.step_day()
	var eff: Dictionary = p.last_report.efficiency
	check(eff.electrolysis >= eff.get("greenhouse", 1.0) and eff.get("greenhouse", 0.0) >= eff.get("radiation_lab", 0.0),
		"life support before greenhouse before lab (%s)" % str(eff))

	print("preview & actions:")
	var q = fresh()
	var diff: Dictionary = q.preview_upgrade("greenhouse")
	check(diff.food > 0.0 and diff.energy < 0.0, "greenhouse preview: +food, -power")
	check(q.lv("greenhouse") == 0 and q.materials == 120.0, "preview doesn't change the colony")
	check(q.start_build("greenhouse") and q.lv("greenhouse") == 1, "building is instant")
	check(q.start_build("greenhouse") and q.lv("greenhouse") == 2, "upgrading is instant")

	print("problems:")
	var pr = Sim.new(3)
	check(pr.problem_day == 5 and pr.problem.id == "dust", "first problem is announced for day 5")
	var seen := 0
	for i in 12:
		var rr: Dictionary = pr.step_day()
		for ev in rr.events:
			if ev is Dictionary and ev.type == "problem":
				seen += 1
				check(ev.text != "" and ev.lesson != "", "day %d problem '%s' is explained (%s)" % [rr.day, ev.problem.title, "good" if ev.passed else "bad"])
	check(seen == 2 and pr.problem_day == 15, "a problem every 5 days")
	check(pr.hint().title != "", "a hint is always available")

	print("120-day runs:")
	for strategy in ["idle", "sensible"]:
		var s = Sim.new(11)
		var min_health := 100.0
		var emergencies := 0
		var order := ["greenhouse", "energy_center", "life_support", "health_center", "greenhouse", "water_recycling",
			"radiation_lab", "energy_center", "life_support", "greenhouse", "health_center", "radiation_lab", "water_recycling"]
		for dday in 120:
			if strategy == "sensible":
				if not order.is_empty() and s.why_not_build(order[0]) == "":
					s.start_build(order.pop_front())
				if s.lv("health_center") >= 1:
					s.exercise_on = true
				if s.lv("health_center") >= 2:
					s.sleep_on = true
				if s.crafts.is_empty() and s.craft_builds.is_empty():
					s.build_craft("rover")
				if s.why_not_launch("tycho") == "":
					s.launch("tycho")
				for card in s.cards_found:
					s.research(card)
			var r: Dictionary = s.step_day()
			min_health = minf(min_health, s.health)
			if "emergency" in r.events:
				emergencies += 1
		var lvv: Dictionary = s.levels_view()
		print("    %-8s day %d pop %d health %d (min %d) food %d water %d power %d O2 %d co2 %d mat %d sci %d goals %d emerg %d" % [
			strategy, s.day, s.population, s.health, min_health, lvv.food, lvv.water, lvv.energy, lvv.oxygen, s.co2,
			s.materials, s.science, s.goal_index, emergencies])
		if strategy == "idle":
			check(s.population == 4 or min_health < 60.0, "an idle colony doesn't grow")
		else:
			check(s.population >= 6 and min_health >= 40.0, "a sensible colony grows and stays healthy")
			check(s.goal_index >= 6, "a sensible colony completes goals (%d)" % s.goal_index)

	print("\n%s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	quit(failures)
