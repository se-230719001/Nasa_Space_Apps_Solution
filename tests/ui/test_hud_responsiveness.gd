extends Node
## HUD layout contract: preserve readable controls by switching to compact mode
## before the fixed desktop zones collide.

var failures := 0


func check(condition: bool, message: String) -> void:
	print(("  PASS " if condition else "  FAIL ") + message)
	if not condition:
		failures += 1


func _ready() -> void:
	var hud: Control = load("res://ui/screens/outpost_hud.tscn").instantiate()
	add_child(hud)
	check(not hud.uses_compact_layout(1280.0), "desktop width keeps the expanded HUD")
	check(is_equal_approx(hud.get_node("BottomBar").offset_left, -330.0), "desktop HUD applies its centered action bar on first load")
	check(hud.uses_compact_layout(959.0), "narrow width switches to compact HUD")
	check(hud.uses_compact_layout(720.0), "tablet width switches to compact HUD")
	hud.call("_apply_responsive_layout_for_width", 720.0)
	check(hud.get_node("TopRight").visible, "compact HUD keeps the mission day visible")
	check(not hud.get_node("TopRight/Row/Stats/CrewLabel").visible, "compact HUD hides secondary crew statistics")
	check(hud.get_node("GoalPanel").visible, "compact HUD keeps the current objective visible")
	check(hud.get_node("BottomBar").size.x >= 688.0, "compact HUD preserves a 48px target for each primary action")
	hud.call("_apply_responsive_layout_for_width", 320.0)
	check(hud.get_node("TopCenter/ResourceBar/ResourceIcons").get_theme_constant("separation") == 0, "narrow HUD removes resource gaps before shrinking targets")
	var first_resource: Control = hud.get_node("TopCenter/ResourceBar/ResourceIcons").get_child(0).get_child(0)
	check(first_resource.custom_minimum_size.x >= 48.0, "narrow HUD keeps resource targets at least 48px")
	check(hud.get_node("TopRight").position.y >= hud.get_node("TopCenter").position.y, "narrow HUD does not overlay mission day on resources")
	hud.call("_apply_responsive_layout_for_width", 1280.0)
	check(hud.get_node("TopRight").visible, "desktop HUD restores secondary statistics")
	print("ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(failures)
