extends SceneTree
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
const Life = preload("res://scripts/life/life_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var polluted := Blueprint.clean({"partitions":[
		{"axis":"x","x":0,"z":2.5,"kind":"wall"},
		{"axis":"x","x":0,"z":2.5,"kind":"wall"},
		{"axis":"x","x":999,"z":2.5,"kind":"wall"},
		{"axis":"z","x":0.3,"z":1.3,"kind":"door"},
		{"axis":"z","x":-3,"z":1,"kind":"door"},
		{"axis":"z","x":INF,"z":1,"kind":"wall"}
	]})
	check(polluted.partitions.size() == 2, "invalid, overlapping and off-grid saved walls are rejected")
	check(Blueprint.clean({}).partitions.is_empty(), "old saves do not introduce unsolicited walls")
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
	check(world.get_node("WallPreview") != null and desktop.get_node("%WallAxis") != null, "wall-painting preview and controls are authored")
	check(room.partitions_editing and room.get_node("Shell/Partitions").scale.y < .3, "plan view displays low-profile partitions")
	check(not layout.add_partition(Vector2(-.5,-1), "x"), "walls cannot be built through the computer desk")
	check(layout.add_partition(Vector2(0,2.5), "x"), "first interior wall segment can be built")
	check(room.get_node("Shell/Partitions").get_child_count() == 1, "wall geometry is generated")
	check(not layout.add_partition(Vector2(0,2.5), "x"), "duplicate segment is blocked")
	check(layout.add_partition(Vector2(1,2.5), "x"), "adjacent grid wall segments can be joined")
	check(layout.add_partition(Vector2(-3,1), "z", "door"), "interior doorway section can be built")
	check(room.get_node("Shell/Partitions").get_child_count() == 3, "wall and doorway segments coexist")
	check(room.get_node("Shell/Partitions/Segment_02").has_node("DoorPost") and room.get_node("Shell/Partitions/Segment_02").has_node("DoorLintel"), "doorway creates physical posts and lintel")
	check(not layout.add_partition(Vector2(-.5,-1), "z", "door"), "doorway cannot overwrite the desk")
	layout.undo()
	check(layout.blueprint.partitions.size() == 2, "undo removes the last doorway segment")
	layout.redo()
	check(layout.blueprint.partitions.size() == 3, "redo restores the doorway and mesh")
	check(layout.remove_partition(Vector2(-3,1)), "right-click erase removes a nearby segment")
	check(layout.blueprint.partitions.size() == 2, "erasing reduces wall count")
	layout.undo()
	check(layout.blueprint.partitions.size() == 3, "erasing a wall is undoable")
	check(layout.set_blueprint_value("width", 10), "a room with partitions can grow")
	check(layout.set_blueprint_value("depth", 8), "partitioned room depth can grow")
	check(layout.add_partition(Vector2(4.5,3), "z"), "a new wall can occupy expanded room space")
	check(not layout.set_blueprint_value("width", 8), "shrinking cannot silently delete built wall sections")
	check(layout.blueprint.width == 10 and layout.blueprint.partitions.size() == 4, "failed shrink preserves wall data")
	desktop.set_blueprint_mode(false)
	check(not room.partitions_editing and room.get_node("Shell/Partitions").scale.y == 1.0, "exiting plan restores full-height walls")
	desktop.finish_layout(false)
	check(room.blueprint.partitions.is_empty(), "cancel discards new walls")
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(layout.add_partition(Vector2(0,2.5), "x"), "draw a persistent wall")
	check(layout.add_partition(Vector2(-3,1), "z", "door"), "draw a persistent doorway")
	desktop.finish_layout(true)
	check(state.life.room_blueprint.partitions.size() == 2, "apply commits all wall sections to life save")
	var stored = State.new()
	state.save_path = "user://room_partition_p2_test.json"
	state.persistence_enabled = true
	state.save_state()
	stored.save_path = state.save_path
	stored.load_state()
	check(stored.life.room_blueprint.partitions == state.life.room_blueprint.partitions, "wall segments round trip through JSON")
	var expected: Dictionary = stored.life.room_blueprint.duplicate(true)
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = stored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	check(resumed.desktop.world.get_node("Room").blueprint == expected, "a new session restores the blueprint with walls")
	check(resumed.desktop.world.get_node("Room/Shell/Partitions").get_child_count() == 2, "saved sections rebuild visible meshes")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "computer peripherals still belong on desk: " + role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.save_path))
	print("ROOM_PARTITIONS_CHECKS: %d / %d passed" % [checks-failures, checks])
	quit(1 if failures else 0)
