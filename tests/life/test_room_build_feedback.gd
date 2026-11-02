extends SceneTree
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _initialize() -> void: run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var layout = world.layout
	var overlay = world.get_node("BlueprintOverlay")
	check(desktop.get_node("%BlueprintQuickEdgeMove") != null and desktop.get_node("%BlueprintStrokeInfo") != null, "wall stroke feedback and edge movement controls are scene-authored")
	check(desktop.get_node("%LayoutSize") != null, "furniture dimension label is a scene-authored control")
	desktop.begin_layout()
	check("占地" in desktop.get_node("%LayoutSize").text and "米" in desktop.get_node("%LayoutSize").text, "selected item reports width depth and height in metres")
	var furniture_size: Vector3 = layout.bounds_for(layout.selected) * layout.nodes[layout.selected].scale.abs()
	check(furniture_size.x > 0 and furniture_size.z > 0, "displayed furniture footprint has nonzero measured extents")
	desktop.set_blueprint_mode(true)
	check(overlay.has_node("WallStrokeValid") and overlay.has_node("WallStrokeBlocked"), "two wall-stroke overlay meshes are authored")
	overlay.show_wall_stroke([Vector2(0,2.5),Vector2(1,2.5)],[Vector2(.5,2.5)],"x")
	check(overlay.get_node("WallStrokeValid").mesh != null and overlay.get_node("WallStrokeBlocked").mesh != null, "valid and blocked stroke segments have colored meshes")
	check(overlay.get_node("WallStrokeValid").mesh.surface_get_array_len(0) == 12, "valid wall stroke holds two quads")
	check(overlay.get_node("WallStrokeBlocked").mesh.surface_get_array_len(0) == 6, "blocked wall stroke holds one quad")
	overlay.clear_wall_stroke()
	check(overlay.get_node("WallStrokeValid").mesh == null and overlay.get_node("WallStrokeBlocked").mesh == null, "clearing stroke releases visual meshes")

	desktop.get_node("%BlueprintFloorTool").select(0)
	desktop._reset_wall_stroke()
	var at := Vector2(0,2.5)
	check(desktop._stroke_wall_step(at,MOUSE_BUTTON_LEFT), "first wall segment can be placed")
	check(not desktop._stroke_wall_step(at,MOUSE_BUTTON_LEFT), "repainting the same spot shows blocked segment")
	check(desktop.wall_stroke_good.size() == 1 and desktop.wall_stroke_bad.size() == 1, "stroke feedback distinguishes valid from blocked placements")
	desktop.last_wall_cell = at
	desktop._continue_wall_stroke(Vector2(2,2.5),MOUSE_BUTTON_LEFT)
	check(desktop.last_wall_cell.is_equal_approx(Vector2(2,2.5)), "fast pointer travel is interpolated over the entire wall line")
	check(layout.blueprint.partitions.size() >= 2, "interpolated wall stroke creates multiple valid adjacent wall segments")
	check(overlay.get_node("WallStrokeValid").mesh != null and overlay.get_node("WallStrokeBlocked").mesh != null, "continuous wall build keeps success and collision trail")
	desktop._reset_wall_stroke()
	check(desktop.wall_stroke_good.is_empty() and desktop.wall_stroke_bad.is_empty(), "finishing a wall drag clears the stroke cache")

	check(layout.set_blueprint_shape("custom"), "custom exterior editing can be opened")
	var cut := {"ix":15,"iz":11}
	check(layout.paint_floor_cell(Blueprint.cell_center(layout.blueprint,cut)), "removing an unoccupied corner creates custom exterior edges")
	var exposed: Array = Blueprint.exposed_edges(layout.blueprint)
	check(exposed.size() >= 2, "a cutout creates more than one wall edge")
	var source: Dictionary = exposed[0]
	var target: Dictionary = exposed[1]
	var source_pos: Vector2 = Blueprint.edge_center(layout.blueprint,source)
	var target_pos: Vector2 = Blueprint.edge_center(layout.blueprint,target)
	check(layout.paint_exterior_edge(source_pos,"window",2), "window can be added to source edge")
	check(layout.paint_exterior_edge(target_pos,"door",1), "another edge can have an existing opening")
	check(layout.begin_custom_edge_drag(source_pos), "window can be selected for dragging")
	check(not layout.edge_drag_blocker(target_pos).is_empty(), "cannot overwrite an already decorated destination wall")
	check(not layout.drag_custom_edge_to(target_pos), "blocked edge movement does not change construction data")
	layout.end_custom_edge_drag(true)
	check(Blueprint.edge_edit(layout.blueprint,source).kind == "window", "cancel drag preserves the original window")
	check(layout.paint_exterior_edge(target_pos,"wall",0), "destination edge can be restored to bare wall")
	var history_before: int = layout.undo_stack.size()
	check(layout.begin_custom_edge_drag(source_pos), "window drag can start once destination is available")
	check(layout.edge_drag_blocker(target_pos).is_empty(), "free exterior edge accepts dragged window")
	check(layout.drag_custom_edge_to(target_pos), "window moves to destination exterior edge")
	check(layout.undo_stack.size() == history_before, "dragging custom window does not push intermediate history")
	check(Blueprint.edge_edit(layout.blueprint,target).kind == "window", "target receives original opening kind")
	check(int(Blueprint.edge_edit(layout.blueprint,target).finish) == 2, "moved opening preserves independent wall finish")
	check(Blueprint.edge_edit(layout.blueprint,source).kind == "wall", "source edge closes after moving its opening")
	layout.end_custom_edge_drag()
	check(layout.undo_stack.size() == history_before+1, "all exterior edge movement is one undo step")
	layout.undo()
	check(Blueprint.edge_edit(layout.blueprint,source).kind == "window", "undo restores original exterior window")
	layout.redo()
	check(Blueprint.edge_edit(layout.blueprint,target).kind == "window", "redo reapplies window relocation")
	check(layout.begin_custom_edge_drag(target_pos), "moved window can be grabbed again")
	check(layout.drag_custom_edge_to(source_pos), "window can be moved back")
	layout.end_custom_edge_drag(true)
	check(Blueprint.edge_edit(layout.blueprint,target).kind == "window", "canceled second drag rolls back its changes")
	check(layout.edge_drag_before.is_empty(), "cancel clears in-progress edge drag history")
	check(not layout.begin_custom_edge_drag(source_pos), "bare wall cannot be dragged as window")

	desktop.set_blueprint_mode(false)
	check(overlay.get_node("WallStrokeValid").mesh == null, "leaving blueprint mode does not retain stroke highlights")
	desktop.finish_layout(false)
	check(layout.blueprint.shape == "rectangle" and layout.blueprint.edge_finishes.is_empty(), "cancel restores original room geometry and openings")
	check(layout.valid, "furniture layout remains valid after canceling draft edits")
	for role: String in world.devices:
		check(layout.surface_for(role) == "desk", "computer equipment stays desk-only: " + role)
	game.queue_free()
	await frames()
	print("ROOM_BUILD_FEEDBACK_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
