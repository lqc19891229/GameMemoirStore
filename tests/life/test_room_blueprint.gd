extends SceneTree
const State = preload("res://scripts/store_state.gd")
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var bad: Dictionary = Blueprint.clean({"width": INF, "depth": -99, "door_x": 100, "window_z": -100})
	check(bad.width == 8.0 and bad.depth == 5.0, "blueprint sanitizes unsafe dimensions")
	check(absf(bad.door_x) <= 3.301 and absf(bad.window_z) <= 1.151, "openings remain wholly inside walls")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var room = world.get_node("Room")
	var shell = room.get_node("Shell")
	var layout = world.layout
	check(room.blueprint == Blueprint.DEFAULT and layout.room_half_size == Vector2(4,3), "existing room starts at 8 x 6 metres")
	check(is_equal_approx((shell.get_node("Floor") as MeshInstance3D).mesh.size.x, 8.24), "default floor remains unchanged")
	var camera_before: Transform3D = world.camera.transform
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(desktop.blueprint_mode and desktop.get_node("%BlueprintPanel").visible and not desktop.get_node("%Content").visible, "blueprint mode displays authored controls")
	check(not world.camera.transform.is_equal_approx(camera_before), "blueprint mode switches to elevated camera")
	check(layout.set_blueprint_value("width", 10.0), "room width can be expanded")
	check(layout.set_blueprint_value("depth", 8.0), "room depth can be expanded")
	check(is_equal_approx((shell.get_node("Floor") as MeshInstance3D).mesh.size.x, 10.24), "floor mesh rebuilds to new room width")
	check(is_equal_approx((shell.get_node("Floor") as MeshInstance3D).mesh.size.z, 8.24), "floor mesh rebuilds to new room depth")
	check(is_equal_approx(shell.get_node("Left_Wall").get_node("WallSurface_Lower").position.x, -5.06), "left wall moves to new boundary")
	check(is_equal_approx(shell.get_node("Back_Wall").get_node("DoorLeaf").position.z, -3.975), "back wall and door move with depth")
	check(layout.room_half_size == Vector2(5,4), "room furniture collision limits follow blueprint")
	check(layout.set_blueprint_value("door_x", -1.5), "door opening can move on back wall")
	check(layout.set_blueprint_value("window_z", .65), "window opening can move on left wall")
	check(is_equal_approx(shell.get_node("Back_Wall/DoorLeaf").position.x, -1.5), "door model follows edit")
	check(is_equal_approx(shell.get_node("Left_Wall/WindowSky").position.z, .65), "window model follows edit")
	layout.undo()
	check(is_equal_approx(room.blueprint.window_z, -.8), "undo restores old window position")
	layout.redo()
	check(is_equal_approx(room.blueprint.window_z, .65), "redo reapplies window position")
	check(not layout.set_blueprint_value("width", 6.0) and layout.valid, "cannot shrink room onto existing desk")
	check(room.blueprint.width == 10.0 and layout.message.begins_with("调整失败"), "rejected blueprint keeps previous valid room")
	desktop.set_blueprint_mode(false)
	check(world.camera.transform.is_equal_approx(camera_before), "leaving blueprint restores previous camera")
	desktop.finish_layout(false)
	check(room.blueprint == Blueprint.DEFAULT and layout.room_half_size == Vector2(4,3), "cancel restores complete original floor plan")
	check(is_equal_approx(shell.get_node("Back_Wall/DoorLeaf").position.x, -2.75), "cancel restores door position")
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	layout.set_blueprint_value("width", 10.0)
	layout.set_blueprint_value("depth", 8.0)
	layout.set_blueprint_value("door_x", -1.5)
	layout.set_blueprint_value("window_z", .65)
	state.save_path = "user://memoir_room_blueprint_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.room_blueprint.width == 10.0 and state.life.room_blueprint.depth == 8.0, "applying blueprint saves dimensions")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life.room_blueprint == room.blueprint, "blueprint survives JSON save and load")
	var expected_blueprint: Dictionary = room.blueprint.duplicate()
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = restored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var resumed_room = resumed.desktop.world.get_node("Room")
	check(resumed_room.blueprint == expected_blueprint, "new session reconstructs saved room geometry")
	check(is_equal_approx(resumed_room.get_node("Shell/Floor").mesh.size.x, 10.24), "new session rebuilds floor dimensions")
	check(resumed.desktop.world.layout.valid, "loaded furniture remains inside resized room")
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	print("ROOM_BLUEPRINT_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
