extends SceneTree
## Structural connectivity is independent from purpose-based area labels.
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
	var bare: Dictionary = Blueprint.clean({"shape":"custom"})
	check(Blueprint.room_regions(bare).size() == 1, "custom rectangle is one connected walkable room")
	check(Blueprint.room_region_at(bare,Vector2.ZERO).size() == 192,
		"8x6 floor still contains 192 half-metre cells")
	check(Blueprint.room_region_at(bare,Vector2(99,99)).is_empty(),
		"clicks outside geometry do not return floor cells")
	var ring: Array = []
	for x in [-.5,.5]:
		for z in [-1.0,1.0]:
			ring.append({"x":x,"z":z,"axis":"x","kind":"wall"})
	for z in [-.5,.5]:
		for x in [-1.0,1.0]:
			ring.append({"x":x,"z":z,"axis":"z","kind":"wall"})
	var isolated: Dictionary = Blueprint.clean({"shape":"custom","partitions":ring})
	check(isolated.partitions.size() == 8, "physical wall segments remain independent of room purposes")
	check(Blueprint.room_region_at(isolated,Vector2.ZERO).size() == 16,
		"walls enclose the expected four-square-meter space")
	check(Blueprint.room_regions(isolated).size() == 2,
		"two physical connected spaces remain detectable without labels")
	var door: Dictionary = isolated.duplicate(true)
	door.partitions[0].kind = "door"
	check(Blueprint.room_region_at(door,Vector2.ZERO).size() == 192,
		"doorways still connect physical spaces")
	check(Blueprint.room_regions(door).size() == 1,
		"room connectivity remains geometry-derived")
	var cutout: Dictionary = Blueprint.clean({"shape":"custom","removed_cells":[{"ix":15,"iz":11}]})
	check(Blueprint.room_region_at(cutout,Blueprint.cell_center(cutout,{"ix":15,"iz":11})).is_empty(),
		"removed floor is absent from connected space")
	check(Blueprint.room_region_at(cutout,Vector2.ZERO).size() == 191,
		"remaining floor connectivity survives carving")
	var obsolete: Dictionary = Blueprint.clean({"shape":"custom",
		"saved_schemes":[{"slot":0,"zone_cells":[{"ix":2,"iz":2,"zone":1}],
			"floor_finishes":[{"ix":2,"iz":2,"finish":1}]}],
		"zone_cells":[{"ix":2,"iz":2,"zone":1}],
		"zone_styles":[{"floor":3,"wall":1,"light":1}]})
	check(not obsolete.has("saved_schemes") and not obsolete.has("zone_cells"),
		"obsolete saved area presets and labels are stripped from new blueprint data")
	check(Blueprint.floor_finish(obsolete,{"ix":2,"iz":2}) == 3,
		"only active old zone floor color becomes a manual finish; snapshots are ignored")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var layout = desktop.world.layout
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(layout.set_blueprint_shape("custom"), "editable custom footprint remains supported")
	check(desktop.get_node_or_null("%BlueprintQuickRegion") == null,
		"automatic named-zone fill action is absent")
	check(desktop.get_node_or_null("%BlueprintSchemeSlot") == null,
		"functional-area snapshot slots are absent")
	var cell := {"ix":3,"iz":8}
	var center: Vector2 = Blueprint.cell_center(layout.blueprint,cell)
	check(layout.paint_floor_finish(center,1), "editing an arbitrary connected cell works directly")
	check(Blueprint.floor_finish(layout.blueprint,cell) == 1,
		"direct decoration does not depend on connectivity labels")
	layout.undo()
	check(Blueprint.floor_finish(layout.blueprint,cell) == 0,
		"tile finish undo works without purpose zones")
	layout.redo()
	check(Blueprint.floor_finish(layout.blueprint,cell) == 1,
		"tile finish redo works without purpose zones")
	state.save_path = "user://memoir_connected_rooms_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(not state.life.room_blueprint.has("saved_schemes"),
		"committed room no longer persists functional-area snapshot data")
	var loaded := State.new()
	loaded.save_path = state.save_path
	loaded.load_state()
	check(loaded.life.room_blueprint == state.life.room_blueprint,
		"physical room and direct tile colors survive JSON roundtrip")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = loaded
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	check(resumed.desktop.world.layout.blueprint == loaded.life.room_blueprint,
		"reloaded room uses the same free-decoration blueprint")
	check(resumed.desktop.world.layout.valid,
		"removing zone metadata does not invalidate furniture placement")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk",
			"existing computer devices remain on their authored desk: "+role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(loaded.save_path))
	print("ROOM_CONNECTED_SPACES_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
