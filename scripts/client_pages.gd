extends RefCounted
## 页面布局保存在 scenes/client/pages；这里只绑定数据、信号和列表场景。
const U = preload("res://scripts/client_ui.gd")
const LifeData = preload("res://scripts/life/life_data.gd")
var c

func _init(client) -> void:
	c = client

func n(root: Node, key: String) -> Node:
	return root.get_node("%" + key)

func bind(button: BaseButton, action: Callable) -> void:
	for connection in button.pressed.get_connections(): button.pressed.disconnect(connection.callable)
	button.pressed.connect(action)

func menu(button: MenuButton, entries: Array, action: Callable) -> void:
	var popup := button.get_popup()
	popup.clear()
	for connection in popup.id_pressed.get_connections(): popup.id_pressed.disconnect(connection.callable)
	for index in range(entries.size()): popup.add_item(str(entries[index]), index)
	popup.id_pressed.connect(action)

func option(button: OptionButton, entries: Array, selected: int, action: Callable) -> void:
	button.clear()
	for connection in button.item_selected.get_connections(): button.item_selected.disconnect(connection.callable)
	for entry in entries: button.add_item(str(entry))
	button.select(selected)
	button.item_selected.connect(action)

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func page(kind: String) -> Control:
	var parent: Node = c.get_node("%PageContent")
	var path := "res://scenes/client/pages/%s.tscn" % kind
	var root: Control = parent.get_child(0) if parent.get_child_count() else null
	if root == null or root.scene_file_path != path:
		clear(parent)
		root = load(path).instantiate()
		parent.add_child(root)
	var browse := root.get_node_or_null("%BrowseStore")
	if browse != null: bind(browse, func() -> void: c.navigate({"kind": "home"}))
	return root

func row(kind: String, parent: Node) -> Control:
	var instance: Control = load("res://scenes/client/components/%s.tscn" % kind).instantiate()
	parent.add_child(instance)
	return instance

func text_button(parent: Node, title: String, action: Callable) -> Button:
	var button: Button = row("text_button", parent)
	button.text = title
	bind(button, action)
	return button

func game_row(parent: Node, entry: Dictionary) -> Button:
	var game_id: String = entry["id"]
	var card: Button = row("game_row", parent)
	bind(card, func() -> void: c.open_product(game_id))
	n(card, "Cover").texture = U.texture(entry)
	n(card, "Title").text = entry["title"]
	n(card, "Tags").text = " / ".join(entry["tags"])
	n(card, "Rating").text = "%s · %d%% 好评" % [entry["rating"], entry["review_percent"]]
	n(card, "Price").text = c.price_text(entry)
	card.tooltip_text = entry["feature"]
	U.passive(card)
	return card

func tile(parent: Node, entry: Dictionary, price: String, action: Callable) -> void:
	var card: Button = row("game_tile", parent)
	bind(card, action)
	n(card, "Cover").texture = U.texture(entry)
	n(card, "Title").text = entry["title"]
	n(card, "Genre").text = entry["genre"]
	n(card, "Price").text = price
	card.tooltip_text = "%s\n%s\n%s · %d%% 好评" % [entry["title"], entry["feature"], entry["rating"], entry["review_percent"]]
	U.passive(card)

func home() -> void:
	var p := page("home")
	bind(n(p, "Discovery"), c.start_discovery)
	bind(n(p, "Wishlist"), func() -> void: c.navigate({"kind": "wishlist"}))
	bind(n(p, "Recent"), func() -> void: c.navigate({"kind": "search", "filter": "recent"}))
	for item in [["Sale", "sale"], ["New", "new"], ["Coming", "coming"], ["All", "all"], ["NewTab", "new"], ["PopularTab", "popular"], ["ComingTab", "coming"], ["SaleTab", "sale"]]:
		var value: String = item[1]
		bind(n(p, item[0]), func() -> void: c.navigate({"kind": "search", "filter": value}))
	clear(n(p, "Genres"))
	for genre: String in c.genre_options():
		text_button(n(p, "Genres"), genre, func() -> void: c.navigate({"kind": "search", "genre": genre}))
	var candidates: Array = c.available_games(true)
	if candidates.is_empty(): candidates = c.available_games()
	var has_games := not candidates.is_empty()
	n(p, "EmptyState").visible = not has_games
	for key in ["FeaturePanel", "Carousel", "OffersTitle", "Offers", "DiscoveryPanel", "Tabs", "GameRows"]: n(p, key).visible = has_games
	if not has_games: return
	c.featured_index = posmod(c.featured_index, candidates.size())
	var feature: Dictionary = candidates[c.featured_index]
	var id: String = feature["id"]
	n(p, "FeatureCover").texture = U.texture(feature)
	n(p, "PosterTitle").text = feature["title"]
	n(p, "FeatureTitle").text = feature["title"]
	var poster: Control = n(p, "Poster")
	for connection in poster.gui_input.get_connections(): poster.gui_input.disconnect(connection.callable)
	poster.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: c.open_product(id)
	)
	for shot in range(4): n(p, "FeatureShot" + str(shot)).texture = U.screenshot(feature, shot)
	n(p, "FeatureRating").text = "%s · %d%% 好评" % [feature["rating"], feature["review_percent"]]
	n(p, "FeaturePrice").text = c.price_text(feature)
	bind(n(p, "FeatureOpen"), func() -> void: c.open_product(id))
	bind(n(p, "Previous"), func() -> void: c.cycle_feature(-1))
	bind(n(p, "Next"), func() -> void: c.cycle_feature(1))
	clear(n(p, "CarouselDots"))
	for i in range(candidates.size()):
		var selected := i
		text_button(n(p, "CarouselDots"), "■" if i == c.featured_index else "□", func() -> void:
			c.featured_index = selected
			c.render_page()
		)
	bind(n(p, "MoreOffers"), func() -> void: c.navigate({"kind": "search", "filter": "sale"}))
	clear(n(p, "Offers"))
	var shown := 0
	for entry: Dictionary in c.available_games():
		if int(entry["discount"]) <= 0: continue
		var game_id: String = entry["id"]
		tile(n(p, "Offers"), entry, c.price_text(entry), func() -> void: c.open_product(game_id))
		shown += 1
		if shown >= 3: break
	bind(n(p, "StartDiscovery"), c.start_discovery)
	clear(n(p, "GameRows"))
	for entry: Dictionary in c.available_games().slice(0, 4): game_row(n(p, "GameRows"), entry)

func search() -> void:
	var p := page("search")
	var query: String = str(c.route.get("query", ""))
	var filter_name: String = str(c.route.get("filter", "all"))
	var genre: String = str(c.route.get("genre", ""))
	var titles := {"sale": "特别优惠", "coming": "即将推出", "new": "新品与热门商品", "popular": "热销商品", "recent": "最近浏览", "all": "所有游戏"}
	n(p, "Heading").text = "搜索：%s" % query if not query.is_empty() else (genre if not genre.is_empty() else titles.get(filter_name, "所有游戏"))
	option(n(p, "Sort"), ["相关性", "价格：由低到高", "价格：由高到低", "折扣幅度", "名称"], int(c.route.get("sort", 0)), func(index: int) -> void:
		var next: Dictionary = c.route.duplicate(true)
		next["sort"] = index
		c.navigate(next, false)
	)
	var hide_owned: CheckButton = n(p, "HideOwned")
	for connection in hide_owned.toggled.get_connections(): hide_owned.toggled.disconnect(connection.callable)
	hide_owned.set_pressed_no_signal(bool(c.route.get("hide_owned", false)))
	hide_owned.toggled.connect(func(value: bool) -> void:
		var next: Dictionary = c.route.duplicate(true)
		next["hide_owned"] = value
		c.navigate(next, false)
	)
	var entries: Array = c.search_games(c.route)
	n(p, "ResultCount").text = "%d 个结果" % entries.size()
	n(p, "EmptyState").visible = entries.is_empty()
	clear(n(p, "Rows"))
	for entry: Dictionary in entries: game_row(n(p, "Rows"), entry)

func product(queue_mode: bool = false) -> void:
	var game_id: String = str(c.route.get("id", ""))
	var index: int = int(c.route.get("index", 0))
	if queue_mode:
		if index >= c.queue_ids.size():
			var complete := page("queue_complete")
			bind(n(complete, "Wishlist"), func() -> void: c.navigate({"kind": "wishlist"}))
			bind(n(complete, "Home"), func() -> void: c.navigate({"kind": "home"}))
			return
		game_id = c.queue_ids[index]
	var entry: Dictionary = c.state.game(game_id)
	if entry.is_empty():
		var unavailable := page("empty")
		n(unavailable, "EmptyText").text = "这款游戏暂时无法查看。"
		return
	var p := page("product")
	c.remember_view(game_id)
	n(p, "QueuePanel").visible = queue_mode
	n(p, "QueueProgress").text = "您的发现队列  %d / %d" % [index + 1, c.queue_ids.size()]
	bind(n(p, "QueueNext"), c.next_queue)
	bind(n(p, "AllGames"), func() -> void: c.navigate({"kind": "search"}))
	n(p, "BreadcrumbText").text = " >  %s  >  %s" % [entry["genre"], entry["title"]]
	n(p, "Title").text = entry["title"]
	bind(n(p, "Creation"), func() -> void: c.navigate({"kind": "community", "id": game_id}))
	var aspect: AspectRatioContainer = n(p, "ScreenshotAspect")
	if not aspect.has_meta("bound"):
		aspect.set_meta("bound", true)
		aspect.resized.connect(func() -> void: aspect.custom_minimum_size.y = aspect.size.x / aspect.ratio)
	var picture: TextureRect = n(p, "ProductScreenshot")
	picture.texture = U.screenshot(entry, int(c.route.get("shot", 0)))
	for shot in range(4):
		var number := shot
		bind(n(p, "ProductThumbnail" + str(shot + 1)), func() -> void: picture.texture = U.screenshot(entry, number))
		n(p, "Shot" + str(shot)).texture = U.screenshot(entry, shot)
	n(p, "Cover").texture = U.texture(entry)
	n(p, "Feature").text = entry["feature"]
	n(p, "Rating").text = "全部评测：%s（%d）" % [entry["rating"], entry["rating_count"]]
	n(p, "Release").text = "发行日期：%s" % entry["release_label"]
	n(p, "Studio").text = "开发商：%s\n发行商：%s" % [entry["studio"], entry["studio"]]
	for i in range(3):
		var button: Button = n(p, "Tag" + str(i))
		button.visible = i < entry["tags"].size()
		if not button.visible: continue
		var tag: String = entry["tags"][i]
		button.text = tag
		bind(button, func() -> void: c.navigate({"kind": "search", "query": tag}))
	n(p, "ProductWish").text = "✓ 已在愿望单" if c.state.wishlist.has(game_id) else "+ 添加至愿望单"
	bind(n(p, "ProductWish"), func() -> void: c.toggle_wish(game_id))
	n(p, "Follow").text = "✓ 已关注" if c.state.followed.has(game_id) else "关注"
	bind(n(p, "Follow"), func() -> void: c.toggle_flag(game_id, "followed"))
	n(p, "Ignore").text = "取消忽略" if c.state.ignored.has(game_id) else "忽略"
	bind(n(p, "Ignore"), func() -> void: c.toggle_flag(game_id, "ignored"))
	var owned: bool = c.state.owned.has(game_id)
	var delisted: bool = c.state.release_state(game_id) == &"delisted"
	var available: bool = c.state.is_available(game_id)
	n(p, "ViewLibrary").visible = owned
	bind(n(p, "ViewLibrary"), func() -> void: c.navigate({"kind": "library", "id": game_id}))
	n(p, "BuyRow").visible = not owned and available
	n(p, "ProductAdd").disabled = owned or not available
	n(p, "PurchaseHint").visible = not owned and not available
	if owned: n(p, "PurchaseTitle").text = "此游戏已在您的库中"
	elif delisted:
		n(p, "PurchaseTitle").text = "此游戏已下架"
		n(p, "PurchaseHint").text = "已购买的玩家仍可在游戏库中安装和游玩。"
	elif not available:
		n(p, "PurchaseTitle").text = "计划发行日期：%s" % entry["release_label"]
		n(p, "PurchaseHint").text = "这款游戏尚未推出。加入愿望单，等待新一段游戏时光。"
	else: n(p, "PurchaseTitle").text = "购买 %s" % entry["title"]
	n(p, "Edition").text = entry["edition"]
	n(p, "Discount").visible = int(entry["discount"]) > 0
	n(p, "OriginalPrice").visible = int(entry["discount"]) > 0
	n(p, "Discount").text = "-%d%%" % entry["discount"]
	n(p, "OriginalPrice").text = "原价 %d 点" % entry["price"]
	n(p, "Price").text = "%d 点" % c.state.price(game_id)
	n(p, "ProductAdd").text = "在购物车中" if c.state.cart.has(game_id) else "添加至购物车"
	bind(n(p, "ProductAdd"), func() -> void:
		if not owned and available: c.add_cart(game_id)
	)
	n(p, "Description").text = entry["description"]
	var cpu: String = str(entry["cpu"]) if not str(entry["cpu"]).is_empty() else "未提供"
	var gpu: String = str(entry["gpu"]) if not str(entry["gpu"]).is_empty() else "未提供"
	n(p, "ProductRequirements").text = "最低配置：\n操作系统：年代兼容系统\n处理器：%s\n显卡：%s\n内存：512 MB\n存储空间：%d MB\n支持语言：简体中文、English" % [cpu, gpu, entry["storage_mb"]]
	clear(n(p, "Reviews"))
	for review: Dictionary in entry["reviews"]:
		var box := row("review", n(p, "Reviews"))
		n(box, "Author").text = "推荐  ·  %s  ·  游戏时间 %s 小时" % [review["name"], review["hours"]]
		n(box, "Review").text = review["text"]

func wishlist() -> void:
	var p := page("wishlist")
	n(p, "Count").text = "%d 款游戏" % c.state.wishlist.size()
	var sort_mode: int = int(c.route.get("sort", 0))
	option(n(p, "Sort"), ["您的排序", "价格：由低到高", "折扣幅度"], sort_mode, func(value: int) -> void:
		var destination: Dictionary = c.route.duplicate(true)
		destination["sort"] = value
		c.navigate(destination, false)
	)
	var entries: Array = []
	for id: String in c.state.wishlist:
		var entry: Dictionary = c.state.game(id)
		if c.matches_query(entry, str(c.route.get("query", ""))): entries.append(entry)
	if sort_mode == 1: entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return c.state.price(a["id"]) < c.state.price(b["id"]))
	elif sort_mode == 2: entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["discount"]) > int(b["discount"]))
	n(p, "EmptyState").visible = entries.is_empty()
	clear(n(p, "Rows"))
	for entry: Dictionary in entries:
		var id: String = entry["id"]
		var item := row("wishlist_row", n(p, "Rows"))
		n(item, "Rank").text = "%02d" % (c.state.wishlist.find(id) + 1)
		n(item, "Cover").texture = U.texture(entry)
		n(item, "Title").text = entry["title"]
		bind(n(item, "Title"), func() -> void: c.open_product(id))
		n(item, "Info").text = "%s · %s" % [entry["genre"], entry["rating"]]
		n(item, "Release").text = entry["release_label"]
		n(item, "Price").text = c.price_text(entry)
		n(item, "Add").visible = c.state.is_available(id) and not c.state.owned.has(id)
		bind(n(item, "Add"), func() -> void: c.add_cart(id))
		bind(n(item, "Prioritize"), func() -> void:
			c.state.prioritize_wish(id)
			c.render_page(true)
		)
		bind(n(item, "Remove"), func() -> void: c.toggle_wish(id))

func cart(checkout_mode: bool = false) -> void:
	var p := page("cart")
	n(p, "Heading").text = "审核并购买" if checkout_mode else "您的购物车"
	n(p, "EmptyState").visible = c.state.cart.is_empty()
	n(p, "Columns").visible = not c.state.cart.is_empty()
	clear(n(p, "Rows"))
	if c.state.cart.is_empty(): return
	var original := 0
	for id: String in c.state.cart:
		var entry: Dictionary = c.state.game(id)
		original += int(entry["price"])
		var item := row("cart_row", n(p, "Rows"))
		n(item, "Cover").texture = U.texture(entry)
		n(item, "Title").text = entry["title"]
		bind(n(item, "Title"), func() -> void: c.open_product(id))
		n(item, "Edition").text = "供我自己使用 · %s" % entry["edition"]
		n(item, "Price").text = c.price_text(entry)
		n(item, "Remove").visible = not checkout_mode
		bind(n(item, "Remove"), func() -> void:
			c.state.remove_from_cart(id)
			c.refresh_client()
		)
	n(p, "RemoveAll").visible = not checkout_mode
	bind(n(p, "RemoveAll"), func() -> void:
		c.state.cart.clear()
		c.state.save_state()
		c.refresh_client()
	)
	n(p, "PaymentPanel").visible = checkout_mode
	n(p, "PaymentInfo").text = "账户：像素收藏家\n可用预算：%d 点" % c.state.wallet
	var total: int = c.state.cart_total()
	n(p, "OriginalTotal").text = "原价合计：%d 点" % original
	n(p, "Savings").text = "优惠：%d 点" % (original - total)
	n(p, "Total").text = "预计总额  %d 点" % total
	n(p, "Wallet").text = "钱包余额：%d 点\n购买后剩余：%d 点" % [c.state.wallet, c.state.wallet - total]
	n(p, "BudgetWarning").visible = total > c.state.wallet
	n(p, "BudgetWarning").text = "预算不足，还差 %d 点。" % (total - c.state.wallet)
	n(p, "ConfirmPurchase").visible = checkout_mode
	n(p, "ContinuePurchase").visible = not checkout_mode
	n(p, "ConfirmPurchase").disabled = total > c.state.wallet
	n(p, "ContinuePurchase").disabled = total > c.state.wallet
	bind(n(p, "ConfirmPurchase"), c.confirm_purchase)
	bind(n(p, "ContinuePurchase"), func() -> void: c.navigate({"kind": "checkout"}))
	bind(n(p, "ContinueShopping"), func() -> void: c.navigate({"kind": "home"}))

func receipt() -> void:
	var p := page("receipt")
	n(p, "OrderInfo").text = "游戏内订单已完成  ·  %s" % c.state.date_text()
	clear(n(p, "Rows"))
	for id: String in c.last_receipt.get("purchased", []): game_row(n(p, "Rows"), c.state.game(id))
	n(p, "Total").text = "本次支出 %d 点  ·  钱包剩余 %d 点" % [c.last_receipt.get("total", 0), c.state.wallet]
	bind(n(p, "Library"), func() -> void: c.navigate({"kind": "library"}))
	bind(n(p, "Home"), func() -> void: c.navigate({"kind": "home"}))

func library() -> void:
	var p := page("library")
	var collection: int = int(c.route.get("collection", 0))
	option(n(p, "Collection"), ["全部游戏", "已安装", "收藏夹"], collection, func(index: int) -> void: c.navigate({"kind": "library", "collection": index}, false))
	var search: LineEdit = n(p, "LibrarySearch")
	search.text = str(c.route.get("query", ""))
	for connection in search.text_submitted.get_connections(): search.text_submitted.disconnect(connection.callable)
	search.text_submitted.connect(func(value: String) -> void: c.navigate({"kind": "library", "query": value, "collection": collection}, false))
	var entries: Array = []
	for id: String in c.state.owned:
		if collection == 1 and not c.state.installed.has(id): continue
		if collection == 2 and not c.state.favorites.has(id): continue
		var entry: Dictionary = c.state.game(id)
		if c.matches_query(entry, str(c.route.get("query", ""))): entries.append(entry)
	n(p, "Count").text = "游戏（%d）" % entries.size()
	var selected: String = str(c.route.get("id", ""))
	var visible_ids: Array = entries.map(func(entry: Dictionary) -> String: return entry["id"])
	if not visible_ids.has(selected): selected = str(entries[0]["id"]) if not entries.is_empty() else ""
	clear(n(p, "Items"))
	for entry: Dictionary in entries:
		var id: String = entry["id"]
		var item := text_button(n(p, "Items"), ("★ " if c.state.favorites.has(id) else "") + str(entry["title"]), func() -> void: c.navigate({"kind": "library", "id": id, "collection": collection}, false))
		item.theme_type_variation = "BlueButton" if selected == id else "FlatButton"
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.name = "LibraryItem_" + id
		item.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: c.library_context(id)
		)
	var inner: ScrollContainer = n(p, "LibraryContentScroll")
	inner.custom_minimum_size.y = maxf(380.0, c.get_viewport_rect().size.y - c.get_node("%ClientHeader").size.y - c.get_node("%StatusBar").size.y - 56.0)
	n(p, "EmptyState").visible = selected.is_empty()
	n(p, "GameContent").visible = not selected.is_empty()
	if selected.is_empty():
		n(p, "EmptyText").text = "您的游戏库正等待新的收藏。" if c.state.owned.is_empty() else "当前分类没有匹配的游戏。"
		return
	var entry: Dictionary = c.state.game(selected)
	n(p, "Cover").texture = U.texture(entry)
	n(p, "Title").text = entry["title"]
	var installed: bool = c.state.installed.has(selected)
	var downloading: bool = c.state.downloads.has(selected)
	var game_button: Button = n(p, "LibraryAction")
	game_button.text = "开始游戏" if installed else ("正在安装" if downloading else "安装")
	game_button.disabled = downloading
	if downloading and c.state.downloads.keys()[0] != selected: game_button.text = "排队中"
	bind(game_button, func() -> void:
		if c.state.installed.has(selected): c.launch_game(selected)
		else: c.install_game(selected)
	)
	n(p, "Playtime").text = "%d 分钟 · %d 次游玩" % [c.state.play_minutes.get(selected, 0), c.state.play_sessions.get(selected, 0)]
	n(p, "Favorite").text = "★" if c.state.favorites.has(selected) else "☆"
	bind(n(p, "Favorite"), func() -> void: c.toggle_flag(selected, "favorites"))
	menu(n(p, "Manage"), ["查看商店页面", "卸载游戏"], func(index: int) -> void:
		if index == 0: c.open_product(selected)
		else:
			c.state.uninstall(selected)
			c.refresh_client()
	)
	n(p, "DownloadProgress").visible = downloading
	if downloading:
		n(p, "DownloadProgress").value = float(c.state.downloads[selected])
		c.download_widgets.append({"id": selected, "bar": n(p, "DownloadProgress")})
	bind(n(p, "Store"), func() -> void: c.open_product(selected))
	bind(n(p, "Creation"), func() -> void: c.navigate({"kind": "community", "id": selected}))
	bind(n(p, "Records"), func() -> void: c.navigate({"kind": "profile"}))
	n(p, "Welcome").text = "欢迎回到 %s" % entry["title"]
	n(p, "Feature").text = entry["feature"]
	var records := 0
	for i in range(3): n(p, "PlayRecord" + str(i)).hide()
	for event: Dictionary in c.state.activity:
		if event["id"] != selected: continue
		var label: Label = n(p, "PlayRecord" + str(records))
		label.text = "游玩记录 · 本次体验 %d 分钟" % event["minutes"]
		label.show()
		records += 1
		if records >= 3: break
	var unlocked: Array = c.state.life["achievements"].get(selected, [])
	var challenge: float = float(c.state.life["progress"].get(selected, 0))
	for i in range(LifeData.MILESTONES.size()):
		var milestone: Dictionary = LifeData.MILESTONES[i]
		var done := unlocked.has(milestone["id"])
		var label: Label = n(p, "Milestone" + str(i))
		label.text = "%s %s  ·  %d%%" % ["★" if done else "☆", milestone["name"], mini(100, int(challenge / float(milestone["target"]) * 100))]
		label.modulate = U.GREEN if done else Color.WHITE

func downloads_page() -> void:
	var p := page("downloads")
	n(p, "EmptyState").visible = c.state.downloads.is_empty() and c.state.installed.is_empty()
	clear(n(p, "Rows"))
	for id: String in c.state.downloads:
		var item := row("download_row", n(p, "Rows"))
		var status := "正在安装" if c.state.downloads.keys()[0] == id else "排队中"
		n(item, "Title").text = "%s · %s" % [status, c.state.game(id)["title"]]
		n(item, "Progress").value = float(c.state.downloads[id])
		c.download_widgets.append({"id": id, "bar": n(item, "Progress")})
		bind(n(item, "Cancel"), func() -> void:
			c.state.uninstall(id)
			c.refresh_client()
		)
	for id: String in c.state.installed:
		var item := row("installed_row", n(p, "Rows"))
		n(item, "Title").text = "%s · 已安装" % c.state.game(id)["title"]
		bind(n(item, "Open"), func() -> void: c.navigate({"kind": "library", "id": id}))

func profile() -> void:
	var p := page("profile")
	n(p, "Games").text = "%d\n游戏" % c.state.owned.size()
	n(p, "Wishes").text = "%d\n愿望单" % c.state.wishlist.size()
	n(p, "NoActivity").visible = c.state.activity.is_empty()
	clear(n(p, "Activity"))
	for event: Dictionary in c.state.activity.slice(0, 8):
		var entry: Dictionary = c.state.game(event["id"])
		var item := row("activity_row", n(p, "Activity"))
		n(item, "Cover").texture = U.texture(entry)
		n(item, "Info").text = "游玩了 %s\n本次 %d 分钟" % [entry["title"], event["minutes"]]
	clear(n(p, "Shelf"))
	for id: String in c.state.owned.slice(0, 4):
		tile(n(p, "Shelf"), c.state.game(id), "已收藏", func() -> void: c.navigate({"kind": "library", "id": id}))

func community() -> void:
	var p := page("community")
	n(p, "StandaloneHint").visible = c.session == null
	n(p, "Content").visible = c.session != null
	if c.session == null: return
	var session: MemoirGameSession = c.session
	n(p, "CreationFollowers").text = "关注者  %d" % c.state.life["followers"]
	n(p, "CreationStreamIncome").text = "直播收入  %d 点" % c.state.life["stream_income"]
	n(p, "CreationGuideIncome").text = "攻略收入  %d 点" % c.state.life["guide_income"]
	n(p, "CreationProgress").text = session.activity_text()
	n(p, "CreationStream").text = "结束直播" if session.active().get("streaming", false) else "开始直播"
	n(p, "CreationStream").disabled = session.active().get("kind") != "play"
	bind(n(p, "CreationStream"), func() -> void: c.notify(session.toggle_stream()))
	n(p, "CancelGuide").visible = session.active().get("kind") == "guide"
	bind(n(p, "CancelGuide"), session.cancel_guide)
	n(p, "NoGames").visible = c.state.owned.is_empty()
	clear(n(p, "Rows"))
	for id: String in c.state.owned:
		var item := row("guide_row", n(p, "Rows"))
		n(item, "Cover").texture = U.texture(c.state.game(id))
		n(item, "Title").text = c.state.game(id)["title"]
		var published: bool = c.state.life["guides"].has(id)
		n(item, "Write").visible = not published
		if published:
			var guide: Dictionary = c.state.life["guides"][id]
			n(item, "Info").text = "已发布 · 质量 %d 星 · 阅读收益 %d / 60 次" % [guide["quality"], guide["royalties"]]
		else:
			n(item, "Info").text = "累计游玩 %d / 10 分钟" % c.state.play_minutes.get(id, 0)
			var button: Button = n(item, "Write")
			bind(button, func() -> void: c.notify(session.start_guide(id)))
			button.name = "WriteGuide_" + id
			button.disabled = not session.active().is_empty() or int(c.state.play_minutes.get(id, 0)) < 10
