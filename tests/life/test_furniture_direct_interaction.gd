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

func mouse(at: Vector2, down: bool, shift: bool = false, alt: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = down
	event.shift_pressed = shift
	event.alt_pressed = alt
	return event

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
		desktop._layout_input(mouse(pixel,true))
		check(layout.selected == picked and layout.gesture == "move", "click-drag on furniture always moves it even when rotate tool is active")
		desktop._layout_input(mouse(pixel,false))
		check(layout.gesture.is_empty() and layout.tool == "rotate", "release completes move without changing the selected tool")
		desktop._layout_input(mouse(pixel,true,true))
		check(layout.gesture == "rotate", "Shift+mouse-down on furniture directly enters rotation")
		check(ui.feedback.visible and ui.feedback_text.text.contains("旋转"), "selected object shows short non-blocking rotation feedback")
		desktop._layout_input(mouse(pixel,false,true))
		check(layout.gesture.is_empty() and not ui.feedback.visible, "releasing rotation clears transient visual feedback")

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
		layout.snap_bypass = true
		check(layout._wall_snap_point("lamp",probe).is_equal_approx(probe) and not layout.wall_magnet_active, "holding Alt bypasses wall and partition magnets")
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
	var initial_yaw: float = layout.nodes["chair"].rotation.y
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll.pressed = true
	scroll.shift_pressed = true
	desktop._layout_input(scroll)
	check(absf(angle_difference(layout.nodes["chair"].rotation.y,initial_yaw)) > 0.05, "Shift+wheel rotates ghost without zooming the camera")
	layout.preview_placement(Vector2(50,50))
	check(not layout.valid and ui.feedback_text.text.contains("边界"), "invalid furniture preview explicitly communicates the collision boundary")
	layout.cancel_placement()
	check(layout.placing_role.is_empty() and layout.placed_instances == stock or layout.placing_role.is_empty() and not layout.placed_instances.has("chair"), "canceling placement never creates an extra owned instance")
	desktop.finish_layout(false)
	check(not layout.active and not ui.feedback.visible, "finishing editor hides feedback")
	check(layout.snapshot() == saved and layout.placed_instances == stock, "canceling layout preserves prior furniture transforms and inventory mappings")
	for role: String in world.devices:
		check(layout.surface_for(role) == "desk", "all computer devices remain restricted to the PC desk: "+role)
	game.queue_free()
	await frames()
	print("FURNITURE_DIRECT_INTERACTION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
