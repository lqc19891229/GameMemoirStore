extends Control
## 客户端外壳：跨页面历史、持久数据、原生菜单、模拟安装与游玩。
const State = preload("res://scripts/store_state.gd")
const U = preload("res://scripts/client_ui.gd")
const Pages = preload("res://scripts/client_pages.gd")
signal host_requested(action: String)
var session: MemoirGameSession
var shared_refresh_pending := false

var state = State.new()
var pages
var route: Dictionary = {"kind": "home"}
var navigation: Array = [{"kind": "home"}]
var navigation_index: int = 0
var navigation_scrolls: Array[int] = [0]
var featured_index: int = 0
var recent_views: Array[String] = []
var queue_ids: Array[String] = []
var last_receipt: Dictionary = {}
var download_widgets: Array = []
var back_button: Button
var forward_button: Button
var store_button: Button
var library_button: Button
var community_button: Button
var profile_button: Button
var wish_button: Button
var cart_button: Button
var wallet_button: Button
var month_button: Button
var downloads_button: Button
var search_box: LineEdit
var popup: AcceptDialog
var notice_timer: Timer
var download_timer: Timer
var running_game_id: String = ""
var running_window: AcceptDialog
var render_serial: int = 0

func _ready() -> void:
	if session == null:
		state.persistence_enabled = not OS.get_cmdline_user_args().has("--fresh")
		state.load_state()
	else:
		state = session.state
		session.changed.connect(_shared_refresh)
		session.tick_updated.connect(_shared_tick)
	pages = Pages.new(self)
	_build_header()
	_build_store_navigation()
	_build_status()
	notice_timer = %NoticeTimer
	notice_timer.timeout.connect(func() -> void: %Notification.hide())
	download_timer = %DownloadTimer
	download_timer.timeout.connect(_download_tick)
	if session == null: download_timer.start()
	refresh_client()
	if session == null: _capture.call_deferred()

func _exit_tree() -> void:
	# 关闭原生窗口、退出客户端或切换场景时，也保存当前下载与收藏。
	state.save_state()

func _build_header() -> void:
	wallet_button = %WalletButton
	back_button = %Back
	forward_button = %Forward
	store_button = %Store
	library_button = %Library
	community_button = %Community
	profile_button = %Profile
	pages.menu(%AccountMenu, ["账户明细", "设置", "退出"], func(index: int) -> void:
		match index:
			0: account_details()
			1: settings()
			2: close_client()
	)
	pages.menu(%ViewMenu, ["商店", "游戏库", "愿望单", "下载"], func(index: int) -> void: navigate({"kind": ["home", "library", "wishlist", "downloads"][index]}))
	pages.menu(%FriendsMenu, ["好友列表", "我的个人资料"], func(index: int) -> void:
		if index == 0: friends()
		else: navigate({"kind": "profile"})
	)
	pages.menu(%GamesMenu, ["浏览所有游戏", "查看已安装游戏"], func(index: int) -> void: navigate({"kind": "search"} if index == 0 else {"kind": "library", "collection": 1}))
	pages.menu(%HelpMenu, ["如何开始收藏", "关于游戏回忆录"], func(index: int) -> void:
		if index == 0: dialog("开始您的游戏时光", "在商店发现游戏并加入购物车。\n使用游戏内预算结算后，作品会保留在您的库中。\n在库中安装游戏，即可开始一次游玩。\n\nAlt+左/右：前进后退\nCtrl+F：搜索\nF11：全屏\nEsc：返回上一页")
		else: dialog("游戏回忆录", "像素风格 · 游戏收藏经营模拟\n\n每一款游戏，都是一段回忆。\n当前目录与玩家资料属于游戏世界。\n字体：Ark Pixel / SIL OFL 1.1")
	)
	pages.bind(wallet_button, account_details)
	%MinimizeClient.visible = session == null
	%MaximizeClient.visible = session == null
	%CloseClient.visible = session == null
	pages.bind(%MinimizeClient, minimize_client)
	pages.bind(%MaximizeClient, toggle_fullscreen)
	pages.bind(%CloseClient, close_client)
	pages.bind(back_button, func() -> void: go_history(-1))
	pages.bind(forward_button, func() -> void: go_history(1))
	pages.bind(store_button, func() -> void: navigate({"kind": "home"}))
	pages.bind(library_button, func() -> void: navigate({"kind": "library"}))
	pages.bind(community_button, func() -> void: navigate({"kind": "community"}))
	pages.bind(profile_button, func() -> void: navigate({"kind": "profile"}))

func _build_store_navigation() -> void:
	pages.menu(%StoreMenu, ["商店主页", "发现队列", "最近浏览", "愿望单"], func(index: int) -> void:
		match index:
			0: navigate({"kind": "home"})
			1: start_discovery()
			2: navigate({"kind": "search", "filter": "recent"})
			3: navigate({"kind": "wishlist"})
	)
	pages.menu(%NewMenu, ["新品", "热销商品", "即将推出", "特别优惠"], func(index: int) -> void: navigate({"kind": "search", "filter": ["new", "popular", "coming", "sale"][index]}))
	var genres: Array[String] = genre_options()
	pages.menu(%GenreMenu, genres + ["所有游戏"], func(index: int) -> void:
		if index == genres.size(): navigate({"kind": "search"})
		else: navigate({"kind": "search", "genre": genres[index]})
	)
	wish_button = %Wish
	cart_button = %Cart
	search_box = %Search
	pages.bind(wish_button, func() -> void: navigate({"kind": "wishlist"}))
	pages.bind(cart_button, func() -> void: navigate({"kind": "cart"}))
	search_box.text_submitted.connect(func(value: String) -> void:
		navigate({"kind": "wishlist", "query": value} if route["kind"] == "wishlist" else {"kind": "search", "query": value})
	)

func _build_status() -> void:
	downloads_button = %Downloads
	month_button = %Month
	pages.bind(%AddGame, func() -> void: navigate({"kind": "search"}))
	pages.bind(downloads_button, func() -> void: navigate({"kind": "downloads"}))
	pages.bind(month_button, advance_month)
	pages.bind(%Friends, friends)

func navigate(destination: Dictionary, push: bool = true) -> void:
	navigation_scrolls[navigation_index] = %ContentScroll.scroll_vertical
	if push and route != destination:
		navigation.resize(navigation_index + 1)
		navigation_scrolls.resize(navigation_index + 1)
		navigation.append(destination.duplicate(true))
		navigation_scrolls.append(0)
		navigation_index = navigation.size() - 1
	elif not push:
		navigation[navigation_index] = destination.duplicate(true)
		if destination.get("kind", "") != route.get("kind", "") or (destination.get("kind", "") == "queue" and destination.get("index", 0) != route.get("index", 0)):
			navigation_scrolls[navigation_index] = 0
	route = destination.duplicate(true)
	refresh_client()

func go_history(direction: int) -> void:
	var index := clampi(navigation_index + direction, 0, navigation.size() - 1)
	if index == navigation_index:
		return
	navigation_scrolls[navigation_index] = %ContentScroll.scroll_vertical
	navigation_index = index
	route = navigation[index].duplicate(true)
	refresh_client()

func refresh_client(keep_scroll: bool = false) -> void:
	wallet_button.text = "钱包 %d 点  v" % state.wallet
	wish_button.text = "愿望单（%d）" % state.wishlist.size()
	cart_button.text = "购物车（%d）" % state.cart.size()
	month_button.text = state.date_text() + ("  > 下个月" if state.month_index < State.MAX_MONTH else "  · 演示结束")
	month_button.disabled = state.month_index >= State.MAX_MONTH
	back_button.disabled = navigation_index == 0
	forward_button.disabled = navigation_index >= navigation.size() - 1
	_update_status()
	var kind: String = str(route["kind"])
	%StoreNavigation.visible = not kind in ["library", "downloads", "profile", "community"]
	%ContentScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if kind == "library" else ScrollContainer.SCROLL_MODE_AUTO
	var active: Button = library_button if kind in ["library", "downloads"] else (community_button if kind == "community" else (profile_button if kind == "profile" else store_button))
	for button: Button in [store_button, library_button, community_button, profile_button]:
		button.add_theme_color_override("font_color", U.BLUE if button == active else U.TEXT)
	search_box.text = str(route.get("query", ""))
	render_page(keep_scroll)

func render_page(keep_scroll: bool = false) -> void:
	render_serial += 1
	var old_scroll: int = %ContentScroll.scroll_vertical
	var old_library: ScrollContainer = find_child("LibraryContentScroll", true, false) as ScrollContainer
	var library_scroll: int = old_library.scroll_vertical if is_instance_valid(old_library) and keep_scroll else -1
	download_widgets.clear()
	match str(route["kind"]):
		"home": pages.home()
		"search": pages.search()
		"product": pages.product()
		"queue": pages.product(true)
		"wishlist": pages.wishlist()
		"cart": pages.cart()
		"checkout": pages.cart(true)
		"receipt": pages.receipt()
		"library": pages.library()
		"downloads": pages.downloads_page()
		"profile": pages.profile()
		"community": pages.community()
		_: pages.home()
	_restore_scroll.call_deferred(old_scroll if keep_scroll else navigation_scrolls[navigation_index], render_serial, library_scroll)

func _restore_scroll(target: int, serial: int, library_target: int = -1) -> void:
	# 等待新容器完成布局；提前赋值会被尚未更新的滚动范围归零。
	await get_tree().process_frame
	await get_tree().process_frame
	if serial != render_serial:
		return
	%ContentScroll.scroll_vertical = target
	if library_target >= 0:
		var library_scroll: ScrollContainer = find_child("LibraryContentScroll", true, false) as ScrollContainer
		if is_instance_valid(library_scroll):
			library_scroll.scroll_vertical = library_target

func available_games(for_feature: bool = false) -> Array:
	var result: Array = []
	for entry: Dictionary in state.catalog:
		if not state.is_available(entry["id"]):
			continue
		if for_feature and state.ignored.has(entry["id"]):
			continue
		result.append(entry)
	return result

func matches_query(entry: Dictionary, query: String) -> bool:
	var text := (str(entry["title"]) + " " + str(entry["english"]) + " " + str(entry["studio"]) + " " + " ".join(entry["genres"]) + " " + " ".join(entry["tags"])).to_lower()
	return query.strip_edges().is_empty() or text.contains(query.strip_edges().to_lower())

func search_games(options: Dictionary) -> Array:
	var result: Array = []
	var filter_name: String = str(options.get("filter", "all"))
	for entry: Dictionary in state.catalog:
		var game_id: String = entry["id"]
		if filter_name == "coming":
			if state.release_state(game_id) != &"coming_soon": continue
		elif not state.is_available(game_id):
			continue
		if filter_name == "sale" and int(entry["discount"]) <= 0: continue
		if filter_name == "recent" and not recent_views.has(game_id): continue
		if bool(options.get("hide_owned", false)) and state.owned.has(game_id): continue
		if not str(options.get("genre", "")).is_empty() and not entry["genres"].has(options["genre"]): continue
		if not matches_query(entry, str(options.get("query", ""))): continue
		result.append(entry)
	var sort_mode: int = int(options.get("sort", 0))
	match sort_mode:
		1: result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return state.price(a["id"]) < state.price(b["id"]))
		2: result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return state.price(a["id"]) > state.price(b["id"]))
		3: result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["discount"]) > int(b["discount"]))
		4: result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["title"]) < str(b["title"]))
		_:
			if filter_name == "popular":
				result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rating_count"]) > int(b["rating_count"]))
			elif filter_name == "new":
				result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["release_month"]) > int(b["release_month"]))
	return result

func price_text(entry: Dictionary) -> String:
	var game_id: String = entry["id"]
	if state.owned.has(game_id): return "已在库中"
	if state.release_state(game_id) == &"delisted": return "已下架"
	if not state.is_available(game_id): return "即将推出"
	return "-%d%%  %d 点" % [entry["discount"], state.price(game_id)] if int(entry["discount"]) > 0 else "%d 点" % state.price(game_id)

func open_product(game_id: String) -> void:
	navigate({"kind": "product", "id": game_id})

func remember_view(game_id: String) -> void:
	recent_views.erase(game_id)
	recent_views.push_front(game_id)
	if recent_views.size() > 16: recent_views.resize(16)

func cycle_feature(amount: int) -> void:
	featured_index += amount
	render_page(true)

func toggle_wish(game_id: String) -> void:
	var added: bool = state.toggle_wishlist(game_id)
	refresh_client(true)
	notify("已添加至愿望单" if added else "已从愿望单移除")

func toggle_flag(game_id: String, list_name: String) -> void:
	var active: bool = state.toggle_list(game_id, list_name)
	refresh_client(true)
	notify(("已" if active else "已取消") + {"followed": "关注", "ignored": "忽略", "favorites": "收藏夹标记"}[list_name])

func add_cart(game_id: String) -> void:
	if state.cart.has(game_id):
		navigate({"kind": "cart"})
		return
	var message: String = state.add_to_cart(game_id)
	refresh_client(true)
	notify(message + " 可在右上方购物车结算。")

func confirm_purchase() -> void:
	last_receipt = state.checkout()
	if bool(last_receipt.get("ok", false)):
		navigate({"kind": "receipt"})
	else:
		notify(str(last_receipt["message"]))
		refresh_client()

func start_discovery() -> void:
	queue_ids.clear()
	for entry: Dictionary in available_games():
		var game_id: String = entry["id"]
		if not state.owned.has(game_id) and not state.ignored.has(game_id):
			queue_ids.append(game_id)
		if queue_ids.size() >= 5: break
	navigate({"kind": "queue", "index": 0})

func next_queue() -> void:
	var index: int = int(route.get("index", 0)) + 1
	while index < queue_ids.size() and (state.owned.has(queue_ids[index]) or state.ignored.has(queue_ids[index])):
		index += 1
	navigate({"kind": "queue", "index": index}, false)

func install_game(game_id: String) -> void:
	var message: String = state.start_install(game_id)
	refresh_client()
	notify(message)

func _download_tick() -> void:
	if state.downloads.is_empty(): return
	var completed: Array[String] = state.tick_downloads(8)
	for widget: Dictionary in download_widgets:
		if is_instance_valid(widget["bar"]):
			widget["bar"].value = float(state.downloads.get(widget["id"], 100))
	_update_status()
	if not completed.is_empty():
		refresh_client(true)
		notify("安装完成：%s" % state.game(completed[0])["title"])

func _update_status() -> void:
	if not is_instance_valid(downloads_button): return
	if state.downloads.is_empty():
		downloads_button.text = "下载 · 没有进行中的任务"
	else:
		var game_id: String = state.downloads.keys()[0]
		downloads_button.text = "下载 · %s  %d%%" % [state.game(game_id)["title"], state.downloads[game_id]]

func launch_game(game_id: String) -> void:
	if session != null:
		notify(session.start_play(game_id))
		return
	if not state.installed.has(game_id) or not state.owned.has(game_id): return
	running_game_id = game_id
	running_window = preload("res://scenes/client/running_dialog.tscn").instantiate()
	running_window.title = state.game(game_id)["title"]
	add_child(running_window)
	running_window.get_node("%Cover").texture = U.texture(state.game(game_id))
	running_window.get_node("%Title").text = state.game(game_id)["title"]
	running_window.confirmed.connect(finish_session)
	running_window.canceled.connect(func() -> void:
		finish_session()
	)
	running_window.popup_centered(Vector2i(640, 420))

func finish_session() -> void:
	if running_game_id.is_empty(): return
	var game_id: String = running_game_id
	running_game_id = ""
	state.record_play(game_id)
	if is_instance_valid(running_window):
		running_window.queue_free()
	refresh_client()
	notify("已记录本次游玩：%s · 45 分钟" % state.game(game_id)["title"])

func advance_month() -> void:
	if state.advance_month():
		refresh_client()
		notify("来到 %s · 钱包增加 60 点" % state.date_text())

func dialog(title: String, text: String) -> void:
	if is_instance_valid(popup): popup.queue_free()
	popup = preload("res://scenes/client/message_dialog.tscn").instantiate()
	popup.title = title
	popup.dialog_text = text
	add_child(popup)
	popup.popup_centered()

func account_details() -> void:
	var spent: int = 0
	for entry: Dictionary in state.history: spent += int(entry["price"])
	dialog("像素收藏家 · 账户明细", "当前年代：%s\n\n钱包余额：%d 点\n收藏游戏：%d 款\n已安装：%d 款\n累计购买支出：%d 点\n\n每月结余增加 60 点，可在底栏进入下个月。" % [state.date_text(), state.wallet, state.owned.size(), state.installed.size(), spent])

func friends() -> void:
	dialog("好友与聊天", "游戏世界内的好友\n\n● 山间旅人  ·  正在游玩 雾谷手记\n● 旧日玩家  ·  在线\n○ 纸飞机  ·  离线\n\n这些人物属于回忆录中的玩家故事。")

func settings() -> void:
	if is_instance_valid(popup): popup.queue_free()
	popup = preload("res://scenes/client/settings_dialog.tscn").instantiate()
	add_child(popup)
	pages.bind(popup.get_node("%ToggleFullscreen"), toggle_fullscreen)
	pages.bind(popup.get_node("%Reset"), func() -> void:
		var confirm = preload("res://scenes/client/reset_dialog.tscn").instantiate()
		add_child(confirm)
		confirm.confirmed.connect(func() -> void:
			if session != null:
				session.reset_run()
			else:
				var persistent: bool = state.persistence_enabled
				state = State.new()
				state.persistence_enabled = persistent
				state.save_state()
				popup.hide()
				navigation = [{"kind": "home"}]
				navigation_scrolls = [0]
				navigation_index = 0
				navigate({"kind": "home"}, false)
			confirm.queue_free()
		)
		confirm.canceled.connect(confirm.queue_free)
		confirm.popup_centered()
	)
	popup.popup_centered(Vector2i(520, 290))

func library_context(game_id: String) -> void:
	var menu: PopupMenu = preload("res://scenes/client/library_context.tscn").instantiate()
	add_child(menu)
	menu.set_item_text(0, "开始游戏" if state.installed.has(game_id) else "安装")
	menu.set_item_text(1, "移出收藏夹" if state.favorites.has(game_id) else "添加至收藏夹")
	menu.id_pressed.connect(func(index: int) -> void:
		match index:
			0:
				if state.installed.has(game_id): launch_game(game_id)
				else: install_game(game_id)
			1: toggle_flag(game_id, "favorites")
			2: open_product(game_id)
			3:
				state.uninstall(game_id)
				refresh_client(true)
	)
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.position = DisplayServer.mouse_get_position()
	menu.popup()

func notify(text: String) -> void:
	%Notification.get_node("Message").text = text
	%Notification.show()
	notice_timer.start()

func toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_XBUTTON1: go_history(-1)
		elif event.button_index == MOUSE_BUTTON_XBUTTON2: go_history(1)
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.alt_pressed and event.keycode == KEY_LEFT: go_history(-1)
	elif event.alt_pressed and event.keycode == KEY_RIGHT: go_history(1)
	elif event.ctrl_pressed and event.keycode == KEY_F:
		if not %StoreNavigation.visible: navigate({"kind": "search"})
		search_box.grab_focus()
	elif event.keycode == KEY_F11: toggle_fullscreen()
	elif event.keycode == KEY_ESCAPE and session == null: go_history(-1)

func _capture() -> void:
	var output: String = ""
	var view: String = "home"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = arg.trim_prefix("--capture=")
		if arg.begins_with("--view="): view = arg.trim_prefix("--view=")
	if output.is_empty(): return
	match view:
		"product": navigate({"kind": "product", "id": "distant_signal"})
		"wishlist":
			for id: String in ["distant_signal", "mist_valley", "midnight_castle"]: state.toggle_wishlist(id)
			navigate({"kind": "wishlist"})
		"cart":
			state.add_to_cart("distant_signal")
			state.add_to_cart("mist_valley")
			navigate({"kind": "cart"})
		"library":
			state.add_to_cart("distant_signal")
			state.add_to_cart("mist_valley")
			state.checkout()
			state.start_install("distant_signal")
			state.tick_downloads(100)
			state.record_play("distant_signal")
			navigate({"kind": "library", "id": "distant_signal"})
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("CLIENT_CAPTURE: ", output, " error=", error)
	get_tree().quit(0 if error == OK else 1)

func close_client() -> void:
	state.save_state()
	if session != null: host_requested.emit("close")
	else: get_tree().quit()

func minimize_client() -> void:
	if session != null: host_requested.emit("minimize")
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

func _shared_refresh() -> void:
	if not shared_refresh_pending and is_node_ready():
		shared_refresh_pending = true
		_flush_shared_refresh.call_deferred()

func _flush_shared_refresh() -> void:
	shared_refresh_pending = false
	if is_inside_tree() and is_node_ready(): refresh_client(true)

func _shared_tick() -> void:
	wallet_button.text = "钱包 %d 点  v" % state.wallet
	_update_status()
	for widget: Dictionary in download_widgets:
		if is_instance_valid(widget["bar"]): widget["bar"].value = float(state.downloads.get(widget["id"], 100))
	var activity_label := find_child("CreationProgress", true, false) as Label
	if is_instance_valid(activity_label): activity_label.text = session.activity_text()
	for entry: Array in [["CreationFollowers", "关注者  %d", "followers"], ["CreationStreamIncome", "直播收入  %d 点", "stream_income"], ["CreationGuideIncome", "攻略收入  %d 点", "guide_income"]]:
		var label := find_child(entry[0], true, false) as Label
		if is_instance_valid(label): label.text = entry[1] % state.life[entry[2]]

func genre_options() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in state.catalog:
		for genre: String in entry["genres"]:
			if not result.has(genre): result.append(genre)
	return result
