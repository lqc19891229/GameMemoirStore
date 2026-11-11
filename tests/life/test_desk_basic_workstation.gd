extends SceneTree
## Regression smoke test for the shared 1.0 x 0.6 m desk_basic workstation.
## Does not change the shop catalog, saved inventory or player save.
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://scenes/computer/workstation_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var layout: Node = world.layout
	var desk: Node3D = world.get_node("TableGroup/Desk")
	check(desk.scene_file_path == "res://scenes/room/tables/desk_basic.tscn", "workstation instances the catalog desk_basic scene")
	check(desk.bounds.is_equal_approx(Vector3(1.0, 0.75, 0.6)), "desk_basic is 100 x 60 x 75 cm")
	check(layout.tabletop_half_size.is_equal_approx(Vector2(0.5, 0.3)), "workstation placement matches the desk footprint")
	check(is_equal_approx(layout.tabletop_height, 0.75), "peripherals use the physical desk height")
	var anchors: Array = desk.get_meta("support_surfaces", [])
	check(anchors.size() == 1, "one table support surface is registered")
	if anchors.size() == 1:
		check(anchors[0].id == "top" and anchors[0].center.is_equal_approx(Vector3(0, 0.75, 0)) and anchors[0].size.is_equal_approx(Vector2(0.9, 0.5)), "desk surface retains five-centimetre insets")
	check((world.get_node("TableGroup/Desk/PickArea").collision_layer & 1) == 0, "duplicate furniture picker does not shadow the workstation picker")
	check(world.get_node("TableGroup/DeskPickArea").get_meta("layout_role") == "desk", "workstation desk remains selectable under stable role")
	for role in ["monitor", "keyboard", "mouse"]:
		check(layout.surface_for(role) == "desk", role + " stays on the tabletop")
		check(is_equal_approx(world.devices[role].position.y, 0.75), role + " rests at the correct desk height")
	check(layout.surface_for("computer") == "floor", "PC tower is floor-standing")
	check(is_equal_approx(world.devices["computer"].position.y, 0), "PC tower stands at floor height")
	for role in world.devices:
		var expected_parent: Node = world if role == "computer" else world.get_node("%Equipment")
		check(world.devices[role].get_parent() == expected_parent, role + " retains the correct parent for safe floor/tabletop layout")
	check(world.devices["monitor"].has_node("Screen"), "monitor screen for computer interaction is retained")
	check(layout._layout_blocker().is_empty(), "default workstation layout has no collisions or desk-edge violations")
	world.queue_free()
	await process_frame
	print("DESK_BASIC_WORKSTATION_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)
