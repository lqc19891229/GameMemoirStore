extends SceneTree
const State = preload("res://scripts/store_state.gd")
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame
	await physics_frame
	await process_frame
func dispatch(event: InputEvent) -> void:
	root.window_input.emit(event.xformed_by(root.get_final_transform()))
	root.push_input(event,true)
func button(point: Vector2, down: bool, index: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = down
	dispatch(event)
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var event := InputEventMouseMotion.new()
	event.position = point
	dispatch(event)
	button(point,true)
	button(point,false)
	await frames()
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	dispatch(event)
	event.pressed = false
	dispatch(event)
	await frames()
func drag(from: Vector2, to: Vector2) -> void:
	button(from,true)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to-from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	dispatch(motion)
	button(to,false)
	await frames()
func same_poses(a: Dictionary,b: Dictionary) -> bool:
	for role: String in a:
		if not a[role].is_equal_approx(b[role]): return false
	return true
func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	var desktop = game.desktop
	var world = desktop.world
	var layout = world.layout
	var original: Dictionary = layout.snapshot()
	check(game.session.state.life["workstation_layout"].is_empty(), "old saves default to authored layout")
	check(layout.valid and not layout.active, "layout initially inactive")
	await click(desktop.get_node("%EditLayout"))
	check(layout.active and world.mode == "layout", "edit layout button enters arrangement mode")
	check(desktop.get_node("%LayoutPanel").visible and not desktop.get_node("%FocusToggle").visible, "arrangement shows dedicated controls and hides screen actions")
	var point: Vector2 = desktop.canvas_point_for_screen(Vector2(640,400))
	button(point,true)
	button(point,false)
	await frames()
	check(layout.selected == "monitor" and world.mode == "layout" and desktop.windows.is_empty(), "screen click selects monitor without launching OS")
	await click(desktop.get_node("%Layout_mouse"))
	var pad: Node3D = layout.gizmo.get_node("MoveHandles/MovePlane")
	var start: Vector2 = world.camera.unproject_position(pad.global_position)
	var target: Vector2 = world.camera.unproject_position(pad.global_position + layout.group.global_basis * Vector3(.45,0,.06))
	await drag(start,target)
	check(world.devices.mouse.position.distance_to(Vector3(.9,.78,.8)) < .03, "actual pointer drag moves mouse on tabletop")
	check(is_equal_approx(world.devices.mouse.position.x/.05,roundf(world.devices.mouse.position.x/.05)), "movement snaps to 5cm grid")
	await key(KEY_E)
	check(is_equal_approx(world.devices.mouse.rotation.y,deg_to_rad(15)), "E rotates selected device 15 degrees")
	await click(desktop.get_node("%SnapLayout"))
	check(not layout.snapping, "snap toggle disables both position and angle snapping")
	var xhandle: Node3D = layout.gizmo.get_node("MoveHandles/MoveX")
	start = world.camera.unproject_position(xhandle.global_position)
	check(layout.pick_handle(start) == "x", "X axis handle is ray-pickable")
	var before_axis: Vector3 = world.devices.mouse.position
	var direction: Vector3 = world.devices.mouse.basis.x.normalized()
	target = world.camera.unproject_position(xhandle.global_position + layout.group.global_basis * direction * .15)
	await drag(start,target)
	check((world.devices.mouse.position - before_axis).distance_to(direction * .15)<.01, "axis drag follows selected device orientation without cross-axis drift")
	await click(desktop.get_node("%SnapLayout"))
	await click(desktop.get_node("%RotateTool"))
	check(layout.tool == "rotate" and layout.gizmo.get_node("RotateHandles").visible, "rotation tool exposes 3D rotation handle")
	# Exercise ring picking and dragging via the real camera projection.
	await frames()
	var knob: Node3D = layout.gizmo.get_node("RotateHandles/Rotate")
	point = world.camera.unproject_position(knob.global_position)
	check(layout.pick_handle(point) == "rotate", "rotation knob is ray-pickable")
	start = world.camera.unproject_position(knob.global_position)
	target = world.camera.unproject_position(knob.get_parent().to_global(knob.position.rotated(Vector3.UP,PI/2)))
	var before_yaw: float = world.devices.mouse.rotation.y
	await drag(start,target)
	check(not is_equal_approx(world.devices.mouse.rotation.y,before_yaw), "ring drag rotates selected device")
	await key(KEY_ESCAPE)
	check(not layout.active and world.mode == "overview", "Escape cancels layout editing")
	check(same_poses(original,layout.snapshot()) and game.session.state.life["workstation_layout"].is_empty(), "cancel restores all transforms and never saves preview")
	await click(desktop.get_node("%EditLayout"))
	layout.select("computer")
	layout.move_to(Vector2(100,100))
	layout.rotate_to(PI/2)
	for corner in layout.footprint("computer"):
		check(absf(corner.x)<=2.4 and absf(corner.y)<=1.15, "rotated case footprint stays within tabletop")
	layout.reset_layout()
	layout.select("mouse")
	layout.move_to(Vector2(world.devices.keyboard.position.x,world.devices.keyboard.position.z))
	check(not layout.valid and desktop.get_node("%ApplyLayout").disabled, "overlapping footprints disable apply")
	check(layout.message.contains("重叠"), "overlap names the conflicting equipment")
	desktop.finish_layout(true)
	check(layout.active and game.session.state.life["workstation_layout"].is_empty(), "invalid arrangement cannot be committed through API")
	await click(desktop.get_node("%RestoreLayout"))
	check(layout.valid and same_poses(original,layout.snapshot()), "restore defaults repairs temporary conflicts")
	# Moving the table changes every global pose while retaining local equipment poses.
	layout.select("desk")
	layout.move_to(Vector2(.3,.1))
	layout.rotate_to(deg_to_rad(30))
	for role: String in world.devices:
		check(world.devices[role].transform.is_equal_approx(original[role]), "table transform preserves device local pose: "+role)
		check(not world.devices[role].global_position.is_equal_approx((original[role] as Transform3D).origin), "table carries device globally: "+role)
	layout.select("mouse")
	layout.move_to(Vector2(.9,.8))
	layout.rotate_to(deg_to_rad(30))
	layout.select("keyboard")
	layout.rotate_to(deg_to_rad(15))
	check(layout.valid, "custom table and device arrangement is valid")
	var browser = desktop.open_app("browser","inventory")
	var app_window = desktop.windows.browser
	var expected: Dictionary = layout.snapshot()
	game.session.state.save_state()
	check(same_poses(expected,layout.snapshot()), "background state refresh preserves the editing draft")
	var state = game.session.state
	state.save_path = "user://memoir_workstation_layout_test.json"
	state.persistence_enabled = true
	await click(desktop.get_node("%ApplyLayout"))
	check(not layout.active and world.mode == "overview", "apply returns to normal overview")
	check(not state.life["workstation_layout"].is_empty(), "apply writes arrangement to existing life save")
	desktop.begin_layout()
	layout.select("desk")
	layout.move_to(Vector2(1,1))
	desktop.finish_layout(false)
	check(same_poses(expected,layout.snapshot()), "cancel after apply restores committed layout rather than factory defaults")
	check(desktop.windows.browser == app_window and browser.tab == "inventory", "editing preserves application instances")
	for role: String in world.devices:
		desktop.select_device(role,false)
		check(world.devices[role].get_parent() == world.get_node("%InspectionStage"), "inspection stage is independent of moved table: "+role)
		desktop.set_screen_focused(false,false)
		check(same_poses(expected,layout.snapshot()), "inspection restores committed player arrangement: "+role)
	desktop.set_screen_focused(true,false)
	var uv: Variant = world.screen_uv(root.get_visible_rect().size/2)
	check(uv != null and uv.distance_to(Vector2(.5,.5))<.002, "moved and rotated monitor still frames correctly")
	desktop.set_screen_focused(false,false)
	state.wallet = 1000
	state.persistence_enabled = false
	game.session.buy_item("precise_mouse")
	game.session.equip_item("precise_mouse")
	check(same_poses(expected,layout.snapshot()), "equipping keyboard/mouse models preserves custom placement")
	state.persistence_enabled = true
	state.save_state()
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	var round_trip := true
	for role: String in state.life["workstation_layout"]:
		for field in ["x","z","yaw"]:
			round_trip = round_trip and is_equal_approx(restored.life["workstation_layout"][role][field],state.life["workstation_layout"][role][field])
	check(round_trip, "layout round-trips through disk save")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = restored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	check(same_poses(expected,resumed.desktop.world.layout.snapshot()), "new game instance restores persisted table and local device poses")
	resumed.desktop.begin_layout()
	resumed.desktop.world.layout.select("desk")
	resumed.desktop.world.layout.move_to(Vector2(-1,-1))
	resumed.session.state.persistence_enabled = true
	resumed.queue_free()
	await frames()
	var after_exit = State.new()
	after_exit.save_path = restored.save_path
	after_exit.load_state()
	check(is_equal_approx(after_exit.life["workstation_layout"].desk.x, expected.desk.origin.x), "closing during editing saves the committed layout and discards the draft")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(restored.save_path))
	var cleaned := LayoutData.clean({"desk":{"x":999,"z":-999,"yaw":100},"mouse":{"x":[],"z":0,"yaw":0},"alien":{"x":0,"z":0,"yaw":0}})
	check(cleaned.size()==1 and cleaned.desk.x==LayoutData.MAX_POSITION and cleaned.desk.z==-LayoutData.MAX_POSITION and absf(cleaned.desk.yaw)<=PI, "saved layout validates roles, finite numeric poses and bounds")
	print("WORKSTATION_LAYOUT_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
