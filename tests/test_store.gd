extends SceneTree
## Run: godot --headless --path . --script res://tests/test_store.gd -- --fresh
const State = preload("res://scripts/store_state.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var model = State.new()
	model.persistence_enabled = false
	check(model.catalog.size() == 12, "catalog loads all twelve sample entries")
	check(model.price("distant_signal") == 66, "discounted price rounds consistently")
	check(model.price("mist_valley") == 38, "fractional discount rounds to integer")
	check(not model.is_available("midnight_castle"), "future title is locked")
	model.add_to_cart("midnight_castle")
	check(model.cart.is_empty(), "unreleased title cannot enter cart")
	model.add_to_cart("distant_signal")
	model.add_to_cart("distant_signal")
	check(model.cart.size() == 1, "duplicate cart entries are prevented")
	model.add_to_cart("iron_frontier")
	model.add_to_cart("mist_valley")
	var initial_owned: int = model.owned.size()
	var refused: Dictionary = model.checkout()
	check(not refused["ok"] and model.wallet == 160 and model.owned.size() == initial_owned and model.cart.size() == 3, "insufficient budget does not partially charge or grant ownership")
	model.remove_from_cart("iron_frontier")
	var purchased: Dictionary = model.checkout()
	check(purchased["ok"] and model.wallet == 56 and model.owned.size() == 2 and model.cart.is_empty(), "purchase charges exactly once and grants both titles")
	check(model.history.size() == 2 and int(model.history[0]["price"]) == 66, "purchase history records prices")
	model.add_to_cart("distant_signal")
	check(model.cart.is_empty(), "already-owned title cannot be purchased again")
	model.toggle_wishlist("midnight_castle")
	check(model.wishlist.has("midnight_castle"), "wishlist accepts upcoming titles")
	model.advance_month()
	check(model.wallet == 116 and model.is_available("midnight_castle"), "new month grants budget and releases the next title")
	for i: int in range(8):
		model.advance_month()
	check(model.month_index == 5 and model.date_text() == "2004 年 02 月", "demo calendar handles year rollover and caps at six months")
	var saved_wallet: int = model.wallet
	check(not model.advance_month() and model.wallet == saved_wallet, "end of demo cannot grant infinite budget")
	model.persistence_enabled = true
	model.save_path = "user://memoir_store_automated_test.json"
	check(model.save_state(), "state saves successfully")
	var restored = State.new()
	restored.save_path = model.save_path
	restored.load_state()
	check(restored.wallet == model.wallet and restored.owned == model.owned and restored.wishlist == model.wishlist and restored.history == model.history, "save/load preserves collection and budget")
	check(restored.save_state(), "existing save can be atomically replaced")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model.save_path))

	var scene: Control = load("res://scenes/legacy_store.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.filtered.size() == 6, "scene initially lists only released games")
	scene.get_node("%Card1").pressed.emit()
	check(scene.current_game_id == "iron_frontier" and scene.get_node("%DetailPanel").visible, "second card opens the matching detail panel")
	scene.get_node("%DetailAdd").pressed.emit()
	check(scene.state.cart.has("iron_frontier"), "detail purchase button adds selected game")
	scene.get_node("%DetailWish").pressed.emit()
	check(scene.state.wishlist.has("iron_frontier"), "detail wishlist button updates state")
	scene.close_modal()
	scene.get_node("%CartButton").pressed.emit()
	check(scene.modal_kind == "cart" and scene.get_node("%CartRows").get_child_count() == 1, "cart UI renders the selected product")
	scene.get_node("%CheckoutButton").pressed.emit()
	check(scene.modal_kind == "receipt" and scene.state.owned.has("iron_frontier"), "checkout displays receipt and owns correct game")
	scene.get_node("%CheckoutButton").pressed.emit()
	check(scene.current_view == "library" and scene.filtered.size() == 1, "receipt action opens the updated library")
	# An announced fixture exercises the coming-soon UI without changing shared resources.
	var announced_catalog: GameCatalog = State.GAME_CATALOG.duplicate(true)
	for definition: GameDefinition in announced_catalog.games:
		if definition.store_release_ym > 200309:
			definition.announce_ym = 200309
	scene.state = State.new(announced_catalog)
	scene.state.persistence_enabled = false
	scene.set_filter("coming")
	check(scene.filtered.size() == 6, "coming-soon filter shows future titles")
	scene.get_node("%SearchBox").text = "午夜"
	scene.get_node("%SearchBox").text_changed.emit("午夜")
	check(scene.filtered.size() == 1 and scene.filtered[0]["id"] == "midnight_castle", "Chinese search combines correctly with filters")
	scene.get_node("%Card0").pressed.emit()
	check(scene.get_node("%DetailAdd").disabled, "upcoming game detail disables purchasing")
	scene.set_view("store")
	scene.get_node("%NextMonthButton").pressed.emit()
	check(scene.filtered.size() == 9, "calendar button releases a new product")
	scene.get_node("%NextButton").pressed.emit()
	scene.get_node("%NextButton").pressed.emit()
	check(scene.current_page == 2 and scene.get_node("%Card0").visible and not scene.get_node("%Card1").visible, "pagination hides unused card slots")
	await process_frame
	scene.queue_free()
	await process_frame
	print("STORE_CHECKS: %d passed / %d checks" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
