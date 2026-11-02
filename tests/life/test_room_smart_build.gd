extends SceneTree
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
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
	check(desktop.get_node("%WallSnapToggle") != null and desktop.get_node("%BlueprintOpeningWidth") != null, "wide-opening and wall-snap controls exist in the authored editor")
	check(layout.nodes.has("lamp"), "lamp furniture exists for wall-clearance testing")
	layout.select("lamp")
	check(layout.wall_clearance("lamp") >= 0.0, "furniture has a computable nonnegative clearance from the room perimeter")
	check("距外墙" in desktop.get_node("%LayoutSize").text, "selected furniture displays its wall clearance")
	var free := Vector2(2,1.65)
	check(layout._wall_snap_point("lamp",free) == free, "automatic wall snapping is opt-in")
	layout.set_wall_snap(true)
	check(layout.wall_snap, "smart wall snap toggle enables the feature")
	var lamp: Node3D = layout.nodes["lamp"]
	var half: Vector2 = Blueprint.half_size(layout.blueprint)
	var size: Vector3 = layout.bounds_for("lamp") * lamp.scale.abs()
	var near := Vector2(half.x-size.x*.5-layout.edge_margin-layout.collision_margin-.15,1.7)
	var snapped: Vector2 = layout._wall_snap_point("lamp",near)
	check(snapped.distance_to(near) <= layout.WALL_SNAP_RADIUS+.001, "magnetic correction is bounded by configured radius")
	check(snapped.x >= near.x, "outer wall magnet moves a nearby item toward the safe right-wall margin")
	layout.set_wall_snap(false)
	check(not layout.wall_snap, "wall snapping can be disabled without changing the room")

	desktop.set_blueprint_mode(true)
	var count_before: int = layout.undo_stack.size()
	layout.begin_wall_stroke()
	check(layout.add_partition(Vector2(0,2.5),"x"), "first wall segment is placed during a gesture")
	check(layout.add_partition(Vector2(1,2.5),"x"), "second adjoining wall segment is placed in the same gesture")
	check(layout.undo_stack.size() == count_before, "wall gestures do not push individual undo entries")
	layout.end_wall_stroke()
	check(layout.undo_stack.size() == count_before+1, "two wall segments are represented by one undo record")
	check(layout.blueprint.partitions.size() == 2, "both walls persist at gesture end")
	layout.undo()
	check(layout.blueprint.partitions.is_empty(), "a single undo removes the complete wall stroke")
	layout.redo()
	check(layout.blueprint.partitions.size() == 2, "redo restores the entire stroke")
	var erase_before: int = layout.undo_stack.size()
	layout.begin_wall_stroke()
	check(layout.remove_partition(Vector2(0,2.5)), "first wall can be removed during a demolition stroke")
	check(layout.remove_partition(Vector2(1,2.5)), "second wall can be removed during the same demolition stroke")
	layout.end_wall_stroke()
	check(layout.undo_stack.size() == erase_before+1 and layout.blueprint.partitions.is_empty(), "demolition is also grouped into one undo action")
	layout.undo()
	check(layout.blueprint.partitions.size() == 2, "undo restores all demolished walls")
	layout.begin_wall_stroke()
	check(layout.remove_partition(Vector2(0,2.5)), "a trial demolition begins")
	layout.end_wall_stroke(true)
	check(layout.blueprint.partitions.size() == 2 and layout.wall_stroke_before.is_empty(), "canceling a stroke restores pre-gesture layout")

	check(layout.set_blueprint_shape("custom"), "custom exterior can be selected for wide openings")
	var cells := [{"ix":15,"iz":11},{"ix":14,"iz":11}]
	for cell: Dictionary in cells:
		check(layout.paint_floor_cell(Blueprint.cell_center(layout.blueprint,cell)), "remove unoccupied corner floor for a straight exterior edge")
	var source := {"ix":14,"iz":11,"dx":0,"dz":-1}
	var adjacent := {"ix":15,"iz":11,"dx":0,"dz":-1}
	check(Blueprint.edge_exposed(layout.blueprint,source) and Blueprint.edge_exposed(layout.blueprint,adjacent), "two aligned exposed exterior segments exist")
	var start: Vector2 = Blueprint.edge_center(layout.blueprint,source)
	var span: Array = Blueprint.edge_span(layout.blueprint,source,2)
	check(span.size() == 2, "contiguous span finder returns two adjacent 0.5m edges")
	check(Blueprint.edge_span(layout.blueprint,source,5).is_empty(), "width beyond the supported limit is rejected")
	check(layout.paint_exterior_edge(Blueprint.edge_center(layout.blueprint,adjacent),"window",3), "other wall segment accepts a preexisting window")
	check(not layout.exterior_span_blocker(start,2,"door",2).is_empty(), "wide door refuses to overwrite a prior window")
	check(not layout.paint_exterior_span(start,2,"door",2), "blocked multi-segment edit cannot mutate room")
	check(layout.paint_exterior_edge(Blueprint.edge_center(layout.blueprint,adjacent),"wall",0), "existing window can be cleared")
	var before: int = layout.undo_stack.size()
	check(layout.paint_exterior_span(start,2,"door",2), "one click creates a full metre wide doorway")
	check(layout.undo_stack.size() == before+1, "width editing creates one undo entry")
	check(Blueprint.edge_edit(layout.blueprint,source).kind == "door" and Blueprint.edge_edit(layout.blueprint,adjacent).kind == "door", "both aligned door edges are recorded")
	check(Blueprint.same_opening_neighbor(layout.blueprint,source,1), "adjacent door modules are recognized as one opening")
	var heads: Array = room.get_node("Shell/Custom_Exterior").find_children("DoorHead","MeshInstance3D",true,false)
	var frames: Array = room.get_node("Shell/Custom_Exterior").find_children("DoorFrame","MeshInstance3D",true,false)
	check(heads.size() == 2 and frames.size() == 2, "wide door renders two lintels with only its outside frame posts")
	layout.undo()
	check(Blueprint.edge_edit(layout.blueprint,source).kind == "wall" and Blueprint.edge_edit(layout.blueprint,adjacent).kind == "wall", "undo removes the entire wide doorway")
	layout.redo()
	check(Blueprint.edge_edit(layout.blueprint,source).kind == "door" and Blueprint.edge_edit(layout.blueprint,adjacent).kind == "door", "redo restores both door modules")
	check(layout.paint_exterior_edge(start,"wall",0), "first door module can be returned to wall")
	check(layout.paint_exterior_edge(Blueprint.edge_center(layout.blueprint,adjacent),"wall",0), "second door module can be returned to wall")
	check(layout.paint_exterior_span(start,2,"window",1), "a one-metre window can be painted in one operation")
	check(Blueprint.same_opening_neighbor(layout.blueprint,source,1), "adjoining window glass modules form a continuous band")
	check(room.get_node("Shell/Custom_Exterior").find_children("WindowGlass","MeshInstance3D",true,false).size() == 2, "a wide window rebuilds both glass panels")

	state.save_path = "user://memoir_room_smart_build_p10_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var stored = State.new()
	stored.save_path = state.save_path
	stored.load_state()
	check(stored.life.room_blueprint.edge_finishes == state.life.room_blueprint.edge_finishes, "multi-segment window survives JSON storage")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = stored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var loaded = resumed.desktop.world.get_node("Room")
	check(loaded.blueprint.edge_finishes.size() == 2, "new session reconstructs both halves of the saved window")
	check(resumed.desktop.world.layout.valid, "smart build features retain valid furniture collision layout")
	for role: String in resumed.desktop.world.devices:
		check(resumed.desktop.world.layout.surface_for(role) == "desk", "desktop hardware remains desk-only: "+role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.save_path))
	print("ROOM_SMART_BUILD_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
