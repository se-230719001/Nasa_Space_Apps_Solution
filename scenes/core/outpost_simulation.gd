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
	## A replica of NASA's Apollo Lunar Module to place in the base (a landmark:
	## no game effect, never upgraded).
	&"lander": {"kit_cost": 0.0, "upgrade_kits": [0.0, 0.0, 0.0], "max_level": 1},
	## Decorations unlocked at campaign milestones (Stage 8): looks only.
	&"lamp": {"kit_cost": 0.0, "upgrade_kits": [0.0, 0.0, 0.0], "max_level": 1},
	&"antenna": {"kit_cost": 0.0, "upgrade_kits": [0.0, 0.0, 0.0], "max_level": 1},
	&"moon_garden": {"kit_cost": 0.0, "upgrade_kits": [0.0, 0.0, 0.0], "max_level": 1},
	&"rover": {"kit_cost": 8.0, "upgrade_kits": [0.0, 4.0, 6.0], "explore_cost": [{}, {&"power": 8.0, &"water": 3.0, &"oxygen": 2.0}, {&"power": 7.0, &"water": 3.0, &"oxygen": 2.0}, {&"power": 6.0, &"water": 2.0, &"oxygen": 1.0}], "science": [0, 1, 2, 3], "ice": [0.0, 6.0, 7.0, 8.0]},
}

## Each finished day task pays this many build kits.
const TASK_KITS := 2.0
## The long-term goal every day's mission builds toward.
const MAIN_MISSION := {"title": "South Pole Science Base",
	"text": "Get a safe base ready at the Moon's south pole, so the science team can come and study the ice."}

## One mission per day, in teaching order (one new idea a day). The next day
## starts only when today's mission is done; later days stay hidden until then.
## `tip` names the trade-off, `idea` the one science idea of the day, `watch`
## the store (or &"health") whose change the player predicts (null = none).
## `why` is the after-mission "why did it work?" question (general science,
## no historical claim): answering earns a star either way (Stage 8).
## `quiz` asks the player to predict the fix before NASA's is shown: one
## option is what NASA really did (from `story.did`), the others are tempting
## ideas with a kind hint; `same`/`different` compare it with the game.
## `story` is a real NASA event with the same kind of problem (checked against
## the linked NASA page on 2026-11-15); `note` says when it was not on the Moon. `problem` and `did`
## may mark key words with **bold** (highlighted in the briefing, see OutpostHUD.md). Each day is a list so a day could hold more later.
## shortcut: one fixed mission chain, move to per-mission data in Phase 1.
const DAY_TASKS := [
	[{"id": &"greenhouse", "watch": &"food", "idea": "Plants need light, water and power to grow food.", "text": "Build a Greenhouse", "tip": "Plants make food and oxygen, but drink water and use power.", "story": {"name": "Veggie zinnias", "where": "International Space Station, 2015-2016", "note": "Not on the Moon: this happened on the Space Station.", "problem": "**Mold** grew on the zinnia flowers in the Veggie plant garden, and the plants were not doing well.", "did": "Astronaut Scott Kelly **cut off the moldy parts** and, with a one-page care guide, decided by himself when the plants needed water. They bloomed in January 2016.", "url": "https://www.nasa.gov/humans-in-space/zinnias-from-space-nasa-studies-the-multiple-benefits-of-gardening/"}, "quiz": {"question": "Mold is growing on the space flowers. What would you try?", "options": [{"text": "Give the plants lots more water", "correct": false, "hint": "Mold loves wet places. More water would help the mold!"}, {"text": "Cut off the moldy parts, water only when needed", "correct": true, "hint": ""}, {"text": "Turn off the plant lights for a week", "correct": false, "hint": "Plants need light to grow. In the dark they get weaker."}], "same": "Plants need light, water and care, on the Station and in your base.", "different": "Veggie was on the Space Station. Your greenhouse is on the Moon, and its numbers are made up."}, "why": {"question": "Why did cutting off the moldy parts help?", "options": [{"text": "Mold spreads, so taking it away keeps healthy leaves safe", "correct": true}, {"text": "Plants grow faster with fewer leaves", "correct": false}], "explain": "Mold spreads from sick parts to healthy ones. Removing it early protects the rest of the plant."}}],
	[{"id": &"ice_drill", "watch": &"water", "idea": "Ice is frozen water. Melting it gives the crew water.", "text": "Build an Ice Drill", "tip": "More water every day, but it is very hungry for power.", "story": {"name": "LCROSS", "where": "Cabeus crater, Moon's south pole, October 9, 2009", "note": "No astronaut was there: robot spacecraft did it.", "problem": "Nobody knew for sure if there was **water ice** in the Moon's dark craters.", "did": "NASA crashed a used rocket stage into Cabeus crater. A spacecraft flew through the dust cloud and **found water ice**.", "url": "https://www.nasa.gov/general/what-is-lcross-the-lunar-crater-observation-and-sensing-satellite/"}, "quiz": {"question": "How can we find out if a dark crater has ice?", "options": [{"text": "Wait for the Sun to shine into the crater", "correct": false, "hint": "Some polar craters never get sun. On NASA's map, about 1 in 10 spots near the pole stay dark!"}, {"text": "Look at it from Earth with a phone camera", "correct": false, "hint": "The crater is dark and very far away. A phone can't see inside."}, {"text": "Crash something in and study the dust cloud", "correct": true, "hint": ""}], "same": "Ice in dark polar craters could become water for a Moon base.", "different": "LCROSS was a robot crash, not a drill. Your Ice Drill is a game idea."}, "why": {"question": "Why look for ice in craters that never see the Sun?", "options": [{"text": "Darkness makes ice out of rocks", "correct": false}, {"text": "It is so cold there that ice can last a very long time", "correct": true}], "explain": "Sunlight warms things up. Where it never shines it stays extremely cold, so ice doesn't melt away."}}],
	[{"id": &"rover_blueprint", "watch": null, "idea": "Scientists study samples to design new machines.", "text": "Research: Rover Plan", "tip": "Research uses your science sample and some power.", "story": {"name": "Apollo 14 at Cone Crater", "where": "Fra Mauro, Moon, February 1971", "note": "", "problem": "Alan Shepard and Edgar Mitchell walked uphill **pulling a two-wheeled cart**. It was hard work, and they turned back before seeing into the crater.", "did": "The next mission, Apollo 15, brought **the first Moon car**: the Lunar Roving Vehicle.", "url": "https://www.nasa.gov/history/50-years-ago-apollo-14-lands-at-fra-mauro/"}, "quiz": {"question": "Pulling a cart uphill on the Moon was hard work. What would help next time?", "options": [{"text": "A car that carries astronauts and tools", "correct": true, "hint": ""}, {"text": "Carry everything in their arms", "correct": false, "hint": "Space suits are stiff and arms get tired fast. They need help, not more carrying."}, {"text": "Walk faster", "correct": false, "hint": "Rushing in a big suit is tiring and risky. They need help, not speed."}], "same": "Going far on the Moon needs a vehicle.", "different": "The real rover was built on Earth. In your base you research a rover plan."}, "why": {"question": "Why does a rover help explorers?", "options": [{"text": "It carries people and tools farther, with less tiring work", "correct": true}, {"text": "It makes the Moon's gravity stronger", "correct": false}], "explain": "Walking in a big suit is tiring. Wheels and a motor do the hard work, so explorers can go farther."}}],
	[{"id": &"solar_upgrade", "watch": &"power", "idea": "More panels catch more sunlight, even when the sun is weak.", "text": "Low sun! Upgrade the Solar panels", "tip": "More panels catch more of the weak sunlight, but cost kits.", "story": {"name": "iROSA (Roll-Out Solar Arrays)", "where": "International Space Station, from June 2021", "note": "Not on the Moon: this happened on the Space Station.", "problem": "The station's old solar wings were **wearing out** after more than 15 years.", "did": "Spacewalkers added **new roll-out solar arrays** to make more power again.", "url": "https://www.nasa.gov/missions/station/iss-research/power-up-roll-out-solar-arrays-boost-space-station-power-supply/"}, "quiz": {"question": "The old solar wings are wearing out. What gives more power?", "options": [{"text": "Turn on more machines", "correct": false, "hint": "Machines use power, they don't make it."}, {"text": "Point the panels away from the Sun", "correct": false, "hint": "Panels make power from sunlight. Away from the Sun they make less."}, {"text": "Add new solar arrays", "correct": true, "hint": ""}], "same": "More solar panels catch more sunlight.", "different": "iROSA was on the Space Station. Your panels are on the Moon, where the Sun stays low near the pole."}, "why": {"question": "Why do more solar panels give more power?", "options": [{"text": "Panels make power from darkness", "correct": false}, {"text": "More panel area catches more sunlight", "correct": true}], "explain": "Each panel turns the sunlight that hits it into power. More panels catch more of it."}}],
	[{"id": &"rover", "watch": null, "idea": "A rover can drive far from the base, where walking is hard.", "text": "Build the Rover", "tip": "The rover costs 8 kits, but it can reach ice and samples.", "story": {"name": "Apollo 15 Lunar Roving Vehicle", "where": "Hadley-Apennine, Moon, July 1971", "note": "", "problem": "On the first drive of the first Moon car, the **front-wheel steering did not work**.", "did": "Dave Scott drove with **only the back wheels** steering. On the next drive the front steering worked again.", "url": "https://www.nasa.gov/image-article/this-week-nasa-history-apollo-15-astronauts-deploy-first-lunar-roving-vehicle-july-31-1971/"}, "quiz": {"question": "The rover's front wheels won't steer! What would you do?", "options": [{"text": "Drive carefully with the back-wheel steering", "correct": true, "hint": ""}, {"text": "Give up and walk back", "correct": false, "hint": "The rover still works. Is there another way to steer it?"}, {"text": "Hit the wheels with a hammer", "correct": false, "hint": "Hitting could break more parts. Try using what still works."}], "same": "Use what still works, and keep going.", "different": "Dave Scott drove a real rover. Yours is a game model."}, "why": {"question": "Why could the rover still drive with only its back wheels steering?", "options": [{"text": "Turning the back wheels still changes the rover's direction", "correct": true}, {"text": "On the Moon you never need to turn", "correct": false}], "explain": "Any wheels that turn can steer, the back ones too. It is just a bit trickier."}}],
	[{"id": &"explore", "watch": null, "idea": "Ice and rocks far away can tell us about the Moon.", "text": "Go on a field trip", "tip": "Trips cost power, water and oxygen, but bring science and ice.", "story": {"name": "Apollo 17 fender repair", "where": "Taurus-Littrow, Moon, December 1972", "note": "", "problem": "A rover **fender broke**, so the wheels threw dust all over Gene Cernan and Harrison Schmitt. Tape did not stick to the dusty parts.", "did": "Mission Control helped them build a new fender from **four maps, tape and clamps**, and the field trips went on.", "url": "https://www.nasa.gov/image-article/duct-tape-saves-day/"}, "quiz": {"question": "The fender broke and dust flies everywhere. What could fix it?", "options": [{"text": "Wipe the dust off every few minutes", "correct": false, "hint": "The wheels throw new dust all the time. Stop it at the wheel!"}, {"text": "Make a new fender from maps, tape and clamps", "correct": true, "hint": ""}, {"text": "Drive much faster", "correct": false, "hint": "Faster wheels throw even more dust."}], "same": "Fix things with what you have on board.", "different": "Apollo 17's repair was real. Your field trip and its numbers are a game."}, "why": {"question": "Why did a fender matter so much on the Moon?", "options": [{"text": "Fenders make the rover go faster", "correct": false}, {"text": "Moon dust is clingy and scratchy and gets everywhere", "correct": true}], "explain": "Moon dust sticks to everything and scratches things. A fender keeps it off the explorers and their tools."}}],
	[{"id": &"radiation_map", "watch": null, "idea": "Space radiation is invisible, so we map where it is strong.", "text": "Research: Radiation Map", "tip": "Uses your new sample. Unlocks the Shield and brings 8 kits.", "story": {"name": "August 1972 solar storm", "where": "Between Apollo 16 and Apollo 17, August 4-7, 1972", "note": "Luckily no astronauts were in space then.", "problem": "Huge **solar flares** sent dangerous radiation through space, toward where Moon crews would travel.", "did": "Today NASA and NOAA **watch the Sun** day and night during Moon flights, so crews get a warning.", "url": "https://science.nasa.gov/science-research/heliophysics/how-nasa-will-protect-astronauts-from-space-radiation-at-the-moon/"}, "quiz": {"question": "Solar storms can be dangerous. How can crews stay safe?", "options": [{"text": "Hope a storm won't happen", "correct": false, "hint": "Storms can come with little warning. What would give the crew time to get safe?"}, {"text": "Watch the Sun day and night for warnings", "correct": true, "hint": ""}, {"text": "Open a window to check outside", "correct": false, "hint": "Space has no air to breathe, and a window doesn't stop radiation."}], "same": "Knowing when radiation is strong keeps crews safe.", "different": "NASA and NOAA watch the real Sun. Your radiation map and its numbers are made up."}, "why": {"question": "Why is a warning about solar storms useful?", "options": [{"text": "It gives the crew time to get to a safer place", "correct": true}, {"text": "A warning makes the storm smaller", "correct": false}], "explain": "We can't stop a storm, but knowing it is coming gives the crew time to protect themselves."}}],
	[{"id": &"shield", "watch": &"health", "idea": "A shield blocks part of the space radiation.", "text": "Build a Shield before the storm", "tip": "Protects the crew from radiation, but uses power every day.", "story": {"name": "Orion storm shelter", "where": "Orion spacecraft, Artemis program", "note": "Not a Moon base: this is the plan inside the Orion capsule.", "problem": "If a solar storm comes, the crew needs a **safer spot** inside the capsule.", "did": "The crew builds a shelter in the middle of the cabin by **moving stowage bags** around them, to block radiation.", "url": "https://www.nasa.gov/missions/artemis/orion/scientists-and-engineers-evaluate-orion-radiation-protection-plan/"}, "quiz": {"question": "A solar storm is coming! Where should the crew go?", "options": [{"text": "Next to the thinnest wall", "correct": false, "hint": "Thin walls stop less radiation. More stuff between you and space is better."}, {"text": "Outside, to look at the storm", "correct": false, "hint": "Outside there is the least protection of all!"}, {"text": "Into a shelter in the middle, with bags around them", "correct": true, "hint": ""}], "same": "More stuff around the crew blocks more radiation.", "different": "Orion's shelter is inside a space capsule. Your Shield is a game building."}, "why": {"question": "Why stay behind walls and bags in a solar storm?", "options": [{"text": "Bags make the storm go away", "correct": false}, {"text": "More stuff between you and space blocks more radiation", "correct": true}], "explain": "Radiation is slowed down by the material it passes through. The more stuff in the way, the less reaches you."}}],
]
## Training campaigns the player picks at the start. `years` is the span of
## the real NASA events its days are based on (not data for those dates).
## `days` are mission ids from DAY_TASKS, in play order.
const CAMPAIGNS := {
	&"apollo": {"name": "Apollo Explorer", "years": "1971-1972",
		"text": "Drive and explore the Moon like the Apollo crews.",
		"days": [&"rover_blueprint", &"rover", &"explore"]},
	&"base": {"name": "Moon Base Builder", "years": "1972-2022",
		"text": "Water, food, power and safety for a Moon base.",
		"days": [&"ice_drill", &"greenhouse", &"solar_upgrade", &"radiation_map", &"shield"]},
	&"full": {"name": "Full Mission", "years": "1971-2022",
		"text": "All eight real NASA problems, one a day.",
		"days": [&"greenhouse", &"ice_drill", &"rover_blueprint", &"solar_upgrade", &"rover", &"explore", &"radiation_map", &"shield"]},
}

## How each mission is done in the HUD: which menu, which option.
const TASK_ACTIONS := {
	&"greenhouse": [&"build", &"greenhouse"], &"ice_drill": [&"build", &"ice_drill"],
	&"rover": [&"build", &"rover"], &"shield": [&"build", &"shield"],
	&"solar_upgrade": [&"build", &"solar"], &"rover_blueprint": [&"search", &"rover_blueprint"],
	&"radiation_map": [&"search", &"radiation_map"], &"explore": [&"explore", &"explore"],
}

## Main scene already contains these three structures; state mirrors that world.
static func new_state() -> Dictionary:
	return {"stores": START.duplicate(), "kits": START_KITS, "modules": {&"habitat": 1, &"solar": 1, &"water_tank": 1},
		"levels": {&"habitat": 1, &"solar": 1, &"water_tank": 1}, "crew": CREW_SIZE,
		"crew_health": 100.0, "science": 1, "trips": 0, "unlocks": {&"habitat": true, &"solar": true, &"water_tank": true, &"greenhouse": true, &"ice_drill": true},
		"research_done": {}, "emergency_used": false, "day": 1, "history": [], "tasks_done": {}, "explored_today": false, "off": {}, "stories_seen": {}, "campaign": &"full", "guesses": {}, "resources": true}


static func preview_build(state: Dictionary, module_id: StringName, environment := {}) -> Dictionary:
	if not MODULES.has(module_id):
		return _denied("Unknown module")
	if not bool(state.unlocks.get(module_id, false)):
		return _denied("Search for this blueprint first")
	if int(state.modules.get(module_id, 0)) > 0:
		return _denied("Already built — upgrade this module")
	var cost := float(MODULES[module_id].kit_cost) if uses_resources(state) else 0.0
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
	if level >= int(MODULES[module_id].get("max_level", MAX_LEVEL)):
		return _denied("Maximum level reached")
	var next_level := level + 1
	var costs: Array = MODULES[module_id].upgrade_kits
	var cost := float(costs[next_level - 1]) if uses_resources(state) else 0.0
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


## Machines the player may switch off to share power differently.
const SWITCHABLE := [&"greenhouse", &"ice_drill", &"shield", &"water_tank"]


## Turns a built machine on or off (no day passes, no cost). An off machine
## takes no power and makes nothing, so the others get a bigger share.
static func set_power(state: Dictionary, module_id: StringName, on: bool) -> Dictionary:
	if not SWITCHABLE.has(module_id) or int(state.modules.get(module_id, 0)) == 0:
		return {"ok": false, "reason": "Only built machines can be switched"}
	if on:
		state.off.erase(module_id)
	else:
		state.off[module_id] = true
	return {"ok": true, "state": state}


## Tomorrow's change if `module_id` is switched on/off (state is not changed).
static func preview_power(state: Dictionary, module_id: StringName, on: bool, environment := {}) -> Dictionary:
	var forecast_state: Dictionary = state.duplicate(true)
	var r := set_power(forecast_state, module_id, on)
	if not r.ok:
		return _denied(r.reason)
	return {"allowed": true, "forecast": _forecast(forecast_state, environment)}


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
	# A machine switched off (state.off) takes no power and makes nothing.
	var off: Dictionary = state.get("off", {})
	var tank_level := int(levels.get(&"water_tank", 1))
	var tank_on := int(state.modules.get(&"water_tank", 0)) > 0 and not off.has(&"water_tank")
	if tank_on and float(consumed.water) > 0.0:
		optional_power_need += float(MODULES[&"water_tank"].power[tank_level - 1])
	var greenhouse_level := 0 if off.has(&"greenhouse") else int(levels.get(&"greenhouse", 0))
	var sunlight_factor := sunlight
	var greenhouse_factor := 0.0
	if greenhouse_level > 0:
		var g: Dictionary = MODULES[&"greenhouse"]
		var water_factor := minf(1.0, float(stores.water) / float(g.water[greenhouse_level - 1]))
		greenhouse_factor = minf(sunlight_factor, water_factor)
		optional_power_need += float(g.power[greenhouse_level - 1]) * greenhouse_factor
	var drill_level := 0 if off.has(&"ice_drill") else int(levels.get(&"ice_drill", 0))
	if drill_level > 0:
		optional_power_need += float(MODULES[&"ice_drill"].power[drill_level - 1])
	var shield_level := 0 if off.has(&"shield") else int(levels.get(&"shield", 0))
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
	if tank_on:
		var recovery_rate := float(MODULES[&"water_tank"].recovery[tank_level - 1])
		water_recovered = float(consumed.water) * recovery_rate * machine_factor
		stores.water = minf(CAPACITY.water, float(stores.water) + water_recovered)

	var food_made := 0.0
	var oxygen_made := 0.0
	var water_used := 0.0
	if greenhouse_level > 0:
		var g: Dictionary = MODULES[&"greenhouse"]
		var factor := greenhouse_factor * machine_factor
		var idx := greenhouse_level - 1
		water_used = float(g.water[idx]) * factor
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
	state.explored_today = false
	# Where each store's change came from (in = added, out = used), so the
	# debrief can explain a change with the sim's own numbers.
	var flows := {
		&"power": {"in": {"sun": generated}, "out": {"habitat": habitat_power, "machines": optional_power}},
		&"water": {"in": {"drill": water_mined, "recycler": water_recovered}, "out": {"crew": consumed.water, "greenhouse": water_used}},
		&"food": {"in": {"greenhouse": food_made}, "out": {"crew": consumed.food}},
		&"oxygen": {"in": {"greenhouse": oxygen_made}, "out": {"crew": consumed.oxygen}},
	}
	var report := {"day": state.day, "generated_power": generated, "spilled_power": spilled,
		"flows": flows, "machine_share": machine_factor, "machine_need": optional_power_need,
		"radiation": radiation, "protection": protection,
		"spilled_food": food_spilled, "spilled_oxygen": oxygen_spilled,
		"power_support": power_support, "unmet_crew_needs": unmet, "water_recovered": water_recovered, "water_mined": water_mined, "kits_delivered": kits_delivered,
		"food_made": food_made, "oxygen_made": oxygen_made, "radiation_after_shield": radiation_after_shield,
		"health_loss": health_loss, "crew_health": state.crew_health, "stores": stores.duplicate()}
	state.history.append(report.duplicate())
	return report


static func preview_explore(state: Dictionary, environment := {}) -> Dictionary:
	if int(state.modules.get(&"rover", 0)) == 0:
		return _denied("Build a rover first")
	if bool(state.get("explored_today", false)):
		return _denied("The rover is recharging. One trip a day")
	var level := int(state.levels.get(&"rover", 1))
	var cost: Dictionary = MODULES[&"rover"].explore_cost[level] if uses_resources(state) else {}
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
	state.explored_today = true
	return {"ok": true, "state": state, "science_found": preview.science, "ice_found": preview.ice}


static func preview_research(state: Dictionary, research_id: StringName, environment := {}) -> Dictionary:
	if not RESEARCH.has(research_id):
		return _denied("Unknown research")
	if bool(state.research_done.get(research_id, false)):
		return _denied("Research already complete")
	var spec: Dictionary = RESEARCH[research_id]
	if int(state.science) < int(spec.science):
		return _denied("Explore to collect one science sample")
	var power := float(spec.power) if uses_resources(state) else 0.0
	if float(state.stores.power) < power:
		return _denied("Need %d power" % int(power))
	var forecast_state: Dictionary = state.duplicate(true)
	forecast_state.science -= int(spec.science)
	forecast_state.stores.power -= power
	forecast_state.unlocks[spec.unlocks] = true
	var kit_total := float(forecast_state.kits) + float(spec.kits)
	forecast_state.kits = minf(KIT_CAPACITY, kit_total)
	var forecast := _forecast(forecast_state, environment)
	return {"allowed": true, "research": research_id, "science_cost": spec.science,
		"power_cost": power, "unlock": spec.unlocks, "kit_reward": forecast_state.kits - float(state.kits),
		"kit_overflow": maxf(0.0, kit_total - KIT_CAPACITY), "forecast": forecast}


static func research(state: Dictionary, research_id: StringName, environment := {}) -> Dictionary:
	var preview := preview_research(state, research_id, environment)
	if not preview.allowed:
		return {"ok": false, "reason": preview.reason}
	var spec: Dictionary = RESEARCH[research_id]
	state.science -= int(spec.science)
	state.stores.power -= float(preview.power_cost)
	state.unlocks[spec.unlocks] = true
	var kit_total := float(state.kits) + float(spec.kits)
	state.kits = minf(KIT_CAPACITY, kit_total)
	state.research_done[research_id] = true
	return {"ok": true, "state": state, "unlock": spec.unlocks,
		"kit_overflow": maxf(0.0, kit_total - KIT_CAPACITY)}


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
	return {"ok": true, "state": state, "cargo": preview.cargo}


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
		"water_recovered": result.water_recovered, "machine_share": result.machine_share}


## Tasks of mission `day` in `campaign` ([] once its days are over).
static func tasks_for(day: int, campaign: StringName = &"full") -> Array:
	var days: Array = CAMPAIGNS[campaign].days
	if day < 1 or day > days.size():
		return []
	for mission in DAY_TASKS:
		if mission[0].id == days[day - 1]:
			return mission
	return []


## Number of mission days in the run's campaign.
static func campaign_length(state: Dictionary) -> int:
	return CAMPAIGNS[state.get("campaign", &"full")].days.size()


static func task_met(state: Dictionary, task_id: StringName) -> bool:
	match task_id:
		&"greenhouse", &"ice_drill", &"shield", &"rover":
			return int(state.modules.get(task_id, 0)) > 0
		&"rover_blueprint", &"radiation_map":
			return bool(state.research_done.get(task_id, false))
		&"explore":
			return int(state.get("trips", 0)) > 0
		&"solar_upgrade":
			return int(state.levels.get(&"solar", 1)) >= 2
	return false


## Ticks off today's tasks whose condition holds and pays their kits.
## Returns the tasks completed just now. Work done early counts on its day.
static func claim_tasks(state: Dictionary) -> Array:
	var claimed := []
	for task in tasks_for(int(state.day), state.campaign):
		if not bool(state.tasks_done.get(task.id, false)) and task_met(state, task.id):
			state.tasks_done[task.id] = true
			state.kits = minf(KIT_CAPACITY, float(state.kits) + TASK_KITS)
			claimed.append(task)
	return claimed


## True when every task of the current day is done (the day may end).
static func day_cleared(state: Dictionary) -> bool:
	var tasks := tasks_for(int(state.day), state.campaign)
	if tasks.is_empty():
		return false
	for task in tasks:
		if not bool(state.tasks_done.get(task.id, false)):
			return false
	return true


## What the player should do next for today's mission: the menu + option,
## and whether it is possible right now (else the reason, from the previews).
static func next_step(state: Dictionary, environment := {}) -> Dictionary:
	for task in tasks_for(int(state.day), state.campaign):
		if bool(state.tasks_done.get(task.id, false)):
			continue
		var how: Array = TASK_ACTIONS[task.id]
		var p: Dictionary
		match how[0]:
			&"search":
				p = preview_research(state, how[1], environment)
			&"explore":
				p = preview_explore(state, environment)
			_:
				p = preview_upgrade(state, how[1], environment) if int(state.modules.get(how[1], 0)) > 0 \
					else preview_build(state, how[1], environment)
		return {"task": task, "menu": how[0], "option": how[1], "ok": bool(p.allowed), "reason": p.get("reason", "")}
	return {}


## Ends a cleared day: the night runs and the next mission day begins.
static func next_day(state: Dictionary, environment := {}) -> Dictionary:
	if not day_cleared(state):
		return {"ok": false, "reason": "Finish today's tasks first"}
	return {"ok": true, "day_report": advance_day(state, environment)}


## Waits one night without moving to the next mission day: supplies are used,
## Mission Control still sends its daily kit. The way out when a task is
## out of reach (not enough kits or power yet).
static func wait_night(state: Dictionary, environment := {}) -> Dictionary:
	var report := advance_day(state, environment)
	state.day = int(state.day) - 1  # same mission day, one more night
	report.day = state.day
	report.waited = true
	state.history[-1] = report.duplicate()
	state.nights_waited = int(state.get("nights_waited", 0)) + 1
	return {"ok": true, "day_report": report}


## 1-3 stars from how healthy the crew finished.
static func star_rating(state: Dictionary) -> int:
	var health := float(state.crew_health)
	return 3 if health >= 80.0 else (2 if health >= 50.0 else 1)


## "playing", "won" or "lost", with the main cause when lost.
static func outcome(state: Dictionary) -> Dictionary:
	if uses_resources(state) and float(state.crew_health) <= 0.0:
		var cause := "radiation"
		if not state.history.is_empty():
			var last: Dictionary = state.history[-1]
			var worst := 0.0
			for key in last.unmet_crew_needs:
				if float(last.unmet_crew_needs[key]) > worst:
					worst = float(last.unmet_crew_needs[key])
					cause = String(key)
		return {"status": &"lost", "cause": cause}
	if int(state.day) > campaign_length(state):
		return {"status": &"won", "stars": star_rating(state)}
	return {"status": &"playing"}


## Is the old resource game on for this run? When off (Stage 6: the HUD shows
## no bars), building, research and trips cost nothing and the crew can't be
## lost; the day model still runs quietly, so it can be switched back on later.
static func uses_resources(state: Dictionary) -> bool:
	return bool(state.get("resources", true))


static func _denied(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}
