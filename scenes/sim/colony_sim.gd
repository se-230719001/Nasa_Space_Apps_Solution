class_name ColonySim
extends RefCounted
## MoonMinds colony model — implements docs/game_systems_design.md.
##
## Turn based: the player makes decisions, then step_day() ends the day and
## returns a report. Every PROBLEM_EVERY days a known problem hits the colony.
## Building and upgrading are instant. Key rules:
## * Stock / production / consumption / capacity are kept apart.
## * Energy and water are SHARED by priority (life support first, hangar last);
##   inside one priority a shortage is split proportionally, and a building
##   runs at the fraction it received.
## * Electrolysis makes O2 from water + power and does NOT touch CO2; the CO2
##   filter is a separate system. Photosynthesis needs light + water + CO2.
## * The battery only stores energy, it never produces it.
## * Radiation only harms unprotected people (and slows plant growth that day);
##   it never deletes stored water, food or oxygen.
## * Health moves toward a TARGET set by how well needs are met, capped by the
##   Health Center level, so hoarding resources can't push it up forever.
## * No punishments: problems lower the health target and the mascot explains;
##   very low health brings an explained emergency supply from Earth.

enum P { LIFE, WATER, FOOD, HEALTH, SCIENCE, HANGAR }

## Per-level tables: index 0 = Lv1 ... index 3 = Lv4.
## costs[i] = materials to reach level i+1 (building is instant).
const BUILDINGS := {
	"life_support": {
		"name": "Life Support Center", "art": "main_base", "costs": [0, 60, 110, 180],
		"o2_out": [12.0, 18.0, 26.0, 34.0], "o2_energy": [15.0, 21.0, 28.0, 35.0], "o2_water": [4.0, 6.0, 8.0, 10.0],
		"scrub": [14.0, 18.0, 26.0, 34.0], "scrub_energy": [6.0, 7.0, 9.0, 11.0], "housing": [4, 8, 12, 16],
		"blurb": "Makes oxygen by splitting water (electrolysis) and cleans CO2 with a filter. Home for the crew.",
		"unlocks": ["Electrolysis + CO2 filter, 4 beds", "+50 % oxygen, 8 beds, CO2 filter on/off switch",
			"Stronger CO2 filter, 12 beds, early CO2 warning", "16 beds, Sabatier: turns CO2 back into water"],
	},
	"greenhouse": {
		"name": "Greenhouse", "art": "greenhouse", "costs": [30, 45, 70, 100],
		"food": [13.0, 17.5, 22.0, 26.0], "oxygen": [4.0, 5.4, 6.8, 8.0], "energy": [12.0, 15.0, 17.4, 19.2],
		"water": [10.0, 12.5, 14.5, 16.0], "co2": [5.0, 6.3, 7.3, 8.0],
		"blurb": "Plants turn light + water + CO2 into food and oxygen.",
		"unlocks": ["Basic food and oxygen", "+35 % harvest (needs more water and light)",
			"+70 % harvest", "+100 % harvest, hydroponics keep growing even with little CO2"],
	},
	"energy_center": {
		"name": "Energy Center", "art": "solar_panel", "costs": [20, 40, 70, 110],
		"energy_out": [40.0, 60.0, 85.0, 110.0], "battery": [100.0, 140.0, 260.0, 320.0],
		"blurb": "Solar panels make power from sunlight. The battery only STORES power for later.",
		"unlocks": ["40 power/day in full sun, battery 100", "Sun-tracking panels: 60 power/day",
			"85 power/day, big battery: 260", "Smart grid: 110 power/day, battery 320"],
	},
	"water_recycling": {
		"name": "Water Recycling Center", "art": "water_system", "costs": [25, 40, 65, 95],
		"recycle": [0.7, 0.8, 0.9, 0.95], "energy": [8.0, 9.0, 10.0, 11.0], "ice": [10.0, 12.0, 16.0, 20.0],
		"blurb": "Cleans used water so it can be used again. Never 100 %: a little is always lost.",
		"unlocks": ["Recycles 70 %, melts 10 ice/day", "80 % + 12 ice/day", "90 % + 16 ice/day", "95 % + 20 ice/day: almost closed loop"],
	},
	"health_center": {
		"name": "Health Center", "art": "habitat", "costs": [35, 50, 75, 110],
		"cap": [80.0, 88.0, 94.0, 100.0], "capacity": [6, 10, 14, 20], "energy": [5.0, 6.0, 7.0, 8.0],
		"blurb": "Keeps the crew healthy: check-ups, exercise and sleep programs.",
		"unlocks": ["Health up to 80, Exercise program", "Health up to 88, Sleep program",
			"Health up to 94, nutrition tracking (-10 % food)", "Health up to 100, sick bay: fast recovery"],
	},
	"radiation_lab": {
		"name": "Radiation Lab", "art": "research_lab", "costs": [40, 55, 80, 110],
		"protect": [0.0, 0.1, 0.1, 0.1], "energy": [6.0, 7.0, 8.0, 9.0],
		"science": [1.0, 1.5, 2.0, 2.5],
		"blurb": "Measures radiation, protects the crew and earns science points.",
		"unlocks": ["Radiation monitor, +1 science/day", "+10 % radiation protection, +1.5 science/day",
			"Storm shelter: the whole crew is safe", "Better space suits: safer missions"],
	},
	"hangar": {
		"name": "Hangar", "art": "hangar", "costs": [0, 70, 130, 200],
		"crafts": [1, 2, 3, 4],
		"blurb": "Builds and launches spacecraft to explore other worlds.",
		"unlocks": ["Moon rover", "Shuttle: reaches Mars", "Deep-space ship: Europa and asteroids", "Science ship: an extra research card from every mission"],
	},
}
## Shortage priority for shared energy (doc A.3).
const ENERGY_PRIORITY := {"life_support": P.LIFE, "water_recycling": P.WATER, "greenhouse": P.FOOD,
	"health_center": P.HEALTH, "radiation_lab": P.SCIENCE, "hangar": P.HANGAR}
const PER_PERSON := {"oxygen": 3.0, "water": 3.0, "food": 2.5, "co2": 3.0}
const CAPACITY := {"water": 200.0, "food": 150.0, "oxygen": 100.0}
const BASE_BATTERY := 40.0
const BASE_PROTECTION := 0.3
const NORMAL_RADIATION := 20.0
const STORM_RADIATION := 85.0
const CO2_SET_POINT := 35.0

## Spacecraft built in the hangar (doc B.7).
const CRAFTS := {
	"rover": {"name": "Moon Rover", "hangar": 1, "cost": 30, "days": 3, "range": 1},
	"shuttle": {"name": "Shuttle", "hangar": 2, "cost": 80, "days": 5, "range": 2},
	"deep": {"name": "Deep-Space Ship", "hangar": 3, "cost": 150, "days": 8, "range": 3},
}
## Destinations: range = which craft can go; days = one way and back.
const DESTINATIONS := {
	"shackleton": {"name": "Shackleton Crater", "body": "Moon", "range": 1, "days": 2, "fuel": 15.0,
		"materials": Vector2(30, 45), "science": 4.0, "water": 30.0, "card": 0.5,
		"lesson": "Polar craters never see the Sun, so ice can hide there."},
	"tycho": {"name": "Tycho Crater", "body": "Moon", "range": 1, "days": 3, "fuel": 20.0,
		"materials": Vector2(40, 60), "science": 6.0, "card": 0.6, "minerals": 0.25,
		"lesson": "Tycho is a young crater: its bright rays are rocks thrown out by an impact."},
	"jezero": {"name": "Jezero Crater", "body": "Mars", "range": 2, "days": 6, "fuel": 40.0,
		"materials": Vector2(70, 100), "science": 15.0, "card": 1.0, "minerals": 0.35,
		"lesson": "Jezero was a lake billions of years ago. Rivers left layered rocks there."},
	"europa": {"name": "Europa", "body": "Jupiter's moon", "range": 3, "days": 10, "fuel": 60.0,
		"materials": Vector2(30, 50), "science": 25.0, "water": 150.0, "card": 1.0,
		"lesson": "Under Europa's ice shell there may be a huge salty ocean."},
	"psyche": {"name": "Psyche", "body": "Asteroid belt", "range": 3, "days": 10, "fuel": 60.0,
		"materials": Vector2(150, 200), "science": 25.0, "card": 1.0, "minerals": 0.6,
		"lesson": "Psyche may be the metal core of a baby planet."},
}
const MISSION_CREW := 2

## Problems: one every PROBLEM_EVERY days, announced in advance (doc A.4: an
## early warning is a chance to prepare, not a punishment). `key` + `min`/`max`
## is checked at the end of the problem day.
const PROBLEM_EVERY := 5
const PROBLEMS := [
	{"id": "dust", "title": "Moon dust storm", "env": {"sun": 0.5}, "key": "energy", "min": 15.0,
		"text": "Dust will cover the solar panels: only half the power that day.",
		"prepare": "Fill the battery the days before: upgrade the Energy Center or use less power.",
		"good": "The battery had enough stored power, so every system kept working.",
		"bad": "The battery ran low, so power was shared: the lab and greenhouse got less.",
		"lesson": "A battery stores energy for days when the panels make less."},
	{"id": "pests", "title": "Greenhouse pests", "env": {"gh": 0.5}, "key": "food", "min": 30.0,
		"text": "Tiny bugs will eat plants: the greenhouse makes half the food that day.",
		"prepare": "Keep a food reserve: upgrade the Greenhouse before the problem day.",
		"good": "We had food saved, so nobody went hungry.",
		"bad": "Food got very low, and hungry people lose health.",
		"lesson": "A reserve protects you when one food source has a bad day."},
	{"id": "storm", "title": "Solar storm", "env": {"radiation": 85.0, "sun": 0.7}, "key": "health", "min": 60.0,
		"text": "Radiation will be very high for a day.",
		"prepare": "Radiation Lab: Lv 2 adds protection, Lv 3 builds a shelter for everyone.",
		"good": "The crew was protected and stayed healthy.",
		"bad": "Unprotected people got radiation and their health dropped. Stored water and food were fine!",
		"lesson": "Radiation can hurt people, but it doesn't spoil stored water or food."},
	{"id": "crew", "title": "New crew member", "crew": 1, "key": "oxygen", "min": 40.0,
		"text": "A new astronaut arrives and needs a bed, air, water and food.",
		"prepare": "Make room and air: upgrade Life Support (beds + oxygen) before they land.",
		"good": "There was enough air for everyone.",
		"bad": "One more person breathing made oxygen drop fast.",
		"lesson": "More people means more oxygen, water and food every single day."},
	{"id": "leak", "title": "Water pipe leak", "instant": {"water": -40.0}, "key": "water", "min": 25.0,
		"text": "A pipe will burst and 40 water will be lost.",
		"prepare": "Keep the tank full: upgrade Water Recycling.",
		"good": "We had plenty of water, so the leak was no big deal.",
		"bad": "Water got very low: plants and the oxygen maker had to share it.",
		"lesson": "Recycling and a full tank make a colony safe from surprises."},
	{"id": "filter", "title": "CO2 filter breakdown", "env": {"scrub": 0.0}, "key": "co2", "max": 65.0,
		"text": "The CO2 filter will stop for a day, so CO2 will rise.",
		"prepare": "Plants eat CO2 too: a Greenhouse (or a bigger one) helps.",
		"good": "The plants cleaned the air while the filter was off.",
		"bad": "CO2 went too high and the air got stuffy.",
		"lesson": "Two ways to clean the air (filter + plants) are safer than one."},
	{"id": "night", "title": "Long lunar night", "env": {"sun": 0.3}, "key": "energy", "min": 10.0,
		"text": "The Sun is behind the horizon: only a third of the power that day.",
		"prepare": "A big battery (Energy Center Lv 3) saves power for the night.",
		"good": "The battery got us through the night.",
		"bad": "The battery was empty, so systems had to share very little power.",
		"lesson": "Production, storage and use are three different things."},
]

## Research cards: found on missions, then researched with science points.
const CARDS := {
	"drip_irrigation": {"name": "Drip Irrigation", "science": 8.0, "needs": ["greenhouse", 2],
		"text": "Greenhouse needs 30 % less water."},
	"led_spectrum": {"name": "LED Grow Lights", "science": 12.0, "needs": ["greenhouse", 3],
		"text": "Greenhouse lights use 25 % less power."},
	"dust_cleaning": {"name": "Panel Dust Cleaning", "science": 6.0, "needs": ["energy_center", 1],
		"text": "Clean panels make 15 % more power."},
	"grey_water": {"name": "Grey-Water Filter", "science": 8.0, "needs": ["water_recycling", 2],
		"text": "Recycles 5 % more water."},
	"regolith_shield": {"name": "Regolith Shielding", "science": 10.0, "needs": ["radiation_lab", 1],
		"text": "Moon soil on the roofs: +15 % radiation protection."},
	"science_sensors": {"name": "Science Sensors", "science": 10.0, "needs": ["hangar", 1],
		"text": "Spacecraft find valuable minerals much more often."},
	"ion_engine": {"name": "Ion Engine", "science": 15.0, "needs": ["hangar", 2],
		"text": "Missions take 30 % fewer days and less fuel."},
	"nutrition_plan": {"name": "Nutrition Plan", "science": 8.0, "needs": ["health_center", 1],
		"text": "Smart menus: the crew needs 10 % less food."},
}

## Guided goals instead of years (doc C): each teaches one idea, no penalty.
const GOALS := [
	{"title": "Grow food", "text": "Build a Greenhouse.", "type": "level", "id": "greenhouse", "lv": 1, "reward": 20,
		"good": "Good: a Greenhouse adds about +14 food a day.", "bad": "Bad: no Greenhouse, food is gone in about 8 days.",
		"lesson": "Plants need light, water AND CO2 at the same time."},
	{"title": "Stay healthy", "text": "Build a Health Center.", "type": "level", "id": "health_center", "lv": 1, "reward": 20,
		"good": "Good: Health Center raises the health limit to 80 and unlocks exercise.", "bad": "Bad: without it health can never go above 70.",
		"lesson": "Health comes from meeting needs: air, water, food, sleep and exercise."},
	{"title": "Fresh air", "text": "Keep oxygen above 60 % for 5 days.", "type": "streak", "key": "oxygen", "min": 60.0, "days": 5, "reward": 20,
		"good": "Good: oxygen stays green, the dome rim glows green.", "bad": "Bad: oxygen drops, the dome turns red and health falls.",
		"lesson": "Electrolysis and plants make oxygen; every person breathes it."},
	{"title": "More power", "text": "Upgrade the Energy Center to Lv 2.", "type": "level", "id": "energy_center", "lv": 2, "reward": 25,
		"good": "Good: 60 power a day keeps every building running.", "bad": "Bad: power runs out, so the greenhouse and lab stop first.",
		"lesson": "Production and storage are different things: panels make power, batteries keep it."},
	{"title": "First vehicle", "text": "Build a Moon Rover in the Hangar.", "type": "craft", "reward": 20,
		"good": "Good: a rover can bring materials and research cards.", "bad": "Bad: without vehicles we can only use what we have.",
		"lesson": "Spacecraft cost a lot of materials, so plan before you build."},
	{"title": "First expedition", "text": "Finish a mission.", "type": "missions", "count": 1, "reward": 25,
		"good": "Good: science points and new research cards.", "bad": "Bad: plan it! A trip also uses fuel, oxygen and food.",
		"lesson": "Missions bring science points and research cards."},
	{"title": "Scientist", "text": "Research one card.", "type": "research", "count": 1, "reward": 25,
		"good": "Good: one research changes the colony forever.", "bad": "Bad: unused science points do nothing.",
		"lesson": "Research changes how much we produce or use."},
	{"title": "Safe from storms", "text": "Build a Radiation Lab.", "type": "level", "id": "radiation_lab", "lv": 1, "reward": 30,
		"good": "Good: radiation protection and science points every day.", "bad": "Bad: solar storms hurt unprotected people.",
		"lesson": "Radiation can't spoil stored water, but it can hurt people."},
	{"title": "Growing colony", "text": "Reach 6 crew members.", "type": "population", "count": 6, "reward": 30,
		"good": "Good: more people, more ideas, a bigger dome.", "bad": "Bad: growing without enough air and food makes everyone sick.",
		"lesson": "More people need more beds, air, water and food."},
	{"title": "Clean water", "text": "Upgrade Water Recycling to Lv 2.", "type": "level", "id": "water_recycling", "lv": 2, "reward": 30,
		"good": "Good: 80 % of water comes back.", "bad": "Bad: with poor recycling water drains every day.",
		"lesson": "Recycling is never 100 %: some water is always lost."},
	{"title": "To Mars!", "text": "Upgrade the Hangar to Lv 2 and finish a mission to Mars.", "type": "destination", "id": "jezero", "reward": 50,
		"good": "Good: lots of materials and science from Mars.", "bad": "Bad: a long trip needs a lot of oxygen and food packed.",
		"lesson": "Farther trips take longer and need more fuel, oxygen and food."},
	{"title": "Storm shelter", "text": "Upgrade the Radiation Lab to Lv 3.", "type": "level", "id": "radiation_lab", "lv": 3, "reward": 40,
		"good": "Good: storms can no longer hurt the crew.", "bad": "Bad: each storm costs health.",
		"lesson": "A shelter keeps the whole crew safe during solar storms."},
	{"title": "Closed loop", "text": "Upgrade Life Support to Lv 4.", "type": "level", "id": "life_support", "lv": 4, "reward": 60,
		"good": "Good: CO2 is turned back into water.", "bad": "Bad: CO2 and water are both lost.",
		"lesson": "The Sabatier reaction turns CO2 and hydrogen into water."},
	{"title": "Moon city", "text": "Reach 12 crew members.", "type": "population", "count": 12, "reward": 80,
		"good": "Good: a big, balanced Moon city!", "bad": "Bad: one missing system can pull the whole city down.",
		"lesson": "A big colony is a balance of many small systems."},
]

## --- State -------------------------------------------------------------------
var day := 1
var population := 4
var materials := 120.0
var science := 0.0
var levels := {"life_support": 1, "energy_center": 1, "water_recycling": 1, "hangar": 1}
var stock := {"energy": 70.0, "water": 160.0, "food": 90.0, "oxygen": 80.0}
var co2 := 40.0
var health := 75.0
var radiation := NORMAL_RADIATION
var sunlight := 1.0
var exercise_on := false
var sleep_on := false
var co2_filter_on := true
var crafts: Array = []          ## [{type, busy}]
var craft_builds: Array = []    ## [{type, days_left}]
var missions: Array = []        ## [{dest, craft, days_left}]
var cards_found: Array[String] = ["dust_cleaning", "nutrition_plan"]
var cards_done: Array[String] = []
var minerals := 0
var missions_done: Array[String] = []
var goal_index := 0
var goal_streak := 0
var storm_days := 0            ## > 0 while a solar storm is active (problem day)
var problem_day := PROBLEM_EVERY
var problem := {}               ## the next problem (announced)
var problems_passed := 0
var problems_seen := 0
var last_report := {}

var _arrival_timer := 0
var _emergency_cooldown := 0
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	_rng.seed = seed_value
	problem = problem_for(0)


## --- Helpers -------------------------------------------------------------------

func lv(id: String) -> int:
	return levels.get(id, 0)


func stat(id: String, key: String) -> float:
	var l := lv(id)
	return 0.0 if l == 0 else float(BUILDINGS[id][key][l - 1])


func has_card(id: String) -> bool:
	return id in cards_done


func battery_capacity() -> float:
	return BASE_BATTERY + stat("energy_center", "battery")


func housing() -> int:
	return int(stat("life_support", "housing"))


func protection() -> float:
	return minf(BASE_PROTECTION + stat("radiation_lab", "protect") + (0.15 if has_card("regolith_shield") else 0.0), 0.95)


func health_cap() -> float:
	return 70.0 if lv("health_center") == 0 else stat("health_center", "cap")


## Shares `supply` between requests [{id, amount, priority}] (doc A.3).
static func allocate(supply: float, requests: Array) -> Dictionary:
	var granted := {}
	var tiers := {}
	for r in requests:
		granted[r.id] = 0.0
		tiers.get_or_add(r.priority, []).append(r)
	var order := tiers.keys()
	order.sort()
	var left := maxf(supply, 0.0)
	for p in order:
		var want := 0.0
		for r in tiers[p]:
			want += r.amount
		if want <= 0.0:
			continue
		var share := minf(1.0, left / want)
		for r in tiers[p]:
			granted[r.id] += r.amount * share
		left -= want * share
	return granted


static func _frac(granted: Dictionary, id: String, amount: float) -> float:
	return 1.0 if amount <= 0.0 else clampf(granted.get(id, 0.0) / amount, 0.0, 1.0)


## Photosynthesis vs CO2 (doc A.2): too little CO2 slows plants, saturates at 130 %.
func photo_factor() -> float:
	var f: float
	if co2 < 20.0:
		f = 0.4 + co2 * 0.03
	else:
		f = minf(1.0 + (co2 - 20.0) / 40.0 * 0.3, 1.3)
	if lv("greenhouse") >= 4:
		f = maxf(f, 1.0)
	return f


## --- One day ----------------------------------------------------------------------

func step_day() -> Dictionary:
	var before := snapshot()
	var events: Array = []
	day += 1

	# Light and the day's problem (if today is a problem day)
	sunlight = 0.775 + 0.225 * cos(TAU * day / 24.0)   # simplified lunar day/night
	var prob: Dictionary = problem if day == problem_day else {}
	var env: Dictionary = prob.get("env", {})
	if prob.has("crew"):
		population += prob.crew
	for k in prob.get("instant", {}):
		stock[k] = clampf(stock[k] + prob.instant[k], 0.0, CAPACITY.get(k, 9999.0))
	radiation = env.get("radiation", NORMAL_RADIATION)
	var storm := radiation >= STORM_RADIATION
	storm_days = 1 if storm else 0
	var sun: float = sunlight * env.get("sun", 1.0)

	var mult_ex := 1.1 if exercise_on and lv("health_center") >= 1 else 1.0
	var food_mult := 0.9 if has_card("nutrition_plan") else 1.0
	food_mult *= 0.9 if lv("health_center") >= 3 else 1.0
	var crew_o2: float = population * PER_PERSON.oxygen * mult_ex
	var crew_water: float = population * PER_PERSON.water * mult_ex
	var crew_food: float = population * PER_PERSON.food * mult_ex * food_mult
	var crew_co2: float = population * PER_PERSON.co2

	# 1) ENERGY: production + battery, shared by priority
	var produced: float = stat("energy_center", "energy_out") * sun * (1.15 if has_card("dust_cleaning") else 1.0)
	var gh := lv("greenhouse") > 0
	var gh_energy: float = stat("greenhouse", "energy") * (0.75 if has_card("led_spectrum") else 1.0)
	var e_req := [
		{"id": "electrolysis", "amount": stat("life_support", "o2_energy"), "priority": P.LIFE},
		{"id": "co2_filter", "amount": stat("life_support", "scrub_energy") if co2_filter_on else 0.0, "priority": P.LIFE},
	]
	for id in ["water_recycling", "health_center", "radiation_lab"]:
		if lv(id) > 0:
			e_req.append({"id": id, "amount": stat(id, "energy"), "priority": ENERGY_PRIORITY[id]})
	if gh:
		e_req.append({"id": "greenhouse", "amount": gh_energy, "priority": P.FOOD})
	var e_supply: float = stock.energy + produced
	var e_got := allocate(e_supply, e_req)
	var e_used := 0.0
	var demand := 0.0
	for r in e_req:
		e_used += e_got[r.id]
		demand += r.amount
	stock.energy = minf(e_supply - e_used, battery_capacity())
	var eff := {}
	for r in e_req:
		eff[r.id] = _frac(e_got, r.id, r.amount)

	# 2) WATER: stock + ice, shared by priority (people first)
	var ice: float = stat("water_recycling", "ice") * eff.get("water_recycling", 0.0)
	var gh_water: float = stat("greenhouse", "water") * (0.7 if has_card("drip_irrigation") else 1.0) * eff.get("greenhouse", 0.0)
	var el_water: float = stat("life_support", "o2_water") * eff.electrolysis
	var w_req := [
		{"id": "crew", "amount": crew_water, "priority": P.LIFE},
		{"id": "electrolysis", "amount": el_water, "priority": P.LIFE},
		{"id": "greenhouse", "amount": gh_water, "priority": P.FOOD},
	]
	var w_supply: float = stock.water + ice
	var w_got := allocate(w_supply, w_req)
	var w_used: float = w_got.crew + w_got.electrolysis + w_got.greenhouse
	var rate := 0.5
	if lv("water_recycling") > 0:
		rate = lerpf(0.5, stat("water_recycling", "recycle") + (0.05 if has_card("grey_water") else 0.0), eff.get("water_recycling", 0.0))
	# Plants breathe out most of their water as vapour, which the air system condenses.
	var recycled: float = (w_got.crew + w_got.greenhouse * 0.9) * minf(rate, 0.97)
	var sabatier: float = 4.0 * eff.co2_filter if lv("life_support") >= 4 and co2_filter_on else 0.0
	stock.water = w_supply - w_used + recycled + sabatier

	var el_eff: float = eff.electrolysis * _frac(w_got, "electrolysis", el_water)
	var gh_eff: float = eff.get("greenhouse", 0.0) * _frac(w_got, "greenhouse", gh_water) * env.get("gh", 1.0) if gh else 0.0
	eff["electrolysis"] = el_eff
	if gh:
		eff["greenhouse"] = gh_eff
	var water_ok := _frac(w_got, "crew", crew_water)

	# 3) OXYGEN & CO2: electrolysis makes O2 only; filter and plants remove CO2
	var photo := photo_factor()
	var growth := 0.8 if storm and protection() < 0.6 else 1.0   # storm slows unprotected plants
	var o2_made: float = stat("life_support", "o2_out") * el_eff + stat("greenhouse", "oxygen") * gh_eff * photo * growth
	stock.oxygen += o2_made - crew_o2
	# The CO2 filter works like a thermostat: it only removes CO2 above its
	# set point (35), up to its capacity, so plants always keep some CO2.
	var plant_co2: float = stat("greenhouse", "co2") * gh_eff * photo
	var over: float = maxf(co2 + crew_co2 - plant_co2 - CO2_SET_POINT, 0.0)
	var scrubbed: float = minf(over, stat("life_support", "scrub") * eff.co2_filter * env.get("scrub", 1.0)) if co2_filter_on else 0.0
	co2 = clampf(co2 + crew_co2 - scrubbed - plant_co2, 0.0, 100.0)

	# 4) FOOD
	var food_made: float = stat("greenhouse", "food") * gh_eff * photo * growth
	stock.food += food_made - crew_food

	var o2_ok := 1.0 if stock.oxygen > 0.0 else clampf((o2_made + stock.oxygen + crew_o2) / crew_o2, 0.0, 1.0)
	var food_ok := 1.0 if stock.food > 0.0 else clampf((food_made + stock.food + crew_food) / crew_food, 0.0, 1.0)
	for k in CAPACITY:
		stock[k] = clampf(stock[k], 0.0, CAPACITY[k])

	# 5) HEALTH: move toward a needs-based target (doc A.1)
	var shelter := storm and lv("radiation_lab") >= 3
	var exposure := 0.0 if shelter else radiation * (1.0 - protection())
	var needs := minf(minf(o2_ok, water_ok), food_ok)
	var cap := health_cap()
	var crowded := lv("health_center") > 0 and population > int(stat("health_center", "capacity"))
	var bonus := 0.0
	if exercise_on and lv("health_center") >= 1:
		bonus += 5.0
	if sleep_on and lv("health_center") >= 2:
		bonus += 5.0
	if crowded:
		bonus *= 0.5
	var target := cap * needs + bonus - exposure * 0.4 - maxf(co2 - 70.0, 0.0)
	target = clampf(target, 0.0, cap)
	var speed := 0.2 if lv("health_center") >= 4 and target > health else 0.1
	health += (target - health) * speed

	# 6) SCIENCE
	science += stat("radiation_lab", "science") * eff.get("radiation_lab", 0.0)

	# 7) Crafts and missions
	for c in craft_builds.duplicate():
		c.days_left -= 1
		if c.days_left <= 0:
			crafts.append({"type": c.type, "busy": false})
			craft_builds.erase(c)
			events.append({"type": "craft", "craft": c.type})
	for m in missions.duplicate():
		m.days_left -= 1
		if m.days_left <= 0:
			missions.erase(m)
			events.append(_finish_mission(m))

	# 8) Population and Earth support
	_arrival_timer += 1
	# A new person only comes when there is a bed and the colony already makes
	# at least as much oxygen and food as it uses (it can't outgrow itself).
	if _arrival_timer >= 10 and population < housing() and health >= 60.0 \
			and o2_made >= crew_o2 and food_made >= crew_food * 0.9 and stock.food > population * 10.0:
		population += 1
		_arrival_timer = 0
		events.append("arrival")
	if day % 7 == 0:
		materials += 15.0
		events.append("supply")
	_emergency_cooldown = maxi(_emergency_cooldown - 1, 0)
	if health < 25.0 and _emergency_cooldown == 0:
		for k in ["food", "water", "oxygen"]:
			stock[k] = minf(stock[k] + 40.0, CAPACITY[k])
		_emergency_cooldown = 15
		events.append("emergency")

	# 9) The problem day's result (good or bad, always explained)
	if not prob.is_empty():
		events.append(_resolve_problem(prob))

	var after := snapshot()
	var delta := {}
	for k in after:
		delta[k] = after[k] - before[k]
	last_report = {"day": day, "delta": delta, "efficiency": eff, "events": events, "storm": storm,
		"energy_produced": produced, "energy_demand": demand, "exposure": exposure, "photo": photo,
		"recycle_rate": rate, "o2_made": o2_made, "o2_used": crew_o2, "food_made": food_made,
		"food_used": crew_food, "scrubbed": scrubbed, "crew_co2": crew_co2}
	_check_goal(events)
	last_report["advice"] = advice()
	return last_report


## --- Building ----------------------------------------------------------------------

func upgrade_cost(id: String) -> int:
	var next := lv(id) + 1
	return -1 if next > 4 else int(BUILDINGS[id].costs[next - 1])


## "" if the building can be built/upgraded now, otherwise why not.
func why_not_build(id: String) -> String:
	var cost := upgrade_cost(id)
	if cost < 0:
		return "Already at the top level (Lv 4)."
	if materials < cost:
		return "Needs %d more materials." % ceili(cost - materials)
	return ""


## Builds or upgrades right away (no construction time).
func start_build(id: String) -> bool:
	if why_not_build(id) != "":
		return false
	materials -= upgrade_cost(id)
	levels[id] = lv(id) + 1
	return true


## Simulates a few days with and without an upgrade to show its trade-off.
func preview_upgrade(id: String, days := 4) -> Dictionary:
	var a := _forecast(func(_s) -> void: pass, days)
	var b := _forecast(func(s) -> void: s.levels[id] = s.lv(id) + 1, days)
	var diff := {}
	for k in a:
		diff[k] = (b[k] - a[k]) / days
	return diff


## --- Research ----------------------------------------------------------------------

func why_not_research(card: String) -> String:
	var c: Dictionary = CARDS[card]
	if has_card(card):
		return "Already researched."
	if card not in cards_found:
		return "Find this card on a mission first."
	if lv(c.needs[0]) < c.needs[1]:
		return "Needs %s Lv %d." % [BUILDINGS[c.needs[0]].name, c.needs[1]]
	if science < c.science:
		return "Needs %d more science points." % ceili(c.science - science)
	return ""


func research(card: String) -> bool:
	if why_not_research(card) != "":
		return false
	science -= CARDS[card].science
	cards_done.append(card)
	return true


## --- Hangar ------------------------------------------------------------------------

func why_not_craft(type: String) -> String:
	var c: Dictionary = CRAFTS[type]
	if lv("hangar") < c.hangar:
		return "Needs Hangar Lv %d." % c.hangar
	if crafts.size() + craft_builds.size() >= int(stat("hangar", "crafts")):
		return "The hangar is full (room for %d)." % int(stat("hangar", "crafts"))
	if materials < c.cost:
		return "Needs %d more materials." % ceili(c.cost - materials)
	return ""


func build_craft(type: String) -> bool:
	if why_not_craft(type) != "":
		return false
	materials -= CRAFTS[type].cost
	craft_builds.append({"type": type, "days_left": CRAFTS[type].days})
	return true


func mission_days(dest: String) -> int:
	var d: int = DESTINATIONS[dest].days
	return maxi(1, roundi(d * 0.7)) if has_card("ion_engine") else d


func mission_needs(dest: String) -> Dictionary:
	var days := mission_days(dest)
	var fuel: float = DESTINATIONS[dest].fuel * (0.7 if has_card("ion_engine") else 1.0)
	return {"energy": fuel, "oxygen": MISSION_CREW * PER_PERSON.oxygen * days * 0.5,
		"food": MISSION_CREW * PER_PERSON.food * days * 0.5}


func free_craft(range_needed: int) -> int:
	for i in crafts.size():
		if not crafts[i].busy and CRAFTS[crafts[i].type].range >= range_needed:
			return i
	return -1


func why_not_launch(dest: String) -> String:
	var d: Dictionary = DESTINATIONS[dest]
	if free_craft(d.range) < 0:
		var names := {1: "a Moon Rover", 2: "a Shuttle", 3: "a Deep-Space Ship"}
		return "Needs %s that is free." % names[d.range]
	var need := mission_needs(dest)
	for k in need:
		if stock[k] < need[k] + 5.0:
			return "Not enough %s for the trip." % ("power" if k == "energy" else k)
	return ""


func launch(dest: String) -> bool:
	if why_not_launch(dest) != "":
		return false
	var i := free_craft(DESTINATIONS[dest].range)
	crafts[i].busy = true
	var need := mission_needs(dest)
	for k in need:
		stock[k] -= need[k]
	missions.append({"dest": dest, "craft": i, "days_left": mission_days(dest)})
	return true


func _finish_mission(m: Dictionary) -> Dictionary:
	var d: Dictionary = DESTINATIONS[m.dest]
	crafts[m.craft].busy = false
	var r := {"type": "mission", "dest": m.dest, "name": d.name, "lesson": d.lesson}
	var mats := _rng.randf_range(d.materials.x, d.materials.y)
	materials += mats
	r["materials"] = roundi(mats)
	science += d.science
	r["science"] = roundi(d.science)
	if d.has("water"):
		stock.water = minf(stock.water + d.water, CAPACITY.water)
		r["water"] = roundi(d.water)
	var mineral_chance: float = d.get("minerals", 0.0) * (2.0 if has_card("science_sensors") else 1.0)
	if _rng.randf() < mineral_chance:
		minerals += 1
		materials += 40.0
		r["minerals"] = 1
	var card_chance: float = d.card + (0.5 if lv("hangar") >= 4 else 0.0)
	var new_cards := []
	for i in (2 if card_chance > 1.0 else 1):
		if _rng.randf() < minf(card_chance, 1.0):
			var pool := CARDS.keys().filter(func(c: String) -> bool: return c not in cards_found)
			if not pool.is_empty():
				var c: String = pool[_rng.randi() % pool.size()]
				cards_found.append(c)
				new_cards.append(c)
	r["cards"] = new_cards
	if lv("radiation_lab") < 4 and d.range >= 2:
		health = maxf(health - 3.0, 0.0)   # deep-space radiation without better suits
		r["suit_warning"] = true
	if m.dest not in missions_done:
		missions_done.append(m.dest)
	return r


## --- Problems ------------------------------------------------------------------------

## The n-th problem. After the first round they come back a bit harder.
func problem_for(n: int) -> Dictionary:
	var p: Dictionary = PROBLEMS[n % PROBLEMS.size()].duplicate(true)
	var round_ := n / PROBLEMS.size()
	if round_ > 0:
		p.title += " (harder)"
		if p.has("min") and p.key != "health":
			p.min = minf(p.min + 10.0 * round_, 60.0)
		for k in p.get("env", {}):
			if k in ["sun", "gh"]:
				p.env[k] = maxf(p.env[k] - 0.1 * round_, 0.1)
		if p.has("instant"):
			p.instant.water = p.instant.water * (1.0 + 0.5 * round_)
	return p


func days_to_problem() -> int:
	return problem_day - day


func _resolve_problem(p: Dictionary) -> Dictionary:
	var value := value_of(p.key)
	var ok: bool = value >= p.min if p.has("min") else value <= p.max
	problems_seen += 1
	var r := {"type": "problem", "problem": p, "passed": ok, "value": value,
		"text": p.good if ok else p.bad, "lesson": p.lesson}
	if ok:
		problems_passed += 1
		materials += 20.0
		r["reward"] = 20
	problem_day += PROBLEM_EVERY
	problem = problem_for(problems_seen)
	return r


func value_of(key: String) -> float:
	return co2 if key == "co2" else float(levels_view()[key])


## A concrete next step for the TAKE HINT button (most urgent first).
func hint() -> Dictionary:
	var d := days_to_problem()
	var key: String = problem.key
	var now := value_of(key)
	var ready: bool = now >= problem.min + 15.0 if problem.has("min") else now <= problem.max - 15.0
	if d <= 3 and not ready:
		return _tip(&"warning", "Get ready: %s in %d day%s" % [problem.title, d, "" if d == 1 else "s"], problem.prepare)
	var worst := ""
	var worst_status := 0
	for k in ["oxygen", "water", "food", "energy", "health"]:
		if status_of(k) > worst_status:
			worst_status = status_of(k)
			worst = k
	var fix := {
		"oxygen": "Open BUILD and upgrade Life Support (more electrolysis) or the Greenhouse (plants make oxygen).",
		"water": "Open BUILD and upgrade Water Recycling: more water comes back every day.",
		"food": "Open BUILD and build or upgrade the Greenhouse.",
		"energy": "Open BUILD and upgrade the Energy Center. Fewer buildings also means less power used.",
		"health": "Build or upgrade the Health Center, then turn on Exercise and Sleep in its panel.",
	}
	if worst != "":
		return _tip(&"warning", "%s needs help" % worst.capitalize(), fix[worst])
	var g := current_goal()
	if not g.is_empty():
		return _tip(&"info", "Next goal: %s" % g.title, "%s %s" % [g.text, g.good])
	return _tip(&"success", "All good!", "Everything is balanced. Try a mission from EXPLORE to find new research cards.")


## --- Goals --------------------------------------------------------------------------

func current_goal() -> Dictionary:
	return GOALS[goal_index] if goal_index < GOALS.size() else {}


func _check_goal(events: Array) -> void:
	var g := current_goal()
	if g.is_empty():
		return
	var done := false
	match g.type:
		"level":
			done = lv(g.id) >= g.lv
		"streak":
			goal_streak = goal_streak + 1 if levels_view()[g.key] >= g.min else 0
			done = goal_streak >= g.days
		"craft":
			done = not crafts.is_empty()
		"missions":
			done = missions_done.size() >= g.count
		"research":
			done = cards_done.size() >= g.count
		"population":
			done = population >= g.count
		"destination":
			done = g.id in missions_done
	if done:
		materials += g.reward
		events.append({"type": "goal", "goal": g})
		goal_index += 1
		goal_streak = 0


## Re-check goals right away after an action (not only at day end).
func check_goals_now() -> Array:
	var ev := []
	_check_goal(ev)
	return ev


## --- Read-outs ----------------------------------------------------------------------

## 0..100 values for the HUD.
func levels_view() -> Dictionary:
	return {
		"health": health,
		"food": stock.food / CAPACITY.food * 100.0,
		"water": stock.water / CAPACITY.water * 100.0,
		"energy": stock.energy / battery_capacity() * 100.0,
		"oxygen": stock.oxygen / CAPACITY.oxygen * 100.0,
	}


func snapshot() -> Dictionary:
	var s := levels_view()
	s["co2"] = co2
	return s


func days_left(key: String, fallback := INF) -> float:
	var d: float = last_report.get("delta", {}).get(key, 0.0)
	if last_report.is_empty() or d >= -0.01:
		return fallback if fallback != 0.0 else INF
	return levels_view()[key] / -d


## 0 healthy, 1 warning, 2 critical — level and trend together.
func status_of(key: String) -> int:
	var v: float = levels_view()[key]
	var dl := days_left(key)
	if v <= 15.0 or dl < 2.0:
		return 2
	if v <= 35.0 or dl < 5.0:
		return 1
	return 0


## Observation -> cause -> next action, most urgent first (no blame).
func advice() -> Dictionary:
	var r := last_report
	var lvs := levels_view()
	var eff: Dictionary = r.get("efficiency", {})
	if r.get("storm", false):
		if lv("radiation_lab") >= 3:
			return _tip(&"info", "Solar storm — crew in the shelter", "Radiation is high outside, but our shelter keeps everyone safe.")
		return _tip(&"warning", "Solar storm!", "Radiation can hurt people (not our stored water). A Radiation Lab shelter would protect the crew.")
	if days_to_problem() <= 2:
		return _tip(&"warning", "%s in %d day%s" % [problem.title, days_to_problem(), "" if days_to_problem() == 1 else "s"], problem.prepare)
	if lvs.oxygen < 30.0 or (status_of("oxygen") > 0 and lvs.oxygen < 60.0):
		return _tip(&"warning", "Oxygen is going down", "Every person breathes oxygen. Upgrade Life Support (electrolysis) or add plants in a Greenhouse.")
	var starved := []
	for id in ["electrolysis", "greenhouse", "water_recycling", "health_center", "radiation_lab"]:
		if eff.has(id) and eff[id] < 0.95:
			starved.append(id)
	if not starved.is_empty() or status_of("energy") > 0:
		var made: float = r.get("energy_produced", 0.0)
		var used: float = r.get("energy_demand", 0.0)
		if made >= used and starved.is_empty():
			return _tip(&"info", "Battery is low but filling up", "We make %d power and use %d, so the battery charges a little every day. Wait before adding power-hungry buildings." % [made, used])
		return _tip(&"warning", "Need more power", "We use %d power a day but make only %d. Upgrade the Energy Center. Remember: the battery stores power, it doesn't make it." % [used, made])
	if status_of("water") > 0:
		return _tip(&"warning", "Water is going down", "People, plants and the oxygen maker all use water. Better recycling saves the most.")
	if status_of("food") > 0:
		return _tip(&"warning", "Food is going down", "The crew eats more than we grow. A Greenhouse (or a bigger one) helps.")
	if r.get("photo", 1.0) < 0.9 and lv("greenhouse") > 0:
		return _tip(&"info", "Plants need CO2", "There is very little CO2, so plants grow slowly. More people breathing out, or the CO2 filter switched off for a while, feeds the plants.")
	if co2 > 70.0:
		return _tip(&"warning", "Too much CO2", "The air is stuffy. The CO2 filter and plants clean it.")
	if health < 60.0:
		return _tip(&"warning", "The crew feels tired", "Health follows needs: air, water, food, sleep and exercise. A Health Center raises the limit.")
	return _tip(&"success", "Great balance!", "Everything the crew needs is covered.")


static func _tip(kind: StringName, title: String, text: String) -> Dictionary:
	return {"kind": kind, "title": title, "text": text}


func _forecast(change: Callable, days: int) -> Dictionary:
	var s = (get_script() as GDScript).new(1)
	for p in ["day", "population", "materials", "science", "co2", "health", "exercise_on", "sleep_on", "co2_filter_on"]:
		s.set(p, get(p))
	s.levels = levels.duplicate()
	s.stock = stock.duplicate()
	s.cards_done = cards_done.duplicate()
	s.problem_day = 999999
	change.call(s)
	var start: Dictionary = s.snapshot()
	for i in days:
		s.step_day()
	var end: Dictionary = s.snapshot()
	var d := {}
	for k in end:
		d[k] = end[k] - start[k]
	return d
