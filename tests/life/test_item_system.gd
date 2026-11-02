extends SceneTree
const Life = preload("res://scripts/life/life_data.gd")
const Items: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Inventory = preload("res://scripts/items/inventory_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	check(Items.lookup("starter_pc") != null and Items.lookup("room_chair") != null, "catalog defines existing hardware and room furniture")
	check(Items.lookup("starter_pc").placement_surface == "desk", "desktop case is desk-only")
	check(Items.lookup("stream_mic").placement_surface == "desk", "microphone is desk-only")
	check(Items.lookup("mechanical_keyboard").placement_surface == "desk", "input devices are desk-only")
	check(Items.lookup("room_chair").placement_surface == "floor", "chairs are floor-only")
	var older: Dictionary = Life.clean({"items":["precise_mouse"],"equipped":{"peripheral":"precise_mouse"}}, [], [])
	check(older.equipped.keyboard == "precise_mouse" and older.equipped.mouse == "precise_mouse", "legacy bundled peripherals restore both device slots")
	check(Inventory.owns(older.inventory,"precise_mouse"), "legacy ownership migrates into instance inventory")
	var corrupt: Dictionary = Life.clean({"inventory":[{"uid":"bad","item_id":"missing"},{"uid":"bad","item_id":"room_chair"}],"placements":{"chair_1":"missing"}}, [], [])
	check(not Inventory.owns(corrupt.inventory,"missing") and not corrupt.placements.has("chair_1"), "invalid inventory and placement references are dropped")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	var session: MemoirGameSession = game.session
	session.timer.stop()
	session.state.wallet = 1000
	var inventory: Array = session.state.life.inventory
	check(Inventory.count(inventory,"room_chair") == 1, "starter room has one owned chair")
	check(session.buy_item("room_chair").begins_with("已购买"), "room furniture can be bought")
	check(session.buy_item("room_chair").begins_with("已购买"), "identical furniture can be bought more than once")
	check(Inventory.count(inventory,"room_chair") == 3, "furniture purchases use separate inventory instances")
	var world = game.desktop.world
	var layout = world.layout
	game.desktop.begin_layout()
	layout.select("chair")
	layout.duplicate_selected()
	check(layout.nodes.has("chair_1") and layout.placed_instances.has("chair_1"), "copy consumes an unplaced owned chair")
	var uid: String = layout.placed_instances.get("chair_1", "")
	game.desktop.finish_layout(true)
	check(session.state.life.placements.get("chair_1","") == uid, "committed furniture maps to its owned instance")
	game.desktop.begin_layout()
	layout.select("chair_1")
	layout.delete_selected()
	game.desktop.finish_layout(true)
	check(not session.state.life.placements.has("chair_1"), "removing furniture makes the instance available again")
	check(Inventory.unused_uid(inventory, session.state.life.placements, "room_chair") != "", "removed furniture remains owned")
	check(session.buy_item("mechanical_keyboard").begins_with("已购买"), "keyboard purchases use unified shop")
	check(session.buy_item("optical_mouse").begins_with("已购买"), "mouse purchases use unified shop")
	session.equip_item("mechanical_keyboard")
	session.equip_item("optical_mouse")
	check(session.state.life.equipped.keyboard == "mechanical_keyboard" and session.state.life.equipped.mouse == "optical_mouse", "keyboard and mouse have independent slots")
	await frames()
	check(world.devices.keyboard.get_node("Models/UpgradeModel").visible and world.devices.mouse.get_node("Models/UpgradeModel").visible, "independent input choices switch the authored 3D models")
	for role: String in world.devices:
		check(world.devices[role].get_parent() == world.get_node("%Equipment") and layout.surface_for(role) == "desk", "device stays on the table: " + role)
	game.desktop.begin_layout()
	layout.select("computer")
	layout.move_to(Vector2(100,100))
	for corner: Vector2 in layout.footprint("computer"):
		check(absf(corner.x) <= 2.4 and absf(corner.y) <= 1.15, "computer cannot leave the tabletop")
	game.desktop.finish_layout(false)
	session.state.persistence_enabled = false
	game.queue_free()
	await frames()
	print("ITEM_SYSTEM_CHECKS: %d / %d passed" % [checks-failures, checks])
	quit(1 if failures else 0)
