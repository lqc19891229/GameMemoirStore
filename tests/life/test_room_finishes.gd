extends SceneTree
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var old: Dictionary = Blueprint.clean({})
	check(old.floor_finishes.is_empty() and old.edge_finishes.is_empty(), "old saves receive empty finish collections")
	var injected: Dictionary = Blueprint.clean({
		"shape":"custom",
		"removed_cells":[{"ix":15,"iz":11}],
		"floor_finishes":[{"ix":2,"iz":2,"finish":1},{"ix":2,"iz":2,"finish":2},
			{"ix":15,"iz":11,"finish":1},{"ix":1,"iz":1,"finish":INF}],
		"edge_finishes":[{"ix":15,"iz":11,"dx":-1,"dz":0,"kind":"window","finish":2},
			{"ix":15,"iz":11,"dx":-1,"dz":0,"kind":"door","finish":1},
			{"ix":15,"iz":11,"dx":1,"dz":0,"kind":"window","finish":1},
			{"ix":2,"iz":2,"dx":1,"dz":0,"kind":"window","finish":2}]
	})
	check(injected.floor_finishes.size() == 1 and Blueprint.floor_finish(injected,{"ix":2,"iz":2}) == 1, "finish sanitizer discards duplicate and removed floor entries")
	check(injected.edge_finishes.size() == 1 and injected.edge_finishes[0].kind == "window", "only valid exposed edges accept unique openings")
	check(Blueprint.nearest_edge(injected,Blueprint.edge_center(injected,injected.edge_finishes[0])).size() > 0, "exterior hit testing uses world-space edge centers")
	check(Blueprint.finish_id(5) == 0 and Blueprint.finish_id(2.5) == 0, "out of range and fractional finish ids are sanitized")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var room = desktop.world.get_node("Room")
	var layout = desktop.world.layout
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(desktop.get_node("%BlueprintWallFinish") != null and desktop.get_node("%BlueprintTileFinish") != null and desktop.get_node("%BlueprintOpeningKind") != null, "painting tools use authored Godot scene controls")
	check(layout.set_blueprint_shape("custom"), "player can edit individual finishes in grid mode")
	layout.select("lamp")
	layout.store_selected()
	var selected: Dictionary = {}
	var dims: Vector2i = Blueprint.cell_count(layout.blueprint)
	for iz in range(dims.y-1,0,-1):
		for ix in range(dims.x-1,0,-1):
			var cell := {"ix":ix,"iz":iz}
			if layout.floor_cell_blocker(cell,true).is_empty():
				selected = cell
				break
		if not selected.is_empty(): break
	check(not selected.is_empty(), "a free cell exists for decorating")
	if selected.is_empty():
		game.queue_free()
		await frames()
		quit(1)
		return
	var center: Vector2 = Blueprint.cell_center(layout.blueprint,selected)
	check(layout.paint_floor_finish(center,1), "paint a single tile finish")
	check(Blueprint.floor_finish(layout.blueprint,selected) == 1, "finish is keyed to the correct cell")
	var painted := false
	for mesh: MeshInstance3D in room.get_node("Shell").find_children("*","MeshInstance3D",true,false):
		if str(mesh.get_meta("surface_role","")) == "floor" and int(mesh.get_meta("finish_id",0)) == 1:
			painted = true
	check(painted, "surface palette generates rendered floor pieces")
	check(not layout.paint_floor_cell(center), "cannot silently delete a painted tile")
	check(layout.paint_floor_finish(center,0), "restore the default tile finish")
	check(layout.paint_floor_cell(center), "remove floor and expose an outer wall edge")
	var exposed: Array = Blueprint.exposed_edges(layout.blueprint)
	check(not exposed.is_empty(), "new outline generates editable wall edges")
	var edge: Dictionary = exposed[0]
	var edge_point: Vector2 = Blueprint.edge_center(layout.blueprint,edge)
	check(layout.paint_exterior_edge(edge_point,"window",2), "custom exterior section accepts a window and wall finish")
	check(layout.blueprint.edge_finishes.size() == 1 and layout.blueprint.edge_finishes[0].kind == "window", "window opening is saved by stable edge coordinates")
	var window_rendered := false
	for mesh: MeshInstance3D in room.get_node("Shell/Custom_Exterior").find_children("*","MeshInstance3D",true,false):
		if mesh.name == "WindowGlass": window_rendered = true
	check(window_rendered, "window produces visible glass inside an exterior opening")
	check(layout.paint_exterior_edge(edge_point,"door",3), "window section can be changed into a doorway")
	var door_rendered := false
	for mesh: MeshInstance3D in room.get_node("Shell/Custom_Exterior").find_children("*","MeshInstance3D",true,false):
		if mesh.name == "DoorHead": door_rendered = true
	check(door_rendered, "doorway has open height below its lintel")
	check(layout.paint_exterior_edge(edge_point,"wall",0), "a section can return to plain wall")
	check(layout.blueprint.edge_finishes.is_empty(), "reset clears wall overrides")
	check(layout.paint_exterior_edge(edge_point,"window",2), "exterior decoration can be repeated")

	check(layout.add_partition(Vector2(0,2.5),"x"), "add a separate interior wall")
	check(layout.paint_partition_finish(Vector2(0,2.5),3), "interior wall accepts independent finish")
	check(int(layout.blueprint.partitions[0].finish) == 3, "wall finish is stored per partition segment")
	var interior: MeshInstance3D = room.get_node("Shell/Partitions/Segment_00/WallBody")
	check(int(interior.get_meta("finish_id",0)) == 3, "partition mesh carries its own material override")
	layout.undo()
	check(int(layout.blueprint.partitions[0].get("finish",0)) == 0, "wall finish undo restores original")
	layout.redo()
	check(int(layout.blueprint.partitions[0].get("finish",0)) == 3, "redo restores independent wall finish")
	desktop.finish_layout(false)
	check(room.blueprint.shape == "rectangle" and room.blueprint.floor_finishes.is_empty() and room.blueprint.edge_finishes.is_empty(), "cancel reverts all room finishes and openings")

	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	layout.select("lamp")
	layout.store_selected()
	check(layout.set_blueprint_shape("custom"), "reopen custom blueprint editing")
	check(layout.paint_floor_finish(center,1), "finish survives new edit session")
	var adjacent: Dictionary = {"ix":int(selected.ix)-1,"iz":int(selected.iz)}
	var candidate: Vector2 = Blueprint.cell_center(layout.blueprint,adjacent)
	if layout.floor_cell_blocker(adjacent,true).is_empty():
		check(layout.paint_floor_cell(candidate), "a neighboring cell exposes an exterior edge without touching a painted tile")
	else:
		layout.paint_floor_finish(center,0)
		check(layout.paint_floor_cell(center), "create exterior cutout")
	if layout.blueprint.removed_cells.size() > 0:
		var option: Dictionary = Blueprint.exposed_edges(layout.blueprint)[0]
		check(layout.paint_exterior_edge(Blueprint.edge_center(layout.blueprint,option),"window",2), "save an exterior window")
	check(layout.add_partition(Vector2(0,2.5),"x"), "create interior wall for saved finishes")
	check(layout.paint_partition_finish(Vector2(0,2.5),1), "save a distinct interior wall finish")
	state.save_path = "user://memoir_room_finishes_p5_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.room_blueprint.shape == "custom", "applied blueprint stores custom shape")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life.room_blueprint == state.life.room_blueprint, "all floor and wall finishes survive JSON")
	var expected: Dictionary = restored.life.room_blueprint.duplicate(true)
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = restored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var restored_room = resumed.desktop.world.get_node("Room")
	check(restored_room.blueprint == expected, "new session reconstructs independent surface assignments")
	check(resumed.desktop.world.layout.valid, "decorations do not invalidate furniture collision constraints")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "desktop hardware remains desk-only: " + role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(restored.save_path))
	print("ROOM_FINISHES_CHECKS: %d / %d passed" % [checks-failures, checks])
	quit(1 if failures else 0)
