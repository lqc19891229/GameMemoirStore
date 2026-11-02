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
	var legacy: Dictionary = Blueprint.clean({})
	check(legacy.saved_schemes.is_empty(), "legacy room saves do not invent area snapshots")
	var bare: Dictionary = Blueprint.clean({"shape":"custom"})
	check(Blueprint.room_regions(bare).size() == 1, "unpartitioned rectangle is one connected room")
	check(Blueprint.room_region_at(bare,Vector2.ZERO).size() == 192, "8x6 room has 192 half-metre floor cells")
	check(Blueprint.room_region_at(bare,Vector2(99,99)).is_empty(), "out-of-bounds region clicks do not create areas")
	var ring: Array = []
	for x in [-.5,.5]:
		for z in [-1.0,1.0]:
			ring.append({"x":x,"z":z,"axis":"x","kind":"wall"})
	for z in [-.5,.5]:
		for x in [-1.0,1.0]:
			ring.append({"x":x,"z":z,"axis":"z","kind":"wall"})
	var isolated: Dictionary = Blueprint.clean({"shape":"custom","partitions":ring})
	check(isolated.partitions.size() == 8, "all eight segments of enclosed room survive sanitation")
	var inside: Array = Blueprint.room_region_at(isolated,Vector2.ZERO)
	check(inside.size() == 16, "closed 2m x 2m space yields a 16-cell interior")
	check(Blueprint.room_regions(isolated).size() == 2, "solid walls produce exactly two connected spaces")
	var door: Dictionary = isolated.duplicate(true)
	door.partitions[0].kind = "door"
	check(Blueprint.room_region_at(door,Vector2.ZERO).size() == 192, "doorways connect separated rooms")
	check(Blueprint.room_regions(door).size() == 1, "an open doorway collapses two rooms into one")
	var removed: Dictionary = Blueprint.clean({"shape":"custom","removed_cells":[{"ix":15,"iz":11}]})
	check(Blueprint.room_region_at(removed,Blueprint.cell_center(removed,{"ix":15,"iz":11})).is_empty(), "missing floor has no region")
	check(Blueprint.room_region_at(removed,Vector2.ZERO).size() == 191, "one corner cutout leaves one connected region")
	var poisoned: Dictionary = Blueprint.clean({"shape":"custom","saved_schemes":[
		{"slot":0,"zone_cells":[{"ix":2,"iz":2,"zone":1},{"ix":2,"iz":2,"zone":2}],
			"zone_styles":[{"floor":2,"wall":1,"light":0}],
			"floor_finishes":[{"ix":2,"iz":2,"finish":1}]},
		{"slot":0,"zone_cells":[{"ix":3,"iz":3,"zone":3}]},
		{"slot":4,"zone_cells":[]},{"slot":INF,"zone_cells":[]}
	]})
	check(poisoned.saved_schemes.size() == 1 and poisoned.saved_schemes[0].slot == 0, "schemes sanitize invalid and duplicate slots")
	check(poisoned.saved_schemes[0].zone_cells.size() == 1, "saved zone maps sanitize duplicate cells")
	check(poisoned.saved_schemes[0].floor_finishes.size() == 1, "saved designs include manual flooring")
	check(Blueprint.clean({"shape":"rectangle","saved_schemes":poisoned.saved_schemes}).saved_schemes.is_empty(), "preset snapshots are custom-room only")

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
	check(desktop.get_node("%BlueprintRegionInfo") != null and desktop.get_node("%BlueprintSchemeSlot") != null, "region brush and design slots are authored")
	check(layout.set_blueprint_shape("custom"), "custom floor can auto-select a connected space")
	var chosen := {"ix":3,"iz":8}
	var center: Vector2 = Blueprint.cell_center(layout.blueprint,chosen)
	check(layout.paint_zone_cell(center,1), "paint an initial gaming zone cell")
	check(layout.paint_floor_finish(center,3), "set an explicit tile finish for saved design")
	check(layout.set_zone_style(1,"wall",2), "customize gaming zone wall finish")
	check(layout.save_decor_scheme(0), "save area design to slot 1")
	check(not Blueprint.scheme_for_slot(layout.blueprint,0).is_empty(), "saved snapshot is available from blueprints")
	check(layout.fill_room_region(center,2) == 192, "single click replaces the full connected room assignment")
	check(layout.blueprint.zone_cells.size() == 192 and Blueprint.zone_at(layout.blueprint,chosen) == 2, "fill replaces all zone assignments without gaps")
	check(room.has_node("ZoneLights/Zone_2"), "filled region updates localized lighting")
	check(layout.load_decor_scheme(0), "load previous area design from slot 1")
	check(layout.blueprint.zone_cells.size() == 1 and Blueprint.zone_at(layout.blueprint,chosen) == 1, "loading restores the original zone map")
	check(Blueprint.floor_finish(layout.blueprint,chosen) == 3, "loading also restores individually painted tiles")
	check(int(Blueprint.zone_style(layout.blueprint,1).wall) == 2, "loading restores saved area wall palettes")
	layout.undo()
	check(layout.blueprint.zone_cells.size() == 192, "loaded scheme can be undone")
	layout.redo()
	check(layout.blueprint.zone_cells.size() == 1, "loaded scheme can be redone")
	check(layout.save_decor_scheme(1), "save a second scheme slot independently")
	check(Blueprint.scheme_for_slot(layout.blueprint,1).size() > 0 and Blueprint.scheme_for_slot(layout.blueprint,2).is_empty(), "scheme slots are independent")
	check(layout.paint_zone_cell(center,0), "existing zone can be cleared")
	check(layout.floor_cell_blocker(chosen,true) != "", "a saved design prevents silently deleting its floor cells")
	check(layout.clear_decor_scheme(1), "scheme deletion is supported")
	check(Blueprint.scheme_for_slot(layout.blueprint,1).is_empty(), "deleted scheme slot is now empty")
	layout.undo()
	check(not Blueprint.scheme_for_slot(layout.blueprint,1).is_empty(), "scheme deletion can be undone")
	check(layout.fill_room_region(Vector2(99,99),1) == 0, "outside clicks do not change layout")
	check(layout.fill_room_region(center,0) == 0, "an all-unassigned open region needs no change")
	desktop.finish_layout(false)
	check(room.blueprint.shape == "rectangle" and room.blueprint.saved_schemes.is_empty(), "cancel restores room and clears uncommitted snapshots")

	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(layout.set_blueprint_shape("custom"), "enter custom floor editing to commit a design")
	check(layout.paint_zone_cell(center,3), "paint rest zone for persistent scheme")
	check(layout.save_decor_scheme(2), "save the current scheme to third slot")
	state.save_path = "user://memoir_room_regions_p7_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.room_blueprint.saved_schemes.size() == 1, "committing stores named design slot data")
	var stored = State.new()
	stored.save_path = state.save_path
	stored.load_state()
	check(stored.life.room_blueprint.saved_schemes == state.life.room_blueprint.saved_schemes, "snapshot data survives JSON serialization")
	var expected: Dictionary = stored.life.room_blueprint.duplicate(true)
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = stored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	check(resumed.desktop.world.get_node("Room").blueprint == expected, "new session restores saved region schemes")
	check(resumed.desktop.world.layout.valid, "automatic regions preserve furniture validity")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "computer hardware remains desk-only: " + role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.save_path))
	print("ROOM_REGIONS_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
