extends SceneTree
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
	var definition: GameDefinition = State.GAME_CATALOG.find_game(&"distant_signal").duplicate(true)
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
	check(client.find_child("ProductAdd", true, false) == null, "owned delisted product never offers another purchase")
	model.month_index = 4
	check(model.current_ym() == 200401, "relative save calendar rolls into next year")
	check(State.GAME_CATALOG.find_game(&"distant_signal").base_price == 88, "test fixtures never mutate shared catalog")
	client.queue_free()
	await process_frame
	print("CATALOG_INTEGRATION_CHECKS: %d passed / %d checks" % [checks - failures, checks])
	quit(1 if failures else 0)
