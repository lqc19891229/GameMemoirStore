extends SceneTree
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
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
	for index in range(5): await process_frame

func run() -> void:
	var old: Dictionary = Blueprint.clean({})
	check(old.shape == "rectangle" and old.partitions.is_empty(), "legacy saves remain rectangular")
	var l: Dictionary = Blueprint.clean({"shape":"l", "width":8.0, "depth":6.0, "notch_width":2.0, "notch_depth":2.0})
	check(l.shape == "l" and l.notch_width == 2.0 and l.notch_depth == 2.0, "blueprint persists L-shaped dimensions")
	check(Blueprint.footprint_inside(l, PackedVector2Array([Vector2(-2,-2), Vector2(-1,-2), Vector2(-1,-1), Vector2(-2,-1)])), "left room wing remains usable")
	check(not Blueprint.footprint_inside(l, PackedVector2Array([Vector2(2.4,1.4), Vector2(3.4,1.4), Vector2(3.4,2.4), Vector2(2.4,2.4)])), "removed corner is outside room")
	check(not Blueprint.footprint_inside(l, PackedVector2Array([Vector2(1.7,.7), Vector2(2.3,.7), Vector2(2.3,1.4), Vector2(1.7,1.4)])), "object bridging concave boundary is invalid")
	check(not Blueprint.inside(l, {"axis":"x","kind":"wall","x":3.0,"z":2.0}), "partition must have floor support")
	check(Blueprint.inside(l, {"axis":"x","kind":"wall","x":0.0,"z":2.0}), "partition can be built in remaining front wing")
	check(Blueprint.clean({"shape":"bad"}).shape == "rectangle", "malformed shapes sanitize to rectangle")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var layout = world.layout
	var room = world.get_node("Room")
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(desktop.get_node("%BlueprintShape") != null and desktop.get_node("%BlueprintNotchWidth") != null, "shape selector and notch controls are authored")
	check(layout.set_blueprint_value("notch_width",2.0) and layout.set_blueprint_value("notch_depth",2.0), "notch dimensions can be edited without removing floor in rectangle mode")
	check(not layout.set_blueprint_shape("l"), "cannot remove existing floor under furniture")
	check(layout.blueprint.shape == "rectangle" and layout.valid, "rejected L shape preserves original room")
	layout.select("lamp")
	layout.store_selected()
	check(layout.set_blueprint_shape("l"), "L shape can be enabled after returning obstructing furniture")
	check(room.blueprint.shape == "l" and room.get_node("Shell").has_node("FloorWing"), "L-shaped floor generates two contiguous meshes")
	check(is_equal_approx((room.get_node("Shell/Floor") as MeshInstance3D).mesh.size.z, 4.12), "back floor portion stops at concave edge")
	check(is_equal_approx((room.get_node("Shell/FloorWing") as MeshInstance3D).mesh.size.x, 6.12), "front-left wing excludes the missing corner")
	check(room.get_node("Shell/Notch_Walls").get_child_count() >= 2, "concave return walls are generated")
	check(not layout.add_partition(Vector2(3,2), "x"), "inner walls cannot be drawn in missing corner")
	check(layout.add_partition(Vector2(0,2), "x"), "inner wall can be built inside L-wing")
	check(not layout.set_blueprint_shape("rectangle") == false or layout.blueprint.shape == "rectangle", "switching to rectangle remains supported")
	layout.undo()
	check(layout.blueprint.shape == "l", "undo restores L-shaped outline")
	layout.redo()
	check(layout.blueprint.shape == "rectangle", "redo restores rectangular outline")
	layout.set_blueprint_shape("l")
	desktop.finish_layout(false)
	check(room.blueprint.shape == "rectangle" and not room.get_node("Shell").has_node("FloorWing"), "cancel restores original floor mesh")
	check(layout.placed_instances.has("lamp"), "cancel restores original furniture")
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	layout.select("lamp")
	layout.store_selected()
	layout.set_blueprint_value("notch_width", 2.0)
	layout.set_blueprint_value("notch_depth", 2.0)
	check(layout.set_blueprint_shape("l"), "L shape can be applied after removing obstruction")
	state.save_path = "user://memoir_l_footprint_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.room_blueprint.shape == "l" and not state.life.placements.has("lamp"), "committed L shape and returned furniture persist")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life.room_blueprint == state.life.room_blueprint, "blueprint corner survives JSON save/load")
	var expected: Dictionary = restored.life.room_blueprint.duplicate(true)
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = restored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var loaded_room = resumed.desktop.world.get_node("Room")
	check(loaded_room.blueprint == expected and loaded_room.get_node("Shell").has_node("Notch_Walls"), "new session reconstructs the concave exterior walls")
	check(resumed.desktop.world.layout.valid, "loaded furniture and devices still have legal placements")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "all computer hardware stays on desk: " + role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(restored.save_path))
	print("ROOM_FOOTPRINT_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
