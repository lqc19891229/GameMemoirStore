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
	check(not overlay.visible, "construction grid does not show during normal gameplay")
	check(world.get_node("WallPreview") != null and overlay.has_node("GridLines") and overlay.has_node("RegionFill"), "overlay nodes are authored into workstation scene")
	check(desktop.get_node("%BlueprintQuickWall") != null and desktop.get_node("%BlueprintQuickRegion") != null and desktop.get_node("%BlueprintQuickOpening") != null, "quick build tools are scene-authored")
	check(desktop.get_node("%BlueprintGridToggle") != null and desktop.get_node("%BlueprintApertureTarget") != null, "grid toggle and opening selector are authored")
	desktop.begin_layout()
	desktop.set_blueprint_mode(true)
	check(overlay.visible and overlay.get_node("GridLines").visible, "blueprint mode enables grid lines")
	var initial: Dictionary = layout.blueprint.duplicate(true)
	check(overlay.get_node("GridLines").mesh != null, "blueprint overlay generates a grid mesh")
	check(overlay.get_node("GridLines").mesh.get_surface_count() > 0, "generated grid has drawable line vertices")
	check(is_equal_approx(overlay.get_node("DoorHandle").position.x,float(initial.door_x)), "door handle matches saved door position")
	check(is_equal_approx(overlay.get_node("WindowHandle").position.z,float(initial.window_z)), "window handle matches saved window position")
	overlay.set_grid_visible(false)
	check(not overlay.get_node("GridLines").visible and overlay.visible, "grid switch hides only lines, keeping handles available")
	overlay.set_grid_visible(true)
	check(overlay.get_node("GridLines").visible, "grid lines restore without rebuilding the room")

	var open_region: int = overlay.preview_region(layout.blueprint,Vector2.ZERO)
	check(open_region == 192, "hover covers the entire unpartitioned 8x6 room")
	check(overlay.get_node("RegionFill").mesh != null, "region hover generates transparent area mesh")
	check(overlay.get_node("RegionFill").mesh.surface_get_array_len(0) == 192*6, "area geometry covers six vertices per floor tile")
	check(overlay.preview_region(layout.blueprint,Vector2(.6,.6)) == 192, "hovering adjacent cell reuses the same connected region")
	check(overlay.preview_region(layout.blueprint,Vector2(20,20)) == 0, "outside hover clears the connected-region preview")
	check(overlay.get_node("RegionFill").mesh == null, "cleared region releases its preview mesh")

	check(layout.set_blueprint_shape("custom"), "grid room can be selected")
	var empty_cell := {"ix":15,"iz":11}
	var empty_point: Vector2 = Blueprint.cell_center(layout.blueprint,empty_cell)
	check(layout.paint_floor_cell(empty_point), "carving an unoccupied corner cell is valid")
	check(overlay.preview_region(layout.blueprint,empty_point) == 0, "hovering removed floor shows no region")
	check(overlay.preview_region(layout.blueprint,Vector2.ZERO) == 191, "highlight excludes missing floor cells")
	check(layout.paint_floor_cell(empty_point,false), "restore carved cell")
	check(overlay.preview_region(layout.blueprint,Vector2.ZERO) == 192, "highlight updates after floor restoration")

	var initial_undo: int = layout.undo_stack.size()
	layout.begin_aperture_drag()
	check(layout.drag_aperture("door_x",-2.45), "dragging a fixed door updates its blueprint position")
	check(layout.drag_aperture("door_x",-2.25), "multiple drag ticks move one shared door handle")
	check(is_equal_approx(overlay.get_node("DoorHandle").position.x,-2.25), "door handle tracks blueprint geometry in realtime")
	check(layout.undo_stack.size() == initial_undo, "intermediate drag ticks never add undo history")
	layout.end_aperture_drag()
	check(layout.undo_stack.size() == initial_undo+1, "completing a door drag records exactly one undo step")
	check(is_equal_approx(layout.blueprint.door_x,-2.25), "door position is retained")
	layout.undo()
	check(is_equal_approx(layout.blueprint.door_x,initial.door_x), "one undo restores original door position")
	layout.redo()
	check(is_equal_approx(layout.blueprint.door_x,-2.25), "redo restores final dragged door position")

	layout.begin_aperture_drag()
	check(layout.drag_aperture("window_z",.05), "left-wall window can be dragged on the Z axis")
	layout.end_aperture_drag()
	check(is_equal_approx(layout.blueprint.window_z,.05), "window blueprint position updates")
	layout.undo()
	check(is_equal_approx(layout.blueprint.window_z,initial.window_z), "window drag is undoable")
	var before_cancel: Dictionary = layout.blueprint.duplicate(true)
	layout.begin_aperture_drag()
	check(layout.drag_aperture("door_x",-1.95), "another door drag can begin")
	layout.end_aperture_drag(true)
	check(layout.blueprint == before_cancel, "canceled aperture drag restores exact blueprint")
	check(not layout.aperture_drag_before.size() > 0, "canceled drag clears its in-progress snapshot")
	desktop.set_blueprint_mode(false)
	check(not overlay.visible and overlay.get_node("RegionFill").mesh == null, "leaving blueprint mode hides grid and clears hover mesh")
	desktop.finish_layout(false)
	check(layout.blueprint == initial, "cancel layout restores original blueprint after drag and floor changes")
	check(not overlay.visible, "normal gameplay keeps blueprint overlay hidden")
	game.queue_free()
	await frames()
	print("BLUEPRINT_UX_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
