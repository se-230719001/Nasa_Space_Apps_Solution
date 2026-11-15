extends SceneTree
## Base grid: unit rules (BaseGrid) and the real placement flow in the scene
## (build card -> ghost on parcels -> reasons -> turn / cancel / build here,
## then tap -> move / turn, and placements survive save + continue).
## Run: <godot> --headless --path . --script res://tools/tests/test_base_grid.gd

const G := preload("res://scenes/core/base_grid.gd")

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


func bar(n: String) -> Control:
	return hud.get_node("%PlacementBar").find_child(n, true, false)


func _initialize() -> void:
	unit()
	await scene_flow()
	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)


func unit() -> void:
	var p := {}
	check("habitat parcels are taken", G.check(p, &"greenhouse", Vector2i(-2, -3), 0).reason == "Something is already here")
	check("the habitat door path stays open", G.check(p, &"greenhouse", Vector2i(1, -3), 0).reason == "Keep the path to the habitat door open")
	check("parcels near the dome wall are not allowed", G.check(p, &"greenhouse", Vector2i(5, 5), 0).reason == "Too close to the dome wall")
	check("a free spot is allowed", G.check(p, &"greenhouse", Vector2i(0, 1), 0).ok)
	p[&"greenhouse"] = {"cell": Vector2i(0, 1), "rot": 0}
	check("buildings can't overlap", G.check(p, &"shield", Vector2i(1, 2), 0).reason == "Something is already here")
	check("a building may stay on its own parcels (moving)", G.check(p, &"greenhouse", Vector2i(1, 1), 0).ok)
	check("turning swaps width and depth", G.size_of(&"solar", 0) == Vector2i(4, 2) and G.size_of(&"solar", 1) == Vector2i(2, 4)
		and G.cells(&"solar", Vector2i.ZERO, 1).size() == 8)
	var centred := true
	for id in G.SIZE:
		for rot in 4:
			var t := G.world_transform(id, Vector2i(-1, 1), rot)
			var mc: Vector2 = G.MODEL_CENTER[id]
			var mesh_centre := t * Vector3(mc.x, 0, mc.y)
			centred = centred and Vector2(mesh_centre.x, mesh_centre.z).distance_to(G.footprint_center(id, Vector2i(-1, 1), rot)) < 0.01
	check("every model sits centred on its parcels at all 4 turns", centred)
	var all := {}
	var fits := true
	for id in G.SIZE:
		var spot := G.suggest(all, id)
		fits = fits and not spot.is_empty() and G.check(all, id, spot.cell, spot.rot).ok
		all[id] = spot
	check("every building, replica and decoration finds a free spot together", fits and all.size() == G.SIZE.size())
	var fresh: Dictionary = root.get_node("Colony")._fresh_state()
	check("a new run places Solar and Recycler on valid parcels", fresh.placements.has(&"solar") and fresh.placements.has(&"water_tank")
		and G.check(fresh.placements, &"solar", fresh.placements.solar.cell, fresh.placements.solar.rot).ok)


func scene_flow() -> void:
	colony = root.get_node("Colony")
	colony.save_path = "user://test_grid_save.txt"
	colony.show_rewards = false  # reward cards are checked in test_rewards.gd
	colony.delete_save()
	colony.session_chosen = true
	colony.tutorial_done = true
	colony.show_stories = false
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.4).timeout
	scene = current_scene
	hud = scene.find_child("OutpostHUD", true, false)

	# --- Build card opens placement instead of building at once ---
	hud._open_menu(&"build")
	hud._select(&"greenhouse")
	hud._confirm()
	await frames()
	check("Build opens placement mode, nothing built yet", scene.is_placing() and not colony.state.modules.has(&"greenhouse"))
	check("bar with Turn / Cancel / Build here replaces the action buttons", hud.get_node("%PlacementBar").visible
		and not hud.get_node("%BuildButton").is_visible_in_tree() and bar("PlaceButton").text == "✓ Build here")
	check("the camera won't pan while placing", scene.get_node("Camera3D").input_locked)
	check("parcels and a see-through ghost are shown", scene._grid_mesh != null and scene._ghost != null)

	# --- Reasons for wrong spots; Build here disabled ---
	scene.move_ghost_to(Vector2i(-2, -3))
	check("on the habitat: reason + disabled", bar("PlaceButton").disabled and bar("PlaceHint").text == "Not here: Something is already here.")
	scene.move_ghost_to(Vector2i(1, -3))
	check("on the door path: reason", bar("PlaceHint").text == "Not here: Keep the path to the habitat door open.")
	scene.move_ghost_to(Vector2i(5, 5))
	check("at the dome wall: reason", bar("PlaceHint").text == "Not here: Too close to the dome wall.")

	# --- Dragging moves the ghost to the parcel under the pointer ---
	var cam: Camera3D = scene.get_node("Camera3D")
	var target := Vector2i(1, 2)
	var screen := cam.unproject_position(Vector3(G.cell_center(target).x, 0, G.cell_center(target).y))
	scene._drag_ghost(screen)
	check("drag puts the ghost under the finger", scene._ghost_cell == target - G.size_of(&"greenhouse", 0) / 2)

	# --- Turn, then build here ---
	scene.move_ghost_to(Vector2i(-1, 1))
	bar("TurnButton").pressed.emit()
	check("Turn turns the ghost", scene._ghost_rot == 1 and not bar("PlaceButton").disabled)
	bar("PlaceButton").pressed.emit()
	await frames()
	var node: Node3D = scene._spawned.get(&"greenhouse")
	check("built on the chosen parcels, turned", colony.state.modules.has(&"greenhouse")
		and colony.placement(&"greenhouse") == {"cell": Vector2i(-1, 1), "rot": 1}
		and node != null and node.transform.origin.is_equal_approx(G.world_transform(&"greenhouse", Vector2i(-1, 1), 1).origin))
	check("placement mode closed, buttons back", not scene.is_placing() and not hud.get_node("%PlacementBar").visible
		and hud.get_node("%BuildButton").is_visible_in_tree() and not cam.input_locked)
	check("the mission counts the building", colony.state.tasks_done.has(&"greenhouse"))
	await create_timer(colony.AUTO_NEXT_DELAY + 0.9).timeout
	for m in get_nodes_in_group(&"hud_modal"):
		m.queue_free()  # debrief
	await frames()

	# --- Cancel builds nothing ---
	hud._open_menu(&"build")
	hud._select(&"ice_drill")
	hud._confirm()
	bar("CancelPlace").pressed.emit()
	await frames()
	check("Cancel: nothing built, no parcel used", not colony.state.modules.has(&"ice_drill") and not colony.state.placements.has(&"ice_drill")
		and not scene.is_placing())

	# --- Tap a building: move / turn, free ---
	scene.building_tapped.emit(&"greenhouse")
	await frames()
	var card: Control = get_nodes_in_group(&"hud_modal")[0]
	var t := ""
	for l in card.find_children("*", "", true, false):
		if l is Label or l is Button:
			t += l.text + "|"
	check("tap offers Move and Turn, says it's free", "Move" in t and "Turn" in t and "free" in t)
	card.find_child("Choice0", true, false).pressed.emit()  # Move
	await frames()
	check("Move: ghost of the same building, button says Move here", scene.is_placing() and bar("PlaceButton").text == "✓ Move here"
		and not node.visible)
	scene.move_ghost_to(Vector2i(1, 2))
	bar("PlaceButton").pressed.emit()
	await frames()
	check("moved to the new parcels", colony.placement(&"greenhouse").cell == Vector2i(1, 2) and node.visible
		and node.transform.origin.is_equal_approx(G.world_transform(&"greenhouse", Vector2i(1, 2), 1).origin))
	var turned: Dictionary = scene.rotate_building(&"greenhouse")
	check("turn in place (free)", turned.ok and colony.placement(&"greenhouse").rot == 2)
	scene.building_tapped.emit(&"habitat")
	await frames()
	check("the habitat can't be moved", get_nodes_in_group(&"hud_modal").is_empty()
		and "crew's home" in hud.get_node("%Helper").get_node("%BubbleText").text)

	# --- 7b: Apollo Lander replica (NASA 3D model) + "Inspired by" ---
	hud._open_menu(&"build")
	hud._select(&"lander")
	var rows := ""
	for l in hud.get_node("%Rows").find_children("*", "Label", true, false):
		rows += l.text + "|"
	check("Apollo Lander card: real fact + NASA model credit + replica", "landed 12 astronauts on the Moon" in rows
		and "NASA/Michael D. Carbajal" in rows and "replica" in rows)
	hud._select(&"greenhouse")
	rows = ""
	for l in hud.get_node("%Rows").find_children("*", "Label", true, false):
		rows += l.text + "|"
	check("game buildings say what inspired them, and that they're simpler", "Veggie plant garden" in rows and "Game building" in rows)
	hud._select(&"lander")
	hud._confirm()
	check("the replica is placed like any building (3x3)", scene.is_placing() and G.size_of(&"lander", 0) == Vector2i(3, 3))
	var spot := G.suggest(colony.state.placements, &"lander")
	scene.move_ghost_to(spot.cell)
	bar("PlaceButton").pressed.emit()
	await frames()
	var lander: Node3D = scene._spawned.get(&"lander")
	check("NASA model is in the base, on its parcels", lander != null and lander.find_children("*", "MeshInstance3D", true, false).size() > 100
		and colony.placement(&"lander").cell == spot.cell)
	check("the replica doesn't upgrade", not colony.preview_build(&"lander").allowed)

	# --- Placements survive save + continue ---
	var before: Dictionary = colony.state.placements.duplicate(true)
	colony.state = colony._fresh_state()
	check("continue restores every parcel", colony.load_save() and colony.state.placements == before)
	colony.delete_save()
