extends SceneTree
const State = preload("res://scripts/store_state.gd")
const Inventory = preload("res://scripts/items/inventory_data.gd")
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
	for i in range(5): await process_frame
	await physics_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 1000
	var desktop = game.desktop
	var layout = desktop.world.layout
	var catalog_button: Button = desktop.get_node("HUD/Interface/LayoutPanel/Margin/Scroll/Content/FurnitureInventory/Place_chair")
	check(catalog_button != null, "room editor exposes a direct furniture inventory")
	check(game.session.buy_item("room_chair").begins_with("已购买"), "multiple copies may be purchased")
	desktop.begin_layout()
	check(catalog_button.text.contains("1/2"), "room catalog displays unplaced item count")
	layout.select("chair")
	layout.store_selected()
	check(not layout.nodes.chair.visible and not layout.placed_instances.has("chair"), "original furniture can be returned to inventory")
	check(layout.nodes.chair.get_node("PickArea").collision_layer == 0, "stored furniture cannot intercept room picking rays")
	check(not layout._layout_blocker().contains("椅子"), "stored furniture does not block the floor")
	check(catalog_button.text.contains("2/2"), "storing original furniture releases its instance")
	var uid := "starter_chair"
	check(layout.start_place("room_chair", uid), "an owned furniture instance can start free placement")
	check(layout.placing_role == "chair" and layout.nodes.chair.visible, "stored original reuses its scene role as a ghost")
	check(layout.nodes.chair.find_children("*", "MeshInstance3D", true, false)[0].transparency > 0.0, "placement preview is translucent")
	layout.preview_placement(Vector2(100.0, 100.0))
	check(not layout.valid and not layout.confirm_placement(), "out-of-room preview is red and cannot be committed")
	var authored: Transform3D = layout.authored.chair
	layout.preview_placement(Vector2(authored.origin.x, authored.origin.z))
	check(layout.valid, "valid floor location is accepted")
	check(layout.confirm_placement() and layout.placing_role.is_empty(), "confirmation finalizes the furniture instance")
	check(layout.nodes.chair.get_node("PickArea").collision_layer == 1, "placed furniture becomes pickable again")
	layout.set_furniture_color(2)
	check(layout.color_for("chair") == 2 and layout.nodes.chair.find_children("*", "MeshInstance3D", true, false)[0].material_overlay != null, "per-instance furniture tint is applied to model")
	layout.select("chair")
	layout.store_selected()
	check(layout.furniture_colors.get(uid) == 2, "furniture keeps its color while stored")
	check(layout.start_place("room_chair", uid), "stored furniture can be placed again")
	layout.preview_placement(Vector2(authored.origin.x, authored.origin.z))
	check(layout.confirm_placement() and layout.color_for("chair") == 2, "restoring furniture preserves the saved tint")
	desktop.finish_layout(true)
	check(state.life.furniture_colors.get(uid) == 2 and state.life.placements.chair == uid, "applied room layout stores furniture UID and color")
	# Canceling a new preview must not consume inventory.
	desktop.begin_layout()
	var second_uid: String = Inventory.unused_uid(state.life.inventory, layout.placed_instances, "room_chair")
	check(not second_uid.is_empty() and layout.start_place("room_chair", second_uid), "a second owned chair can be previewed")
	check(layout.placing_role == "chair_1", "additional furniture receives a distinct room role")
	layout.cancel_placement()
	check(layout.placing_role.is_empty() and not layout.nodes.has("chair_1") and not layout.placed_instances.values().has(second_uid), "preview cancellation fully restores room and inventory")
	desktop.finish_layout(false)
	# Storing an authored piece must survive a save/load round trip.
	desktop.begin_layout()
	layout.select("chair")
	layout.store_selected()
	state.save_path = "user://memoir_room_free_place_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var restored = State.new()
	restored.save_path = state.save_path
	restored.load_state()
	check(not state.life.placements.has("chair"), "live room store removes the original placement")
	check(not restored.life.placements.has("chair"), "stored original stays absent after save reload: %s" % [str(restored.life.placements)])
	check(restored.life.furniture_colors.get(uid) == 2, "furniture tint survives reload: %s" % [str(restored.life.furniture_colors)])
	check(layout.nodes.chair.find_children("*", "MeshInstance3D", true, false)[0].material_override == null, "preview overrides are restored on confirmation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	state.persistence_enabled = false
	# Built-in computers and all input peripherals remain restricted to the desk.
	for role: String in desktop.world.devices:
		check(layout.surface_for(role) == "desk" and desktop.world.devices[role].get_parent() == desktop.world.get_node("%Equipment"), "hardware is still desk-only: " + role)
	game.queue_free()
	await frames()
	print("ROOM_PLACEMENT_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
