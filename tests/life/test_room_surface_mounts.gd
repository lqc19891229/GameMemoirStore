extends SceneTree
## Purchase -> floor placement -> shelf mount -> undo -> save -> reload regression.
const Inventory = preload("res://scripts/items/inventory_data.gd")
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const MountData = preload("res://scripts/room/furniture_mount_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5):
		await process_frame

func run() -> void:
	var fixture := {"bookcase":"starter_bookcase","desk_memento__instance__item_9":"item_9"}
	var valid_entry := {"support":"bookcase","anchor":"shelf_0","x":0.0,"z":0.0,"yaw":0.0,
		"floor_pose":{"x":2.1,"z":-1.8,"yaw":0.0}}
	check(MountData.clean({"desk_memento__instance__item_9":valid_entry},fixture).size() == 1,
		"valid purchased UID furniture may mount on known support")
	var spoofed := valid_entry.duplicate(true)
	spoofed.support = "nonexistent"
	check(MountData.clean({"desk_memento__instance__item_9":spoofed},fixture).is_empty(),
		"unknown support rejected")
	spoofed = valid_entry.duplicate(true)
	spoofed.x = INF
	check(MountData.clean({"desk_memento__instance__item_9":spoofed},fixture).is_empty(),
		"non-finite attachment position rejected")
	check(MountData.clean({"bookcase":valid_entry},fixture).is_empty(),
		"support may not attach to itself")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 15000
	var desktop = game.desktop
	var layout = desktop.world.layout
	var item_id := "room_desk_memento"
	var bought: String = str(game.session.buy_item(item_id))
	check(bought.begins_with("已购买"),"small decor is bought through existing inventory economy")
	check(str(game.session.buy_item("room_mini_book_stack")).begins_with("已购买"),
		"second compact collectible can be bought independently")
	desktop.begin_layout()
	var uid: String = Inventory.unused_uid(state.life.inventory,layout.placed_instances,item_id)
	check(not uid.is_empty(),"purchase creates one unused UID")
	check(layout.start_place(item_id,uid),"room editor accepts purchased mini decoration")
	var role := Data.instance_role("desk_memento",uid)
	check(not role.is_empty() and layout.nodes.has(role),"item has stable UID scene instance")
	layout.preview_placement(Vector2(2.1,-1.8))
	check(layout.valid,"small decoration has a safe floor staging position")
	if layout.valid: check(layout.confirm_placement(),"floor staging placement committed")
	check(layout.mount_selected_on_nearest_surface(),"item mounts on available bookshelf surface")
	check(layout.surface_mounts.has(role),"mounted item recorded by stable role")
	if layout.surface_mounts.has(role):
		check(str(layout.surface_mounts[role].support) == "bookcase", "starter bookshelf is chosen as support")
	check(layout.nodes[role].global_position.y > 0.2,"mounted item appears above the floor")
	# Direct placement from the inventory should not require a temporary floor
	# confirmation followed by a separate mount action.
	var book_id := "room_mini_book_stack"
	var book_uid: String = Inventory.unused_uid(state.life.inventory,layout.placed_instances,book_id)
	check(layout.start_place(book_id,book_uid),"begin direct placement for purchased mini art books")
	var book_role: String = Data.instance_role("mini_book_stack",book_uid)
	var shelf: Node3D = layout.nodes["bookcase"]
	var anchors: Array[Dictionary] = layout.SupportSurfaces.anchors_for(shelf)
	var target_point: Vector3 = shelf.to_global(anchors[3].center)
	var target_pixel: Vector2 = layout.world.camera.unproject_position(target_point)
	layout.preview_at(target_pixel)
	check(layout.surface_mounts.has(book_role),"hovering over upper shelf generates a direct surface preview")
	check(layout.valid,"direct surface preview passes collision checks")
	layout.cancel_placement()
	check(not layout.nodes.has(book_role) and not layout.surface_mounts.has(book_role),
		"cancelling a direct preview returns the UID to inventory without leaked scene nodes")
	check(layout.start_place(book_id,book_uid),"cancelled purchased UID can be placed again")
	layout.preview_at(target_pixel)
	if layout.surface_mounts.has(book_role) and layout.valid:
		check(layout.confirm_placement(),"direct shelf placement confirms without floor staging")
	else:
		check(false,"direct shelf placement must be ready for confirmation")
	check(layout.placed_instances.get(book_role,"") == book_uid and layout.surface_mounts.has(book_role),
		"confirmed shelf attachment preserves the purchased inventory UID")
	if layout.surface_mounts.has(book_role):
		var floor_pose: Dictionary = layout.surface_mounts[book_role].floor_pose
		check(is_finite(float(floor_pose.x)) and is_finite(float(floor_pose.z)),
			"direct shelf placement reserves a removable floor fallback")
		layout.select(book_role)
		check(layout.unmount_selected(),"direct shelf item can return to its reserved floor spot")
		layout.undo()
		check(layout.surface_mounts.has(book_role),"undo restores the direct shelf mount after take-down")
	layout.select(role)
	check(layout.nudge_selected(Vector2.RIGHT),"mounted item supports surface-local keyboard nudge")
	check(is_equal_approx(float(layout.surface_mounts[role].x),0.05),"mounted nudge changes local X without changing floor pose")
	var drag_point: Vector2 = layout.world.camera.unproject_position(layout.nodes[role].global_position + Vector3.UP * 0.10)
	layout.begin_drag(drag_point,"move")
	check(layout.gesture == "move","mounted item can begin pointer-driven drag on its support plane")
	layout.end_drag()
	var offset_before_invalid: float = float(layout.surface_mounts[role].x)
	check(not layout.edit_selected_mount(Vector2(5,0),0.0),"off-surface drag target is rejected")
	check(is_equal_approx(float(layout.surface_mounts[role].x),offset_before_invalid),"rejected move preserves the last valid position")
	layout.rotate_step(1.0)
	check(is_equal_approx(float(layout.surface_mounts[role].yaw),deg_to_rad(15.0)),"mounted item rotates independently of its shelf")
	check(not layout.edit_selected_mount(Vector2(0.5,0.1),deg_to_rad(45.0)),"rotated corners cannot cross a shelf edge")
	layout.undo()
	check(is_zero_approx(float(layout.surface_mounts[role].yaw)),"mounted rotation supports undo")
	layout.redo()
	check(is_equal_approx(float(layout.surface_mounts[role].yaw),deg_to_rad(15.0)),"mounted rotation supports redo")
	layout.select("bookcase")
	var previous: Vector3 = layout.nodes[role].global_position
	layout.store_selected()
	check(layout.placed_instances.has("bookcase"),"support may not be stored while child is mounted")
	layout.move_to(Vector2(2.7,-2.55))
	check(layout.nodes[role].global_position.distance_to(previous) > 0.04,"mounted item follows moved shelf")
	check(layout.valid,"parent and mounted child remain a valid layout")
	layout.select(role)
	check(layout.unmount_selected(),"mounted furniture can return to its original floor location")
	check(not layout.surface_mounts.has(role),"unmount clears support metadata")
	layout.undo()
	check(layout.surface_mounts.has(role),"undo restores mount")
	layout.redo()
	check(not layout.surface_mounts.has(role),"redo restores unmounted state")
	check(layout.mount_selected_on_nearest_surface(),"item may mount again after redo")
	var photo_safe: Dictionary = layout.surface_mounts.get(role,{}).duplicate(true)
	check(not photo_safe.is_empty(),"mounted state preserved before saving")

	state.save_path = "user://memoir_surface_mount_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	check(state.life.get("furniture_mounts",{}).has(role),"save writes mount metadata")
	var loaded := State.new()
	loaded.save_path = state.save_path
	loaded.load_state()
	check(loaded.life.get("furniture_mounts",{}).has(role),"JSON reload keeps UID surface attachment")
	check(loaded.life.get("furniture_mounts",{}).has(book_role),"directly placed UID survives JSON reload")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = loaded
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var restored = resumed.desktop.world.layout
	check(restored.surface_mounts.has(role),"room rebuild restores mounted furniture")
	check(restored.surface_mounts.has(book_role),"room rebuild restores directly placed miniature books")
	check(restored._layout_blocker().is_empty(),"restored scene has no collision or loss of support")
	check(restored.nodes.has(role) and restored.nodes[role].global_position.y > 0.2,"mounted model is physically elevated after reload")
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(loaded.save_path))
	print("ROOM_SURFACE_MOUNTS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures > 0 else 0)
