class_name Rewards
extends RefCounted
## Stage 8 rewards: they reward thinking, trying and finishing, never speed,
## ranking or being right the first time. Nothing can be lost. Pure rules on
## the run's state (Colony stores the results and announces them).
##
## state.stars    {mission_id: {"done": bool, "guessed": bool, "reflected": bool}}
## state.badges   {badge_id: true}
## state.player_placements  how many times the player chose a building's spot

## Science stars per mission: finished it, picked NASA's fix yourself (first
## try or after the hint), answered the "why did it work?" question right.
const STAR_KINDS := ["done", "guessed", "reflected"]

## Concept badges: each one stands for a science idea (or for not giving up).
const BADGES := {
	&"plant_keeper": {"name": "Plant Keeper", "icon": "icon_food", "how": "Finish the greenhouse mission.", "missions": [&"greenhouse"]},
	&"ice_hunter": {"name": "Ice Hunter", "icon": "icon_water", "how": "Finish the ice drill mission.", "missions": [&"ice_drill"]},
	&"sun_catcher": {"name": "Sun Catcher", "icon": "icon_energy", "how": "Finish the solar panel mission.", "missions": [&"solar_upgrade"]},
	&"rover_driver": {"name": "Rover Driver", "icon": "icon_explore", "how": "Build the rover and go on a field trip.", "missions": [&"rover", &"explore"]},
	&"storm_watcher": {"name": "Storm Watcher", "icon": "icon_health", "how": "Map the radiation and build the shield.", "missions": [&"radiation_map", &"shield"]},
	&"base_architect": {"name": "Base Architect", "icon": "icon_build", "how": "Choose the spot for 3 buildings yourself."},
	&"never_give_up": {"name": "Never Give Up", "icon": "icon_add", "how": "Find an answer after a hint."},
}

## Decorations unlocked when a third, two thirds and all of the campaign's days
## are done (looks only, 1x1 parcel, free).
const DECOR := [
	{"id": &"lamp", "name": "Light Post"},
	{"id": &"antenna", "name": "Antenna"},
	{"id": &"moon_garden", "name": "Moon Rock Garden"},
]


static func give_star(state: Dictionary, mission_id: StringName, kind: String) -> bool:
	var s: Dictionary = state.get("stars", {}).get(mission_id, {})
	if s.get(kind, false):
		return false
	s[kind] = true
	if not state.has("stars"):
		state.stars = {}
	state.stars[mission_id] = s
	return true


static func stars_for(state: Dictionary, mission_id: StringName) -> int:
	var s: Dictionary = state.get("stars", {}).get(mission_id, {})
	return STAR_KINDS.filter(func(k): return s.get(k, false)).size()


static func total_stars(state: Dictionary) -> int:
	var n := 0
	for id in state.get("stars", {}):
		n += stars_for(state, id)
	return n


static func badge_met(state: Dictionary, badge_id: StringName) -> bool:
	match badge_id:
		&"base_architect":
			return int(state.get("player_placements", 0)) >= 3
		&"never_give_up":
			for g in state.get("guesses", {}).values():
				if g.get("hint_win", false):
					return true
			return false
	for m in BADGES[badge_id].missions:
		if not state.tasks_done.get(m, false):
			return false
	return true


## Newly earned badges (recorded in state.badges). Never removed.
static func claim_badges(state: Dictionary) -> Array:
	if not state.has("badges"):
		state.badges = {}
	var out := []
	for id in BADGES:
		if not state.badges.has(id) and badge_met(state, id):
			state.badges[id] = true
			out.append(id)
	return out


## Newly unlocked decorations for the campaign progress (state.unlocks).
static func claim_decor(state: Dictionary) -> Array:
	var total := OutpostSimulation.campaign_length(state)
	var done := mini(int(state.day) - 1, total)
	var out := []
	for i in DECOR.size():
		var need := ceili(total * (i + 1) / 3.0)
		var id: StringName = DECOR[i].id
		if done >= need and not state.unlocks.get(id, false):
			state.unlocks[id] = true
			out.append(id)
	return out


## One Mission Log page per finished day of the campaign, in order.
static func log_pages(state: Dictionary) -> Array:
	var pages := []
	var total := OutpostSimulation.campaign_length(state)
	for day in range(1, mini(int(state.day) - 1, total) + 1):
		var task: Dictionary = OutpostSimulation.tasks_for(day, state.campaign)[0]
		var g: Dictionary = state.get("guesses", {}).get(task.id, {})
		var how := "You finished it."
		if g.get("tries", 0) == 1:
			how = "You guessed NASA's fix on the first try."
		elif g.get("hint_win", false):
			how = "You found NASA's fix after a hint."
		elif g.get("tries", 0) >= 2:
			how = "You learned NASA's fix from the answer."
		pages.append({"day": day, "task": task, "how": how, "stars": stars_for(state, task.id)})
	return pages
