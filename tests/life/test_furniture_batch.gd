extends SceneTree
## P38: batch duplication/storage operate on owned UIDs and commit atomically.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var original: Dictionary = layout._draft()
	for unused: String in ["chair","bookcase","rug","plant"]:
		layout.placed_instances.erase(unused)
	layout._create_copy("lamp_1")
	layout.available_inventory.append({"uid":"item_97011","item_id":"room_lamp"})
	layout.placed_instances["lamp_1"] = "item_97011"
	layout._apply_furniture_appearance()
	var selected_sources: Array[String] = ["lamp","lamp_1"]
	var found := false
	for z in [-2.3,-2.0,1.8,2.1]:
		for distance in [2.0,2.4,2.8,3.0]:
			layout.nodes["lamp"].position = Vector3(-distance*.5,layout.nodes["lamp"].position.y,z)
			layout.nodes["lamp_1"].position = Vector3(distance*.5,layout.nodes["lamp_1"].position.y,z)
			if not layout._layout_blocker().is_empty(): continue
			layout.select("lamp")
			layout.toggle_group_member("lamp_1")
			for ring in range(1,21):
				for step in range(24):
					var angle := TAU*float(step)/24.0
					var offset := Vector2(cos(angle),sin(angle))*float(ring)*.25
					if layout.snapping: offset = offset.snapped(Vector2.ONE*layout.grid_step)
					if not layout._group_duplicate_targets(offset).is_empty():
						found = true
						break
				if found: break
			if found: break
		if found: break
	check(found,"an actual 3D room arrangement admits a fully safe batch copy")
	if not found:
		desktop.finish_layout(false)
		game.queue_free()
		await frames()
		quit(1)
		return
	check(layout.group_selection == selected_sources and layout.valid, "fixture selects two owned, collision-free lamp instances")
	var before_stock: Dictionary = layout.placed_instances.duplicate()
	var before_poses: Dictionary = layout.snapshot()
	var before_history: int = layout.undo_stack.size()
	check(layout.group_duplicate_plan().has("error"),"no extra lamp stock disables batch copy")
	check(not layout.begin_group_copy_preview() and layout.group_copy_preview_nodes.is_empty(),"preview cannot start without fully reserved stock")
	check(not layout.duplicate_group(),"batch duplication rejects missing stock")
	check(layout.placed_instances == before_stock and layout.snapshot() == before_poses and layout.undo_stack.size() == before_history,"missing stock never consumes a UID, moves furniture or writes history")
	layout.available_inventory.append({"uid":"item_97012","item_id":"room_lamp"})
	check(layout.group_duplicate_plan().has("error") and not layout.duplicate_group(),"one available UID cannot partially copy two requested items")
	check(layout.placed_instances == before_stock and layout.undo_stack.size() == before_history,"partial stock shortage leaves every source and UID unchanged")
	layout.available_inventory.append({"uid":"item_97013","item_id":"room_lamp"})
	var plan: Dictionary = layout.group_duplicate_plan()
	check(plan.has("copies") and plan.copies.size() == 2,"enough unplaced owned stock makes a complete group copy feasible")
	check(str(plan.copies["lamp"].uid) != str(plan.copies["lamp_1"].uid),"same-category copies reserve two different inventory UIDs")
	var previous_margin: float = layout.edge_margin
	layout.edge_margin = 100.0
	check(not layout.duplicate_group() and layout.message.contains("空闲位置"),"when the room cannot hold any new furniture, the whole copy is rejected")
	layout.edge_margin = previous_margin
	check(layout.placed_instances == before_stock and layout.snapshot() == before_poses and layout.undo_stack.size() == before_history,"blocked placement leaves no ghost nodes, partial copy or undo record")
	check(layout.group_selection == selected_sources,"failed group duplication retains original active selection")
	layout.furniture_colors[str(layout.placed_instances["lamp_1"])] = 4
	layout._apply_furniture_appearance()
	var before_success: Dictionary = layout._draft()
	var history_before_copy: int = layout.undo_stack.size()
	check(layout.begin_group_copy_preview(),"two owned spare furniture items start a non-destructive group copy preview")
	var actions = desktop.room_ui.scene_actions
	check(layout.group_copy_preview_active and layout.group_copy_preview_valid and layout.group_copy_preview_nodes.size() == 2, "preview chooses an initial collision-safe group landing point and shows both ghosts")
	check(actions.group_copy_panel.visible and not actions.group_copy_confirm.disabled and actions.group_copy_status.text.contains("可复制"),"copy preview displays an enabled confirmation and member-count feedback")
	check(not actions.action_strip.visible and not actions.rail.visible and not desktop.room_ui.catalog_toggle.visible, "copy preview hides conflicting furniture actions and inventory drawer")
	var ghost_count := 0
	for source: String in layout.group_copy_preview_sources:
		var ghost: Node3D = layout.group_copy_preview_nodes[source]
		ghost_count += ghost.find_children("*","MeshInstance3D",true,false).size()
		for collider: CollisionObject3D in ghost.find_children("*","CollisionObject3D",true,false):
			check(collider.collision_layer == 0 and not collider.input_ray_pickable,"preview meshes have no pickable collider or room physics layer")
	check(ghost_count > 0 and layout.group_copy_preview_good.albedo_color.a < .5,"copy ghosts use real transparent material overrides")
	check(layout.placed_instances == before_success.placements and layout.snapshot() == before_success.poses and layout.undo_stack.size() == history_before_copy,"creating transparent copy ghosts writes no layout, UID or undo changes")
	var initial_offset: Vector2 = layout.group_copy_preview_offset
	check(not layout.set_group_copy_preview_offset(Vector2.ZERO) and not layout.group_copy_preview_valid,"preview at original furniture locations is blocked")
	check(actions.group_copy_confirm.disabled and actions.group_copy_status.text.contains("无法复制"),"blocked preview disables confirm and explains collision")
	check(not layout.confirm_group_copy_preview(),"blocked red preview cannot create a partial copied object")
	check(layout.placed_instances == before_success.placements and layout.undo_stack.size() == history_before_copy,"invalid preview confirmation does not touch stock or history")
	check(layout.set_group_copy_preview_offset(initial_offset),"moving the ghost group back to its safe initial offset restores valid confirmation")
	# P40: preview rigid rotation, exact 1 cm movement and a new safe
	# candidate must not write inventory, transforms or undo state.
	var pivot_before_copy: Vector2 = layout.group_pivot()
	var normal_step: float = layout.grid_step
	var yaw_before: float = layout.group_copy_preview_yaw
	check(layout.nudge_group_copy_preview(Vector2.RIGHT,true) or not layout.group_copy_preview_valid,"Shift+arrow fine movement updates preview even if the destination is blocked")
	check(absf(layout.group_copy_preview_offset.x-(initial_offset.x+.01)) < .002 and layout.snapping,"fine movement adds exactly 1 cm without disabling the global grid")
	var fine_offset: Vector2 = layout.group_copy_preview_offset
	layout.nudge_group_copy_preview(Vector2(0,-1))
	check(absf(layout.group_copy_preview_offset.y-snappedf(fine_offset.y-normal_step,normal_step)) < .003,"normal arrow movement uses configured grid step on the room Z axis")
	check(layout.rotate_group_copy_preview_step(1,true) or not layout.group_copy_preview_valid,"Shift+E rotates preview by a fine one-degree step")
	check(absf(rad_to_deg(layout.group_copy_preview_yaw-yaw_before)-1.0) < .01,"fine rotation is precisely 1 degree")
	check(layout.rotate_group_copy_preview_step(1) or not layout.group_copy_preview_valid,"E rotates the group by another regular 15 degrees")
	check(absf(rad_to_deg(layout.group_copy_preview_yaw)-16.0) < .01,"regular rotation preserves fine yaw and adds exactly 15 degrees")
	var preview_pivot: Vector2 = layout.group_pivot()
	var ghost_lamp: Transform3D = layout.group_copy_preview_nodes["lamp"].transform
	var expected_ghost: Transform3D = layout._group_copy_pose("lamp",layout.group_copy_preview_offset,layout.group_copy_preview_yaw,preview_pivot)
	check(ghost_lamp.is_equal_approx(expected_ghost),"3D ghost transform uses rigid rotation about the actual shared center")
	layout.rotate_group_copy_preview_step(-1)
	layout.rotate_group_copy_preview_step(-1,true)
	check(absf(layout.group_copy_preview_yaw) < .0001 and layout.group_pivot().distance_to(pivot_before_copy) < .001,"opposite rotations restore yaw and never shift source pivot")
	layout.set_group_copy_preview_offset(Vector2.ZERO)
	check(layout.find_group_copy_preview_space() and layout.group_copy_preview_valid and not layout.group_copy_preview_offset.is_zero_approx(),"F-style nearest-free-space search repairs a blocked group without creating inventory")
	check(layout.snapshot() == before_success.poses and layout.placed_instances == before_success.placements and layout.undo_stack.size() == history_before_copy,"precision and auto-find actions are transient previews only")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	desktop._input(esc)
	check(not layout.group_copy_preview_active and layout.group_copy_preview_nodes.is_empty() and not actions.group_copy_panel.visible,"Escape discards all preview ghosts and UI without clearing original multiselection")
	check(layout.group_selection == selected_sources and layout.placed_instances == before_success.placements and layout.undo_stack.size() == history_before_copy,"canceling preview preserves sources, selection, colors and undo")
	check(layout.begin_group_copy_preview() and layout.group_copy_preview_valid,"group copy preview may restart immediately after cancellation")
	var rotated_valid: bool = layout.rotate_group_copy_preview_step(1)
	if not rotated_valid: rotated_valid = layout.find_group_copy_preview_space()
	check(rotated_valid and layout.group_copy_preview_valid,"rotated group can be re-positioned into a collision-safe landing pose")
	var committed_offset: Vector2 = layout.group_copy_preview_offset
	var committed_yaw: float = layout.group_copy_preview_yaw
	var committed_pivot: Vector2 = layout.group_pivot()
	var original_poses: Dictionary = layout.snapshot()
	check(layout.confirm_group_copy_preview(),"explicit confirmation commits both rotated owned spare instances at the visible ghost poses")
	check(not layout.group_copy_preview_active and layout.group_copy_preview_nodes.is_empty() and not actions.group_copy_panel.visible,"successful confirmation destroys preview ghosts and returns to ordinary furniture edit")
	var new_roles: Array[String] = layout.group_selection.duplicate()
	check(new_roles.size() == 2 and layout.selected == str(plan.copies["lamp_1"].role),"newly created pair becomes the active selection with original primary preserved")
	check(layout.undo_stack.size() == history_before_copy+1 and layout.placed_instances.size() == before_stock.size()+2,"entire batch copy has one history entry and exactly two additional placements")
	check(layout.valid and layout._layout_blocker().is_empty(),"group copy never intersects the walls, source pair, other furniture or itself")
	var originals_delta := Vector2.ZERO
	if new_roles.size() == 2:
		var first_new: String = str(plan.copies["lamp"].role)
		var second_new: String = str(plan.copies["lamp_1"].role)
		check(layout.nodes.has(first_new) and layout.nodes.has(second_new),"each destination role is present as a distinct 3D scene instance")
		check(str(layout.placed_instances.get(first_new,"")) == str(plan.copies["lamp"].uid) and str(layout.placed_instances.get(second_new,"")) == str(plan.copies["lamp_1"].uid),"copy role and stock UIDs match the complete preflight plan")
		var first_expected: Transform3D = layout._group_copy_pose("lamp",committed_offset,committed_yaw,committed_pivot)
		var second_expected: Transform3D = layout._group_copy_pose("lamp_1",committed_offset,committed_yaw,committed_pivot)
		check(layout.nodes[first_new].transform.is_equal_approx(first_expected) and layout.nodes[second_new].transform.is_equal_approx(second_expected),"actual copied poses exactly match the rotated ghost group's rigid X/Z transforms and member yaws")
		check(original_poses["lamp"].is_equal_approx(layout.nodes["lamp"].transform) and original_poses["lamp_1"].is_equal_approx(layout.nodes["lamp_1"].transform),"preview/confirm rotation never modifies the source furniture poses")
		check(layout.color_for(first_new) == 0 and layout.color_for(second_new) == 4,"per-member furniture color is copied to each new inventory UID")
	var copied_poses: Dictionary = layout.snapshot()
	var copy_inventory: Dictionary = layout.placed_instances.duplicate()
	layout.undo()
	check(layout.placed_instances == before_success.placements and not layout.nodes.has(str(plan.copies["lamp"].role)) and not layout.nodes.has(str(plan.copies["lamp_1"].role)),"one undo completely removes all batch duplicates and restores original inventory placements")
	layout.redo()
	check(layout.placed_instances == copy_inventory and layout.snapshot() == copied_poses and layout.valid,"one redo recreates the same copied group roles, UIDs, colors and safe transforms")
	layout.select(str(plan.copies["lamp"].role))
	layout.toggle_group_member(str(plan.copies["lamp_1"].role))
	var history_before_store: int = layout.undo_stack.size()
	check(layout.store_group(),"bulk storage accepts two actual placed group members")
	check(layout.group_selection.is_empty() and layout.selected == "desk","batch storage leaves no dangling selected roles or group gizmo")
	check(layout.placed_instances == before_stock and layout.undo_stack.size() == history_before_store+1,"bulk storage removes both copies using one undo step")
	check(layout.available_inventory.any(func(entry: Dictionary) -> bool: return str(entry.uid) == "item_97012") and layout.available_inventory.any(func(entry: Dictionary) -> bool: return str(entry.uid) == "item_97013"),"storage frees two placements without destroying owned physical stock")
	layout.undo()
	check(layout.placed_instances == copy_inventory and layout.valid,"one undo restores every stored member at its original pose")
	layout.redo()
	check(layout.placed_instances == before_stock and layout.valid,"one redo stores the same pair again")
	layout.select("lamp")
	layout.toggle_group_member("lamp_1")
	var history_before_source_store: int = layout.undo_stack.size()
	check(layout.store_group(),"batch storage also accepts mixed authored and copied furniture roles")
	check(not layout.placed_instances.has("lamp") and not layout.placed_instances.has("lamp_1") and layout.undo_stack.size() == history_before_source_store+1,"both original roles are stored atomically")
	check(layout.available_inventory.any(func(entry: Dictionary) -> bool: return str(entry.uid) == "starter_lamp"),"storing the authored lamp preserves its original ownership UID")
	layout.undo()
	check(layout.placed_instances == before_stock and layout.valid,"undo restores authored and copied group sources together")
	layout.redo()
	check(not layout.placed_instances.has("lamp") and not layout.placed_instances.has("lamp_1"),"redo safely repeats the entire source group storage")
	desktop.finish_layout(false)
	check(layout.snapshot() == original.poses and layout.placed_instances == original.placements,"canceling editor restores the initial scene and owned placements after all bulk operations")
	game.queue_free()
	await frames()
	print("FURNITURE_BATCH_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
