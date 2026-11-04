extends SceneTree
## Exterior wall hanging, door/window exclusion, undo, inventory and JSON recovery.
const Wall = preload("res://scripts/room/room_wall_mount_data.gd")
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
const Inventory = preload("res://scripts/items/inventory_data.gd")
const Roles = preload("res://scripts/life/workstation_layout_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var role := "poster_floor_frame__instance__item_99"
	var pose := {"x":0.0,"z":-1.6,"yaw":0.0}
	var record := {"wall":"north","along":0.0,"height":1.2,"floor_pose":pose}
	var placed := {role:"item_99"}
	check(Wall.clean({role:record},placed,Blueprint.DEFAULT).has(role),"owned framed poster validates")
	var unsafe := record.duplicate(true)
	unsafe.wall = "ceiling"
	check(Wall.clean({role:unsafe},placed,Blueprint.DEFAULT).is_empty(),"invalid wall name rejected")
	unsafe = record.duplicate(true)
	unsafe.height = NAN
	check(Wall.clean({role:unsafe},placed,Blueprint.DEFAULT).is_empty(),"nonfinite wall height rejected")
	check(Wall.clean({"chair":record},{"chair":"starter_chair"},Blueprint.DEFAULT).is_empty(),"chairs cannot be mounted")
	check(not Wall.fits({"wall":"south","along":float(Blueprint.DEFAULT.door_x),"height":1.2},Blueprint.DEFAULT,.77,1.2),"door opening cannot host frame")
	check(not Wall.fits({"wall":"west","along":float(Blueprint.DEFAULT.window_z),"height":1.2},Blueprint.DEFAULT,.77,1.2),"window opening cannot host frame")
	check(not Wall.fits({"wall":"north","along":3.95,"height":1.2},Blueprint.DEFAULT,.77,1.2),"corner clearance enforced")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 15000
	var sku := "room_poster_floor_frame"
	check(str(game.session.buy_item(sku)).begins_with("已购买"),"existing collectible is purchased normally")
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var uid: String = Inventory.unused_uid(state.life.inventory,layout.placed_instances,sku)
	check(not uid.is_empty() and layout.start_place(sku,uid),"purchased frame starts the standard placement workflow")
	var frame_role: String = Roles.instance_role("poster_floor_frame",uid)
	var floor_found := false
	# Prefer a north-facing wall segment away from the door/window and corners.
	for z in [-2.2,-1.7,-1.2,-0.7,0.0]:
		if floor_found: break
		for x in [0.0,-.5,.5,-1.0,1.0,-1.5,1.5,-2.0,2.0]:
			layout.preview_placement(Vector2(x,z))
			if layout.valid:
				floor_found = true
				break
	check(floor_found,"room has a safe original floor spot for the framed poster")
	if floor_found: check(layout.confirm_placement(),"floor staging position confirms")
	var hung: bool = layout.hang_selected_on_wall()
	if not hung:
		print("WALL_DIAGNOSTIC selected=",layout.selected,
			" role=",frame_role," pose=",layout.nodes[frame_role].position,
			" stage=",layout.placing_role," group=",layout.group_selection,
			" error=",layout.message," dims=",layout.bounds_for(frame_role))
		for wall: String in ["north","south","west","east"]:
			var check_mount := {"wall":wall,"along":layout.nodes[frame_role].position.x if wall in ["north","south"] else layout.nodes[frame_role].position.z,
				"height":1.2}
			print("WALL_DIAGNOSTIC ",wall,": ",Wall.fits(check_mount,layout.blueprint,.77,1.2))
	check(hung,"frame moves from floor to a valid exterior wall")
	check(layout.wall_mounts.has(frame_role),"wall attachment is tracked independently of surface mounts")
	check(layout.nodes[frame_role].position.y > 0.8,"frame is elevated on the wall")
	var original_mount: Dictionary = layout.wall_mounts[frame_role].duplicate(true)
	var position_3d: Vector3 = layout.nodes[frame_role].global_position
	var wall_axis: Vector3 = Vector3.RIGHT if str(original_mount.wall) in ["north","south"] else Vector3.BACK
	var camera: Camera3D = layout.world.camera
	var pointer_start: Vector2 = camera.unproject_position(position_3d + Vector3.UP * .2)
	var pointer_next: Vector2 = camera.unproject_position(position_3d + wall_axis * .10 + Vector3.UP * .30)
	var undo_count: int = layout.undo_stack.size()
	layout.begin_drag(pointer_start,"move")
	check(layout.gesture == "move","wall hanging begins mouse drag on its vertical plane")
	layout.drag_to(pointer_next)
	check(float(layout.wall_mounts[frame_role].height) > float(original_mount.height),
		"mouse drag moves a wall frame vertically")
	check(not is_equal_approx(float(layout.wall_mounts[frame_role].along),float(original_mount.along)),
		"mouse drag changes the frame's horizontal wall position")
	layout.end_drag()
	check(layout.undo_stack.size() == undo_count+1,"entire wall drag is one undo operation")
	layout.undo()
	check(is_equal_approx(float(layout.wall_mounts[frame_role].along),float(original_mount.along)) and
		is_equal_approx(float(layout.wall_mounts[frame_role].height),float(original_mount.height)),
		"undo restores precise wall attachment before mouse drag")
	layout.redo()
	check(float(layout.wall_mounts[frame_role].height) > float(original_mount.height),
		"redo restores position after wall drag")
	var before_blocked: Dictionary = layout.wall_mounts[frame_role].duplicate(true)
	check(not layout.set_wall_mount_position(Vector2(20.0,1.5)),
		"invalid wall drag targets cannot cross the wall boundaries")
	check(layout.wall_mounts[frame_role] == before_blocked,
		"rejected wall drag keeps the last safe wall position")
	var moved: bool = layout.move_wall_mount(Vector2(0.05,0.05))
	check(moved,"wall mount supports horizontal and vertical adjustment")
	check(layout.nudge_selected(Vector2.LEFT),"wall mount accepts keyboard adjustments")
	var height_before: float = float(layout.wall_mounts[frame_role].height)
	check(layout.nudge_selected(Vector2.UP) and float(layout.wall_mounts[frame_role].height)>height_before,"arrow up raises the wall decoration")
	check(not layout.move_wall_mount(Vector2(10.0,0)),"wall edge prevents invalid translation")
	layout.undo()
	check(layout.wall_mounts.has(frame_role),"undo preserves wall attachment")
	layout.redo()
	check(layout.wall_mounts.has(frame_role),"redo restores wall attachment")
	check(layout.take_down_selected_wall_mount(),"poster can return to its saved floor position")
	check(not layout.wall_mounts.has(frame_role),"take-down releases wall metadata")
	layout.undo()
	check(layout.wall_mounts.has(frame_role),"undo take-down restores wall placement")
	state.save_path = "user://memoir_wall_mount_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.get("wall_mounts",{}).has(frame_role),"commit writes wall mounting data")
	var loaded := State.new()
	loaded.save_path = state.save_path
	loaded.load_state()
	check(loaded.life.get("wall_mounts",{}).has(frame_role),"JSON roundtrip keeps mounted UID")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = loaded
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var recovered = resumed.desktop.world.layout
	check(recovered.wall_mounts.has(frame_role),"wall mount restored into active layout")
	check(recovered._layout_blocker().is_empty(),"restored wall frame passes layout validation")
	check(recovered.nodes.has(frame_role) and recovered.nodes[frame_role].position.y > .8,"wall frame remains elevated after reload")
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(loaded.save_path))
	print("ROOM_WALL_MOUNTS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
