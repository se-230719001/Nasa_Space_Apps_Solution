extends Node3D
## Colony scene root. Owns the ColonySim model (docs/game_systems_design.md).
## Turn based: the player decides, then presses END DAY to run one day and see
## the report. Keeps the 3D world in sync: buildings on cells the player chose
## (their look changes with each level) and a dome that grows with the colony
## and shows the air quality.

const MODULES := {
	"greenhouse": preload("res://scenes/buildings/greenhouse.gd"),
	"health_center": preload("res://scenes/buildings/shelter.gd"),
	"radiation_lab": preload("res://scenes/buildings/research_lab.gd"),
}
## Cells used by the buildings that exist at the start.
const START_CELLS := {
	"life_support": [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
		Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)],
	"energy_center": [Vector2i(7, 4)],
	"water_recycling": [Vector2i(7, 6)],
	"hangar": [Vector2i(4, 7)],
}

var sim := ColonySim.new(randi())
var occupied := {}     # Vector2i -> building id
var nodes := {}        # building id -> Node3D

@onready var _hud := $UI/OutpostHUD
@onready var _grid: BuildGrid = $World/BuildGrid
@onready var _dome: ColonyDome = $World/Dome


func _ready() -> void:
	nodes = {"life_support": $World/HabitatBase, "energy_center": $World/SolarArray,
		"water_recycling": $World/WaterTank, "hangar": $World/Hangar}
	for id in START_CELLS:
		for c in START_CELLS[id]:
			occupied[c] = id
	_hud.sim = sim
	_grid.is_free = func(c: Vector2i) -> bool: return BuildGrid.in_radius(c, dome_radius()) and not occupied.has(c)
	_grid.cell_tapped.connect(_on_cell_tapped)
	_hud.place_requested.connect(func(_id: String) -> void: _grid.show_free_cells())
	_hud.place_cancelled.connect(_grid.hide_cells)
	_hud.build_confirmed.connect(_on_build_confirmed)
	_hud.research_requested.connect(func(card: String) -> void:
		if sim.research(card):
			_handle_events(sim.check_goals_now())
			_hud.show_advice({"kind": &"success", "title": "Research done!", "text": ColonySim.CARDS[card].text})
		_hud.refresh()
		_hud.show_research())
	_hud.craft_requested.connect(func(type: String) -> void:
		if sim.build_craft(type):
			_hud.show_advice({"kind": &"info", "title": "Building a %s" % ColonySim.CRAFTS[type].name,
				"text": "It will be ready in %d days." % ColonySim.CRAFTS[type].days})
		_hud.refresh()
		_hud.show_hangar())
	_hud.launch_requested.connect(func(dest: String) -> void:
		if sim.launch(dest):
			_hud.close_overlay()
			_update_hangar()
			_hud.show_advice({"kind": &"success", "title": "Liftoff!",
				"text": "Off to %s. Back in %d days." % [ColonySim.DESTINATIONS[dest].name, sim.mission_days(dest)]})
		_hud.refresh())
	_hud.toggle_requested.connect(_on_toggle)
	_hud.end_day_requested.connect(_next_day)
	for id in nodes:
		_show_level(id, false)
	_dome.set_radius(dome_radius(), false)
	_dome.set_air(sim.levels_view().oxygen, sim.co2, false)
	_hud.refresh()
	_hud.show_advice({"kind": &"info", "title": "Welcome, Commander!",
		"text": "Make your choices, then press END DAY. Tap TAKE HINT if you are not sure."})
	Music.play(&"outpost")
	# The robot explains the game after the logo splash.
	get_tree().create_timer(2.0).timeout.connect(_hud.show_tutorial)


func _on_toggle(setting: String) -> void:
	match setting:
		"exercise":
			sim.exercise_on = not sim.exercise_on
		"sleep":
			sim.sleep_on = not sim.sleep_on
		"co2_filter":
			sim.co2_filter_on = not sim.co2_filter_on


func _next_day() -> void:
	if _hud.is_busy():
		return
	var report := sim.step_day()
	_handle_events(report.events)
	_sync_air()
	_hud.refresh()
	_hud.show_advice(report.advice)
	_hud.show_day_report(report)


func _sync_air() -> void:
	_dome.set_air(sim.levels_view().oxygen, sim.co2)
	_dome.set_radius(dome_radius())


## The dome covers the colony and grows with building levels and crew.
func dome_radius() -> float:
	var total := 0
	for id in sim.levels:
		total += sim.levels[id]
	return clampf(15.0 + 0.6 * (total - 4) + 0.35 * (sim.population - 4), 15.0, 27.0)


func _handle_events(events: Array) -> void:
	for ev in events:
		if ev is String:
			continue   # shown in the day report
		match ev.type:
			"craft":
				_update_hangar()
			"mission":
				_update_hangar()
				_hud.show_mission_report.call_deferred(ev)
			"goal":
				Music.stinger(&"mission_complete")
				_say("success", "Goal done: %s (+%d materials)" % [ev.goal.title, ev.goal.reward], ev.goal.lesson)
			"problem":
				if ev.passed:
					Music.stinger(&"mission_complete")


func _say(kind: String, title: String, text: String) -> void:
	_hud.show_advice({"kind": StringName(kind), "title": title, "text": text})


## --- Building ---------------------------------------------------------------------

func _on_cell_tapped(cell: Vector2i) -> void:
	if _grid.placing:
		if _grid.is_free.call(cell):
			_grid.hide_cells()
			_hud.confirm_placement(cell)
	elif occupied.has(cell) and not _hud.is_busy():
		_hud.show_building(occupied[cell])


func _on_build_confirmed(id: String, cell: Vector2i) -> void:
	_grid.hide_cells()
	if not sim.start_build(id):
		return
	if cell.x >= 0:
		occupied[cell] = id
	_on_built(id, sim.lv(id), cell)
	_handle_events(sim.check_goals_now())
	_sync_air()
	_hud.refresh()
	var def: Dictionary = ColonySim.BUILDINGS[id]
	_say("success", "%s %s!" % [def.name, "built" if sim.lv(id) == 1 else "is now Lv %d" % sim.lv(id)],
		def.unlocks[sim.lv(id) - 1])


func _on_built(id: String, level: int, cell: Vector2i) -> void:
	if level == 1 and MODULES.has(id):
		var module: Node3D = MODULES[id].new()
		module.position = BuildGrid.cell_center(cell)
		module.scale = Vector3.ONE * 0.01
		$World.add_child(module)
		nodes[id] = module
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(module, "scale", Vector3.ONE, 0.6)
	_show_level(id, true)
	_dome.set_radius(dome_radius())


## Each level rebuilds the model with new parts (domes, tanks, antennas...).
func _show_level(id: String, animate: bool) -> void:
	if not nodes.has(id):
		return
	var n: Node3D = nodes[id]
	var level := sim.lv(id)
	if n.get(&"level") != level:
		n.set(&"level", level)
		if animate:
			n.scale = Vector3.ONE * 0.85
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.tween_property(n, "scale", Vector3.ONE, 0.5)
	var tag: Label3D = n.get_node_or_null(^"LevelTag")
	if tag == null:
		tag = Label3D.new()
		tag.name = "LevelTag"
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 120
		tag.outline_size = 32
		tag.pixel_size = 0.012
		tag.modulate = Color("#FFE27A")
		tag.position = Vector3(0, 3.6 if id != "life_support" else 5.4, 0)
		n.add_child(tag)
	tag.text = "Lv %d" % level


func _update_hangar() -> void:
	var free := sim.crafts.filter(func(c: Dictionary) -> bool: return not c.busy).size()
	nodes.hangar.set_crafts(free)
