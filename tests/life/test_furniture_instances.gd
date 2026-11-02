extends SceneTree
## Regression for unlimited UID-keyed furniture instances, legacy migration,
## ownership validation, undo/redo, and JSON save/reload.
const Inventory = preload("res://scripts/items/inventory_data.gd")
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const Life = preload("res://scripts/life/life_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5):
		await process_frame

func run() -> void:
	check(Data.instance_role("rug_round","item_999") == "rug_round__instance__item_999", "new instance role uses stable inventory UID")
	check(Data.base_role("side_table_oak__instance__item_123") == "side_table_oak", "multiword SKU role parses correctly")
	check(Data.is_copy("chair_8") and Data.base_role("chair_8") == "chair", "legacy numbered copy remains valid")
	check(not Data.valid_role("chair_9"), "old unsupported numbered roles are not mistaken for new instances")
	check(not Data.valid_role("rug_round__instance__item_0"), "zero UID is rejected")
	check(not Data.valid_role("unknown__instance__item_5"), "unknown SKU is rejected")
	check(not Data.valid_role("rug_round__instance__item_-4"), "negative inventory UID is rejected")
	check(not Data.valid_role("rug_round__instance__item_5/unsafe"), "unsafe UID is rejected")

	var legacy: Dictionary = Life.clean({
		"workstation_layout": {"chair_1": {"x":2.0,"z":0.0,"yaw":0.0}}
	}, [], [])
	check(legacy.placements.get("chair_1", "") == "legacy_chair_1", "pre-v4 numbered furniture is restored without owned instance records")
	check(Inventory.owns(legacy.inventory, "room_chair"), "legacy furniture stock still migrates into UID inventory")
	var fake_role := Data.instance_role("rug_round", "item_111")
	var forged: Dictionary = Life.clean({
		"inventory": [{"uid":"item_111","item_id":"room_rug_round"},{"uid":"item_112","item_id":"room_rug_round"}],
		"workstation_layout": {fake_role:{"x":2.0,"z":0.0,"yaw":0.0}},
		"placements": {fake_role:"item_112"}
	}, [], [])
	check(not forged.placements.has(fake_role), "a role cannot be redirected to a different owned UID")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 15000
	var desktop = game.desktop
	var layout = desktop.world.layout
	var sku := "room_rug_round"
	const COUNT := 12
	for i in range(COUNT):
		check(game.session.buy_item(sku).begins_with("已购买"), "repeat purchase creates furniture stock %d" % i)
	desktop.begin_layout()
	var roles: Array[String] = []
	var uids: Array[String] = []
	for i in range(COUNT):
		var uid: String = Inventory.unused_uid(state.life.inventory,layout.placed_instances,sku)
		check(not uid.is_empty(), "the next unplaced unit remains available")
		check(layout.start_place(sku,uid), "place instance after old nine-instance limit %d" % i)
		var role: String = Data.instance_role("rug_round",uid)
		check(layout.placing_role == role and layout.nodes.has(role), "each purchased UID receives its own model and role")
		layout.preview_placement(Vector2(-2.5,2.0))
		check(layout.valid and layout.confirm_placement(), "overlapping non-blocking rug is placed")
		roles.append(role)
		uids.append(uid)
	check(roles.size() == COUNT and layout.placed_instances.size() >= COUNT+5, "twelve same-SKU GLB furniture instances coexist")
	check(layout.nodes.has(roles[10]) and layout.nodes.has(roles[11]), "the eleventh and twelfth models remain separately selectable")
	layout.select(roles[10])
	layout.set_furniture_color(8)
	check(layout.color_for(roles[10]) == 8 and layout.color_for(roles[11]) == 0, "one instance tint does not change another")
	layout.store_selected()
	check(not layout.placed_instances.has(roles[10]) and layout.placed_instances.has(roles[11]), "storing one copy does not affect siblings")
	layout.undo()
	check(layout.placed_instances.get(roles[10],"") == uids[10], "undo recreates the selected UID instance")
	layout.redo()
	check(not layout.placed_instances.has(roles[10]), "redo restores the stored state")
	layout.undo()
	check(layout.placed_instances.get(roles[10],"") == uids[10], "second undo restores saved instance")
	state.save_path = "user://memoir_uid_instance_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var saved_state = State.new()
	saved_state.save_path = state.save_path
	saved_state.load_state()
	for i in range(COUNT):
		check(saved_state.life.placements.get(roles[i],"") == uids[i], "instance mapping survives JSON reload: %d" % i)
		check(saved_state.life.workstation_layout.has(roles[i]), "per-instance transform survives JSON reload: %d" % i)
	check(saved_state.life.furniture_colors.get(uids[10],0) == 8, "eleventh piece preserves individual tint")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = saved_state
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var recovered = resumed.desktop.world.layout
	for i in range(COUNT):
		check(recovered.nodes.has(roles[i]) and recovered.placed_instances.get(roles[i],"") == uids[i], "session loads unique UID-keyed scene nodes: %d" % i)
	check(recovered._layout_blocker().is_empty(), "multi-instance room remains valid after reload")
	for device_role: String in resumed.desktop.world.devices:
		check(recovered.surface_for(device_role) == "desk", "computer devices remain desk-only: "+device_role)
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_state.save_path))
	print("FURNITURE_INSTANCES_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
