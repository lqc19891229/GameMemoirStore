class_name MemoirStoreState
extends RefCounted
## 独立的商店状态：不依赖场景节点，可在以后接入正式经营系统。

const SAVE_PATH := "user://memoir_store_v01.json"
const GAME_CATALOG: GameCatalog = preload("res://data/games/_catalog.tres")
const PRESENTATION_PATH := "res://data/catalog.json"
const START_YM := 200309
const MAX_MONTH := 5

var catalog: Array = []
var wallet: int = 160
var month_index: int = 0
var owned: Array[String] = []
var wishlist: Array[String] = []
var cart: Array[String] = []
var history: Array = []
var persistence_enabled: bool = true
var save_path: String = SAVE_PATH
var installed: Array[String] = []
var favorites: Array[String] = []
var ignored: Array[String] = []
var followed: Array[String] = []
var play_minutes: Dictionary = {}
var play_sessions: Dictionary = {}
var downloads: Dictionary = {}
var activity: Array = []
var _definitions: Dictionary = {}

func _init(source: GameCatalog = GAME_CATALOG) -> void:
	# The resource manifest owns membership, spreadsheet fields and resolved art.
	# JSON only supplements UI fields not yet managed by the spreadsheet.
	var presentation: Dictionary = {}
	var file := FileAccess.open(PRESENTATION_PATH, FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Array:
			for entry: Variant in parsed:
				if entry is Dictionary:
					presentation[str(entry.get("id", ""))] = entry
	for definition: GameDefinition in source.games:
		var game_id := str(definition.game_id)
		_definitions[game_id] = definition
		var genre := str(definition.genres[0]) if not definition.genres.is_empty() else "未分类"
		var entry: Dictionary = {
			"english": definition.title, "tags": Array(definition.genres) if not definition.genres.is_empty() else [genre],
			"discount": 0, "rating": "暂无评测", "rating_count": 0, "review_percent": 0,
			"storage_mb": 0, "edition": "标准版", "playtime": "暂无游玩记录", "reviews": [],
		}
		entry.merge(presentation.get(game_id, {}), true)
		entry.merge({
			"id": game_id, "game_id": game_id, "title": definition.title,
			"announce_ym": definition.announce_ym, "store_release_ym": definition.store_release_ym,
			"delist_ym": definition.delist_ym, "base_price": definition.base_price, "price": definition.base_price,
			"developer": definition.developer, "studio": definition.developer,
			"genres": Array(definition.genres), "genre": genre,
			"cpu": definition.cpu, "gpu": definition.gpu, "series_id": str(definition.series_id),
			"description": definition.description, "feature": definition.description.get_slice("\n", 0),
			"capsule": definition.capsule,
			"screenshots": definition.screenshots,
			"release_month": month_serial(definition.store_release_ym) - month_serial(START_YM),
			"release_label": "%d 年 %02d 月" % [definition.store_release_ym / 100, definition.store_release_ym % 100],
		}, true)
		catalog.append(entry)

static func month_serial(ym: int) -> int:
	return (ym / 100) * 12 + ym % 100 - 1

func current_ym() -> int:
	var serial := month_serial(START_YM) + month_index
	var year: int = serial / 12
	return year * 100 + serial % 12 + 1

func definition(game_id: String) -> GameDefinition:
	return _definitions.get(game_id) as GameDefinition

func release_state(game_id: String) -> StringName:
	var resource := definition(game_id)
	return resource.state_at(current_ym()) if resource != null else &"hidden"

func game(game_id: String) -> Dictionary:
	for entry: Dictionary in catalog:
		if str(entry.get("id", "")) == game_id:
			return entry
	return {}

func price(game_id: String) -> int:
	var entry := game(game_id)
	if entry.is_empty():
		return 0
	return roundi(float(entry["price"]) * (100.0 - float(entry.get("discount", 0))) / 100.0)

func is_available(game_id: String) -> bool:
	return release_state(game_id) == &"available"

func add_to_cart(game_id: String) -> String:
	if game(game_id).is_empty():
		return "未找到这款游戏。"
	if owned.has(game_id):
		return "这款游戏已经在你的游戏库中。"
	if not is_available(game_id):
		return "这款游戏已下架。" if release_state(game_id) == &"delisted" else "尚未上架，可以先加入愿望单。"
	if cart.has(game_id):
		return "这款游戏已经在购物车中。"
	cart.append(game_id)
	save_state()
	return "已加入购物车。"

func remove_from_cart(game_id: String) -> void:
	cart.erase(game_id)
	save_state()

func toggle_wishlist(game_id: String) -> bool:
	if game(game_id).is_empty():
		return false
	if wishlist.has(game_id):
		wishlist.erase(game_id)
	else:
		wishlist.append(game_id)
	save_state()
	return wishlist.has(game_id)

func cart_total() -> int:
	var total: int = 0
	for game_id: String in cart:
		if not owned.has(game_id) and is_available(game_id):
			total += price(game_id)
	return total

func checkout() -> Dictionary:
	if cart.is_empty():
		return {"ok": false, "message": "购物车还是空的，去挑一段新的回忆吧。"}
	for game_id: String in cart:
		if owned.has(game_id) or not is_available(game_id) or game(game_id).is_empty():
			return {"ok": false, "message": "商品状态发生变化，请重新选择。"}
	var total := cart_total()
	if total > wallet:
		return {"ok": false, "message": "预算不足，还差 %d 点。可以移除部分游戏，或等待下个月。" % (total - wallet)}
	var purchased: Array[String] = cart.duplicate()
	wallet -= total
	for game_id: String in purchased:
		owned.append(game_id)
		wishlist.erase(game_id)
		history.append({"id": game_id, "price": price(game_id), "month": month_index})
	cart.clear()
	save_state()
	return {"ok": true, "message": "%d 款游戏已加入你的收藏。" % purchased.size(), "purchased": purchased, "total": total}

func advance_month() -> bool:
	if month_index >= MAX_MONTH:
		return false
	month_index += 1
	wallet += 60
	save_state()
	return true

func date_text() -> String:
	var month_number := 8 + month_index
	return "%d 年 %02d 月" % [2003 + month_number / 12, month_number % 12 + 1]

func save_state() -> bool:
	if not persistence_enabled:
		return true
	var payload := {"version": 2, "wallet": wallet, "month": month_index, "owned": owned, "wishlist": wishlist, "cart": cart, "history": history, "installed": installed, "favorites": favorites, "ignored": ignored, "followed": followed, "play_minutes": play_minutes, "play_sessions": play_sessions, "downloads": downloads, "activity": activity}
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_warning("无法保存商店状态：%s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if result != OK:
		push_warning("无法提交商店存档：%s" % result)
	return result == OK

func load_state() -> void:
	if not persistence_enabled or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not int(data.get("version", 0)) in [1, 2]:
		return
	wallet = maxi(0, int(data.get("wallet", 160)))
	month_index = clampi(int(data.get("month", 0)), 0, MAX_MONTH)
	owned = _validated_ids(data.get("owned", []), false)
	wishlist = _validated_ids(data.get("wishlist", []), false)
	cart = _validated_ids(data.get("cart", []), true)
	var saved_history: Variant = data.get("history", [])
	history.clear()
	if saved_history is Array:
		var recorded_ids: Array[String] = []
		for record: Variant in saved_history:
			if not record is Dictionary:
				continue
			var game_id := str(record.get("id", ""))
			if not owned.has(game_id) or recorded_ids.has(game_id):
				continue
			recorded_ids.append(game_id)
			history.append({"id": game_id, "price": maxi(0, int(record.get("price", 0))), "month": clampi(int(record.get("month", 0)), 0, month_index)})
	installed = _owned_ids(data.get("installed", []))
	favorites = _owned_ids(data.get("favorites", []))
	ignored = _validated_ids(data.get("ignored", []), false)
	followed = _validated_ids(data.get("followed", []), false)
	play_minutes = _owned_numbers(data.get("play_minutes", {}))
	play_sessions = _owned_numbers(data.get("play_sessions", {}))
	downloads = _owned_numbers(data.get("downloads", {}), 99)
	for game_id: String in installed:
		downloads.erase(game_id)
	activity.clear()
	var saved_activity: Variant = data.get("activity", [])
	if saved_activity is Array:
		for entry: Variant in saved_activity:
			if entry is Dictionary and owned.has(str(entry.get("id", ""))):
				activity.append({"id": str(entry["id"]), "month": clampi(int(entry.get("month", 0)), 0, month_index), "minutes": maxi(0, int(entry.get("minutes", 0)))})

func _validated_ids(value: Variant, cart_only: bool) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value:
		var game_id := str(item)
		if game(game_id).is_empty() or result.has(game_id):
			continue
		if cart_only and (owned.has(game_id) or not is_available(game_id)):
			continue
		result.append(game_id)
	return result

func _owned_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for game_id: String in _validated_ids(value, false):
		if owned.has(game_id):
			result.append(game_id)
	return result

func _owned_numbers(value: Variant, maximum: int = 999999) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			var game_id := str(key)
			if owned.has(game_id) and (value[key] is float or value[key] is int):
				result[game_id] = clampi(int(value[key]), 0, maximum)
	return result

func toggle_list(game_id: String, list_name: String) -> bool:
	if game(game_id).is_empty():
		return false
	var target: Array[String]
	match list_name:
		"favorites":
			if not owned.has(game_id):
				return false
			target = favorites
		"ignored": target = ignored
		"followed": target = followed
		_: return false
	if target.has(game_id):
		target.erase(game_id)
	else:
		target.append(game_id)
	save_state()
	return target.has(game_id)

func prioritize_wish(game_id: String) -> void:
	if wishlist.has(game_id):
		wishlist.erase(game_id)
		wishlist.push_front(game_id)
		save_state()

func start_install(game_id: String) -> String:
	if not owned.has(game_id):
		return "购买后即可安装。"
	if installed.has(game_id):
		return "游戏已安装。"
	if downloads.has(game_id):
		return "已经在下载队列中。"
	downloads[game_id] = 0
	save_state()
	return "已加入下载队列。"

func tick_downloads(amount: int = 10) -> Array[String]:
	var completed: Array[String] = []
	# 与客户端的下载队列一致：每次只推进队首任务。
	var active: Array = downloads.keys().slice(0, 1)
	for game_id: String in active:
		downloads[game_id] = int(downloads[game_id]) + amount
		if int(downloads[game_id]) >= 100:
			if not installed.has(game_id):
				installed.append(game_id)
			completed.append(game_id)
	for game_id: String in completed:
		downloads.erase(game_id)
	if not completed.is_empty():
		save_state()
	return completed

func uninstall(game_id: String) -> void:
	installed.erase(game_id)
	downloads.erase(game_id)
	save_state()

func record_play(game_id: String) -> bool:
	if not owned.has(game_id) or not installed.has(game_id):
		return false
	play_minutes[game_id] = int(play_minutes.get(game_id, 0)) + 45
	play_sessions[game_id] = int(play_sessions.get(game_id, 0)) + 1
	activity.push_front({"id": game_id, "month": month_index, "minutes": 45})
	if activity.size() > 40:
		activity.resize(40)
	save_state()
	return true
