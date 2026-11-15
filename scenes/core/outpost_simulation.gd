class_name OutpostSimulation
extends RefCounted
## One deterministic mission-day model. Values are simple game units, not SI units.

const CAPACITY := {&"power": 100.0, &"water": 100.0, &"food": 100.0, &"oxygen": 100.0}
const START := {&"power": 70.0, &"water": 65.0, &"food": 45.0, &"oxygen": 80.0}
const START_KITS := 18.0
const KIT_CAPACITY := 30.0
## Mission Control supply shuttle: a small daily kit delivery so spending kits
## on the "wrong" module can never lock the run (wait a few days instead).
const DAILY_KITS := 1.0
const CREW_SIZE := 2
const CREW_DAILY := {&"water": 2.0, &"food": 2.0, &"oxygen": 4.0}
const MAX_LEVEL := 3
const RESEARCH := {
	&"rover_blueprint": {"science": 1, "power": 2.0, "unlocks": &"rover", "kits": 0.0},
	&"radiation_map": {"science": 1, "power": 3.0, "unlocks": &"shield", "kits": 8.0},
}

## Kit prices are one-time cargo costs; power is only an operating resource.
const MODULES := {
	&"habitat": {"kit_cost": 0.0, "upgrade_kits": [0.0, 4.0, 6.0], "critical_power": [4.0, 3.0, 2.0]},
	&"solar": {"kit_cost": 0.0, "upgrade_kits": [0.0, 4.0, 6.0], "generation": [24.0, 32.0, 40.0]},
	&"greenhouse": {"kit_cost": 6.0, "upgrade_kits": [0.0, 4.0, 6.0], "power": [8.0, 10.0, 12.0], "water": [6.0, 7.0, 8.0], "food": [12.0, 17.0, 22.0], "oxygen": [3.0, 4.0, 5.0]},
	&"water_tank": {"kit_cost": 0.0, "upgrade_kits": [0.0, 4.0, 6.0], "power": [2.0, 3.0, 4.0], "recovery": [0.50, 0.65, 0.80]},
	## Mines ice into water: the colony's only real water income. Power hungry,
	## so it competes with the greenhouse on low-sun days.
	&"ice_drill": {"kit_cost": 6.0, "upgrade_kits": [0.0, 4.0, 6.0], "power": [10.0, 12.0, 14.0], "water": [6.0, 8.0, 10.0]},
	&"shield": {"kit_cost": 8.0, "upgrade_kits": [0.0, 4.0, 6.0], "power": [3.0, 4.0, 5.0], "protection": [2.0, 4.0, 6.0]},
	&"rover": {"kit_cost": 8.0, "upgrade_kits": [0.0, 4.0, 6.0], "explore_cost": [{}, {&"power": 8.0, &"water": 3.0, &"oxygen": 2.0}, {&"power": 7.0, &"water": 3.0, &"oxygen": 2.0}, {&"power": 6.0, &"water": 2.0, &"oxygen": 1.0}], "science": [0, 1, 2, 3], "ice": [0.0, 6.0, 7.0, 8.0]},
}

## Mission goals, in teaching order (one new idea each). The run is won when
## all are done with the crew alive, and lost when crew health reaches 0.
const GOALS := [&"greenhouse", &"rover_blueprint", &"rover", &"explore"]

## Main scene already contains these three structures; state mirrors that world.
static func new_state() -> Dictionary:
	return {"stores": START.duplicate(), "kits": START_KITS, "modules": {&"habitat": 1, &"solar": 1, &"water_tank": 1},
		"levels": {&"habitat": 1, &"solar": 1, &"water_tank": 1}, "crew": CREW_SIZE,
		"crew_health": 100.0, "science": 1, "trips": 0, "unlocks": {&"habitat": true, &"solar": true, &"water_tank": true, &"greenhouse": true, &"ice_drill": true},
		"research_done": {}, "emergency_used": false, "day": 1, "history": []}


static func preview_build(state: Dictionary, module_id: StringName, environment := {}) -> Dictionary:
	if not MODULES.has(module_id):
		return _denied("Unknown module")
	if not bool(state.unlocks.get(module_id, false)):
		return _denied("Search for this blueprint first")
	if int(state.modules.get(module_id, 0)) > 0:
		return _denied("Already built — upgrade this module")
	var cost := float(MODULES[module_id].kit_cost)
	if float(state.kits) < cost:
		return _denied("Need %d build kits" % int(cost))
	var forecast_state: Dictionary = state.duplicate(true)
	forecast_state.modules[module_id] = 1
	forecast_state.levels[module_id] = 1
	var forecast := _forecast(forecast_state, environment)
	return {"allowed": true, "action": "build", "module": module_id, "cost_kits": cost,
		"next_level": 1, "forecast": forecast}


static func build(state: Dictionary, module_id: StringName, environment := {}) -> Dictionary:
	var preview := preview_build(state, module_id, environment)
	if not preview.allowed:
		return {"ok": false, "reason": preview.reason}
	state.kits -= float(preview.cost_kits)
	state.modules[module_id] = 1
	state.levels[module_id] = 1
	return {"ok": true, "state": state, "preview": preview}


static func preview_upgrade(state: Dictionary, module_id: StringName, environment := {}) -> Dictionary:
	if not MODULES.has(module_id) or int(state.modules.get(module_id, 0)) == 0:
		return _denied("Build this module first")
	var level := int(state.levels.get(module_id, 1))
	if level >= MAX_LEVEL:
		return _denied("Maximum level reached")
	var next_level := level + 1
	var costs: Array = MODULES[module_id].upgrade_kits
	var cost := float(costs[next_level - 1])
	if float(state.kits) < cost:
		return _denied("Need %d build kits" % int(cost))
	var forecast_state: Dictionary = state.duplicate(true)
	forecast_state.levels[module_id] = next_level
	var forecast := _forecast(forecast_state, environment)
	return {"allowed": true, "action": "upgrade", "module": module_id,
		"from_level": level, "next_level": next_level, "cost_kits": cost,
		"forecast": forecast}


static func upgrade(state: Dictionary, module_id: StringName, environment := {}) -> Dictionary:
	var preview := preview_upgrade(state, module_id, environment)
	if not preview.allowed:
		return {"ok": false, "reason": preview.reason}
	state.kits -= float(preview.cost_kits)
	state.levels[module_id] = int(preview.next_level)
	return {"ok": true, "state": state, "preview": preview}


## Advance exactly one mission day. Solar charges the store first; habitat and crew
## get first claim. Remaining power is shared evenly across optional machinery.
static func advance_day(state: Dictionary, environment := {}) -> Dictionary:
	var sunlight := clampf(float(environment.get("sunlight", 1.0)), 0.0, 1.0)
	var radiation := maxf(0.0, float(environment.get("radiation", 4.0)))
	var stores: Dictionary = state.stores
	var levels: Dictionary = state.levels
	var generated := 0.0
	var spilled := 0.0
	var food_spilled := 0.0
	var oxygen_spilled := 0.0
	var available_power := float(stores.power)
	if int(state.modules.get(&"solar", 0)) > 0:
		var solar_level := int(levels.get(&"solar", 1))
		generated = float(MODULES[&"solar"].generation[solar_level - 1]) * sunlight
		available_power += generated

	# Critical habitat power is served before optional machines.
	var habitat_level := int(levels.get(&"habitat", 1))
	var habitat_need := float(MODULES[&"habitat"].critical_power[habitat_level - 1])
	var habitat_power := minf(available_power, habitat_need)
	available_power -= habitat_power
	var power_support := 1.0 if habitat_need == 0.0 else habitat_power / habitat_need

	# Crew needs are handled before food production, recycling, or exploration.
	var crew := maxi(1, int(state.get("crew", CREW_SIZE)))
	var unmet := {}
	var consumed := {}
	for key in CREW_DAILY:
		var need := float(CREW_DAILY[key]) * crew / CREW_SIZE
		consumed[key] = minf(float(stores[key]), need)
		stores[key] -= consumed[key]
		unmet[key] = need - consumed[key]
	var water_recovered := 0.0
	var optional_power_need := 0.0
	var tank_level := int(levels.get(&"water_tank", 1))
	if int(state.modules.get(&"water_tank", 0)) > 0 and float(consumed.water) > 0.0:
		optional_power_need += float(MODULES[&"water_tank"].power[tank_level - 1])
	var greenhouse_level := int(levels.get(&"greenhouse", 0))
	var sunlight_factor := sunlight
	var greenhouse_factor := 0.0
	if greenhouse_level > 0:
		var g: Dictionary = MODULES[&"greenhouse"]
		var water_factor := minf(1.0, float(stores.water) / float(g.water[greenhouse_level - 1]))
		greenhouse_factor = minf(sunlight_factor, water_factor)
		optional_power_need += float(g.power[greenhouse_level - 1]) * greenhouse_factor
	var drill_level := int(levels.get(&"ice_drill", 0))
	if drill_level > 0:
		optional_power_need += float(MODULES[&"ice_drill"].power[drill_level - 1])
	var shield_level := int(levels.get(&"shield", 0))
	if shield_level > 0:
		optional_power_need += float(MODULES[&"shield"].power[shield_level - 1])
	var optional_power := minf(available_power, optional_power_need)
	var machine_factor := 1.0 if optional_power_need <= 0.0 else optional_power / optional_power_need
	available_power -= optional_power
	stores.power = minf(float(CAPACITY.power), available_power)
	spilled = maxf(0.0, available_power - float(CAPACITY.power))

	# Ice drill output scales with the power it actually received.
	var water_mined := 0.0
	if drill_level > 0:
		water_mined = float(MODULES[&"ice_drill"].water[drill_level - 1]) * machine_factor
		stores.water = minf(CAPACITY.water, float(stores.water) + water_mined)

	# Water recovery only returns a share of water actually used by the crew.
	if int(state.modules.get(&"water_tank", 0)) > 0:
		var recovery_rate := float(MODULES[&"water_tank"].recovery[tank_level - 1])
		water_recovered = float(consumed.water) * recovery_rate * machine_factor
		stores.water = minf(CAPACITY.water, float(stores.water) + water_recovered)

	var food_made := 0.0
	var oxygen_made := 0.0
	if greenhouse_level > 0:
		var g: Dictionary = MODULES[&"greenhouse"]
		var factor := greenhouse_factor * machine_factor
		var idx := greenhouse_level - 1
		var water_used := float(g.water[idx]) * factor
		stores.water = maxf(0.0, float(stores.water) - water_used)
		food_made = float(g.food[idx]) * factor
		oxygen_made = float(g.oxygen[idx]) * factor
		var food_total := float(stores.food) + food_made
		var oxygen_total := float(stores.oxygen) + oxygen_made
		food_spilled = maxf(0.0, food_total - CAPACITY.food)
		oxygen_spilled = maxf(0.0, oxygen_total - CAPACITY.oxygen)
		stores.food = minf(CAPACITY.food, food_total)
		stores.oxygen = minf(CAPACITY.oxygen, oxygen_total)

	var shield_power_factor := machine_factor if shield_level > 0 else 0.0
	var protection := 0.0
	if shield_level > 0:
		protection = float(MODULES[&"shield"].protection[shield_level - 1]) * shield_power_factor
	var radiation_after_shield := maxf(0.0, radiation - protection)
	var worst_shortage := 1.0 - power_support
	for key in unmet:
		var need := float(CREW_DAILY[key]) * crew / CREW_SIZE
		if need > 0.0:
			worst_shortage = maxf(worst_shortage, float(unmet[key]) / need)
	var health_loss := ceilf(worst_shortage * 10.0) + maxf(0.0, radiation_after_shield - 2.0)
	state.crew_health = clampf(float(state.crew_health) - health_loss, 0.0, 100.0)
	var kits_delivered := minf(DAILY_KITS, KIT_CAPACITY - float(state.kits))
	state.kits = float(state.kits) + kits_delivered
	state.day = int(state.day) + 1
	var report := {"day": state.day, "generated_power": generated, "spilled_power": spilled,
		"spilled_food": food_spilled, "spilled_oxygen": oxygen_spilled,
		"power_support": power_support, "unmet_crew_needs": unmet, "water_recovered": water_recovered, "water_mined": water_mined, "kits_delivered": kits_delivered,
		"food_made": food_made, "oxygen_made": oxygen_made, "radiation_after_shield": radiation_after_shield,
		"health_loss": health_loss, "crew_health": state.crew_health, "stores": stores.duplicate()}
	state.history.append(report.duplicate())
	return report


static func preview_explore(state: Dictionary, environment := {}) -> Dictionary:
	if int(state.modules.get(&"rover", 0)) == 0:
		return _denied("Build a rover first")
	var level := int(state.levels.get(&"rover", 1))
	var cost: Dictionary = MODULES[&"rover"].explore_cost[level]
	for key in cost:
		if float(state.stores[key]) < float(cost[key]):
			return _denied("Need more %s for this trip" % String(key))
	var forecast_state: Dictionary = state.duplicate(true)
	for key in cost:
		forecast_state.stores[key] -= float(cost[key])
	var ice := float(MODULES[&"rover"].ice[level])
	forecast_state.stores.water = minf(CAPACITY.water, float(forecast_state.stores.water) + ice)
	var forecast := _forecast(forecast_state, environment)
	return {"allowed": true, "cost": cost, "science": MODULES[&"rover"].science[level], "ice": ice, "forecast": forecast}


static func explore(state: Dictionary, environment := {}) -> Dictionary:
	var preview := preview_explore(state, environment)
	if not preview.allowed:
		return {"ok": false, "reason": preview.reason}
	for key in preview.cost:
		state.stores[key] -= float(preview.cost[key])
	state.science += int(preview.science)
	state.stores.water = minf(CAPACITY.water, float(state.stores.water) + float(preview.ice))
	state.trips = int(state.get("trips", 0)) + 1
	var day_report := advance_day(state, environment)
	return {"ok": true, "state": state, "science_found": preview.science, "ice_found": preview.ice, "day_report": day_report}


static func preview_research(state: Dictionary, research_id: StringName, environment := {}) -> Dictionary:
	if not RESEARCH.has(research_id):
		return _denied("Unknown research")
	if bool(state.research_done.get(research_id, false)):
		return _denied("Research already complete")
	var spec: Dictionary = RESEARCH[research_id]
	if int(state.science) < int(spec.science):
		return _denied("Explore to collect one science sample")
	if float(state.stores.power) < float(spec.power):
		return _denied("Need %d power" % int(spec.power))
	var forecast_state: Dictionary = state.duplicate(true)
	forecast_state.science -= int(spec.science)
	forecast_state.stores.power -= float(spec.power)
	forecast_state.unlocks[spec.unlocks] = true
	var kit_total := float(forecast_state.kits) + float(spec.kits)
	forecast_state.kits = minf(KIT_CAPACITY, kit_total)
	var forecast := _forecast(forecast_state, environment)
	return {"allowed": true, "research": research_id, "science_cost": spec.science,
		"power_cost": spec.power, "unlock": spec.unlocks, "kit_reward": forecast_state.kits - float(state.kits),
		"kit_overflow": maxf(0.0, kit_total - KIT_CAPACITY), "forecast": forecast}


static func research(state: Dictionary, research_id: StringName, environment := {}) -> Dictionary:
	var preview := preview_research(state, research_id, environment)
	if not preview.allowed:
		return {"ok": false, "reason": preview.reason}
	var spec: Dictionary = RESEARCH[research_id]
	state.science -= int(spec.science)
	state.stores.power -= float(spec.power)
	state.unlocks[spec.unlocks] = true
	var kit_total := float(state.kits) + float(spec.kits)
	state.kits = minf(KIT_CAPACITY, kit_total)
	state.research_done[research_id] = true
	var day_report := advance_day(state, environment)
	return {"ok": true, "state": state, "unlock": spec.unlocks,
		"kit_overflow": maxf(0.0, kit_total - KIT_CAPACITY), "day_report": day_report}


## One-use Mission Control cargo prevents a child's mistake from soft-locking a run.
static func preview_emergency_supply(state: Dictionary) -> Dictionary:
	if bool(state.get("emergency_used", false)):
		return _denied("Emergency cargo already used")
	if float(state.crew_health) > 50.0 and minf(float(state.stores.power), minf(float(state.stores.water), minf(float(state.stores.food), float(state.stores.oxygen)))) > 10.0:
		return _denied("Emergency cargo is for a critical situation")
	return {"allowed": true, "cargo": {&"power": 15.0, &"water": 10.0, &"food": 10.0, &"oxygen": 10.0}}


static func emergency_supply(state: Dictionary, environment := {}) -> Dictionary:
	var preview := preview_emergency_supply(state)
	if not preview.allowed:
		return {"ok": false, "reason": preview.reason}
	for key in preview.cargo:
		state.stores[key] = minf(float(CAPACITY[key]), float(state.stores[key]) + float(preview.cargo[key]))
	state.emergency_used = true
	var day_report := advance_day(state, environment)
	return {"ok": true, "state": state, "cargo": preview.cargo, "day_report": day_report}


static func _forecast(state: Dictionary, environment := {}) -> Dictionary:
	var before: Dictionary = state.stores.duplicate()
	var result := advance_day(state, environment)
	var changes := {}
	for key in CAPACITY:
		changes[key] = float(state.stores[key]) - float(before[key])
	return {"next_day_store_change": changes, "health_change": -float(result.health_loss),
		"radiation_after_shield": result.radiation_after_shield,
		"power_generated": result.generated_power, "power_wasted": result.spilled_power,
		"unmet_needs": result.unmet_crew_needs,
		"greenhouse_food": result.food_made, "greenhouse_oxygen": result.oxygen_made,
		"water_recovered": result.water_recovered}


## Which mission goals are done (id -> bool).
static func goals_done(state: Dictionary) -> Dictionary:
	return {
		&"greenhouse": int(state.modules.get(&"greenhouse", 0)) > 0,
		&"rover_blueprint": bool(state.research_done.get(&"rover_blueprint", false)),
		&"rover": int(state.modules.get(&"rover", 0)) > 0,
		&"explore": int(state.get("trips", 0)) > 0,
	}


## "playing", "won" or "lost", with the main cause when lost.
static func outcome(state: Dictionary) -> Dictionary:
	if float(state.crew_health) <= 0.0:
		var cause := "radiation"
		if not state.history.is_empty():
			var last: Dictionary = state.history[-1]
			var worst := 0.0
			for key in last.unmet_crew_needs:
				if float(last.unmet_crew_needs[key]) > worst:
					worst = float(last.unmet_crew_needs[key])
					cause = String(key)
		return {"status": &"lost", "cause": cause}
	for done in goals_done(state).values():
		if not done:
			return {"status": &"playing"}
	return {"status": &"won"}


static func _denied(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}
