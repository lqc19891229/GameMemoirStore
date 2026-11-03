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
	check(layout.duplicate_group(),"two owned spare instances are duplicated together into a safe room location")
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
		originals_delta = Vector2(layout.nodes[first_new].position.x-layout.nodes["lamp"].position.x,layout.nodes[first_new].position.z-layout.nodes["lamp"].position.z)
		var second_delta := Vector2(layout.nodes[second_new].position.x-layout.nodes["lamp_1"].position.x,layout.nodes[second_new].position.z-layout.nodes["lamp_1"].position.z)
		check(originals_delta.distance_to(second_delta) < .003,"group duplication translates each furniture by the same rigid X/Z offset")
		check(layout.nodes[first_new].basis.is_equal_approx(layout.nodes["lamp"].basis) and layout.nodes[second_new].basis.is_equal_approx(layout.nodes["lamp_1"].basis),"each duplicate retains its own original yaw")
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
