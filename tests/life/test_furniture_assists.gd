extends SceneTree
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var layout = desktop.world.layout
	desktop.begin_layout()
	var tools = desktop.room_ui.scene_actions
	check(desktop.get_node("%InnerWallSnapToggle") != null, "inner-wall snap is an authored, independent toggle")
	check(desktop.get_node("%AlignFurnitureX") != null and desktop.get_node("%AlignFurnitureZ") != null, "X/Z alignment buttons are authored")
	check(desktop.get_node("%DistributeFurnitureX") != null and desktop.get_node("%DistributeFurnitureZ") != null, "X/Z equal spacing tools are authored")
	check(desktop.get_node("%FurnitureAssistHint") != null, "wall distance and furniture spacing summary are authored")
	check(not layout.wall_snap and not layout.inner_wall_snap, "interior and exterior wall snapping default to disabled")
	check(layout.inner_wall_clearance("mouse") == -1.0, "desk equipment cannot be assigned a room-wall distance")
	check(layout.nearest_alignment("mouse","x").is_empty(), "computer equipment remains excluded from floor furniture alignment")
	check(not layout.distribute_matching_furniture("x"), "without enough furniture distribution reports failure")
	check(layout._matching_furniture("lamp").size() == 1, "single placed lamp is not yet a distribution group")
	check("不足 2 件" in layout.furniture_spacing_summary("lamp"), "empty spacing guide explains requirement")
	var initial: Dictionary = layout._draft()
	check(layout.add_partition(Vector2(0,2.5),"x"), "create a solid interior wall section")
	var part: Dictionary = layout.blueprint.partitions[0]
	check(part.kind == "wall", "wall snap anchors on solid partitions")
	var lamp: Node3D = layout.nodes["lamp"]
	var sample: Transform3D = lamp.transform
	sample.origin.x = 0.0
	sample.origin.z = 0.0
	var max_z := -INF
	for corner: Vector2 in layout._footprint_at("lamp",sample,0.0):
		max_z = maxf(max_z,corner.y)
	var probe := Vector2(0.0,float(part.z)-Blueprint.WALL_THICKNESS*.5-layout.WALL_SAFE_GAP-max_z-.15)
	check(layout._wall_snap_point("lamp",probe).is_equal_approx(probe), "interior-wall snap is disabled until explicitly enabled")
	layout.set_inner_wall_snap(true)
	check(layout.inner_wall_snap and not layout.wall_snap, "internal-wall magnet works independently from exterior magnet")
	var snapped: Vector2 = layout._wall_snap_point("lamp",probe)
	check(snapped.distance_to(probe) <= layout.WALL_SNAP_RADIUS+.001, "interior magnet limits reposition distance")
	check(snapped.y >= probe.y-.001, "inner-wall magnet points toward the front interior wall")
	check(not layout._blocker("lamp",layout._footprint_at("lamp",Transform3D(lamp.basis,Vector3(snapped.x,lamp.position.y,snapped.y)),layout.collision_margin)).contains("内墙"), "magnetic destination does not overlap the wall")
	layout.set_inner_wall_snap(false)
	check(layout._wall_snap_point("lamp",probe).is_equal_approx(probe), "turning off wall snap restores free placement")
	check(layout.inner_wall_clearance("lamp") >= -1.0, "wall distance helper handles existing furniture pose")
	check("最近内墙" in desktop.get_node("%FurnitureAssistHint").text or "附近无内墙" in desktop.get_node("%FurnitureAssistHint").text, "live layout panel exposes real wall distance")

	# Construct three same-category lamps in a cleared editor-only corner.
	# Stow unrelated loose furnishings so test feasibility is independent
	# of the shipped room's decorative starting positions.
	for unused_role: String in ["chair","bookcase","rug","plant"]:
		layout.placed_instances.erase(unused_role)
	layout._apply_furniture_appearance()
	for role: String in ["lamp_1","lamp_2"]:
		layout._create_copy(role)
		layout.placed_instances[role] = "editor_fixture_" + role
	check(layout._matching_furniture("lamp").size() == 3, "same-type furniture selection includes valid copies")
	var group: Array[String] = ["lamp","lamp_1","lamp_2"]
	var base_y: float = layout.nodes["lamp"].position.y
	var found := false
	for z in [-2.3,-2.0,1.8,2.1]:
		for spread in [2.4,2.7,2.1]:
			var coords := [-spread,0.0,spread]
			for i in range(group.size()):
				var node: Node3D = layout.nodes[group[i]]
				node.position = Vector3(coords[i],base_y,z)
			if layout._layout_blocker().is_empty():
				found = true
				break
		if found: break
	check(found, "a collision-free row exists for three fixture lamps: " + layout._layout_blocker())
	if not found:
		layout._restore_draft(initial)
		desktop.finish_layout(false)
		game.queue_free()
		await frames()
		quit(1)
		return
	var middle: Node3D = layout.nodes["lamp_1"]
	var common_z: float = middle.position.z
	layout.select("lamp_1")
	var z_shift := 0.0
	var align := {}
	for candidate_shift: float in [-.12,.12,-.08,.08,-.04,.04]:
		middle.position.z = common_z+candidate_shift
		if not layout._layout_blocker().is_empty(): continue
		align = layout.nearest_alignment("lamp_1","z")
		if not align.is_empty():
			z_shift = candidate_shift
			break
	check(not is_zero_approx(z_shift), "fixture has a small collision-free Z offset and alignment guide")
	if is_zero_approx(z_shift):
		layout._restore_draft(initial)
		desktop.finish_layout(false)
		game.queue_free()
		await frames()
		quit(1)
		return
	check(align.axis == "z", "nearby furniture provides an exact Z alignment guide")
	tools._refresh_arrangement("lamp_1")
	check(not tools.arrange_buttons["align_z"].disabled and not tools.arrange_buttons["space_x"].disabled, "scene arrangement exposes safe Z alignment and three-piece X distribution")
	var history_before: int = layout.undo_stack.size()
	tools.arrange_panel.show()
	tools.perform_arrangement("align_z")
	check(layout.nodes["lamp_1"].position.z == common_z, "contextual Z alignment delegates to the existing collision-checked layout action")
	check(is_equal_approx(layout.nodes["lamp_1"].position.z,common_z), "alignment moves furniture to a shared center line")
	check(layout.undo_stack.size() == history_before+1, "single alignment produces exactly one undo step")
	layout.undo()
	check(is_equal_approx(layout.nodes["lamp_1"].position.z,common_z+z_shift), "undo restores the prior Z offset")
	layout.redo()
	check(is_equal_approx(layout.nodes["lamp_1"].position.z,common_z), "redo reapplies furniture alignment")
	check("3 件同类家具" in layout.furniture_spacing_summary("lamp_1"), "spacing guide reports the matching group")
	check("中心距" in layout.furniture_spacing_summary("lamp_1"), "guides measure center distance in metres")
	middle = layout.nodes["lamp_1"]
	var first_x: float = layout.nodes["lamp"].position.x
	var last_x: float = layout.nodes["lamp_2"].position.x
	var expected: float = (first_x+last_x)*.5
	var x_shift := 0.0
	for trial_shift: float in [.10,-.10,.06,-.06,.03,-.03]:
		middle.position.x = expected+trial_shift
		if layout._layout_blocker().is_empty():
			x_shift = trial_shift
			break
	check(not is_zero_approx(x_shift), "fixture has a valid uneven X spacing")
	if is_zero_approx(x_shift):
		layout._restore_draft(initial)
		desktop.finish_layout(false)
		game.queue_free()
		await frames()
		quit(1)
		return
	history_before = layout.undo_stack.size()
	tools.arrange_panel.show()
	tools.perform_arrangement("space_x")
	check(is_equal_approx(layout.nodes["lamp_1"].position.x,expected), "contextual X distribution delegates to existing same-type grouping")
	check(is_equal_approx(layout.nodes["lamp_1"].position.x,expected), "equal-spacing action moves only the interior item to midpoint")
	check(is_equal_approx(layout.nodes["lamp"].position.x,first_x) and is_equal_approx(layout.nodes["lamp_2"].position.x,last_x), "distribution keeps both endpoint furniture unmoved")
	check(layout.undo_stack.size() == history_before+1, "an entire arrangement is a single undo entry")
	layout.undo()
	check(is_equal_approx(layout.nodes["lamp_1"].position.x,expected+x_shift), "undo restores uneven positions")
	layout.redo()
	check(is_equal_approx(layout.nodes["lamp_1"].position.x,expected), "redo restores equal spacing")
	check(layout.valid and layout._layout_blocker().is_empty(), "aligned and distributed furniture remain collision-free")
	check(not layout.distribute_matching_furniture("x"), "repeating already-even distribution is a no-op")
	check(not layout.distribute_matching_furniture("invalid"), "unknown distribution axis is rejected")
	check(layout.nearest_alignment("lamp_1","invalid").is_empty(), "unknown alignment axis is rejected")

	desktop.finish_layout(false)
	check(layout.blueprint == initial.blueprint and layout.snapshot() == initial.poses, "canceling restores original walls, furnishings and all poses")
	check(not layout.nodes.has("lamp_1") and not layout.nodes.has("lamp_2"), "temporary fixture furniture is removed on cancel")
	for role: String in desktop.world.devices:
		check(layout.surface_for(role) == "desk", "computer hardware remains desk-only: " + role)
	game.queue_free()
	await frames()
	print("FURNITURE_ASSISTS_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
