extends SceneTree
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const Life = preload("res://scripts/life/life_data.gd")
const State = preload("res://scripts/store_state.gd")
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
func same_poses(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for role: String in a:
		if not b.has(role) or not (a[role] as Transform3D).is_equal_approx(b[role]): return false
	return true
func same_layout(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for role: String in a:
		for field in ["x","z","yaw"]:
			if not b.has(role) or not is_equal_approx(a[role][field], b[role][field]): return false
	return true
func dispatch(event: InputEvent) -> void:
	root.window_input.emit(event.xformed_by(root.get_final_transform()))
	root.push_input(event,true)
func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	var desktop = game.desktop
	var world = desktop.world
	var layout = world.layout
	var room = world.get_node("Room")
	var original: Dictionary = layout.snapshot()
	check(layout.nodes.size() == 10, "room and equipment share one placement controller")
	check(layout._layout_blocker().is_empty(), "authored room starts without intersections")
	check(world.overview_pitch > .5 and world.overview_pitch < .8, "default camera shows an elevated room overview")
	check(world.get_node("PixelPass").visible, "overview uses pixel rendering")
	for role in ["chair","bookcase","lamp","rug","plant"]:
		var item = layout.nodes[role]
		check(item.get_node("Model").get_child_count() > 0, "saved complete model exists for " + role)
		# Selection bounds must enclose the complete exported geometry, including rug stripes.
		var enclosed := true
		for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = item.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			for point: Vector3 in [box.position,box.end]:
				enclosed = enclosed and absf(point.x) <= item.bounds.x/2+.001 and absf(point.z) <= item.bounds.z/2+.001 and point.y <= item.bounds.y+.001
		check(enclosed, "furniture collision bounds enclose geometry: " + role)
	desktop.begin_layout()
	layout.select("chair")
	await frames()
	var handle: Node3D = layout.gizmo.get_node("MoveHandles/MovePlane")
	var start: Vector2 = world.camera.unproject_position(handle.global_position)
	var target: Vector2 = world.camera.unproject_position(handle.global_position + Vector3(.3,0,0))
	var button := InputEventMouseButton.new()
	button.position = start
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	dispatch(button)
	var motion := InputEventMouseMotion.new()
	motion.position = target
	motion.relative = target-start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	dispatch(motion)
	button.position = target
	button.pressed = false
	dispatch(button)
	await frames()
	check(is_equal_approx(layout.nodes.chair.position.x,-.4), "real projected pointer drag moves floor furniture")
	layout.undo()
	check(layout.nodes.chair.transform.is_equal_approx(original.chair), "pointer gesture is one undoable transaction")
	layout.select("chair")
	layout.move_to(Vector2(-.7,-2.3))
	check(layout.nodes.chair.position.z > .75 and layout.valid, "fast floor drag stops against table")
	check(layout.message.contains("桌子"), "floor collision identifies blocking furniture")
	check(not Data.overlap(layout.footprint("chair"),layout.footprint("desk")), "chair cannot tunnel through table")
	layout.undo()
	check(layout.nodes.chair.transform.is_equal_approx(original.chair), "undo restores previous floor placement")
	layout.redo()
	check(layout.nodes.chair.position.z < 1.4, "redo restores accepted contact pose")
	layout.reset_layout()
	layout.select("rug")
	layout.move_to(Vector2(-.7,-.8))
	check(layout.valid and Data.overlap(layout.footprint("rug"),layout.footprint("desk")), "floor decoration may lie underneath furniture")
	layout.select("lamp")
	layout.move_to(Vector2(100,100))
	for corner in layout.footprint("lamp"):
		check(absf(corner.x) <= 4 and absf(corner.y) <= 3, "floor furniture stays inside room")
	layout.reset_layout()
	layout.select("desk")
	layout.move_to(Vector2(-100,-100))
	layout.rotate_to(PI/2)
	check(layout.valid, "table rotation and room edges remain valid")
	for corner in layout.footprint("desk"):
		check(absf(corner.x) <= 4 and absf(corner.y) <= 3, "rotated table remains within room")
	for role: String in world.devices:
		check(world.devices[role].transform.is_equal_approx(original[role]), "table carries local equipment unchanged: " + role)
	layout.select("plant")
	layout.duplicate_selected()
	check(layout.selected == "plant_1" and layout.valid, "copy spawns a complete furniture instance in a free floor position")
	check(layout.nodes.plant_1.role == "plant_1", "copied furniture has an independent picking identity")
	layout.undo()
	check(not layout.nodes.has("plant_1"), "undo removes copied furniture")
	layout.redo()
	check(layout.nodes.has("plant_1"), "redo recreates copied furniture")
	layout.select("plant_1")
	layout.delete_selected()
	check(not layout.nodes.has("plant_1"), "delete removes only the selected copy")
	layout.undo()
	check(layout.nodes.has("plant_1"), "deletion can be undone")
	layout.set_style("wall",2)
	layout.set_style("floor",1)
	layout.set_style("light",2)
	check(room.style == {"wall":2,"floor":1,"light":2}, "wall floor and light preview together")
	layout.undo()
	check(room.style.light == 0 and room.style.wall == 2, "undo includes room appearance")
	layout.redo()
	check(room.style.light == 2, "redo includes room appearance")
	desktop.finish_layout(false)
	check(layout.snapshot() == original and room.style == {"wall":0,"floor":0,"light":0}, "cancel restores room poses and appearance atomically")
	check(game.session.state.life.workstation_layout.is_empty(), "cancel does not write preview to state")
	desktop.begin_layout()
	layout.select("chair")
	layout.move_to(Vector2(-.2,1.6))
	layout.rotate_to(PI/4)
	layout.select("lamp")
	layout.duplicate_selected()
	check(layout.selected == "lamp_1" and layout.valid, "lamp copy has a valid free placement")
	check(layout.nodes.lamp_1.has_node("LampGlow"), "lamp copies include their authored light")
	(desktop.get_node("%Style_wall") as OptionButton).item_selected.emit(1)
	(desktop.get_node("%Style_light") as OptionButton).item_selected.emit(2)
	check(room.style.wall == 1 and room.style.light == 2, "UI style callbacks target their own setting")
	var expected: Dictionary = layout.snapshot()
	var state = game.session.state
	state.save_path = "user://memoir_pixel_room_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.workstation_layout.has("chair") and state.life.room_style.light == 2 and state.life.workstation_layout.has("lamp_1"), "apply saves room furniture and style into shared state")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life.room_style == state.life.room_style and same_layout(restored.life.workstation_layout, state.life.workstation_layout), "room save round trips on disk")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	game = load("res://scenes/main/game_root.tscn").instantiate()
	game.get_node("GameSession").state = restored
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	desktop = game.desktop
	world = desktop.world
	check(same_poses(world.layout.snapshot(), expected) and world.get_node("Room").style.light == 2, "new session restores full room and lighting")
	desktop.set_screen_focused(true,false)
	check(not world.get_node("PixelPass").visible, "computer UI remains clear without room pixel filtering")
	var browser = desktop.open_app("browser")
	var platform = desktop.open_app("platform")
	check(browser != null and platform != null, "shopping and platform apps remain available")
	desktop.set_screen_focused(false,false)
	check(world.get_node("PixelPass").visible and same_poses(world.layout.snapshot(), expected), "returning to room restores pixels and retains furniture")
	world.camera.position = Vector3(-8,6,8)
	world.get_node("Room").update_cutaway(world.camera)
	check(not world.get_node("Room/Shell/Left_Wall").visible and world.get_node("Room/Shell/Back_Wall").visible, "outside wall hides without hiding other room parts")
	world.reset_overview()
	world.get_node("Room").update_cutaway(world.camera)
	check(world.get_node("Room/Shell/Left_Wall").visible, "wall reappears when viewing interior")
	var legacy := Life.clean({}, [], [])
	check(legacy.room_style == {"wall":0,"floor":0,"light":0} and legacy.workstation_layout.is_empty(), "legacy saves receive room defaults without data loss")
	check(Data.clean({"plant_8":{"x":0,"z":0,"yaw":0},"plant_9":{"x":0,"z":0,"yaw":0},"desk_1":{"x":0,"z":0,"yaw":0}}).size() == 1, "save validation accepts bounded furniture copies and rejects device duplication")
	var invalid := Life.clean({"room_style":{"wall":INF,"floor":{},"light":99}},[],[])
	check(invalid.room_style == {"wall":0,"floor":0,"light":2}, "appearance save validation rejects malformed values")
	world.layout.load_saved({"desk":{"x":100,"z":100,"yaw":0},"chair":{"x":0,"z":0,"yaw":0}})
	check(world.layout.valid and world.layout._layout_blocker().is_empty(), "conflicting legacy furniture poses recover to a usable room")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	game.queue_free()
	await frames()
	print("PIXEL_ROOM_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
