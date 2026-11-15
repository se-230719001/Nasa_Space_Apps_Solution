extends Node
## Autoload "Colony": owns the one live OutpostSimulation state and the mission
## scenario (daily sunlight/radiation). UI and the 3D world never compute game
## numbers themselves; they call the actions here and react to the signals.

## Something about the state changed (stores, kits, levels, unlocks...).
signal changed
## A mission day ran. `before` holds the stores from just before it.
signal day_finished(report: Dictionary, before: Dictionary)
## A module was built (level 1) or upgraded (level 2-3).
signal module_changed(module_id: StringName, level: int)
## A building moved or turned on the base grid (see BaseGrid).
signal placement_changed(module_id: StringName)
## The player named the base or picked its flag colour.
signal base_changed
## Stage 8 rewards (also announced on Events for the audio side).
signal star_earned(mission_id: StringName)
signal badge_earned(badge_id: StringName)
signal decor_unlocked(decor_id: StringName)
## The run is over. `result` is OutpostSimulation.outcome(): status + cause.
signal mission_ended(result: Dictionary)
## One of today's tasks was finished (its kits are already paid).
signal task_completed(task: Dictionary)
## Every task of `day` is done; the next day starts after AUTO_NEXT_DELAY.
signal day_cleared(day: int)
## The crew's health hit 0: Mission Control helped them and today starts again
## (state is already back to this morning, with health at least RESCUE_HEALTH).
signal crew_rescued

## Pause between "all tasks done" and the night, so the cheer can be seen.
const AUTO_NEXT_DELAY := 2.5
## Progress is saved here after every action, so the main mission spans sittings.
## A var so tests can point it elsewhere and never touch the player's save.
var save_path := "user://moonminds_save.txt"
const SAVE_VERSION := 9
## A rescued crew restarts the day with at least this much health.
const RESCUE_HEALTH := 50.0

## Local scenario used until a validated NASA bundle is plugged in (see
## NasaEnvironmentData). Sunlight is a 0-1 fraction; radiation is game points.
## shortcut: fixed 8-day list, replace with adapter output when NASA data lands.
const SCENARIO := [
	{"sunlight": 1.0, "radiation": 3.0},
	{"sunlight": 0.8, "radiation": 4.0},
	{"sunlight": 0.5, "radiation": 4.0},
	{"sunlight": 0.2, "radiation": 5.0},
	{"sunlight": 0.6, "radiation": 4.0},
	{"sunlight": 0.9, "radiation": 4.0},
	{"sunlight": 1.0, "radiation": 3.0},
	{"sunlight": 0.9, "radiation": 6.0},
]

var state := _fresh_state()
var finished := false
## The robot's first-time tutorial ran (kept across "Play Again").
var tutorial_done := false
## The start cards (continue / campaign / briefing) ran in this app run.
var session_chosen := false
## "Continue saved mission?" was already asked in this app run.
var save_offered := false
var _advancing := 0  # day whose automatic next_day is already scheduled
## Show each day's real NASA story card once (tests that check other cards
## turn it off).
var show_stories := true
## Celebrate new badges / decorations with a card (tests of other cards turn it off).
var show_rewards := true
## Hint level reached today (0 none, 1 small hint, 2 clear hint).
var hint_level := 0
## The night report that led to the last rescue (for the kind explanation).
var rescue_report := {}
var _morning := {}  # state at the start of today, for "try today again"


func _ready() -> void:
	_morning = state.duplicate(true)


## A new run: the NASA-problem game without the old resource bars (Stage 6),
## with the starting buildings on their first free parcels (Stage 7).
static func _fresh_state() -> Dictionary:
	var s := OutpostSimulation.new_state()
	s.resources = false
	s.unlocks[&"lander"] = true  # the Apollo replica is always free to place
	s.base_name = "Moon Base"
	s.flag = &"blue"
	s.stars = {}
	s.badges = {}
	s.player_placements = 0
	s.placements = {}
	for id in [&"solar", &"water_tank"]:
		s.placements[id] = BaseGrid.suggest(s.placements, id)
	return s


## Flag colours the player can pick (named, so colour is never the only cue).
const FLAGS := {&"red": Color("#E8473F"), &"blue": Color("#3D7BF0"), &"green": Color("#33B864"), &"yellow": Color("#F5C431")}
const NAME_MAX := 20


## Names the base (trimmed, at most NAME_MAX letters; empty keeps the old one)
## and/or picks its flag. Stays on this device only.
func set_base(base_name: String, flag: StringName = &"") -> void:
	var clean := base_name.strip_edges().left(NAME_MAX)
	if clean != "":
		state.base_name = clean
	if FLAGS.has(flag):
		state.flag = flag
	save()
	base_changed.emit()


## Where `id` stands on the grid ({} for the fixed habitat / not placed).
func placement(module_id: StringName) -> Dictionary:
	return state.get("placements", {}).get(module_id, {})


## Moves/turns a building, or chooses the spot for one about to be built.
## Free of charge (Stage 6). Returns {ok, reason}.
func set_placement(module_id: StringName, cell: Vector2i, rot: int) -> Dictionary:
	if not state.has("placements"):
		state.placements = {}
	var result := BaseGrid.check(state.placements, module_id, cell, rot)
	if result.ok:
		state.placements[module_id] = {"cell": cell, "rot": rot}
		state.player_placements = int(state.get("player_placements", 0)) + 1
		_check_rewards()
		save()
		placement_changed.emit(module_id)
	return result


## Fresh run (the caller reloads the scene so the world matches).
func reset() -> void:
	state = _fresh_state()
	finished = false
	_advancing = 0
	_morning = state.duplicate(true)
	save()


## Starts a new run of `campaign` (an OutpostSimulation.CAMPAIGNS key).
func start_campaign(campaign: StringName) -> void:
	state.campaign = campaign
	_morning.campaign = campaign
	session_chosen = true
	save()
	Events.campaign_started.emit(campaign)


## Back to how today began (stores, kits, buildings). The caller reloads the
## scene so the world matches.
func retry_day() -> void:
	state = _morning.duplicate(true)
	finished = false
	_advancing = 0
	save()


## No game over: back to this morning with a healthier crew and the one-time
## cargo available again, so the day can be tried with a new plan.
func _rescue() -> void:
	rescue_report = state.history[-1] if not state.history.is_empty() else {}
	retry_day()
	state.crew_health = maxf(float(state.crew_health), RESCUE_HEALTH)
	state.emergency_used = false
	state.rescues = int(state.get("rescues", 0)) + 1
	_morning = state.duplicate(true)  # a later retry keeps the rescued crew
	hint_level = 2
	save()
	Events.crew_rescued.emit()
	crew_rescued.emit()


## Called by the outpost scene once its world is built from `state`: a day
## whose mission was already done (e.g. after a retry) still moves on.
func resume() -> void:
	_advancing = 0
	_claim()



# --- Save / load -------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## var_to_str keeps StringName keys that JSON would turn into plain strings.
func save() -> void:
	if finished:  # a finished mission is not resumed
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save progress: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(var_to_str({"version": SAVE_VERSION, "state": state, "morning": _morning,
		"tutorial_done": tutorial_done}))


## Loads saved progress. A missing, old or damaged file is ignored (false).
func load_save() -> bool:
	if not has_save():
		return false
	var data: Variant = str_to_var(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION \
			or not data.get("state") is Dictionary or not data.get("morning") is Dictionary:
		push_warning("Ignoring an unreadable save file")
		return false
	var fresh := OutpostSimulation.new_state()
	for key in fresh:  # every field the game reads must be there
		if not data.state.has(key) or not data.morning.has(key):
			push_warning("Ignoring a save file from an older game version")
			return false
	state = data.state
	_morning = data.morning
	tutorial_done = bool(data.get("tutorial_done", false))
	finished = false
	_advancing = 0
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## Today's tasks ([] after the last mission day).
func today_tasks() -> Array:
	return OutpostSimulation.tasks_for(int(state.day), state.campaign)


## What to do next for today's mission (menu, option, possible now?).
func next_step() -> Dictionary:
	return OutpostSimulation.next_step(state, environment())


## Today's conditions (the ones the next day-advance will use).
func environment() -> Dictionary:
	return SCENARIO[(int(state.day) - 1) % SCENARIO.size()]


## Kid-friendly sun wording for the day card.
func sun_word() -> String:
	var s := float(environment().sunlight)
	return "Strong sun" if s >= 0.8 else ("Some sun" if s >= 0.4 else "Low sun")


# --- Previews (never change state) -----------------------------------------

func preview_build(module_id: StringName) -> Dictionary:
	if int(state.modules.get(module_id, 0)) > 0:
		return OutpostSimulation.preview_upgrade(state, module_id, environment())
	return OutpostSimulation.preview_build(state, module_id, environment())


func preview_research(research_id: StringName) -> Dictionary:
	return OutpostSimulation.preview_research(state, research_id, environment())


func preview_explore() -> Dictionary:
	return OutpostSimulation.preview_explore(state, environment())


func preview_emergency() -> Dictionary:
	return OutpostSimulation.preview_emergency_supply(state)


func preview_power(module_id: StringName, on: bool) -> Dictionary:
	return OutpostSimulation.preview_power(state, module_id, on, environment())


## The player's answer to a mission's "what would you do?" question. Returns
## the number of tries so far. Wrong answers cost nothing; the card shows a
## hint, then the answer after the second miss.
func record_guess(mission_id: StringName, correct: bool) -> int:
	var g: Dictionary = state.guesses.get(mission_id, {"tries": 0, "solved": false})
	if not g.solved:
		g.tries += 1
		g.solved = correct or g.tries >= 2
		g.hint_win = correct and g.tries == 2  # got it after the hint
		state.guesses[mission_id] = g
		if correct:
			_star(mission_id, "guessed")  # only a right pick earns it (1st try or after the hint)
		_check_rewards()
		save()
	Events.prediction_made.emit(correct)
	return int(g.tries)


## The after-mission "why did it work?" answer: a star only when it's right
## (a wrong one gets the explanation instead). Returns whether it was right.
func answer_why(mission_id: StringName, correct: bool) -> bool:
	if correct:
		_star(mission_id, "reflected")
	_check_rewards()
	save()
	return correct


func _star(mission_id: StringName, kind: String) -> void:
	if Rewards.give_star(state, mission_id, kind):
		star_earned.emit(mission_id)
		Events.star_earned.emit(mission_id)


## Announces badges / decorations that just became earned.
func _check_rewards() -> void:
	if not state.has("badges"):
		return  # an old-rules run (tests of the resource game)
	for id in Rewards.claim_badges(state):
		badge_earned.emit(id)
		Events.badge_earned.emit(id)
	for id in Rewards.claim_decor(state):
		decor_unlocked.emit(id)
		Events.decor_unlocked.emit(id)


## Next hint level for today (a problem happened again); returns it.
func bump_hint() -> int:
	hint_level = mini(hint_level + 1, 2)
	Events.hint_shown.emit(hint_level)
	return hint_level


# --- Actions ---------------------------------------------------------------
# Build, Search and Explore never end the day: a day ends by itself once all
# of its tasks are done (next_day), or the player waits a night (rest).

## Build or upgrade. A new building without a chosen spot gets the nearest
## free parcel (the HUD normally lets the player choose it first).
func build(module_id: StringName) -> Dictionary:
	var upgrading := int(state.modules.get(module_id, 0)) > 0
	var result := OutpostSimulation.upgrade(state, module_id, environment()) if upgrading \
		else OutpostSimulation.build(state, module_id, environment())
	if result.ok:
		# Only a building that really got built takes a parcel.
		if not upgrading and state.has("placements") and BaseGrid.SIZE.has(module_id) \
				and not state.placements.has(module_id):
			var spot := BaseGrid.suggest(state.placements, module_id)
			if not spot.is_empty():
				state.placements[module_id] = spot
		module_changed.emit(module_id, int(state.levels[module_id]))
	return _after(result)


func research(research_id: StringName) -> Dictionary:
	return _after(OutpostSimulation.research(state, research_id, environment()))


func explore() -> Dictionary:
	return _after(OutpostSimulation.explore(state, environment()))


func emergency_supply() -> Dictionary:
	return _after(OutpostSimulation.emergency_supply(state, environment()))


## Switches a built machine on/off (no day passes).
func set_power(module_id: StringName, on: bool) -> Dictionary:
	return _after(OutpostSimulation.set_power(state, module_id, on))


## Waits one night on the same mission day (always possible, so a task that
## is out of reach can never lock the run).
func rest() -> Dictionary:
	var before: Dictionary = state.stores.duplicate()
	return _run_night(OutpostSimulation.wait_night(state, environment()), before)


## Ends a cleared day. Called automatically AUTO_NEXT_DELAY after day_cleared.
func next_day() -> Dictionary:
	var before: Dictionary = state.stores.duplicate()
	return _run_night(OutpostSimulation.next_day(state, environment()), before)


func _after(result: Dictionary) -> Dictionary:
	if result.ok:
		_claim()
		changed.emit()
		_check_outcome()
		save()
	return result


func _run_night(result: Dictionary, before: Dictionary) -> Dictionary:
	if not result.ok:
		return result
	day_finished.emit(result.day_report, before)
	var new_day := not bool(result.day_report.get("waited", false))
	if new_day:
		hint_level = 0
		_morning = state.duplicate(true)
	_claim()  # work done ahead of time counts on its own day
	changed.emit()
	_check_outcome()
	save()
	if new_day and not finished:
		Events.mission_day_started.emit(int(state.day))
	return result


func _claim() -> void:
	for task in OutpostSimulation.claim_tasks(state):
		_star(task.id, "done")
		task_completed.emit(task)
	_check_rewards()
	var day := int(state.day)
	if OutpostSimulation.day_cleared(state) and not finished and _advancing != day:
		_advancing = day
		day_cleared.emit(day)
		get_tree().create_timer(AUTO_NEXT_DELAY).timeout.connect(func() -> void:
			if int(state.day) == day and not finished:  # not already advanced
				next_day())


func _check_outcome() -> void:
	var result := OutpostSimulation.outcome(state)
	if finished or result.status == &"playing":
		return
	if result.status == &"lost":
		_rescue()
		return
	finished = true
	delete_save()  # the next start is a new mission
	mission_ended.emit(result)
	Events.mission_ended.emit(result.status == &"won")
