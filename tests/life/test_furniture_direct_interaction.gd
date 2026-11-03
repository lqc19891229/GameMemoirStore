extends SceneTree
## P21: direct object manipulation, contextual wall magnet, bypass and HUD feedback.
const Inventory = preload("res://scripts/items/inventory_data.gd")
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

func mouse(at: Vector2, down: bool, shift: bool = false, alt: bool = false, ctrl: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = down
	event.shift_pressed = shift
	event.alt_pressed = alt
	event.ctrl_pressed = ctrl
	return event

func motion(at: Vector2, shift: bool = false) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event

func screen_bounds(layout, role: String, camera: Camera3D) -> Rect2:
	var node: Node3D = layout.nodes[role]
	var half: Vector3 = layout.bounds_for(role)*.5
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			for y in [0.0,1.0]:
				var point: Vector2 = camera.unproject_position(node.to_global(Vector3(half.x*x,half.y*y*2,half.z*z)))
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return Rect2(minimum,maximum-minimum)

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	desktop.begin_layout()
	var layout = world.layout
	var ui = desktop.room_ui
	var saved: Dictionary = layout.snapshot()
	var stock: Dictionary = layout.placed_instances.duplicate()

	check(layout.active and layout.smart_snap, "contextual magnetic assistance is available without enabling advanced options")
	check(not layout.wall_snap and not layout.inner_wall_snap, "advanced persistent wall snap toggles still default to off")
	check(not ui.feedback.visible and ui.feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visual feedback starts hidden and does not block pointer events")
	check(ui.feedback_state == "none" and ui._confirmation_timer.one_shot, "placement feedback begins inactive and completion banner is temporary")
	check(ui.feedback_pose_text.mouse_filter == Control.MOUSE_FILTER_IGNORE, "live transform readout never intercepts 3D mouse picking")

	# Find a genuine ray-pickable body point; never confuse a gizmo hit for an object.
	var picked := ""
	var pixel := Vector2.ZERO
	for role: String in ["chair","bookcase","plant","lamp","rug"]:
		if not layout.nodes.has(role) or not layout.placed_instances.has(role): continue
		layout.select(role)
		var furniture: Node3D = layout.nodes[role]
		var dims: Vector3 = layout.bounds_for(role)
		for f: float in [0.24,0.48,0.73]:
			for x: float in [-0.28,0.0,0.28]:
				var candidate: Vector2 = world.camera.unproject_position(furniture.to_global(Vector3(dims.x*x,dims.y*f,0)))
				if world.pick_at(candidate) == role and layout.pick_handle(candidate).is_empty():
					picked = role
					pixel = candidate
					break
			if not picked.is_empty(): break
		if not picked.is_empty(): break
	check(not picked.is_empty(), "at least one authored furniture body is directly ray-selectable")
	if not picked.is_empty():
		layout.select(picked)
		layout.set_tool("rotate")
		var original_pose: Transform3D = layout.nodes[picked].transform
		var original_undo_size: int = layout.undo_stack.size()
		desktop._layout_input(mouse(pixel,true))
		check(layout.selected == picked and layout.gesture.is_empty() and desktop.pending_drag_role == picked, "mouse-down selects furniture without starting movement")
		desktop._layout_input(motion(pixel+Vector2(3,2)))
		check(layout.gesture.is_empty() and layout.nodes[picked].transform.is_equal_approx(original_pose), "pointer jitter under six pixels cannot move selected furniture")
		desktop._layout_input(mouse(pixel+Vector2(3,2),false))
		check(desktop.pending_drag_role.is_empty() and layout.gesture.is_empty() and layout.undo_stack.size() == original_undo_size, "click-release creates no ghost drag or unnecessary undo record")
		check(layout.nodes[picked].transform.is_equal_approx(original_pose) and not ui.feedback.visible, "clicking to select leaves pose and transient feedback unchanged")
		desktop._layout_input(mouse(pixel,true))
		desktop._layout_input(motion(pixel+Vector2(14,0)))
		check(desktop.pending_drag_role.is_empty() and layout.gesture == "move", "drag beyond threshold moves furniture even when rotate tool is selected")
		check(ui.feedback.visible and ui.feedback_text.text.contains("移动"), "actual drag shows movement cue only after threshold")
		check(ui.feedback_pose_text.text.contains("X ") and ui.feedback_pose_text.text.contains("Z ") and ui.feedback_pose_text.text.contains("角度"), "freehand dragging shows live local coordinates and yaw")
		check(ui.feedback_pose_text.text.contains("网格 0.05 m") and ui.feedback_pose_text.text.contains("旋转步长 15°"), "precision readout reflects real grid and angle increments")
		desktop._layout_input(mouse(pixel+Vector2(14,0),false))
		check(layout.gesture.is_empty() and layout.tool == "rotate", "release completes movement while preserving selected gizmo tool")
		desktop._layout_input(mouse(pixel,true,true))
		check(layout.gesture.is_empty() and desktop.pending_drag_operation == "rotate", "Shift+mouse-down arms rotation without immediately transforming furniture")
		desktop._layout_input(motion(pixel+Vector2(0,14),true))
		check(layout.gesture == "rotate", "Shift+drag beyond threshold activates rotation")
		check(ui.feedback.visible and ui.feedback_text.text.contains("旋转"), "selected object shows short non-blocking rotation feedback during real drag")
		desktop._layout_input(mouse(pixel+Vector2(0,14),false,true))
		check(layout.gesture.is_empty() and not ui.feedback.visible, "releasing rotation clears transient visual feedback")

	# Actual Ctrl+click on two distinct ray-pickable furniture bodies must
	# change selection membership without starting a drag or undo transaction.
	if not picked.is_empty():
		var second_role := ""
		var second_pixel := Vector2.ZERO
		for role: String in ["chair","bookcase","plant","lamp","rug"]:
			if role == picked or not layout.placed_instances.has(role): continue
			layout.select(role)
			var furniture: Node3D = layout.nodes[role]
			var dims: Vector3 = layout.bounds_for(role)
			for f: float in [0.24,0.48,0.73]:
				for x: float in [-0.28,0.0,0.28]:
					var candidate: Vector2 = world.camera.unproject_position(furniture.to_global(Vector3(dims.x*x,dims.y*f,0)))
					if world.pick_at(candidate) == role and layout.pick_handle(candidate).is_empty():
						second_role = role
						second_pixel = candidate
						break
				if not second_role.is_empty(): break
			if not second_role.is_empty(): break
		check(not second_role.is_empty(), "a second room furniture body can be clicked for additive selection")
		if not second_role.is_empty():
			layout.select(picked)
			var selection_before: Dictionary = layout.snapshot()
			var history_depth: int = layout.undo_stack.size()
			desktop._layout_input(mouse(second_pixel,true,false,false,true))
			desktop._layout_input(mouse(second_pixel,false,false,false,true))
			check(layout.group_selection.size() == 2 and layout.group_selection.has(picked) and layout.group_selection.has(second_role), "Ctrl+click adds a second real furniture item without clearing first selection")
			check(layout.gesture.is_empty() and desktop.pending_drag_role.is_empty(), "Ctrl+click does not secretly arm a movement gesture")
			check(layout.snapshot() == selection_before and layout.undo_stack.size() == history_depth, "Ctrl+click does not transform furniture or write undo history")
			check(layout.group_markers.size() == 1 and ui.scene_actions.selection_chip.text.contains("已选 2 件"), "multi-selection has both a secondary 3D outline and a contextual furniture-count label")
			check(not ui.scene_actions.action_buttons["store"].disabled and ui.scene_actions.action_buttons["duplicate"].disabled and not ui.scene_actions.action_buttons["paint"].disabled and not ui.scene_actions.action_buttons["arrange"].disabled, "multi-selection supports batch storage but blocks duplication when it lacks enough unused inventory UIDs")
			layout.store_selected()
			check(layout.placed_instances.has(second_role), "storage shortcuts cannot silently remove one member of a multi-selection")
			desktop._layout_input(mouse(second_pixel,true,false,false,true))
			desktop._layout_input(mouse(second_pixel,false,false,false,true))
			check(layout.group_selection.size() == 1, "Ctrl+click on an existing extra member removes it from the current group")
			# Whole-body projected bounds make marquee selection camera-aware.
			# A tiny crossing window hits the second item but cannot fully
			# enclose it: left-to-right versus right-to-left are distinct.
			var second_bounds: Rect2 = screen_bounds(layout,second_role,world.camera)
			var small_window := Rect2(second_bounds.get_center()-Vector2(3,3),Vector2(6,6))
			check(layout.marquee_candidates(small_window,true).has(second_role), "right-to-left crossing selection finds an intersected room object")
			check(not layout.marquee_candidates(small_window,false).has(second_role), "left-to-right box requires the complete projected furniture bounds")
			var whole_window: Rect2 = screen_bounds(layout,picked,world.camera).merge(second_bounds).grow(24.0)
			var whole_candidates: Array[String] = layout.marquee_candidates(whole_window)
			check(whole_candidates.has(picked) and whole_candidates.has(second_role), "room marquee finds two 3D furniture footprints without selecting hardware")
			for role: String in whole_candidates:
				check(layout._group_eligible(role), "screen-space marquee excludes desk devices and unplaced inventory furniture")
			var blank_start := Vector2(INF,INF)
			var blank_finish := Vector2.ZERO
			for corner_id in range(4):
				var test_start: Vector2
				var test_end: Vector2
				match corner_id:
					0:
						test_start = whole_window.position
						test_end = whole_window.end
					1:
						test_start = whole_window.end
						test_end = whole_window.position
					2:
						test_start = Vector2(whole_window.position.x,whole_window.end.y)
						test_end = Vector2(whole_window.end.x,whole_window.position.y)
					_:
						test_start = Vector2(whole_window.end.x,whole_window.position.y)
						test_end = Vector2(whole_window.position.x,whole_window.end.y)
				if world.pick_at(test_start).is_empty() and layout.pick_handle(test_start).is_empty():
					blank_start = test_start
					blank_finish = test_end
					break
			check(blank_start.x != INF, "box selection begins in blank screen space rather than dragging a furniture body")
			if blank_start.x != INF:
				layout.select(picked)
				var poses_before_marquee: Dictionary = layout.snapshot()
				var history_before_marquee: int = layout.undo_stack.size()
				desktop._layout_input(mouse(blank_start,true))
				desktop._layout_input(motion(blank_finish))
				check(desktop.marquee_active and ui.scene_actions.marquee_box.visible and ui.scene_actions.marquee_box.mouse_filter == Control.MOUSE_FILTER_IGNORE, "dragging blank floor reveals a transparent screen-space selection rectangle")
				check(layout.gesture.is_empty() and desktop.pending_drag_role.is_empty(), "marquee never arms furniture transform gestures")
				desktop._layout_input(mouse(blank_finish,false))
				check(not desktop.marquee_pending and not ui.scene_actions.marquee_box.visible, "marquee rectangle disappears immediately after pointer release")
				check(layout.group_selection.has(picked) and layout.group_selection.has(second_role) and layout.group_selection.size() >= 2, "screen-space drag selects the intended furniture as one group")
				check(layout.snapshot() == poses_before_marquee and layout.undo_stack.size() == history_before_marquee, "marquee selection does not change poses, owned stock or undo history")
				layout.select(picked)
				layout.marquee_select(second_bounds.grow(24),false,true)
				check(layout.group_selection.has(picked) and layout.group_selection.has(second_role), "Ctrl-style marquee adds furniture while keeping existing selected members")
				layout.select(picked)

	# A close-to-wall probe should snap during direct dragging, but never
	# mutate an actual furniture transform just by checking a candidate.
	layout.select("lamp")
	var lamp_before: Transform3D = layout.nodes["lamp"].transform
	var candidate_found := false
	var probe := Vector2.ZERO
	var destination := Vector2.ZERO
	layout.gesture = "move"
	for coordinate in range(-10,11):
		for side in range(4):
			var along: float = float(coordinate) * 0.35
			var half: Vector2 = layout.room_half_size
			var edge_offset := 0.42
			var trial: Vector2
			match side:
				0: trial = Vector2(along, -half.y + edge_offset)
				1: trial = Vector2(along, half.y - edge_offset)
				2: trial = Vector2(-half.x + edge_offset, along)
				_: trial = Vector2(half.x - edge_offset, along)
			var snapped: Vector2 = layout._wall_snap_point("lamp",trial)
			if layout.wall_magnet_active and snapped.distance_to(trial) > 0.005:
				candidate_found = true
				probe = trial
				destination = snapped
				break
		if candidate_found: break
	check(candidate_found, "freehand furniture movement finds a collision-free magnetic wall position")
	if candidate_found:
		check(destination.distance_to(probe) <= layout.WALL_SNAP_RADIUS + .001, "automatic wall magnet never pulls more than configured radius")
		check(layout.wall_magnet_active, "magnetic placement reports its active visual state")
		layout.update()
		check(ui.feedback_state == "snapped" and ui.feedback_text.text.contains("已吸附"), "magnetic feedback explains snap and Alt bypass beside selected furniture")
		check(ui.feedback_pose_text.text.contains("墙面已吸附") and ui.feedback_pose_text.text.contains("0.32 m"), "readout distinguishes wall magnets and uses configured attraction radius")
		layout.snap_bypass = true
		check(layout._wall_snap_point("lamp",probe).is_equal_approx(probe) and not layout.wall_magnet_active, "holding Alt bypasses wall and partition magnets")
		layout.update()
		check(ui.feedback_pose_text.text.contains("Alt 已跳过贴墙吸附"), "Alt bypass is explicitly visible in the live precision readout")
		layout.snap_bypass = false
	check(layout.nodes["lamp"].transform.is_equal_approx(lamp_before), "magnetic candidate checks never mutate existing furniture")
	layout.end_drag()
	check(not layout.wall_magnet_active and not layout.snap_bypass, "magnetic state resets on drag completion")

	# A placed owned piece can be stored, previewed, rotated by Shift+wheel,
	# rejected at an invalid coordinate, and canceled without affecting stock.
	layout.select("chair")
	layout.store_selected()
	var uid: String = Inventory.unused_uid(layout.available_inventory,layout.placed_instances,"room_chair")
	check(not uid.is_empty() and layout.start_place("room_chair",uid), "owned furniture can enter its transient ghost placement")
	check(ui.feedback.visible and not ui.feedback_text.text.is_empty(), "new ghost uses in-world textual placement feedback")
	if layout.valid:
		check(ui.feedback_state == "ready" and ui.feedback_text.text.contains("左键确认"), "collision-free ghost clearly marks it as ready for placement")
	else:
		check(ui.feedback_state == "blocked" and ui.feedback_text.text.contains("无法放置"), "initial blocked ghost clearly explains why placement is unavailable")
	check(ui.feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "semantic feedback remains transparent to mouse picking")
	check(ui.feedback_pose_text.text.contains("X ") and ui.feedback_pose_text.text.contains("Z "), "placement preview exposes actual projected coordinates")
	# Arrow nudges must reposition the temporary ghost, not confirm or consume it.
	layout.preview_placement(Vector2(0,2))
	var ghost_start: Vector3 = layout.nodes["chair"].position
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	desktop._input(arrow)
	check(absf(layout.nodes["chair"].position.x - ghost_start.x - layout.grid_step) < 0.003, "arrow-key placement preview advances by one grid cell")
	check(layout.placing_role == "chair" and layout.placed_instances["chair"] == uid, "nudge leaves preview active and preserves the owned furniture UID")
	var initial_yaw: float = layout.nodes["chair"].rotation.y
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll.pressed = true
	scroll.shift_pressed = true
	desktop._layout_input(scroll)
	check(absf(angle_difference(layout.nodes["chair"].rotation.y,initial_yaw)) > 0.05, "Shift+wheel rotates ghost without zooming the camera")
	var after_shift: float = layout.nodes["chair"].rotation.y
	scroll.shift_pressed = false
	scroll.ctrl_pressed = true
	desktop._layout_input(scroll)
	check(absf(angle_difference(layout.nodes["chair"].rotation.y,after_shift)) > 0.05, "Ctrl+wheel also rotates furniture ghost as in the reference game")
	var yaw_readout := "角度 %.0f°" % rad_to_deg(layout.nodes["chair"].rotation.y)
	check(ui.feedback_pose_text.text.contains(yaw_readout), "live orientation changes after Ctrl or Shift wheel rotation")
	layout.preview_placement(Vector2(50,50))
	check(ui.feedback_pose_text.text.contains("X 50.00 m") and ui.feedback_pose_text.text.contains("Z 50.00 m"), "rejected out-of-bounds placement shows the actual ghost position, not the last valid pose")
	layout.snapping = false
	layout.update()
	check(ui.feedback_pose_text.text.contains("自由定位") and ui.feedback_pose_text.text.contains("自由旋转"), "disabled grid and angle snapping are reflected immediately")
	layout.snapping = true
	layout.update()
	check(not layout.valid and ui.feedback_text.text.contains("边界"), "invalid furniture preview explicitly communicates the collision boundary")
	check(ui.feedback_state == "blocked" and ui.feedback_text.text.contains("无法放置"), "out-of-bounds ghost uses distinct collision warning instead of success")
	check(not layout.confirm_placement() and ui.feedback_state == "blocked", "invalid preview cannot trigger placement-complete confirmation")
	layout.cancel_placement()
	check(ui.feedback_state != "confirmed" and ui._confirmed_role.is_empty(), "canceling an invalid placement never displays a success banner")
	check(layout.placing_role.is_empty() and layout.placed_instances == stock or layout.placing_role.is_empty() and not layout.placed_instances.has("chair"), "canceling placement never creates an extra owned instance")
	if layout.start_place("room_chair",uid):
		if layout.valid:
			check(layout.confirm_placement(), "collision-free furniture preview confirms placement")
			check(ui.feedback_state == "confirmed" and ui.feedback_text.text.contains("已放置"), "confirmed furniture shows a nearby success cue")
			check(ui._confirmation_timer.time_left > 0.0, "completion cue has a finite lifetime")
			ui._confirmation_timer.stop()
			ui._confirmation_timer.timeout.emit()
			check(ui.feedback_state == "none" and not ui.feedback.visible, "completion cue dismisses without affecting furniture data")
			layout.undo()
			check(not layout.placed_instances.has("chair"), "undo still restores inventory after confirming furniture")
		else:
			layout.cancel_placement()
			check(false, "restored default chair position must be valid for placement")
	else:
		check(false, "canceled furniture can start another preview with the same UID")
	desktop.finish_layout(false)
	check(not layout.active and not ui.feedback.visible, "finishing editor hides feedback")
	check(ui.feedback_pose_text.get_parent() == ui.feedback_text.get_parent(), "readout stays grouped with nonblocking semantic feedback")
	check(layout.snapshot() == saved and layout.placed_instances == stock, "canceling layout preserves prior furniture transforms and inventory mappings")
	for role: String in world.devices:
		check(layout.surface_for(role) == "desk", "all computer devices remain restricted to the PC desk: "+role)
	game.queue_free()
	await frames()
	print("FURNITURE_DIRECT_INTERACTION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
