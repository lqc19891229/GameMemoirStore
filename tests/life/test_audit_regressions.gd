extends SceneTree
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame
func run() -> void:
	var browser = load("res://scenes/apps/browser/browser.tscn").instantiate()
	root.add_child(browser)
	var preview_count: int = browser.get_node("%Rows").get_child_count()
	browser.get_node("%InventoryTab").pressed.emit()
	browser.get_node("%ShopTab").pressed.emit()
	check(browser.get_node("%Rows").get_child_count() == preview_count, "standalone browser tabs preserve authored preview without a session")
	browser.queue_free()
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	var desktop = game.desktop
	var world = desktop.world
	desktop.position = Vector3(3,0,1)
	desktop.rotation.y = 0.7
	desktop.scale = Vector3.ONE * 1.2
	desktop.set_screen_focused(true,false)
	var uv: Variant = world.screen_uv(root.get_visible_rect().size / 2.0)
	check(uv != null and uv.distance_to(Vector2(.5,.5)) < .002, "screen camera centers correctly under a transformed desktop root")
	var logical := Vector2(410,270)
	uv = world.screen_uv(desktop.canvas_point_for_screen(logical))
	check(uv != null and (uv * Vector2(1280,800)).distance_to(logical) < .02, "transformed desktop retains screen input projection")
	desktop.transform = Transform3D.IDENTITY
	desktop.set_screen_focused(false,false)
	var screen: MeshInstance3D = world.devices["monitor"].get_node("Screen")
	world.camera.global_transform = Transform3D(Basis.IDENTITY,screen.global_position - screen.global_basis.z*2).looking_at(screen.global_position)
	check(world.screen_uv(root.get_visible_rect().size / 2.0) == null, "back of monitor never accepts screen input")
	game.queue_free()
	await frames()
	# Capture commands use current enabled games, never retired sample IDs.
	for view in ["product","wishlist","cart","library"]:
		var client = load("res://scenes/apps/platform/store.tscn").instantiate()
		root.add_child(client)
		client.download_timer.stop()
		client._prepare_capture(view)
		if view == "product":
			check(not client.state.game(client.route["id"]).is_empty(), "product capture uses current catalog")
		elif view == "wishlist":
			var ids: Array = client.state.wishlist.duplicate()
			client._prepare_capture(view)
			check(not ids.is_empty() and client.state.wishlist == ids, "wishlist capture is valid and idempotent")
		elif view == "cart":
			check(not client.state.cart.is_empty() and client.state.cart.all(func(id): return not client.state.game(id).is_empty()), "cart capture uses current products")
		else:
			check(not client.state.installed.is_empty() and client.state.owned.has(client.route["id"]), "library capture installs current product")
		client.queue_free()
		await frames()
	var state = State.new()
	state.save_path = "user://memoir_audit_regression.json"
	var id: String = state.catalog[0]["id"]
	var file := FileAccess.open(state.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":3,"wallet":{},"month":[],"owned":[id],"history":[{"id":id,"price":[],"month":{}}],"activity":[{"id":id,"minutes":{},"month":[]}],"downloads":{id:1e100}}))
	file.close()
	state.load_state()
	check(state.wallet == 160 and state.month_index == 0 and state.owned.has(id), "invalid numeric save fields fall back without losing ownership")
	check(state.history.size() == 1 and state.history[0]["price"] == 0 and state.activity[0]["minutes"] == 0, "invalid history and activity numbers are cleaned")
	check(state.downloads.get(id) == 99, "oversized numeric fields clamp before integer conversion")
	file = FileAccess.open(state.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":{},"wallet":0}))
	file.close()
	state.load_state()
	check(state.wallet == 160 and state.owned.has(id), "invalid save version is rejected without mutating loaded state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	state.persistence_enabled = false
	print("AUDIT_REGRESSION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
