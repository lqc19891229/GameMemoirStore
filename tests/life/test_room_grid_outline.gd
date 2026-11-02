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
	var saved: Dictionary = Blueprint.clean({"shape":"custom","removed_cells":[
		{"ix":15,"iz":11}, {"ix":15,"iz":11},
		{"ix":-1,"iz":9}, {"ix":0,"iz":6},
		{"ix":7.5,"iz":5}, {"ix":INF,"iz":6}
	]})
	check(saved.shape == "custom" and saved.removed_cells.size() == 1, "malformed and duplicate cutouts are stripped")
	check(Blueprint.has_cell(saved, {"ix":15,"iz":11}), "stored cells retain integral indices")
	check(Blueprint.floor_connected(saved), "single custom cutout remains connected")
	check(not Blueprint.footprint_inside(saved, Blueprint.cell_polygon(saved, {"ix":15,"iz":11})), "deleted cells have no floor support")
	check(Blueprint.footprint_inside(saved, Blueprint.cell_polygon(saved, {"ix":1,"iz":1})), "remaining cells support placement")
	check(Blueprint.clean({"shape":"custom","removed_cells":[]}).removed_cells.is_empty(), "empty freeform blueprint is a full rectangular floor")
	check(Blueprint.clean({"shape":"strange"}).shape == "rectangle", "unknown shapes remain compatible")
	# Four removed neighbors would leave an isolated retained island.
	var ring: Array = [{"ix":5,"iz":6},{"ix":7,"iz":6},{"ix":6,"iz":5},{"ix":6,"iz":7}]
	var ringed: Dictionary = Blueprint.clean({"shape":"custom","removed_cells":ring})
	check(ringed.removed_cells.size() == 3 and Blueprint.floor_connected(ringed), "room sanitation refuses cutouts that disconnect an island")
	var legacy_l: Dictionary = Blueprint.clean({"shape":"l","notch_width":2,"notch_depth":2})
	check(legacy_l.shape == "l" and legacy_l.removed_cells.is_empty(), "L shaped old saves remain unchanged")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var layout = desktop.world.layout
	var room = desktop.world.get_node("Room")
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(desktop.get_node("%BlueprintFloorTool") != null, "floor carving tool is authored in the blueprint panel")
	check(layout.set_blueprint_shape("custom"), "the player can switch a rectangle into freeform mode")
	check(room.blueprint.shape == "custom" and room.get_node("Shell").has_node("Floor"), "freeform blueprint rebuilds a continuous floor")
	var occupied: Dictionary = Blueprint.cell_at(layout.blueprint, Vector2(-.5,-1))
	check(not layout.floor_cell_blocker(occupied, true).is_empty(), "drawing cannot cut out floor occupied by a computer desk")
	check(not layout.paint_floor_cell(Vector2(-.5,-1)), "unsafe floor deletion is rejected")
	var boundary := {"ix":0,"iz":4}
	check(not layout.floor_cell_blocker(boundary, true).is_empty(), "rear/left mounted door and window walls retain their supporting floor")
	layout.select("lamp")
	layout.store_selected()
	var selected: Dictionary = {}
	var dims: Vector2i = Blueprint.cell_count(layout.blueprint)
	for z in range(dims.y - 1, 0, -1):
		for x in range(dims.x - 1, 0, -1):
			var candidate := {"ix":x,"iz":z}
			if layout.floor_cell_blocker(candidate, true).is_empty():
				selected = candidate
				break
		if not selected.is_empty(): break
	check(not selected.is_empty(), "an available exterior grid cell exists for editing")
	if selected.is_empty():
		game.queue_free()
		await frames()
		quit(1)
		return
	var center: Vector2 = Blueprint.cell_center(layout.blueprint, selected)
	check(layout.paint_floor_cell(center), "left brush removes a free floor cell")
	check(layout.blueprint.removed_cells.size() == 1, "paint operation updates the serialized grid")
	check(room.get_node("Shell/Custom_Exterior").get_child_count() > 0, "exposed custom edges receive generated walls")
	check(layout.floor_cell_blocker(selected, false).is_empty(), "deleted cell can be restored")
	check(not Blueprint.footprint_inside(layout.blueprint, Blueprint.cell_polygon(layout.blueprint, selected)), "carved cell rejects future furniture placement")
	check(not layout.add_partition(center, "x"), "interior walls cannot be built on a deleted cell")
	layout.undo()
	check(layout.blueprint.removed_cells.is_empty(), "undo restores floor")
	layout.redo()
	check(layout.blueprint.removed_cells.size() == 1, "redo removes floor again")
	check(layout.paint_floor_cell(center, false), "restore brush fills the missing floor")
	check(layout.blueprint.removed_cells.is_empty(), "restoring removes the saved cutout")
	layout.undo()
	check(layout.blueprint.removed_cells.size() == 1, "restoring floor can itself be undone")
	desktop.finish_layout(false)
	check(room.blueprint.shape == "rectangle" and room.blueprint.removed_cells.is_empty(), "cancel reverts freeform outline and floor meshes")
	check(layout.placed_instances.has("lamp"), "cancel restores stored furniture")

	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	layout.select("lamp")
	layout.store_selected()
	check(layout.set_blueprint_shape("custom"), "custom floor editing can be committed")
	check(layout.paint_floor_cell(center), "valid cutout is reproducible in a second edit session")
	state.save_path = "user://memoir_custom_floor_grid_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.room_blueprint.shape == "custom" and state.life.room_blueprint.removed_cells.size() == 1, "apply persists custom floor outline")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life.room_blueprint == state.life.room_blueprint, "cutout cell data survives JSON round trip")
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
	check(loaded_room.blueprint == expected and loaded_room.get_node("Shell").has_node("Custom_Exterior"), "loaded room reconstructs the customized outline")
	check(resumed.desktop.world.layout.valid, "resumed furniture respects custom floor boundaries")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "desktop equipment stays on computer desk: " + role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(restored.save_path))
	print("ROOM_GRID_OUTLINE_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
