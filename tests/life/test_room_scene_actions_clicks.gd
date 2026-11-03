extends SceneTree
## Graphical Xvfb regression for actual screen-space contextual buttons.
## Headless Godot uses a tiny 64x64 window with a 0.05 content scale and
## cannot meaningfully hit-test GUI located at 1280x800 logical pixels.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func frames(n: int = 3) -> void:
	for i in range(n): await process_frame

func click(control: Control) -> void:
	var pos: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	root.push_input(move,true)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down,true)
	await process_frame
	down.pressed = false
	root.push_input(down,true)
	await frames()

func run() -> void:
	var scale_x: float = root.get_final_transform().x.length()
	check(scale_x >= 0.6, "graphical viewport uses full-size GUI hit testing rather than the 64px headless fallback")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var ui = desktop.room_ui
	var actions = ui.scene_actions
	layout.select("chair")
	await frames(3)
	check(actions.action_strip.is_visible_in_tree(), "selected furniture has a visible compact context ribbon")
	check(actions.selection_chip.is_visible_in_tree() and actions.selection_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visible selection label does not intercept contextual GUI input")
	check(not desktop.get_node("%LayoutPanel").is_visible_in_tree(), "right inspector does not block the primary 3D pointer target")
	actions.show_marquee(Vector2(250,280),Vector2(520,450))
	check(actions.marquee_box.is_visible_in_tree() and actions.marquee_box.mouse_filter == Control.MOUSE_FILTER_IGNORE, "graphical marquee renders while allowing genuine pointer controls underneath")
	check(actions.marquee_box.position.distance_to(Vector2(250,280)) < 1.0 and actions.marquee_box.size.distance_to(Vector2(270,170)) < 1.0, "marquee geometry matches start/end screen coordinates")
	actions.hide_marquee()
	check(not actions.marquee_box.visible, "screen-space selection overlay clears before ordinary contextual GUI click tests")
	var paint: Button = actions.action_buttons["paint"]
	check(paint.get_global_rect().has_point(paint.get_global_rect().get_center()), "color button has a valid screen-space input rectangle")
	await click(paint)
	check(actions.swatches.is_visible_in_tree(), "real mouse click on object-side color button opens palette")
	check(actions.action_buttons["paint"].button_pressed, "real pointer click highlights the active color palette control")
	if actions.swatches.is_visible_in_tree():
		await click(actions.color_buttons[2])
	check(layout.color_for("chair") == 2, "real mouse click on palette swatch recolors selected furniture")
	check(not actions.swatches.visible and not actions.action_buttons["paint"].button_pressed, "palette and its active state clear after color selection")
	await click(actions.action_buttons["rotate"])
	check(layout.tool == "rotate" and actions.action_buttons["rotate"].button_pressed, "real mouse click activates the rotate gizmo and its button highlight")
	await click(actions.action_buttons["move"])
	check(layout.tool == "move" and actions.action_buttons["move"].button_pressed, "real mouse click restores move gizmo and its button highlight")
	await click(actions.action_buttons["arrange"])
	check(actions.arrange_panel.is_visible_in_tree() and actions.action_buttons["arrange"].button_pressed, "real click opens nearby arrangement popup without falling through to 3D furniture")
	check(actions.arrange_buttons["space_x"].disabled and actions.arrange_buttons["space_z"].disabled, "equal-spacing buttons are disabled without three same-type furniture items")
	await click(actions.action_buttons["arrange"])
	check(not actions.arrange_panel.visible and not actions.action_buttons["arrange"].button_pressed, "second real click dismisses the arrangement popup")
	var group_history: int = layout.undo_stack.size()
	var chair_pose: Transform3D = layout.nodes["chair"].transform
	var plant_pose: Transform3D = layout.nodes["plant"].transform
	check(layout.toggle_group_member("plant") and layout.group_selection.size() == 2, "graphical group manager starts with two real placed furniture items")
	await frames()
	check(actions.group_button.is_visible_in_tree() and actions.action_strip.is_visible_in_tree(), "contextual member button is reachable next to actual multi-selection")
	await click(actions.quick_groups_button)
	check(actions.quick_groups_panel.is_visible_in_tree() and actions.quick_slot_buttons.size() == 3, "actual GUI mouse click opens the left-rail quick-group picker")
	if actions.quick_groups_panel.is_visible_in_tree():
		await click(actions.quick_slot_buttons[1]["save"])
	check(layout.quick_group_size(1) == 2 and not actions.quick_slot_buttons[1]["recall"].disabled, "mouse save button stores both furniture UIDs and enables quick recall")
	await click(actions.quick_groups_button)
	check(not actions.quick_groups_panel.visible, "second actual click closes the quick-group picker")
	await click(actions.group_button)
	check(actions.group_panel.is_visible_in_tree() and actions.group_member_buttons.size() == 2, "real mouse click opens the contextual group members list")
	if actions.group_panel.is_visible_in_tree():
		await click(actions.group_member_buttons["chair"].primary)
	check(layout.selected == "chair" and layout.group_selection.size() == 2 and actions.group_panel.visible, "real member-row click changes primary without hiding the group manager")
	if actions.group_panel.is_visible_in_tree():
		await click(actions.group_member_buttons["plant"].remove)
	check(layout.group_selection.size() == 1 and not actions.group_panel.visible and not actions.group_button.visible, "real remove click drops only the selected membership")
	check(layout.nodes["chair"].transform.is_equal_approx(chair_pose) and layout.nodes["plant"].transform.is_equal_approx(plant_pose), "group manager click controls never move the actual 3D furniture")
	check(layout.undo_stack.size() == group_history and layout.placed_instances.has("chair") and layout.placed_instances.has("plant"), "group manager click controls do not add undo entries or alter inventory UIDs")
	await click(actions.quick_groups_button)
	check(actions.quick_groups_panel.is_visible_in_tree() and not actions.quick_slot_buttons[1]["recall"].disabled, "quick-group picker remains accessible after selection collapses to one item")
	if actions.quick_groups_panel.is_visible_in_tree():
		await click(actions.quick_slot_buttons[1]["recall"])
	check(layout.group_selection.size() == 2 and layout.group_selection.has("chair") and layout.group_selection.has("plant"), "real GUI recall button restores the previously selected furniture pair")
	check(not actions.quick_groups_panel.visible and layout.undo_stack.size() == group_history, "recall closes the popup and does not create undo history")
	await click(actions.action_buttons["arrange"])
	check(actions.arrange_panel.is_visible_in_tree() and actions.arrange_summary.text.contains("当前多选 2 件"), "real mouse click opens selected-group alignment instead of single-item same-category tools")
	check(actions.arrange_buttons["space_x"].disabled and actions.arrange_buttons["space_z"].disabled, "group equal-spacing buttons require three selected items")
	await click(actions.action_buttons["paint"])
	check(actions.swatches.is_visible_in_tree() and not actions.arrange_panel.visible, "real mouse click switches from group arrangement to the group color palette")
	if actions.swatches.is_visible_in_tree(): await click(actions.color_buttons[4])
	check(layout.color_for("chair") == 4 and layout.color_for("plant") == 4, "actual palette swatch click recolors both selected furniture items")
	check(layout.undo_stack.size() == group_history+1, "GUI group recolor creates only one undo entry")
	layout.undo()
	check(layout.color_for("chair") == 2 and layout.color_for("plant") == 0 and layout.undo_stack.size() == group_history, "one undo restores independent original colors for the whole group")
	check(not actions.action_buttons["store"].disabled and actions.action_buttons["duplicate"].disabled, "real group GUI permits storage but correctly disables copy when stock is missing")
	await click(actions.action_buttons["store"])
	check(not layout.placed_instances.has("chair") and not layout.placed_instances.has("plant") and layout.undo_stack.size() == group_history+1, "actual group store button stows both furniture instances in one undo step")
	layout.undo()
	check(layout.placed_instances.has("chair") and layout.placed_instances.has("plant") and layout.nodes["chair"].transform.is_equal_approx(chair_pose) and layout.nodes["plant"].transform.is_equal_approx(plant_pose), "single GUI store undo restores both original furniture and their poses")
	desktop.finish_layout(false)
	check(not actions.action_strip.is_visible_in_tree() and not actions.selection_chip.is_visible_in_tree() and not actions.arrange_panel.is_visible_in_tree() and not actions.group_panel.is_visible_in_tree() and not actions.quick_groups_panel.is_visible_in_tree(), "context buttons and both group panels are hidden outside room editing")
	check(layout.quick_groups.is_empty(), "session-only furniture presets do not persist after editor exit")
	check(not game.session.state.life.furniture_colors.has("starter_chair"), "GUI selection and swatches remain draft-only until room is saved")
	game.queue_free()
	await frames()
	print("ROOM_SCENE_POINTER_CHECKS: %d / %d passed" % [checks - failures,checks])
	quit(1 if failures else 0)
