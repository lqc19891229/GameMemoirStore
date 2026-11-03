extends SceneTree
## P39 graphical test: actual UI clicks on group-copy confirm/cancel controls.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move,true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press,true)
	await process_frame
	press.pressed = false
	root.push_input(press,true)
	await frames()

func run() -> void:
	check(root.get_final_transform().x.length() >= .6, "Xvfb provides a real, full-scale graphical viewport")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var actions = desktop.room_ui.scene_actions
	for unused: String in ["chair","bookcase","rug","plant"]:
		layout.placed_instances.erase(unused)
	layout._create_copy("lamp_1")
	layout.available_inventory.append({"uid":"item_97511","item_id":"room_lamp"})
	layout.placed_instances["lamp_1"] = "item_97511"
	layout.available_inventory.append({"uid":"item_97512","item_id":"room_lamp"})
	layout.available_inventory.append({"uid":"item_97513","item_id":"room_lamp"})
	layout._apply_furniture_appearance()
	var fixture_ready := false
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
						fixture_ready = true
						break
				if fixture_ready: break
			if fixture_ready: break
		if fixture_ready: break
	check(fixture_ready,"two visible pieces admit a collision-safe offset for the real UI preview")
	if not fixture_ready:
		desktop.finish_layout(false)
		game.queue_free()
		await frames()
		quit(1)
		return
	await frames()
	check(actions.action_buttons["duplicate"].is_visible_in_tree() and not actions.action_buttons["duplicate"].disabled,"real contextual group-copy button is visible and stock-aware")
	var baseline: Dictionary = layout._draft()
	var count_before: int = layout.undo_stack.size()
	await click(actions.action_buttons["duplicate"])
	check(layout.group_copy_preview_active and layout.group_copy_preview_valid and actions.group_copy_panel.is_visible_in_tree(),"actual mouse click opens transparent group copy preview rather than committing duplicates")
	check(not actions.action_strip.is_visible_in_tree() and not actions.rail.is_visible_in_tree(),"active preview removes all competing furniture toolbar hit targets")
	check(layout.placed_instances == baseline.placements and layout.undo_stack.size() == count_before,"opening via real click does not modify draft or consume any stock")
	check(actions.group_copy_confirm.is_visible_in_tree() and actions.group_copy_cancel.is_visible_in_tree(),"explicit confirm and cancel buttons are clickable in graphical viewport")
	layout.set_group_copy_preview_offset(Vector2.ZERO)
	await frames()
	check(actions.group_copy_confirm.disabled and actions.group_copy_status.text.contains("无法复制"),"invalid preview visibly disables real confirm button")
	var status_before: Dictionary = layout._draft()
	await click(actions.group_copy_confirm)
	check(layout.group_copy_preview_active and layout.placed_instances == status_before.placements and layout.undo_stack.size() == count_before,"clicking disabled confirm cannot place overlapping furniture")
	await click(actions.group_copy_cancel)
	check(not layout.group_copy_preview_active and not actions.group_copy_panel.is_visible_in_tree() and layout.placed_instances == baseline.placements,"real cancel button leaves no preview or committed duplicate")
	await frames()
	check(actions.action_buttons["duplicate"].is_visible_in_tree(),"cancel restores the original contextual group-copy action")
	await click(actions.action_buttons["duplicate"])
	check(layout.group_copy_preview_valid and actions.group_copy_confirm.is_visible_in_tree() and not actions.group_copy_confirm.disabled,"reopened ghost group starts at a collision-safe offset ready for confirmation")
	await click(actions.group_copy_confirm)
	check(not layout.group_copy_preview_active and not actions.group_copy_panel.visible and layout.placed_instances.size() == baseline.placements.size()+2,"real GUI confirm click atomically commits the two furniture duplicates")
	check(layout.undo_stack.size() == count_before+1 and layout.valid and layout.group_selection.size() == 2,"confirm creates one undo step, valid positions and a selected duplicate group")
	layout.undo()
	check(layout.placed_instances == baseline.placements and layout.valid,"one undo restores original stock placement and removes all copied instances")
	desktop.finish_layout(false)
	game.queue_free()
	await frames()
	print("FURNITURE_COPY_PREVIEW_GUI_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
