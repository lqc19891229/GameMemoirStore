extends SceneTree
## Real light, inventory-owned wall attachment, power/brightness and JSON persistence.
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
	var role := "wall_sconce__instance__item_99"
	var floor := {"x":0.0,"z":-1.2,"yaw":0.0}
	var entry := {"wall":"north","along":0.0,"height":1.4,"floor_pose":floor,"on":false,"level":3}
	var placements := {role:"item_99"}
	check(Wall.clean({role:entry},placements,Blueprint.DEFAULT).has(role),
		"valid UID wall light saves and loads as a mounted fixture")
	check(Wall.clean({role:entry},placements,Blueprint.DEFAULT)[role].level == 3,
		"persisted brightness level is preserved")
	var invalid := entry.duplicate(true)
	invalid["level"] = 4
	check(Wall.clean({role:invalid},placements,Blueprint.DEFAULT).is_empty(),
		"out-of-range lamp brightness is rejected")
	invalid = entry.duplicate(true)
	invalid["on"] = 1
	check(Wall.clean({role:invalid},placements,Blueprint.DEFAULT).is_empty(),
		"non-boolean lamp power is rejected")
	var mini_blueprint := Blueprint.DEFAULT.duplicate(true)
	mini_blueprint.partitions = [{"x":1.0,"z":1.0,"axis":"x","kind":"wall"}]
	var inner := {"wall":"partition","part":{"x":1.0,"z":1.0,"axis":"x"},
		"side":1,"along":0.0,"height":1.4,"floor_pose":floor,"on":true,"level":1}
	check(Wall.clean({role:inner},placements,mini_blueprint).has(role),
		"new wall sconce fits a player-built interior partition")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 15000
	var sku := "room_wall_sconce"
	check(str(game.session.buy_item(sku)).begins_with("已购买"),
		"warm brass wall sconce can be purchased through the existing shop")
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var uid: String = Inventory.unused_uid(state.life.inventory,layout.placed_instances,sku)
	check(not uid.is_empty() and layout.start_place(sku,uid),
		"owned sconce starts normal floor preview mode")
	var item_role: String = Roles.instance_role("wall_sconce",uid)
	var floor_found := false
	for z in [-2.3,-1.8,-1.3,-0.8,0.0]:
		if floor_found: break
		for x in [0.0,-.5,.5,-1.0,1.0,-1.5,1.5,-2.0,2.0]:
			layout.preview_placement(Vector2(x,z))
			if layout.valid:
				floor_found = true
				break
	check(floor_found,"one collision-free floor staging spot exists for lamp")
	if floor_found: check(layout.confirm_placement(),"lamp floor placement is confirmed")
	var glow := layout.nodes[item_role].get_node_or_null("LampGlow") as OmniLight3D
	check(glow != null and not glow.visible,"unmounted wall lamp never illuminates the floor preview")
	check(layout.hang_selected_on_wall(),"new lamp mounts on nearest valid exterior wall")
	check(layout.wall_mounts.has(item_role),"sconce mount stores item UID")
	check(glow.visible and glow.light_energy > .4,"mounted wall lamp visibly contributes real light")
	check(layout.set_wall_sconce_light(false),"wall lamp can be switched off")
	check(not glow.visible,"power off disables the real light source")
	layout.undo()
	check(glow.visible,"undo restores powered on state")
	layout.redo()
	check(not glow.visible,"redo restores powered off state")
	check(layout.set_wall_sconce_brightness(3),"lamp brightness accepts highest preset")
	check(is_equal_approx(glow.light_energy,float(Wall.LAMP_ENERGY[2])),
		"brightness setting changes OmniLight energy")
	check(layout.set_wall_sconce_light(true),"lamp can be switched on again")
	check(glow.visible,"power on restores the visible light")
	check(not layout.set_wall_sconce_brightness(5),"out of range brightness is refused")
	var lamp_before: Dictionary = layout.wall_mounts[item_role].duplicate(true)
	check(not layout.set_wall_mount_position(Vector2(20.0,1.4)),
		"lamp also respects wall collision bounds")
	check(layout.wall_mounts[item_role] == lamp_before,
		"invalid drag preserves lamp power and brightness settings")
	state.save_path = "user://memoir_wall_sconce_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var saved := State.new()
	saved.save_path = state.save_path
	saved.load_state()
	check(saved.life.get("wall_mounts",{}).has(item_role),"lamp wall mount exists in actual JSON save")
	check(int(saved.life.wall_mounts[item_role].level) == 3 and bool(saved.life.wall_mounts[item_role].on),
		"power and brightness survive JSON serialization")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var restored = load("res://scenes/main/game_root.tscn").instantiate()
	restored.get_node("GameSession").state = saved
	root.add_child(restored)
	restored.session.timer.stop()
	await frames()
	var recovered = restored.desktop.world.layout
	var restored_glow := recovered.nodes[item_role].get_node_or_null("LampGlow") as OmniLight3D
	check(recovered.wall_mounts.has(item_role),"reloaded layout restores the sconce mount")
	check(restored_glow != null and restored_glow.visible and is_equal_approx(restored_glow.light_energy,float(Wall.LAMP_ENERGY[2])),
		"reloaded room actually emits the saved brightness")
	restored.desktop.begin_layout()
	recovered.select(item_role)
	check(recovered.take_down_selected_wall_mount(),"lamp can return to its floor position")
	check(not restored_glow.visible,"taking down a lamp safely turns off its mounted light")
	recovered.undo()
	check(restored_glow.visible,"undo restores lamp mount and illumination")
	restored.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.save_path))
	print("ROOM_WALL_SCONCE: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
