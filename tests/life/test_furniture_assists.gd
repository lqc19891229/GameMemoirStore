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

	# P33: mixed Ctrl selection is editor-only and its rigid transform is
	# constrained against the room and other furniture, never against itself.
	layout.select("lamp")
	check(layout.group_selection.size() == 1, "ordinary selection begins with exactly one active furniture item")
	check(layout.toggle_group_member("lamp_1") and layout.toggle_group_member("lamp_2"), "Ctrl-style toggles add two more individually owned instances to the selection")
	check(layout.group_selection.size() == 3 and layout.selected == "lamp_2", "multi-selection tracks three live roles and a movable primary member")
	check(layout.group_markers.size() == 2, "each additional selected furniture has a collision-free visual selection outline")
	# P36: quick groups are selection presets only, never object transforms,
	# undo entries or persistent room contents.
	var quick_poses: Dictionary = layout.snapshot()
	var quick_history: int = layout.undo_stack.size()
	var quick_inventory: Dictionary = layout.placed_instances.duplicate()
	check(layout.quick_groups.is_empty() and layout.quick_group_summary(1) == "未保存", "new editor sessions begin with all quick selection slots empty")
	check(not layout.save_quick_group(0) and not layout.recall_quick_group(4), "out-of-range quick group slots are rejected")
	check(layout.save_quick_group(1) and layout.save_quick_group(3), "three-piece group can be saved into two independent quick slots")
	check(layout.quick_group_size(1) == 3 and layout.quick_group_size(3) == 3 and layout.quick_group_summary(1).contains("3 件"), "quick slot summaries expose valid selected furniture counts")
	layout.clear_group_selection()
	check(layout.group_selection.size() == 1 and layout.quick_group_size(1) == 3, "clearing multi-selection preserves temporary saved group membership")
	check(layout.recall_quick_group(1) and layout.group_selection == group and layout.selected == "lamp_2", "quick recall restores the exact 3-piece set and saved primary")
	check(layout.snapshot() == quick_poses and layout.undo_stack.size() == quick_history and layout.placed_instances == quick_inventory, "saving and recalling groups changes neither poses, undo stack nor stock mapping")
	layout.clear_group_selection()
	layout.select("lamp_1")
	check(not layout.save_quick_group(2), "quick group save rejects a single selected item")
	check(layout.recall_quick_group(3), "other saved quick slot independently recalls the original furniture group")
	check(layout.clear_quick_group(3) and layout.quick_group_summary(3) == "未保存" and not layout.recall_quick_group(3), "cleared quick slot can no longer be recalled")
	var actual_uid: String = str(layout.placed_instances["lamp_1"])
	layout.placed_instances["lamp_1"] = "unrelated_new_inventory_uid"
	check(layout.quick_group_size(1) == 2 and layout.recall_quick_group(1), "a slot skips a replaced UID rather than selecting a different furniture instance")
	check(not layout.group_selection.has("lamp_1") and layout.group_selection.size() == 2, "UID protection removes the stale role from recalled members")
	layout.placed_instances["lamp_1"] = actual_uid
	check(layout.quick_group_size(1) == 3 and layout.recall_quick_group(1), "restoring the owned UID makes the full original group selectable again")
	check(layout.clear_quick_group(1) and not layout.clear_quick_group(1), "clearing the same slot twice is a safe no-op")
	check(layout.snapshot() == quick_poses and layout.undo_stack.size() == quick_history and layout.placed_instances == quick_inventory, "all quick-group operations leave furniture transforms and inventory unchanged")
	check(is_instance_valid(layout.group_bounds_marker) and layout.group_bounds_marker.mesh != null, "multi-selection draws a room-space group boundary and rotation-center cross")
	check(layout.group_bounds_marker.find_children("*","CollisionShape3D",true,false).is_empty(), "group boundary marker never intercepts physics ray picks")
	var group_box: Rect2 = layout.group_world_bounds()
	check(group_box.has_area() and group_box.has_point(layout.group_pivot()), "group bounding box contains actual shared rotation pivot")
	var pivot: Vector2 = layout.group_pivot()
	var gizmo_at: Vector3 = desktop.world.to_local(layout.gizmo.global_position)
	check(Vector2(gizmo_at.x,gizmo_at.z).distance_to(pivot) < .003, "multi-object move handle appears at the true group center rather than the primary furniture")
	check(absf(layout.gizmo.global_rotation.y) < .002 and not layout.gizmo.get_node("Outline").visible, "multi-object handles use world-aligned axes without duplicating the group boundary outline")
	var history_at_pick: int = layout.undo_stack.size()
	check(layout.set_primary_group_member("lamp"), "any current group member may become the primary controlled furniture")
	check(layout.selected == "lamp" and layout.group_selection.size() == 3, "changing the primary furniture preserves all members")
	var pivot_after_primary: Vector3 = desktop.world.to_local(layout.gizmo.global_position)
	check(Vector2(pivot_after_primary.x,pivot_after_primary.z).distance_to(pivot) < .003, "changing the primary member never moves the group gizmo off the center")
	check(not layout.set_primary_group_member("desk") and not layout.remove_group_member("desk"), "non-members cannot become primary or be removed from the group")
	check(layout.set_primary_group_member("lamp_2"), "returning primary to the original group role works without mutating transforms")
	layout.set_tool("rotate")
	var rotate_gizmo: Vector3 = desktop.world.to_local(layout.gizmo.global_position)
	check(Vector2(rotate_gizmo.x,rotate_gizmo.z).distance_to(pivot) < .003 and layout.gizmo.get_node("RotateHandles").visible, "rotate gizmo uses the same true group center and exposes existing rotation handles")
	var sample_pixel: Vector2 = desktop.world.camera.unproject_position(desktop.world.to_global(Vector3(pivot.x+.32,.65,pivot.y+.24)))
	layout.begin_drag(sample_pixel,"rotate")
	check(layout.gesture == "rotate" and layout.start_group_pivot.distance_to(pivot) < .003, "rotating through the gizmo stores the group pivot rather than the selected item's origin")
	if layout.gesture == "rotate":
		var ray_point: Variant = layout._plane_point(sample_pixel)
		if ray_point != null:
			var expected_angle: float = atan2(ray_point.z-pivot.y,ray_point.x-pivot.x)
			check(absf(angle_difference(expected_angle,layout.start_angle)) < .002, "group drag start angle is computed around the shared pivot")
	layout.end_drag()
	check(layout.undo_stack.size() == history_at_pick, "switching primary or starting/releasing untouched group handles never creates an undo record")
	layout.set_tool("move")
	for role: String in group:
		for corner: Vector2 in layout.footprint(role):
			check(group_box.grow(.002).has_point(corner), "group bounding guide encloses all member footprint corners: " + role)
	var poses_before_group: Dictionary = {}
	for role: String in group:
		poses_before_group[role] = layout.nodes[role].transform
	var placed_before_group: Dictionary = layout.placed_instances.duplicate()
	history_before = layout.undo_stack.size()
	check(layout.nudge_selected(Vector2.RIGHT,true), "one-centimeter keyboard nudge moves the entire selected group")
	for role: String in group:
		var old_pose: Transform3D = poses_before_group[role]
		check(absf(layout.nodes[role].position.x-old_pose.origin.x-.01) < .003 and absf(layout.nodes[role].position.z-old_pose.origin.z) < .003, "group nudge preserves every member offset: " + role)
	check(layout.undo_stack.size() == history_before+1, "all three members moved in exactly one undo transaction")
	check(layout.valid and layout._layout_blocker().is_empty(), "group translation never violates existing collision checks")
	check(layout.group_world_bounds().position.distance_to(group_box.position+Vector2(.01,0)) < .003, "group bounding outline follows every translated member")
	var moved_poses: Dictionary = {}
	for role: String in group: moved_poses[role] = layout.nodes[role].transform
	layout.undo()
	for role: String in group:
		check(layout.nodes[role].transform.is_equal_approx(poses_before_group[role]), "one undo restores the entire selected group: " + role)
	layout.redo()
	for role: String in group:
		check(layout.nodes[role].transform.is_equal_approx(moved_poses[role]), "one redo reapplies the whole group transform: " + role)
	history_before = layout.undo_stack.size()
	var angle_before: float = layout.nodes["lamp_2"].rotation.y
	var group_center := Vector2.ZERO
	for role: String in group:
		group_center += Vector2(layout.nodes[role].position.x,layout.nodes[role].position.z)
	group_center /= float(group.size())
	var original_separation: float = layout.nodes["lamp"].position.distance_to(layout.nodes["lamp_2"].position)
	layout.rotate_step(1,true)
	var actual_angle := angle_difference(angle_before,layout.nodes["lamp_2"].rotation.y)
	check(absf(actual_angle) > .00001 and absf(actual_angle) <= deg_to_rad(1.01), "fine rotation turns every group member by at most one degree until collision")
	check(absf(layout.nodes["lamp"].position.distance_to(layout.nodes["lamp_2"].position)-original_separation) < .002, "group rotation preserves relative distances around its shared pivot")
	var new_center := Vector2.ZERO
	for role: String in group: new_center += Vector2(layout.nodes[role].position.x,layout.nodes[role].position.z)
	new_center /= float(group.size())
	check(new_center.distance_to(group_center) < .002 and layout.group_pivot().distance_to(new_center) < .002, "visible center cross matches the exact pivot used by rigid group rotation")
	check(layout.undo_stack.size() == history_before+1, "the entire pivot rotation makes one undo record")
	check(layout.valid and layout._layout_blocker().is_empty(), "rotated group remains valid and outside wall geometry")
	layout.undo()
	for role: String in group:
		check(layout.nodes[role].transform.is_equal_approx(moved_poses[role]), "undo fully restores group positions and yaw after rotation: " + role)
	history_before = layout.undo_stack.size()
	var before_blocked_move: Dictionary = {}
	for role: String in group: before_blocked_move[role] = layout.nodes[role].transform
	var far_anchor := Vector2(55.0,55.0)
	layout.move_to(far_anchor)
	check(layout.valid and layout._layout_blocker().is_empty(), "moving selected group past the room boundary stops at a collision-safe point")
	var actually_moved := false
	for role: String in group:
		if not layout.nodes[role].transform.is_equal_approx(before_blocked_move[role]):
			actually_moved = true
	check(layout.undo_stack.size() == history_before + (1 if actually_moved else 0), "group adds exactly one undo step if movement was possible, or no entry when fully blocked")
	check(layout.placed_instances == placed_before_group, "group transforms never consume, create or reassign owned furniture UIDs")
	if actually_moved: layout.undo()
	# Group wall magnet uses full group extents and validates each member's
	# swept path, while Alt bypass leaves the requested delta unchanged.
	var magnet_probe := Vector2.ZERO
	var group_snap_found := false
	var current_box: Rect2 = layout.group_world_bounds()
	layout.gesture = "move"
	for axis_id in range(2):
		for direction in [-1.0,1.0]:
			var adjust: float
			if axis_id == 0:
				adjust = (-layout.room_half_size.x+layout.edge_margin+layout.collision_margin+.015-current_box.position.x) if direction < 0 else (layout.room_half_size.x-layout.edge_margin-layout.collision_margin-.015-current_box.end.x)
			else:
				adjust = (-layout.room_half_size.y+layout.edge_margin+layout.collision_margin+.015-current_box.position.y) if direction < 0 else (layout.room_half_size.y-layout.edge_margin-layout.collision_margin-.015-current_box.end.y)
			var trial: Vector2 = (Vector2(adjust-direction*.12,0) if axis_id == 0 else Vector2(0,adjust-direction*.12))
			var magnetic: Vector2 = layout._group_wall_snap_delta(trial)
			if magnetic.distance_to(trial) > .005:
				magnet_probe = trial
				group_snap_found = true
				break
		if group_snap_found: break
	check(group_snap_found, "at least one room edge offers a collision-safe whole-group magnet")
	if group_snap_found:
		var before_magnet: Dictionary = {}
		for role: String in group: before_magnet[role] = layout.nodes[role].transform
		var magnet_target: Vector3 = layout.nodes[layout.selected].position
		layout.move_to(Vector2(magnet_target.x,magnet_target.z)+magnet_probe)
		check(layout.wall_magnet_active and layout.valid, "dragging whole selection toward a wall shows active magnet only for a valid group destination")
		var xz_delta: Vector2 = Vector2(layout.nodes[layout.selected].position.x-magnet_target.x,layout.nodes[layout.selected].position.z-magnet_target.z)
		for role: String in group:
			var old_pose: Transform3D = before_magnet[role]
			var actual: Vector2 = Vector2(layout.nodes[role].position.x-old_pose.origin.x,layout.nodes[role].position.z-old_pose.origin.z)
			check(actual.distance_to(xz_delta) < .003, "magnet pulls every group member by exactly the same displacement: " + role)
		layout.snap_bypass = true
		check(layout._group_wall_snap_delta(magnet_probe).is_equal_approx(magnet_probe), "Alt disables group magnets without changing grid settings")
		for role: String in group: layout.nodes[role].transform = before_magnet[role]
		layout.snap_bypass = false
		layout.update()
	layout.gesture = ""
	layout.end_drag()
	# P37: batch tint is one inventory-UID-colored transaction, while group
	# alignment/distribution verify their entire sweep and roll back atomically.
	check(layout.group_selection.size() == 3 and layout.selected == "lamp_2", "batch arrangement operates on actual selected members, not the full same-item catalog")
	var first_uid: String = str(layout.placed_instances["lamp"])
	var second_uid: String = str(layout.placed_instances["lamp_1"])
	var third_uid: String = str(layout.placed_instances["lamp_2"])
	layout.furniture_colors[first_uid] = 2
	layout.furniture_colors[second_uid] = 4
	layout.furniture_colors.erase(third_uid)
	layout._apply_furniture_appearance()
	layout.update()
	check(layout.group_color_index() == -1, "mixed group finishes are reported without guessing a common color")
	var before_group_colors: Dictionary = layout.furniture_colors.duplicate()
	var color_history: int = layout.undo_stack.size()
	check(layout.set_group_furniture_color(5), "one batch color action recolors all three selected furniture UIDs")
	check(layout.color_for("lamp") == 5 and layout.color_for("lamp_1") == 5 and layout.color_for("lamp_2") == 5 and layout.group_color_index() == 5, "batch recolor applies the chosen finish to all group members")
	check(layout.undo_stack.size() == color_history+1 and not layout.set_group_furniture_color(5), "identical group recolor is a no-op and a real change takes one undo record")
	layout.undo()
	check(layout.furniture_colors == before_group_colors and layout.group_color_index() == -1, "one undo restores every previously mixed member finish")
	layout.redo()
	check(layout.group_color_index() == 5 and layout.undo_stack.size() == color_history+1, "one redo reapplies all selected furniture colors")
	check(not layout.set_group_furniture_color(-1) and not layout.set_group_furniture_color(999), "invalid group finish indices never modify owned stock")
	check(layout.placed_instances == placed_before_group, "batch recolor changes per-UID appearance but never relabels inventory")

	# Start from a previously verified valid row, then introduce small offsets.
	for role: String in group: layout.nodes[role].transform = quick_poses[role]
	layout.nodes["lamp"].position.z -= .10
	layout.nodes["lamp_1"].position.z += .15
	layout.update()
	check(layout.valid and layout._layout_blocker().is_empty(), "group arrangement fixture remains clear after small Z offsets")
	var before_group_align: Dictionary = layout.snapshot()
	var align_history: int = layout.undo_stack.size()
	check(layout.align_group("z"), "group alignment centers each member on the primary lamp's Z position")
	var aligned_z: float = layout.nodes["lamp_2"].position.z
	for role: String in group:
		check(absf(layout.nodes[role].position.z-aligned_z) < .003, "group alignment preserves every member and matches the chosen primary center line: " + role)
	check(layout.undo_stack.size() == align_history+1 and layout.valid, "all three aligned members share one undo record and a valid layout")
	check(not layout.align_group("z") and not layout.align_group("invalid"), "repeating aligned axis or supplying unknown axis cannot add undo entries")
	layout.undo()
	for role: String in group:
		check(layout.nodes[role].transform.is_equal_approx(before_group_align[role]), "single undo restores all group offsets after alignment: " + role)
	layout.redo()

	# Aligning all three onto the same X when already co-linear on Z would
	# make them overlap. Reject the entire operation without partial moves.
	var before_invalid_align: Dictionary = layout.snapshot()
	var rejected_history: int = layout.undo_stack.size()
	check(not layout.align_group("x"), "alignment that would stack three furniture footprints is rejected")
	for role: String in group:
		check(layout.nodes[role].transform.is_equal_approx(before_invalid_align[role]), "collision rejection rolls back every member, not just the last: " + role)
	check(layout.undo_stack.size() == rejected_history and layout.valid, "blocked group alignment creates no undo record and restores a valid layout")

	var ordered: Array[String] = group.duplicate()
	ordered.sort_custom(func(a: String,b: String) -> bool: return layout.nodes[a].position.x < layout.nodes[b].position.x)
	var minimum_x: float = layout.nodes[ordered[0]].position.x
	var maximum_x: float = layout.nodes[ordered[-1]].position.x
	layout.nodes[ordered[1]].position.x += .28
	layout.update()
	check(layout.valid and layout._layout_blocker().is_empty(), "off-center middle item gives a collision-free distribution fixture")
	var before_spacing: Dictionary = layout.snapshot()
	var spacing_history: int = layout.undo_stack.size()
	check(layout.distribute_group("x"), "three selected members can be evenly spaced along X")
	check(absf(layout.nodes[ordered[1]].position.x-(minimum_x+maximum_x)*.5) < .003, "group X distribution centers only the middle member")
	check(absf(layout.nodes[ordered[0]].position.x-minimum_x) < .003 and absf(layout.nodes[ordered[-1]].position.x-maximum_x) < .003, "group equal spacing preserves both endpoint coordinates")
	check(layout.undo_stack.size() == spacing_history+1 and layout.valid and layout._layout_blocker().is_empty(), "complete group equal spacing is one safe undo transaction")
	check(not layout.distribute_group("x") and not layout.distribute_group("bad"), "an already-even group or invalid axis adds no history")
	layout.undo()
	for role: String in group:
		check(layout.nodes[role].transform.is_equal_approx(before_spacing[role]), "single undo restores every member's pre-distribution pose: " + role)
	layout.redo()
	check(layout.placed_instances == placed_before_group, "group alignment and spacing never change owned furniture UIDs")
	check(layout.toggle_group_member("lamp_2"), "Ctrl-style toggle removes one existing member without moving it")
	check(layout.group_selection.size() == 2 and layout.group_markers.size() == 1, "removing a member updates group selection outlines")
	layout.clear_group_selection()
	check(layout.group_selection.size() == 1 and layout.group_markers.is_empty() and not is_instance_valid(layout.group_bounds_marker), "Esc-style group clearing removes group boundary, center marker and auxiliary outlines")
	check(layout.save_quick_group(2) == false, "a single remaining item cannot overwrite quick group memory")
	layout.toggle_group_member("lamp_2")
	check(layout.save_quick_group(2), "a two-piece temporary group is remembered until editing ends")
	desktop.finish_layout(false)
	check(layout.quick_groups.is_empty() and layout.quick_group_size(2) == 0, "finishing room editing clears all nonpersistent quick groups")
	desktop.begin_layout()
	check(layout.quick_groups.is_empty() and not layout.recall_quick_group(2), "reopening the editor never restores session-only group slots")
	desktop.finish_layout(false)
	check(layout.blueprint == initial.blueprint and layout.snapshot() == initial.poses, "canceling restores original walls, furnishings and all poses")
	check(not layout.nodes.has("lamp_1") and not layout.nodes.has("lamp_2"), "temporary fixture furniture is removed on cancel")
	for role: String in desktop.world.devices:
		check(layout.surface_for(role) == "desk", "computer hardware remains desk-only: " + role)
	game.queue_free()
	await frames()
	print("FURNITURE_ASSISTS_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
