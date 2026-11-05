extends SceneTree
## P24 shop → inventory → ghost placement → room focus / save.
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Stock = preload("res://scripts/items/inventory_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 5) -> void:
	for i in range(count):
		await process_frame

func find_row(browser: Control, action_name: String) -> Control:
	for row: Node in browser.get_node("%Rows").get_children():
		var action: Button = row.get_node_or_null("Row/" + action_name)
		if action != null and action.name == action_name:
			return row as Control
	return null

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var session = game.session
	session.state.persistence_enabled = false
	session.state.wallet = 2500
	var desktop = game.desktop
	var layout = desktop.world.layout
	var browser = desktop.open_app("browser")
	check(browser != null, "shared shopping browser loads")
	if browser == null:
		quit(1)
		return
	# A high-priced chair is intentionally not clickable without funds.
	# It must explain why instead of appearing as an empty, broken button.
	check(browser.get_node("%Wallet").get_parent() == browser.get_node("%ContentScroll").get_parent(), "wallet balance stays visible above the scrolling shop list")
	session.state.wallet = 100
	browser.refresh()
	check(browser.purchase_buttons.has("chair_gaming") and browser.quick_buttons.has("chair_gaming"), "gaming chair is registered for both purchase actions")
	if browser.purchase_buttons.has("chair_gaming") and browser.quick_buttons.has("chair_gaming"):
		var buy_chair: Button = browser.purchase_buttons["chair_gaming"]
		var place_chair: Button = browser.quick_buttons["chair_gaming"]
		check(buy_chair.disabled and buy_chair.text == "差 1400 点", "unaﬀordable gaming chair has an explicit shortfall instead of an empty-looking purchase button")
		check(place_chair.disabled and place_chair.text == "差 1400 点", "unaffordable buy-and-place shows the same shortfall")
		check(buy_chair.tooltip_text.contains("余额不足"), "disabled chair purchase explains why it cannot be clicked")
	check(browser.get_node("%Wallet").text.contains("100 点"), "fixed wallet label displays current funds")
	session.state.wallet = 2500
	browser.refresh()
	check(not browser.purchase_buttons["chair_gaming"].disabled and browser.purchase_buttons["chair_gaming"].text == "购买", "chair purchase becomes available automatically when wallet has enough funds")
	var origin: Dictionary = layout.snapshot()
	var orig_placements: Dictionary = session.state.life["placements"].duplicate()
	var picker: OptionButton = browser.get_node("%ShopPreviewFinish")
	var sofa: MemoirItemDefinition = Catalog.lookup("room_sofa")
	var price: int = sofa.price
	var summary: Dictionary = Stock.stock_summary(session.state.life["inventory"],session.state.life["placements"],"room_sofa")
	check(int(summary.owned) == 0 and int(summary.available) == 0, "an unpurchased sofa starts with no physical instances")
	var owned_before: int = session.state.life["inventory"].size()
	check(browser.purchase_buttons.has("room_sofa") and browser.quick_buttons.has("room_sofa"), "shop offers separate buy and buy+place for floor furniture")
	check(not browser.quick_buttons.has("mechanical_keyboard"), "computer devices never offer room-floor placement")
	var row: Control = find_row(browser,"Buy_room_sofa")
	check(row != null, "sofa shop row exists")
	if row != null:
		check(row.get_node("Row/BuyPlace_room_sofa").visible, "shop exposes the explicit combined action")
		check(row.get_node("%StockStatus").text.contains("可摆放 0"), "shop shows the same stock summary as the room editor")
		var expand: Button = row.get_node("Row/Text/PreviewToggle")
		var large: TextureRect = row.get_node("Row/Text/LargePreview")
		check(not large.visible, "larger furniture model preview starts collapsed")
		expand.pressed.emit()
		check(large.visible and str(large.get_meta("thumbnail_key","")).begins_with("room_sofa:"), "expanded furniture view reuses the 3D renderer with current finish")
		expand.pressed.emit()
		check(not large.visible, "expanded 3D preview can be collapsed without losing shop filters")
	picker.select(8)
	browser.refresh()
	check(browser.quick_buttons["room_sofa"].visible, "material preview keeps combined action available")
	browser.quick_buttons["room_sofa"].pressed.emit()
	check(layout.active and not layout.placing_role.is_empty(), "buy-and-place opens in-room ghost without inventory-tab detour")
	var first_uid: String = str(session.state.life["inventory"].back().uid)
	check(Stock.count(session.state.life["inventory"],"room_sofa") == 1, "combined action buys exactly one independent sofa")
	check(session.state.wallet == 2500 - price, "combined action charges the correct price once")
	check(str(layout.placed_instances.get(layout.placing_role,"")) == first_uid, "newly purchased UID, not another copy, is placed")
	check(layout.color_for(layout.placing_role) == 8, "previewed finish applies to the pending owned instance")
	check(session.pending_furniture_finish == -1, "finish handoff clears immediately after synchronous placement signal")
	check(not session.state.life["furniture_colors"].has(first_uid), "unsaved color preview does not mutate persistent inventory data")
	layout.cancel_placement()
	desktop.finish_layout(false)
	check(not layout.active and session.state.life["placements"] == orig_placements, "canceling room design never commits an unfinished purchased placement")
	check(Stock.stock_summary(session.state.life["inventory"],session.state.life["placements"],"room_sofa").available == 1, "canceled placement retains a legitimately purchased but unplaced sofa")
	check(not session.state.life["furniture_colors"].has(first_uid), "canceled placement leaves the new sofa finish unchanged")

	browser.set_tab("inventory")
	picker.select(5)
	browser.refresh()
	var free_row: Control = find_row(browser,"Equip_room_sofa")
	check(free_row != null and free_row.get_node("Row/Equip_room_sofa").text == "摆放", "inventory offers one-click placement for a stored sofa")
	check(free_row.get_node("%StockStatus").text.contains("可摆放 1"), "inventory displays actual available UID count")
	free_row.get_node("Row/Equip_room_sofa").pressed.emit()
	check(layout.active and not layout.placing_role.is_empty(), "inventory placement routes into existing 3D editor")
	check(str(layout.placed_instances.get(layout.placing_role,"")) == first_uid, "stored copy preserves its distinct identity")
	check(layout.color_for(layout.placing_role) == 5, "inventory's selected preview finish becomes the editable object's finish")
	layout.preview_placement(Vector2(-2.6,2.1))
	check(layout.valid, "stored sofa can be previewed at a valid location")
	check(layout.confirm_placement(), "previewed furniture can be confirmed")
	desktop.finish_layout(true)
	check(str(session.state.life["furniture_colors"].get(first_uid,"")) == "5", "saving room persists finish against the correct UID")
	check(Stock.stock_summary(session.state.life["inventory"],session.state.life["placements"],"room_sofa").placed == 1, "saved sofa moves from available to placed in unified stock ledger")
	check(not session.state.life["placements"].is_empty(), "room save persists existing and newly purchased placements")
	check(layout.snapshot().has("sofa__instance__"+first_uid), "saved extra sofa has an independent 3D scene role")

	browser.set_tab("inventory")
	browser.refresh()
	var placed_row: Control = find_row(browser,"Equip_room_sofa")
	check(placed_row != null and placed_row.get_node("Row/Equip_room_sofa").text == "查看已摆放", "inventory replaces disabled already-placed button with a navigation action")
	var saved_layout: Dictionary = layout.snapshot()
	placed_row.get_node("Row/Equip_room_sofa").pressed.emit()
	check(layout.active and layout.Data.base_role(layout.selected) == "sofa", "clicking placed sofa selects and enters room editor")
	check(desktop.world.orbit_target.x > -4 and desktop.world.orbit_target.z > 0, "inventory navigation focuses the selected 3D furniture")
	check(layout.snapshot() == saved_layout, "navigating to an owned furniture never alters transforms")
	desktop.finish_layout(false)

	browser.set_tab("shop")
	browser.refresh()
	session.state.wallet = price - 1
	var count_before: int = Stock.count(session.state.life["inventory"],"room_sofa")
	check(session.buy_and_place_furniture("room_sofa",8).begins_with("预算不足"), "insufficient points reject the combined action")
	check(Stock.count(session.state.life["inventory"],"room_sofa") == count_before and not layout.active, "failed checkout creates neither furniture nor editor mode")
	check(session.buy_and_place_furniture("mechanical_keyboard",0).contains("不能直接摆放"), "floor-only combined action rejects hardware")
	check(session.buy_and_place_furniture("room_sofa",99).contains("无效"), "invalid finish cannot silently buy or consume points")
	session.state.wallet = 2000
	browser.refresh()
	browser.quick_buttons["room_sofa"].pressed.emit()
	var newest_uid: String = str(session.state.life["inventory"].back().uid)
	check(layout.active and layout.placed_instances.get(layout.placing_role) == newest_uid and newest_uid != first_uid, "buy-and-place with an already-owned model always chooses newly purchased UID")
	layout.cancel_placement()
	desktop.finish_layout(false)
	var duplicate_inventory := [
		{"uid":"foo","item_id":"room_chair"},
		{"uid":"foo","item_id":"room_chair"},
		{"uid":"bar","item_id":"room_chair"},
		{"uid":"baz","item_id":"room_sofa"}
	]
	var duplicate_summary: Dictionary = Stock.stock_summary(duplicate_inventory,{"chair":"foo"},"room_chair")
	check(duplicate_summary == {"owned":2,"available":1,"placed":1}, "stock counter avoids duplicate legacy UIDs and ignores other product types")
	check(Stock.stock_summary(duplicate_inventory,{}, "room_plant") == {"owned":0,"available":0,"placed":0}, "stock counter returns an empty but complete result for unknown stock")
	check(layout.placed_instances.has("chair") and layout.surface_for("monitor") == "desk", "new store flow retains starter room furniture and computer-only device constraints")
	check(not layout.active, "store and room editing can be returned to cleanly")
	game.queue_free()
	await frames()
	print("SHOP_ROOM_FLOW_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
