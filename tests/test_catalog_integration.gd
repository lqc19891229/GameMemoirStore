extends SceneTree
const FIXTURE_CATALOG = preload("res://tests/fixtures/catalog/_catalog.tres")
const State = preload("res://scripts/store_state.gd")
const UI = preload("res://scripts/client_ui.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest := GameCatalog.new()
	var definition: GameDefinition = FIXTURE_CATALOG.find_game(&"distant_signal").duplicate(true)
	definition.title = "资源覆盖的名称"
	definition.developer = "资源开发商"
	definition.description = "来自资源的新介绍"
	definition.base_price = 200
	definition.genres = PackedStringArray(["新类型", "生活模拟"])
	definition.announce_ym = 200309
	definition.store_release_ym = 200310
	definition.delist_ym = 200311
	definition.cpu = "测试CPU"
	definition.gpu = "测试GPU"
	definition.capsule = load("res://assets/art/desert.png")
	manifest.games.append(definition)
	var fresh := GameDefinition.new()
	fresh.game_id = &"new_sheet_game"
	fresh.title = "表格新增游戏"
	fresh.developer = "新开发商"
	fresh.base_price = 20
	fresh.store_release_ym = 200309
	fresh.delist_ym = 200310
	manifest.games.append(fresh)
	var model := State.new(manifest)
	model.persistence_enabled = false
	check(model.catalog.size() == 2 and model.game("iron_frontier").is_empty(), "manifest owns membership; JSON cannot restore removed games")
	var entry: Dictionary = model.game("distant_signal")
	check(entry["title"] == definition.title and entry["studio"] == definition.developer, "resource title and developer override legacy values")
	check(entry["description"] == definition.description and entry["feature"] == definition.description, "resource description feeds detail and card")
	check(entry["price"] == 200 and model.price("distant_signal") == 150, "resource base price combines with existing supplemental discount")
	check(entry["release_label"] == "2003 年 10 月" and entry["release_month"] == 1, "absolute month maps into client timeline")
	check(entry["cpu"] == "测试CPU" and entry["gpu"] == "测试GPU", "hardware values reach client data")
	check(UI.texture(entry) == definition.capsule, "UI reads resource capsule instead of legacy art key")
	check(UI.texture(model.game("new_sheet_game")) == null, "blank capsule remains blank")
	check(model.game("new_sheet_game")["rating_count"] == 0 and model.game("new_sheet_game")["reviews"].is_empty(), "new spreadsheet-only game receives safe presentation defaults")
	check(model.current_ym() == 200309 and model.release_state("distant_signal") == &"coming_soon", "announced title is visible before release")
	model.add_to_cart("distant_signal")
	check(model.cart.is_empty(), "announced game cannot be purchased early")
	var client = load("res://scenes/store.tscn").instantiate()
	root.add_child(client)
	await process_frame
	client.download_timer.stop()
	# Exercise the real workbook's cover + four independent screenshots end-to-end.
	var actual: GameDefinition = State.GAME_CATALOG.find_game(&"CounterSquad")
	var actual_entry: Dictionary = client.state.game("CounterSquad")
	check(UI.texture(actual_entry) == actual.capsule, "store cards use cover, not screenshot 01")
	for i in range(4):
		check(UI.screenshot(actual_entry, i) == actual.screenshots[i], "gallery preserves numbered screenshot order")
	client.open_product("CounterSquad")
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var picture: TextureRect = client.find_child("ProductScreenshot", true, false)
	check(picture.texture == actual.screenshots[0], "product opens with screenshot 01 instead of cover")
	check(picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "product displays full screenshot without cropping")
	check(picture.size.y <= picture.get_parent().size.y + 1, "gallery reserves enough height without overlapping surrounding controls")
	check(absf(picture.size.x / picture.size.y - 16.0 / 9.0) < 0.01, "main screenshot keeps 16:9 at current window width")
	for i in range(4):
		client.find_child("ProductThumbnail%d" % (i + 1), true, false).pressed.emit()
		check(picture.texture == actual.screenshots[i], "thumbnail switches to its independent screenshot")
	client.state = model
	check(client.search_games({"filter": "coming"}).size() == 1, "coming-soon filter follows resource announcement")
	client.open_product("new_sheet_game")
	check(client.find_child("ProductAdd", true, false) != null, "new resource-only game renders a purchasable product page")
	check(client.find_child("ProductRequirements", true, false).text.contains("未提供"), "missing hardware values display as unspecified")
	model.advance_month()
	check(model.current_ym() == 200310 and model.is_available("distant_signal"), "release month is inclusive")
	check(client.search_games({"genre": "生活模拟"}).size() == 1, "genre filter supports secondary resource genre")
	check(client.search_games({"query": "生活模拟"}).size() == 1, "text search includes every resource genre")
	client.open_product("distant_signal")
	check(client.find_child("ProductRequirements", true, false).text.contains("测试CPU") and client.find_child("ProductRequirements", true, false).text.contains("测试GPU"), "product requirements display resource CPU and GPU")
	check(model.release_state("new_sheet_game") == &"delisted" and not model.is_available("new_sheet_game"), "delist month is inclusive")
	model.add_to_cart("new_sheet_game")
	check(model.cart.is_empty(), "delisted resource cannot be added to cart")
	model.add_to_cart("distant_signal")
	var result: Dictionary = model.checkout()
	check(result["ok"] and model.history[0]["price"] == 150, "checkout records actual price from resource-backed catalog")
	model.advance_month()
	check(model.release_state("distant_signal") == &"delisted" and model.owned.has("distant_signal"), "delisting retains previously purchased game")
	model.start_install("distant_signal")
	model.tick_downloads(100)
	check(model.installed.has("distant_signal"), "owned delisted game remains installable")
	client.open_product("distant_signal")
	check(client.find_child("ProductAdd", true, false).disabled, "owned delisted product never offers another purchase")
	model.month_index = 4
	check(model.current_ym() == 200401, "relative save calendar rolls into next year")
	check(FIXTURE_CATALOG.find_game(&"distant_signal").base_price == 88, "test fixtures never mutate shared catalog")
	client.queue_free()
	await process_frame
	print("CATALOG_INTEGRATION_CHECKS: %d passed / %d checks" % [checks - failures, checks])
	quit(1 if failures else 0)
