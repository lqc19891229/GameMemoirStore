extends SceneTree
## P41: continuous group-copy batches independently reserve inventory and undo.
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var actions = desktop.room_ui.scene_actions
	for removed: String in ["chair","bookcase","rug","plant"]:
		layout.placed_instances.erase(removed)
	layout._create_copy("lamp_1")
	layout.available_inventory.append({"uid":"item_98111","item_id":"room_lamp"})
	layout.placed_instances["lamp_1"] = "item_98111"
	for uid in ["item_98112","item_98113","item_98114","item_98115"]:
		layout.available_inventory.append({"uid":uid,"item_id":"room_lamp"})
	layout._apply_furniture_appearance()
	var found := false
	for z in [-2.3,-2.0,1.8,2.1]:
		for distance in [2.0,2.4,2.8,3.0]:
			layout.nodes["lamp"].position = Vector3(-distance*.5,layout.nodes["lamp"].position.y,z)
			layout.nodes["lamp_1"].position = Vector3(distance*.5,layout.nodes["lamp_1"].position.y,z)
			if not layout._layout_blocker().is_empty(): continue
			layout.select("lamp")
			layout.toggle_group_member("lamp_1")
			if not layout._find_group_copy_offset(Vector2.ZERO,0.0).is_empty():
				found = true
				break
		if found: break
	check(found,"fixture has a collision-free room layout and initial group copy candidate")
	if not found:
		desktop.finish_layout(false)
		game.queue_free()
		await frames()
		quit(1)
		return
	var sources: Array[String] = layout.group_selection.duplicate()
	var original: Dictionary = layout._draft()
	var original_undo: int = layout.undo_stack.size()
	layout.furniture_colors[str(layout.placed_instances["lamp_1"])] = 4
	layout._apply_furniture_appearance()
	check(layout.begin_group_copy_preview() and layout.group_copy_preview_valid,"continuous batch preview initializes with two stocked furniture copies")
	check(not layout.group_copy_repeat and layout.group_copy_preview_placed_count == 0,"continuous placement is opt-in and defaults to single confirmation")
	check(actions.group_copy_repeat_button.visible and not actions.group_copy_repeat_button.button_pressed,"continuous-mode toggle starts off in the scene confirmation panel")
	actions.group_copy_repeat_button.pressed.emit()
	check(layout.group_copy_repeat and actions.group_copy_repeat_button.button_pressed and actions.group_copy_confirm.text.contains("继续"),"scene toggle enables continuous group-copy placement and updates confirmation label")
	var first_plan: Dictionary = layout.group_copy_preview_plan.duplicate(true)
	var yaw_valid: bool = layout.rotate_group_copy_preview_step(1)
	if not yaw_valid: yaw_valid = layout.find_group_copy_preview_space()
	check(yaw_valid,"continuous group can choose a safe rotated placement")
	var yaw: float = layout.group_copy_preview_yaw
	actions.confirm_group_copy_preview()
	var first_batch: Array[String] = layout.group_copy_last_roles.duplicate()
	var after_first: Dictionary = layout._draft()
	check(layout.group_copy_preview_active and layout.group_copy_repeat and layout.group_copy_preview_placed_count == 1,"first placement commits and keeps live ghosts for the next copy")
	check(layout.group_selection == sources and layout.selected == "lamp_1","continuous mode continues copying original furniture rather than newly created copies")
	check(first_batch.size() == 2 and layout.placed_instances.size() == original.placements.size()+2,"first batch installs exactly two independently owned furniture instances")
	check(layout.undo_stack.size() == original_undo+1 and layout.valid and layout._layout_blocker().is_empty(),"first batch is valid and produces one undo transaction")
	check(absf(layout.group_copy_preview_yaw-yaw) < .0001 and layout.group_copy_preview_plan != first_plan,"next ghost retains chosen rotation but reserves a different inventory UID pair")
	check(actions.group_copy_status.text.contains("已放置 1 组"),"preview clearly reports number of already committed batches")
	check(layout.group_copy_preview_nodes.size() == 2 and layout.group_copy_preview_sources == sources,"repeat reuses its two original non-pickable preview models")
	for source: String in sources:
		var first_uid: String = str(first_plan[source].uid)
		check(after_first.placements.values().has(first_uid) and not layout.group_copy_preview_plan.values().has(first_plan[source]),"committed stock stays placed and never becomes another batch's reservation")
	if not layout.group_copy_preview_valid:
		check(layout.find_group_copy_preview_space(),"next ghost can be moved to a fresh safe location after first placement")
	check(layout.group_copy_preview_valid,"second batch has a valid copy landing point")
	# No free floor: the next batch is blocked but the previous batch is intact.
	var edge_before: float = layout.edge_margin
	layout.edge_margin = 100.0
	layout.set_group_copy_preview_offset(layout.group_copy_preview_offset,true)
	check(not layout.group_copy_preview_valid and not layout.confirm_group_copy_preview(),"a blocked next batch cannot commit even though an earlier batch succeeded")
	check(layout.placed_instances == after_first.placements and layout.undo_stack.size() == original_undo+1 and layout.group_copy_preview_active,"failure during the second batch preserves the entire first batch and keeps placement active")
	layout.edge_margin = edge_before
	check(layout.find_group_copy_preview_space() and layout.group_copy_preview_valid,"automatic space search recovers after temporary room blockage")
	# Losing a reserved UID must not silently substitute another one.
	var reserved_uid: String = str(layout.group_copy_preview_plan["lamp_1"].uid)
	var removed: Dictionary = {}
	for i in range(layout.available_inventory.size()-1,-1,-1):
		if str(layout.available_inventory[i].get("uid","")) == reserved_uid:
			removed = layout.available_inventory[i]
			layout.available_inventory.remove_at(i)
			break
	check(not removed.is_empty(),"second preview reserves an actual owned unused UID")
	layout.set_group_copy_preview_offset(layout.group_copy_preview_offset,true)
	check(not layout.group_copy_preview_valid and not layout.confirm_group_copy_preview() and layout.undo_stack.size() == original_undo+1,"loss of next reserved UID prevents copying without modifying previous batch")
	layout.available_inventory.append(removed)
	check(layout.set_group_copy_preview_offset(layout.group_copy_preview_offset,true),"restoring the exact same UID makes the next preview valid again")
	var second_plan: Dictionary = layout.group_copy_preview_plan.duplicate(true)
	desktop._input(key(KEY_ENTER))
	var second_batch: Array[String] = layout.group_selection.duplicate()
	var after_second: Dictionary = layout._draft()
	check(not layout.group_copy_preview_active and not layout.group_copy_repeat and layout.group_copy_preview_placed_count == 2,"second Enter confirmation automatically exits repeat mode when inventory is depleted")
	check(layout.group_copy_preview_end_reason.contains("库存") and actions.group_copy_panel.visible == false,"stock exhaustion explains why continuation ended and removes ghost panel")
	check(layout.placed_instances.size() == original.placements.size()+4 and layout.undo_stack.size() == original_undo+2,"two confirmed batches consume four distinct spare UIDs and create precisely two undo records")
	check(second_batch.size() == 2 and layout.selected == str(second_plan["lamp_1"].role),"after automatic stop the last placed batch is selected")
	check(layout.valid and layout._layout_blocker().is_empty(),"both placed groups remain collision-safe and all source objects survive")
	for source: String in sources:
		check(str(first_plan[source].uid) != str(second_plan[source].uid),"consecutive batches never reuse the same inventory UID for " + source)
		check(str(layout.placed_instances[str(first_plan[source].role)]) == str(first_plan[source].uid),"first copied group remains owned after second placement: " + source)
		check(str(layout.placed_instances[str(second_plan[source].role)]) == str(second_plan[source].uid),"second copied group receives correct new UID: " + source)
	check(layout.furniture_colors.get(str(second_plan["lamp_1"].uid),0) == 4 and layout.furniture_colors.get(str(first_plan["lamp_1"].uid),0) == 4,"both copies independently retain source furniture finish")
	layout.undo()
	check(layout.placed_instances == after_first.placements and layout.valid and layout.undo_stack.size() == original_undo+1,"first Ctrl+Z removes only the second batch while preserving the first one")
	layout.undo()
	check(layout.placed_instances == original.placements and layout.undo_stack.size() == original_undo,"second Ctrl+Z removes the first batch while restoring original owned sources")
	layout.redo()
	check(layout.placed_instances == after_first.placements,"first Ctrl+Y restores only the first placed batch")
	layout.redo()
	check(layout.placed_instances == after_second.placements and layout.snapshot() == after_second.poses,"second Ctrl+Y restores all finished batches to their exact transforms")
	desktop.finish_layout(false)
	game.queue_free()
	await frames()
	print("FURNITURE_CONTINUOUS_COPY_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
