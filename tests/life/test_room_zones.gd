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
	for i in range(5): await process_frame

func run() -> void:
	var legacy: Dictionary = Blueprint.clean({})
	check(legacy.zone_cells.is_empty() and legacy.zone_styles.size() == 3, "legacy saves migrate with unassigned area presets")
	var cleaned: Dictionary = Blueprint.clean({"shape":"custom",
		"zone_cells":[{"ix":2,"iz":2,"zone":1},{"ix":2,"iz":2,"zone":2},
			{"ix":-1,"iz":2,"zone":3},{"ix":4,"iz":4,"zone":9},
			{"ix":5,"iz":5,"zone":1.2},{"ix":6,"iz":6,"zone":INF}],
		"zone_styles":[{"floor":3,"wall":2,"light":2},
			{"floor":INF,"wall":-1,"light":5},{"floor":1,"wall":3,"light":0}]})
	check(cleaned.zone_cells.size() == 1 and Blueprint.zone_at(cleaned,{"ix":2,"iz":2}) == 1, "invalid and duplicate zone grid entries are removed")
	check(Blueprint.zone_style(cleaned,1) == {"floor":3,"wall":2,"light":2}, "valid independent zone styles persist")
	check(Blueprint.zone_style(cleaned,2) == {"floor":0,"wall":0,"light":0}, "invalid style values sanitize")
	check(Blueprint.zone_at(cleaned,{"ix":4,"iz":4}) == 0, "unpainted floor has no zone")
	var in_zone: Dictionary = {"ix":2,"iz":2}
	check(Blueprint.effective_floor_finish(cleaned,in_zone) == 3, "zone floor style affects its assigned cells")
	var manual: Dictionary = cleaned.duplicate(true)
	manual.floor_finishes.append({"ix":2,"iz":2,"finish":1})
	check(Blueprint.effective_floor_finish(manual,in_zone) == 1, "explicit floor-paint overrides zone preset")
	var removed: Dictionary = Blueprint.clean({"shape":"custom",
		"removed_cells":[{"ix":15,"iz":11}],
		"zone_cells":[{"ix":15,"iz":11,"zone":1},{"ix":14,"iz":11,"zone":2}]})
	check(removed.zone_cells.size() == 1 and Blueprint.zone_at(removed,{"ix":15,"iz":11}) == 0, "removed floor cannot retain zone assignments")
	check(Blueprint.clean({"shape":"rectangle","zone_cells":[{"ix":2,"iz":2,"zone":1}]}).zone_cells.is_empty(), "rectangular legacy format ignores custom zone tiles")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var room = world.get_node("Room")
	var layout = world.layout
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(desktop.get_node("%BlueprintZoneSelect") != null and desktop.get_node("%BlueprintZoneApplyPreset") != null, "zone editing UI nodes are authored in the scene")
	check(layout.set_blueprint_shape("custom"), "zones are painted on the custom grid")
	var cell := {"ix":3,"iz":8}
	var center: Vector2 = Blueprint.cell_center(layout.blueprint,cell)
	check(layout.paint_zone_cell(center,1), "paint a game-zone floor cell")
	check(Blueprint.zone_at(layout.blueprint,cell) == 1 and layout.blueprint.zone_cells.size() == 1, "zone assignment is serialized by cell coordinates")
	check(room.has_node("ZoneLights/Zone_1"), "painted area generates a localized accent light")
	check(int(Blueprint.zone_style(layout.blueprint,1).floor) == 2, "game zone starts with its default floor style")
	var mesh_found := false
	for mesh: MeshInstance3D in room.get_node("Shell").find_children("*","MeshInstance3D",true,false):
		if int(mesh.get_meta("zone_id",0)) == 1 and int(mesh.get_meta("finish_id",0)) == 2:
			mesh_found = true
	check(mesh_found, "game-zone materials render on matching floor strips")
	check(layout.set_zone_style(1,"floor",3), "game zone floor can be set independently")
	check(layout.set_zone_style(1,"wall",1), "game zone wall can be set independently")
	check(layout.set_zone_style(1,"light",2), "game zone lighting color can be set independently")
	check(room.get_node("ZoneLights/Zone_1").light_color == Color("d5b7ea"), "zone light updates to the selected palette")
	check(Blueprint.zone_style(layout.blueprint,1) == {"floor":3,"wall":1,"light":2}, "all three area settings persist together")
	check(layout.paint_floor_finish(center,1), "explicit per-cell floor override still works inside a zone")
	check(Blueprint.effective_floor_finish(layout.blueprint,cell) == 1, "manual material takes priority over zone floor")
	check(layout.paint_floor_finish(center,0), "manual finish can be cleared without losing zone")
	check(Blueprint.effective_floor_finish(layout.blueprint,cell) == 3, "zone material is restored beneath manual override")
	check(not layout.paint_floor_cell(center), "removing floor beneath a named zone is blocked")
	check(not layout.set_blueprint_shape("rectangle"), "switching away from custom mode cannot silently discard zones")
	layout.undo()
	check(Blueprint.floor_finish(layout.blueprint,cell) == 1, "undo restores previous manual finish")
	layout.redo()
	check(Blueprint.floor_finish(layout.blueprint,cell) == 0, "redo reapplies zone material under floor")
	check(layout.paint_zone_cell(center,2), "a tile can be reassigned to the work zone")
	check(not room.has_node("ZoneLights/Zone_1") and room.has_node("ZoneLights/Zone_2"), "zone lights move when zone membership changes")
	check(layout.paint_zone_cell(center,3), "relaxation zone can replace work zone")
	check(room.has_node("ZoneLights/Zone_3"), "rest-zone localized lighting is created")
	check(layout.apply_zone_preset(3,0), "chosen zone can apply a different decorating preset")
	check(Blueprint.zone_style(layout.blueprint,3) == Blueprint.ZONE_PRESETS[0], "preset updates floor, wall and light together")
	layout.undo()
	check(Blueprint.zone_style(layout.blueprint,3) == Blueprint.ZONE_PRESETS[2], "preset changes are undoable")
	layout.redo()
	check(Blueprint.zone_style(layout.blueprint,3) == Blueprint.ZONE_PRESETS[0], "preset redo restores selected theme")
	check(layout.paint_zone_cell(center,0), "right-brush unassigns the tile")
	check(layout.blueprint.zone_cells.is_empty() and not room.has_node("ZoneLights"), "unassigned grid has no per-zone lights")
	desktop.finish_layout(false)
	check(room.blueprint.shape == "rectangle" and room.blueprint.zone_cells.is_empty(), "cancel restores initial room and zone state")

	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(layout.set_blueprint_shape("custom"), "resume area editing after cancellation")
	check(layout.paint_zone_cell(center,1), "paint persistent gaming zone")
	var cell2 := {"ix":4,"iz":8}
	var center2: Vector2 = Blueprint.cell_center(layout.blueprint,cell2)
	check(layout.paint_zone_cell(center2,2), "paint adjacent work zone")
	check(layout.paint_zone_cell(Blueprint.cell_center(layout.blueprint,{"ix":5,"iz":8}),3), "paint rest zone")
	check(layout.set_zone_style(2,"floor",3), "change work-zone floor preset")
	check(layout.set_zone_style(2,"light",1), "change work-zone accent lighting")
	state.save_path = "user://memoir_room_zones_p6_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.room_blueprint.zone_cells.size() == 3, "commit persists zone map")
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life.room_blueprint == state.life.room_blueprint, "zone map and independent styles survive JSON round trip")
	var expected: Dictionary = restored.life.room_blueprint.duplicate(true)
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = restored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var loaded = resumed.desktop.world.get_node("Room")
	check(loaded.blueprint == expected and loaded.has_node("ZoneLights/Zone_3"), "new session rebuilds all saved area lights")
	check(resumed.desktop.world.layout.valid, "zone finishes preserve valid furniture placement")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "computer equipment remains desk-only: " + role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(restored.save_path))
	print("ROOM_ZONES_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
