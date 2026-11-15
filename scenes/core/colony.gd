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
## The run is over. `result` is OutpostSimulation.outcome(): status + cause.
signal mission_ended(result: Dictionary)

## Local scenario used until a validated NASA bundle is plugged in (see
## NasaEnvironmentData). Sunlight is a 0-1 fraction; radiation is game points.
## shortcut: fixed 7-day loop, replace with adapter output when NASA data lands.
const SCENARIO := [
	{"sunlight": 1.0, "radiation": 3.0},
	{"sunlight": 0.8, "radiation": 4.0},
	{"sunlight": 0.5, "radiation": 4.0},
	{"sunlight": 0.2, "radiation": 5.0},
	{"sunlight": 0.6, "radiation": 4.0},
	{"sunlight": 1.0, "radiation": 3.0},
	{"sunlight": 0.9, "radiation": 6.0},
]

var state := OutpostSimulation.new_state()
var finished := false


## Fresh run (the caller reloads the scene so the world matches).
func reset() -> void:
	state = OutpostSimulation.new_state()
	finished = false


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


# --- Actions ---------------------------------------------------------------

## Build or upgrade (no day passes).
func build(module_id: StringName) -> Dictionary:
	var upgrading := int(state.modules.get(module_id, 0)) > 0
	var result := OutpostSimulation.upgrade(state, module_id, environment()) if upgrading \
		else OutpostSimulation.build(state, module_id, environment())
	if result.ok:
		module_changed.emit(module_id, int(state.levels[module_id]))
		changed.emit()
		_check_outcome()
	return result


func research(research_id: StringName) -> Dictionary:
	return _run_day(func(): return OutpostSimulation.research(state, research_id, environment()))


func explore() -> Dictionary:
	return _run_day(func(): return OutpostSimulation.explore(state, environment()))


## Just let the day pass (always possible, so the player can never get stuck).
func rest() -> Dictionary:
	return _run_day(func(): return {"ok": true, "day_report": OutpostSimulation.advance_day(state, environment())})


func emergency_supply() -> Dictionary:
	return _run_day(func(): return OutpostSimulation.emergency_supply(state, environment()))


## Runs an action that ends the day, then announces the day report.
func _run_day(action: Callable) -> Dictionary:
	var before: Dictionary = state.stores.duplicate()
	var result: Dictionary = action.call()
	if result.ok:
		day_finished.emit(result.day_report, before)
		changed.emit()
		_check_outcome()
	return result


func _check_outcome() -> void:
	var result := OutpostSimulation.outcome(state)
	if finished or result.status == &"playing":
		return
	finished = true
	mission_ended.emit(result)
	Events.mission_ended.emit(result.status == &"won")
