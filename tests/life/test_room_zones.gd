extends SceneTree
## Replaces the former functional-zone test with free-decoration and migration coverage.
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
	for i in range(5): await process_frame

func run() -> void:
	var plain: Dictionary = Blueprint.clean({})
	check(not plain.has("zone_cells") and not plain.has("zone_styles") and not plain.has("saved_schemes"),
		"new rooms never generate purpose-based zones or scene preset slots")
	var legacy: Dictionary = Blueprint.clean({"shape":"custom",
		"zone_cells":[{"ix":2,"iz":2,"zone":1},{"ix":2,"iz":2,"zone":2},
			{"ix":3,"iz":2,"zone":2},{"ix":4,"iz":2,"zone":3},
			{"ix":-1,"iz":0,"zone":1},{"ix":5,"iz":2,"zone":99}],
		"zone_styles":[{"floor":3,"wall":2,"light":2},{"floor":2,"wall":3,"light":1},{"floor":1,"wall":1,"light":0}],
		"floor_finishes":[{"ix":3,"iz":2,"finish":1}],
		"saved_schemes":[{"slot":0,"zone_cells":[{"ix":5,"iz":2,"zone":1}]}]})
	check(not legacy.has("zone_cells") and not legacy.has("zone_styles") and not legacy.has("saved_schemes"),
		"legacy labels, area lighting and preset slots are retired from persisted blueprints")
	check(Blueprint.floor_finish(legacy,{"ix":2,"iz":2}) == 3,
		"old game-area flooring becomes direct tile material without an area label")
	check(Blueprint.floor_finish(legacy,{"ix":3,"iz":2}) == 1,
		"explicit manual flooring takes priority during migration")
	check(Blueprint.floor_finish(legacy,{"ix":4,"iz":2}) == 1,
		"old rest-area flooring becomes direct tile material")
	check(Blueprint.floor_finish(legacy,{"ix":5,"iz":2}) == 0,
		"invalid old purpose assignments do not decorate other tiles")
	check(Blueprint.clean(legacy) == legacy,
		"legacy conversion happens only once and is stable on subsequent saves")
	check(Blueprint.effective_wall_finish(legacy,Vector2.ZERO,2) == 2,
		"wall appearance comes from direct decoration rather than named purposes")
	check(Blueprint.effective_wall_finish(legacy,Vector2.ZERO,0) == 0,
		"unpainted wall never inherits a removed functional-area palette")
	var removed := Blueprint.clean({"shape":"custom","removed_cells":[{"ix":15,"iz":11}],
		"zone_cells":[{"ix":15,"iz":11,"zone":1}]})
	check(Blueprint.floor_finish(removed,{"ix":15,"iz":11}) == 0,
		"deleted floor tiles do not inherit a migrated finish")

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
	check(desktop.get_node_or_null("%BlueprintZoneSelect") == null and desktop.get_node_or_null("%BlueprintQuickZone") == null,
		"functional-area selectors and quick buttons are removed from the actual UI")
	check(desktop.get_node_or_null("%BlueprintSchemeSave") == null and desktop.get_node_or_null("%BlueprintRegionInfo") == null,
		"area-design presets and connected-region fill interfaces are removed")
	check(desktop.get_node("%BlueprintFloorTool").item_count == 8,
		"build selector contains only wall, floor, manual finish and opening tools")
	check(layout.set_blueprint_shape("custom"),"custom room geometry still works without functional areas")
	var cell := {"ix":3,"iz":8}
	var center: Vector2 = Blueprint.cell_center(layout.blueprint,cell)
	check(layout.paint_floor_finish(center,3),"player can paint any floor tile independently")
	check(Blueprint.floor_finish(room.blueprint,cell) == 3,
		"direct floor material appears without a zone assignment")
	check(not room.has_node("ZoneLights"),
		"room no longer creates implicit localized lights from floor painting")
	layout.undo()
	check(Blueprint.floor_finish(layout.blueprint,cell) == 0,
		"undo removes manual tile material without restoring a zone")
	layout.redo()
	check(Blueprint.floor_finish(layout.blueprint,cell) == 3,
		"redo restores manual tile material")
	check(layout.paint_floor_finish(center,0),
		"player can clear individual flooring independently")
	check(layout.floor_cell_blocker(cell,true).is_empty(),
		"no deprecated zone membership prevents removing an otherwise empty floor tile")
	desktop.finish_layout(false)
	check(room.blueprint == Blueprint.DEFAULT,
		"cancel restores original room without functional-area data")

	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(layout.set_blueprint_shape("custom"),
		"freeform mode remains available after cancelling")
	check(layout.paint_floor_finish(center,2),
		"player can decorate a tile for saving without declaring its purpose")
	state.save_path = "user://memoir_free_decoration_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(not state.life.room_blueprint.has("zone_cells"),
		"committing free decoration never saves a zone map")
	var loaded := State.new()
	loaded.save_path = state.save_path
	loaded.load_state()
	check(loaded.life.room_blueprint == state.life.room_blueprint,
		"manual decoration roundtrips through real JSON save")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = loaded
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	check(Blueprint.floor_finish(resumed.desktop.world.layout.blueprint,cell) == 2,
		"reloaded room restores independently painted floor material")
	check(not resumed.desktop.world.get_node("Room").has_node("ZoneLights"),
		"reloaded room does not generate old automatic area lights")
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(loaded.save_path))
	print("ROOM_FREE_DECORATION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
