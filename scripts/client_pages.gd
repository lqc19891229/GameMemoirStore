extends RefCounted
## 页面分开构建：商店、完整商品页、愿望单、游戏库、购物车。
const U = preload("res://scripts/client_ui.gd")
var c

func _init(client) -> void:
	c = client

func root_box() -> VBoxContainer:
	return U.vbox(U.margin(c.get_node("%PageContent"), 28), 18)

func heading(parent: Node, text: String, subtitle: String = "") -> void:
	U.label(parent, text, 24, Color.WHITE)
	if not subtitle.is_empty():
		U.label(parent, subtitle, 12, U.MUTED, true)

func empty(parent: Node, text: String) -> void:
	U.spacer(parent, 38)
	U.label(parent, text, 24, U.TEXT, true)
	U.spacer(parent, 16)
	U.button(parent, "浏览商店", func() -> void: c.navigate({"kind": "home"}), "blue", 160)

func home() -> void:
	var root := root_box()
	var layout := U.hbox(root, 26)
	var side := U.vbox(layout, 6)
	side.custom_minimum_size.x = 158
	side.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	U.image(side, {"art": "icon"}, 48, 48)
	U.label(side, "发现值得拥有的游戏", 12, U.BLUE)
	U.spacer(side)
	U.label(side, "推荐", 12, U.MUTED)
	U.button(side, "您的发现队列  >", c.start_discovery, "flat")
	U.button(side, "您的愿望单", func() -> void: c.navigate({"kind": "wishlist"}), "flat")
	U.button(side, "最近浏览的游戏", func() -> void: c.navigate({"kind": "search", "filter": "recent"}), "flat")
	U.spacer(side)
	U.label(side, "浏览分类", 12, U.MUTED)
	for item: Array in [["特别优惠", "sale"], ["新品", "new"], ["即将推出", "coming"], ["所有游戏", "all"]]:
		var value: String = item[1]
		U.button(side, item[0], func() -> void: c.navigate({"kind": "search", "filter": value}), "flat")
	U.spacer(side)
	U.label(side, "按类型浏览", 12, U.MUTED)
	for genre: String in ["探索冒险", "策略战术", "生活模拟", "角色扮演"]:
		U.button(side, genre, func() -> void: c.navigate({"kind": "search", "genre": genre}), "flat")
	U.spacer(side, 36)
	U.label(side, "一段自己的游戏时光\n从一份收藏开始。", 12, U.MUTED, true)
	var main := U.vbox(layout, 16)
	U.label(main, "精选和推荐", 12, Color.WHITE)
	var candidates: Array = c.available_games(true)
	if candidates.is_empty():
		candidates = c.available_games()
	if candidates.is_empty():
		empty(main, "新的作品即将到来。")
		return
	c.featured_index = posmod(c.featured_index, candidates.size())
	var feature: Dictionary = candidates[c.featured_index]
	var featured := U.hbox(U.panel(main, "101923", 0), 0)
	var image_col := U.vbox(featured, 0)
	var poster := U.cover(image_col, feature, 274)
	poster.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	poster.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			c.open_product(str(feature["id"]))
	)
	var side_panel := U.panel(featured, "172331", 18)
	side_panel.custom_minimum_size.x = 302
	side_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var details := U.vbox(side_panel, 10)
	U.label(details, feature["title"], 24, Color.WHITE)
	var thumbs := GridContainer.new()
	thumbs.columns = 2
	thumbs.add_theme_constant_override("h_separation", 4)
	thumbs.add_theme_constant_override("v_separation", 4)
	details.add_child(thumbs)
	for shot: int in range(4):
		var preview := U.image(thumbs, feature, 128, 72)
		preview.texture = U.screenshot(feature, shot)
	U.label(details, "现已推出", 12, U.TEXT)
	U.label(details, "%s · %d%% 好评" % [feature["rating"], feature["review_percent"]], 12, U.BLUE)
	var feature_actions := U.hbox(details)
	U.label(feature_actions, c.price_text(feature), 12, U.GREEN)
	var feature_id: String = feature["id"]
	U.button(feature_actions, "查看商店页面", func() -> void: c.open_product(feature_id), "blue")
	var carousel := U.hbox(main, 6)
	U.button(carousel, "<", func() -> void: c.cycle_feature(-1), "flat", 32)
	U.spring(carousel)
	for i: int in range(candidates.size()):
		var selected: int = i
		U.button(carousel, "■" if i == c.featured_index else "□", func() -> void:
			c.featured_index = selected
			c.render_page()
		, "flat", 24)
	U.spring(carousel)
	U.button(carousel, ">", func() -> void: c.cycle_feature(1), "flat", 32)
	var offers_title := U.hbox(main)
	U.label(offers_title, "特别优惠", 12, Color.WHITE)
	U.button(offers_title, "浏览更多", func() -> void: c.navigate({"kind": "search", "filter": "sale"}), "flat")
	var offers := U.hbox(main, 12)
	var shown: int = 0
	for entry: Dictionary in c.available_games():
		if int(entry["discount"]) <= 0:
			continue
		var game_id: String = entry["id"]
		U.tile(offers, entry, c.price_text(entry), func() -> void: c.open_product(game_id))
		shown += 1
		if shown >= 3:
			break
	var queue_panel := U.panel(main, "25485f", 18)
	var queue_row := U.hbox(queue_panel)
	var queue_text := U.vbox(queue_row, 4)
	U.label(queue_text, "探索您的发现队列", 24, Color.WHITE)
	U.label(queue_text, "逐款发现新游戏，加入愿望单，或者告诉我们您不感兴趣。", 12, U.TEXT, true)
	U.button(queue_row, "开始探索  >", c.start_discovery, "blue", 144)
	var tabs := U.hbox(main)
	for item: Array in [["新品与热门商品", "new"], ["热销商品", "popular"], ["热门即将推出", "coming"], ["优惠", "sale"]]:
		var value: String = item[1]
		U.button(tabs, item[0], func() -> void: c.navigate({"kind": "search", "filter": value}), "flat")
	for entry: Dictionary in c.available_games().slice(0, 4):
		game_row(main, entry)

func game_row(parent: Node, entry: Dictionary) -> Button:
	var game_id: String = entry["id"]
	var card := U.button(parent, "", func() -> void: c.open_product(game_id), "dark")
	card.custom_minimum_size.y = 76
	var margin := MarginContainer.new()
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	var row := U.hbox(margin, 14)
	U.image(row, entry, 152, 62)
	var text := U.vbox(row, 2)
	U.label(text, entry["title"], 12, Color.WHITE)
	U.label(text, " / ".join(entry["tags"]), 12, U.MUTED)
	U.label(text, "%s · %d%% 好评" % [entry["rating"], entry["review_percent"]], 12, U.BLUE)
	var price := U.label(row, c.price_text(entry), 12, U.GREEN)
	price.size_flags_horizontal = Control.SIZE_SHRINK_END
	price.custom_minimum_size.x = 138
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	U.passive(card)
	card.tooltip_text = entry["feature"]
	return card

func search() -> void:
	var root := root_box()
	var query: String = str(c.route.get("query", ""))
	var filter_name: String = str(c.route.get("filter", "all"))
	var genre: String = str(c.route.get("genre", ""))
	var titles := {"sale": "特别优惠", "coming": "即将推出", "new": "新品与热门商品", "popular": "热销商品", "recent": "最近浏览", "all": "所有游戏"}
	heading(root, "搜索：%s" % query if not query.is_empty() else (genre if not genre.is_empty() else titles.get(filter_name, "所有游戏")))
	var controls := U.hbox(root)
	U.label(controls, "按您的偏好寻找下一段回忆。", 12, U.MUTED)
	var sort_index: int = int(c.route.get("sort", 0))
	U.option(controls, ["相关性", "价格：由低到高", "价格：由高到低", "折扣幅度", "名称"], sort_index, func(index: int) -> void:
		var next: Dictionary = c.route.duplicate(true)
		next["sort"] = index
		c.navigate(next, false)
	)
	var hide_owned := CheckButton.new()
	hide_owned.text = "隐藏已拥有"
	hide_owned.button_pressed = bool(c.route.get("hide_owned", false))
	controls.add_child(hide_owned)
	hide_owned.toggled.connect(func(value: bool) -> void:
		var next: Dictionary = c.route.duplicate(true)
		next["hide_owned"] = value
		c.navigate(next, false)
	)
	var entries: Array = c.search_games(c.route)
	U.label(root, "%d 个结果" % entries.size(), 12, U.MUTED)
	if entries.is_empty():
		empty(root, "没有找到符合条件的游戏。")
	for entry: Dictionary in entries:
		game_row(root, entry)

func product(queue_mode: bool = false) -> void:
	var root := root_box()
	var game_id: String = str(c.route.get("id", ""))
	if queue_mode:
		var index: int = int(c.route.get("index", 0))
		if index >= c.queue_ids.size():
			heading(root, "您的发现队列已浏览完毕", "喜欢的作品已经留在愿望单里。随时可以回来继续探索。")
			U.button(root, "查看愿望单", func() -> void: c.navigate({"kind": "wishlist"}), "blue")
			U.button(root, "返回商店", func() -> void: c.navigate({"kind": "home"}), "flat")
			return
		game_id = c.queue_ids[index]
		var queue_bar := U.hbox(U.panel(root, "294f68", 14))
		U.label(queue_bar, "您的发现队列  %d / %d" % [index + 1, c.queue_ids.size()], 12, Color.WHITE)
		U.button(queue_bar, "下一个游戏  >", c.next_queue, "blue", 160).name = "QueueNext"
	var entry: Dictionary = c.state.game(game_id)
	if entry.is_empty():
		empty(root, "这款游戏暂时无法查看。")
		return
	c.remember_view(game_id)
	var breadcrumb := U.hbox(root)
	U.button(breadcrumb, "所有游戏", func() -> void: c.navigate({"kind": "search"}), "flat")
	U.label(breadcrumb, " >  %s  >  %s" % [entry["genre"], entry["title"]], 12, U.MUTED)
	var title_row := U.hbox(root)
	U.label(title_row, entry["title"], 24, Color.WHITE)
	U.button(title_row, "社区中心", func() -> void: c.navigate({"kind": "community", "id": game_id}), "dark")
	var top := U.hbox(root, 20)
	var gallery := U.vbox(top, 8)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.custom_minimum_size.y = 236
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Reserve the image's full height in the VBox, including after window resizing.
	aspect.resized.connect(func() -> void:
		aspect.custom_minimum_size.y = aspect.size.x / aspect.ratio
	)
	gallery.add_child(aspect)
	var picture := U.image(aspect, entry, 0, 0)
	picture.texture = U.screenshot(entry, int(c.route.get("shot", 0)))
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.name = "ProductScreenshot"
	var thumb_row := U.hbox(gallery, 8)
	for shot: int in range(4):
		var number: int = shot
		var thumbnail := U.button(thumb_row, "", func() -> void:
			picture.texture = U.screenshot(entry, number)
		, "dark")
		thumbnail.name = "ProductThumbnail%d" % (shot + 1)
		thumbnail.custom_minimum_size = Vector2(0, 56)
		thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art := TextureRect.new()
		art.texture = U.screenshot(entry, shot)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 3
		art.offset_right = -3
		art.offset_top = 3
		art.offset_bottom = -3
	var info := U.vbox(top, 8)
	info.custom_minimum_size.x = 320
	info.size_flags_horizontal = Control.SIZE_SHRINK_END
	U.image(info, entry, 320, 126)
	U.label(info, entry["feature"], 12, U.TEXT, true)
	U.label(info, "全部评测：%s（%d）" % [entry["rating"], entry["rating_count"]], 12, U.BLUE)
	U.label(info, "发行日期：%s" % entry["release_label"], 12, U.MUTED)
	U.label(info, "开发商：%s\n发行商：%s" % [entry["studio"], entry["studio"]], 12, U.BLUE, true)
	var tags := U.hbox(info, 4)
	for tag: String in entry["tags"].slice(0, 3):
		U.button(tags, tag, func() -> void: c.navigate({"kind": "search", "query": tag}), "dark")
	var actions := U.hbox(root)
	U.button(actions, "✓ 已在愿望单" if c.state.wishlist.has(game_id) else "+ 添加至愿望单", func() -> void: c.toggle_wish(game_id), "dark").name = "ProductWish"
	U.button(actions, "✓ 已关注" if c.state.followed.has(game_id) else "关注", func() -> void: c.toggle_flag(game_id, "followed"), "dark")
	U.button(actions, "取消忽略" if c.state.ignored.has(game_id) else "忽略", func() -> void: c.toggle_flag(game_id, "ignored"), "dark")
	U.spring(actions)
	U.label(actions, "单人游戏 · 中文界面", 12, U.MUTED)
	var purchase := U.vbox(U.panel(root, "2b3d50", 20), 10)
	if c.state.owned.has(game_id):
		U.label(purchase, "此游戏已在您的库中", 24, U.GREEN)
		U.button(purchase, "在游戏库中查看", func() -> void: c.navigate({"kind": "library", "id": game_id}), "green", 220)
	elif c.state.release_state(game_id) == &"delisted":
		U.label(purchase, "此游戏已下架", 24, U.MUTED)
		U.label(purchase, "已购买的玩家仍可在游戏库中安装和游玩。", 12, U.MUTED, true)
	elif not c.state.is_available(game_id):
		U.label(purchase, "计划发行日期：%s" % entry["release_label"], 24, Color.WHITE)
		U.label(purchase, "这款游戏尚未推出。加入愿望单，等待新一段游戏时光。", 12, U.MUTED, true)
	else:
		U.label(purchase, "购买 %s" % entry["title"], 24, Color.WHITE)
		var buy_row := U.hbox(purchase)
		U.label(buy_row, entry["edition"], 12, U.MUTED)
		if int(entry["discount"]) > 0:
			U.label(buy_row, "-%d%%" % entry["discount"], 24, U.GREEN)
			U.label(buy_row, "原价 %d 点" % entry["price"], 12, U.MUTED)
		U.label(buy_row, "%d 点" % c.state.price(game_id), 24, Color.WHITE)
		U.button(buy_row, "在购物车中" if c.state.cart.has(game_id) else "添加至购物车", func() -> void: c.add_cart(game_id), "green", 180).name = "ProductAdd"
	U.spacer(root)
	heading(root, "关于这款游戏")
	U.rule(root)
	U.label(root, entry["description"], 12, U.TEXT, true)
	U.label(root, "• 以自己的节奏探索世界\n• 记录旅途中的发现与选择\n• 适合反复回味的单人体验", 12, U.MUTED, true)
	heading(root, "系统需求")
	U.rule(root)
	var cpu: String = str(entry["cpu"]) if not str(entry["cpu"]).is_empty() else "未提供"
	var gpu: String = str(entry["gpu"]) if not str(entry["gpu"]).is_empty() else "未提供"
	U.label(root, "最低配置：\n操作系统：年代兼容系统\n处理器：%s\n显卡：%s\n内存：512 MB\n存储空间：%d MB\n支持语言：简体中文、English" % [cpu, gpu, entry["storage_mb"]], 12, U.MUTED, true).name = "ProductRequirements"
	heading(root, "玩家评测", "以下为游戏世界内的玩家记录。")
	for review: Dictionary in entry["reviews"]:
		var box := U.vbox(U.panel(root, "16202d", 16), 8)
		U.label(box, "推荐  ·  %s  ·  游戏时间 %s 小时" % [review["name"], review["hours"]], 12, U.BLUE)
		U.label(box, review["text"], 12, U.TEXT, true)

func wishlist() -> void:
	var root := root_box()
	heading(root, "像素收藏家的愿望单", "排好下一次心动的顺序。")
	var tools := U.hbox(root)
	U.label(tools, "%d 款游戏" % c.state.wishlist.size(), 12, U.MUTED)
	var sort_mode: int = int(c.route.get("sort", 0))
	U.option(tools, ["您的排序", "价格：由低到高", "折扣幅度"], sort_mode, func(value: int) -> void:
		var destination: Dictionary = c.route.duplicate(true)
		destination["sort"] = value
		c.navigate(destination, false)
	)
	var entries: Array = []
	for game_id: String in c.state.wishlist:
		var entry: Dictionary = c.state.game(game_id)
		if c.matches_query(entry, str(c.route.get("query", ""))):
			entries.append(entry)
	if sort_mode == 1:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return c.state.price(a["id"]) < c.state.price(b["id"]))
	elif sort_mode == 2:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["discount"]) > int(b["discount"]))
	if entries.is_empty():
		empty(root, "您的愿望单还没有匹配的游戏。")
	for entry: Dictionary in entries:
		var game_id: String = entry["id"]
		var row := U.hbox(U.panel(root, "202f40", 12), 18)
		U.label(row, "%02d" % (c.state.wishlist.find(game_id) + 1), 24, U.MUTED).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		U.image(row, entry, 180, 82)
		var text := U.vbox(row, 4)
		U.button(text, entry["title"], func() -> void: c.open_product(game_id), "flat").alignment = HORIZONTAL_ALIGNMENT_LEFT
		U.label(text, "%s · %s" % [entry["genre"], entry["rating"]], 12, U.BLUE)
		U.label(text, entry["release_label"], 12, U.MUTED)
		var actions := U.vbox(row, 6)
		actions.size_flags_horizontal = Control.SIZE_SHRINK_END
		U.label(actions, c.price_text(entry), 12, U.GREEN)
		if c.state.is_available(game_id) and not c.state.owned.has(game_id):
			U.button(actions, "添加至购物车", func() -> void: c.add_cart(game_id), "green", 156)
		var small := U.hbox(actions, 8)
		U.button(small, "移到顶部", func() -> void:
			c.state.prioritize_wish(game_id)
			c.render_page(true)
		, "flat")
		U.button(small, "移除", func() -> void: c.toggle_wish(game_id), "flat")

func cart(checkout_mode: bool = false) -> void:
	var root := root_box()
	heading(root, "审核并购买" if checkout_mode else "您的购物车", "使用游戏内钱包完成购买，新的收藏将保留在您的库中。")
	if c.state.cart.is_empty():
		empty(root, "购物车还是空的。")
		return
	var layout := U.hbox(root, 24)
	var items := U.vbox(layout, 12)
	var original_total: int = 0
	for game_id: String in c.state.cart:
		var entry: Dictionary = c.state.game(game_id)
		original_total += int(entry["price"])
		var row := U.hbox(U.panel(items, "16202d", 12), 16)
		U.image(row, entry, 170, 80)
		var text := U.vbox(row, 4)
		U.button(text, entry["title"], func() -> void: c.open_product(game_id), "flat").alignment = HORIZONTAL_ALIGNMENT_LEFT
		U.label(text, "供我自己使用 · %s" % entry["edition"], 12, U.MUTED)
		var price := U.vbox(row, 5)
		price.size_flags_horizontal = Control.SIZE_SHRINK_END
		U.label(price, c.price_text(entry), 12, U.GREEN)
		if not checkout_mode:
			U.button(price, "移除", func() -> void:
				c.state.remove_from_cart(game_id)
				c.refresh_client()
			, "flat")
	if not checkout_mode:
		U.button(items, "移除所有物品", func() -> void:
			c.state.cart.clear()
			c.state.save_state()
			c.refresh_client()
		, "flat")
	else:
		var payment := U.vbox(U.panel(items, "202f40", 18), 8)
		U.label(payment, "支付方式：游戏内钱包", 24, Color.WHITE)
		U.label(payment, "账户：像素收藏家\n可用预算：%d 点" % c.state.wallet, 12, U.MUTED, true)
	var side := U.vbox(U.panel(layout, "16202d", 20), 12)
	side.get_parent().custom_minimum_size.x = 310
	side.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_END
	var total: int = c.state.cart_total()
	U.label(side, "原价合计：%d 点" % original_total, 12, U.MUTED)
	U.label(side, "优惠：%d 点" % (original_total - total), 12, U.GREEN)
	U.rule(side)
	U.label(side, "预计总额  %d 点" % total, 24, Color.WHITE)
	U.label(side, "钱包余额：%d 点\n购买后剩余：%d 点" % [c.state.wallet, c.state.wallet - total], 12, U.MUTED, true)
	if total > c.state.wallet:
		U.label(side, "预算不足，还差 %d 点。" % (total - c.state.wallet), 12, Color("e7a47d"), true)
	var action: Button
	if checkout_mode:
		action = U.button(side, "确认购买", c.confirm_purchase, "green")
		action.name = "ConfirmPurchase"
	else:
		action = U.button(side, "继续至购买", func() -> void: c.navigate({"kind": "checkout"}), "green")
		action.name = "ContinuePurchase"
	action.disabled = total > c.state.wallet
	U.button(side, "继续购物", func() -> void: c.navigate({"kind": "home"}), "flat")

func receipt() -> void:
	var root := root_box()
	heading(root, "感谢您的购买！", "新的游戏已经添加到您的库中。")
	U.label(root, "游戏内订单已完成  ·  %s" % c.state.date_text(), 12, U.GREEN)
	for game_id: String in c.last_receipt.get("purchased", []):
		game_row(root, c.state.game(game_id))
	U.label(root, "本次支出 %d 点  ·  钱包剩余 %d 点" % [c.last_receipt.get("total", 0), c.state.wallet], 24, Color.WHITE)
	var actions := U.hbox(root)
	U.button(actions, "前往游戏库", func() -> void: c.navigate({"kind": "library"}), "blue", 180)
	U.button(actions, "继续购物", func() -> void: c.navigate({"kind": "home"}), "flat", 160)

func library() -> void:
	var root := root_box()
	var layout := U.hbox(root, 22)
	var sidebar := U.vbox(U.panel(layout, "1b2028", 14), 8)
	sidebar.get_parent().custom_minimum_size.x = 230
	sidebar.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	U.label(sidebar, "游戏库", 24, Color.WHITE)
	var collection: int = int(c.route.get("collection", 0))
	U.option(sidebar, ["全部游戏", "已安装", "收藏夹"], collection, func(index: int) -> void: c.navigate({"kind": "library", "collection": index}, false))
	var search := LineEdit.new()
	search.placeholder_text = "按名称搜索 · 回车"
	search.text = str(c.route.get("query", ""))
	sidebar.add_child(search)
	search.text_submitted.connect(func(value: String) -> void: c.navigate({"kind": "library", "query": value, "collection": collection}, false))
	U.rule(sidebar)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size.y = 180
	sidebar.add_child(list_scroll)
	var game_list := U.vbox(list_scroll, 6)
	var entries: Array = []
	for game_id: String in c.state.owned:
		if collection == 1 and not c.state.installed.has(game_id):
			continue
		if collection == 2 and not c.state.favorites.has(game_id):
			continue
		var entry: Dictionary = c.state.game(game_id)
		if c.matches_query(entry, str(c.route.get("query", ""))):
			entries.append(entry)
	U.label(game_list, "游戏（%d）" % entries.size(), 12, U.MUTED)
	var selected: String = str(c.route.get("id", ""))
	var visible_ids: Array = entries.map(func(entry: Dictionary) -> String: return entry["id"])
	if not visible_ids.has(selected):
		selected = str(entries[0]["id"]) if not entries.is_empty() else ""
	for entry: Dictionary in entries:
		var game_id: String = entry["id"]
		var title: String = ("★ " if c.state.favorites.has(game_id) else "") + str(entry["title"])
		var item := U.button(game_list, title, func() -> void: c.navigate({"kind": "library", "id": game_id, "collection": collection}, false), "blue" if selected == game_id else "flat")
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.name = "LibraryItem_" + game_id
		item.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				c.library_context(game_id)
		)
	var inner_scroll := ScrollContainer.new()
	inner_scroll.name = "LibraryContentScroll"
	inner_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner_scroll.custom_minimum_size.y = maxf(380.0, c.get_viewport_rect().size.y - c.get_node("%ClientHeader").size.y - c.get_node("%StatusBar").size.y - 56.0)
	layout.add_child(inner_scroll)
	var main := U.vbox(inner_scroll, 14)
	if selected.is_empty():
		empty(main, "您的游戏库正等待新的收藏。" if c.state.owned.is_empty() else "当前分类没有匹配的游戏。")
		return
	var entry: Dictionary = c.state.game(selected)
	U.cover(main, entry, 220)
	var actions := U.hbox(U.panel(main, "202c39", 16), 18)
	var installed: bool = c.state.installed.has(selected)
	var downloading: bool = c.state.downloads.has(selected)
	var game_button := U.button(actions, "开始游戏" if installed else ("正在安装" if downloading else "安装"), func() -> void:
		if c.state.installed.has(selected):
			c.launch_game(selected)
		else:
			c.install_game(selected)
	, "green", 172)
	game_button.name = "LibraryAction"
	game_button.add_theme_font_size_override("font_size", 24)
	game_button.custom_minimum_size.y = 48
	game_button.disabled = downloading
	if downloading and c.state.downloads.keys()[0] != selected:
		game_button.text = "排队中"
	var stats := U.vbox(actions, 0)
	U.label(stats, "游戏时间", 12, U.MUTED)
	U.label(stats, "%d 分钟 · %d 次游玩" % [c.state.play_minutes.get(selected, 0), c.state.play_sessions.get(selected, 0)], 12, U.TEXT)
	U.button(actions, "★" if c.state.favorites.has(selected) else "☆", func() -> void: c.toggle_flag(selected, "favorites"), "flat", 40)
	U.menu(actions, "管理  v", ["查看商店页面", "卸载游戏"], func(index: int) -> void:
		if index == 0:
			c.open_product(selected)
		else:
			c.state.uninstall(selected)
			c.refresh_client()
	)
	if downloading:
		var bar := U.progress(main, float(c.state.downloads[selected]))
		c.download_widgets.append({"id": selected, "bar": bar})
	var links := U.hbox(main)
	U.button(links, "商店页面", func() -> void: c.open_product(selected), "flat")
	U.button(links, "社区中心", func() -> void: c.navigate({"kind": "community", "id": selected}), "flat")
	U.button(links, "游戏记录", func() -> void: c.navigate({"kind": "profile"}), "flat")
	U.rule(main)
	U.label(main, "最近动态", 24, Color.WHITE)
	var news := U.vbox(U.panel(main, "25374a", 16), 8)
	U.label(news, "欢迎回到 %s" % entry["title"], 12, U.BLUE)
	U.label(news, entry["feature"], 12, U.TEXT, true)
	U.label(news, "这里将记录您在这款游戏中度过的时光。", 12, U.MUTED)
	var records: int = 0
	for event: Dictionary in c.state.activity:
		if event["id"] == selected:
			U.label(main, "游玩记录 · 本次体验 %d 分钟" % event["minutes"], 12, U.TEXT)
			records += 1
			if records >= 3:
				break
	U.label(main, "成就", 24, Color.WHITE)
	U.label(main, "成就功能将随游戏平台的年代更新逐步开放。", 12, U.MUTED, true)

func downloads_page() -> void:
	var root := root_box()
	heading(root, "下载", "管理游戏的安装状态。")
	if c.state.downloads.is_empty() and c.state.installed.is_empty():
		empty(root, "暂时没有下载任务。购买后可在游戏库安装。")
	for game_id: String in c.state.downloads:
		var entry: Dictionary = c.state.game(game_id)
		var box := U.vbox(U.panel(root, "202f40", 16), 10)
		var status: String = "正在安装" if c.state.downloads.keys()[0] == game_id else "排队中"
		U.label(box, "%s · %s" % [status, entry["title"]], 24, Color.WHITE)
		var bar := U.progress(box, float(c.state.downloads[game_id]))
		c.download_widgets.append({"id": game_id, "bar": bar})
		U.button(box, "取消安装", func() -> void:
			c.state.uninstall(game_id)
			c.refresh_client()
		, "flat")
	for game_id: String in c.state.installed:
		var row := U.hbox(U.panel(root, "16202d", 14))
		U.label(row, "%s · 已安装" % c.state.game(game_id)["title"], 12, U.GREEN)
		U.button(row, "在库中查看", func() -> void: c.navigate({"kind": "library", "id": game_id}), "blue")

func profile() -> void:
	var root := root_box()
	var header := U.hbox(U.panel(root, "223b50", 22), 20)
	U.image(header, {"art": "icon"}, 80, 80)
	var text := U.vbox(header, 6)
	U.label(text, "像素收藏家", 24, Color.WHITE)
	U.label(text, "在线  ·  每一款游戏，都是一段回忆。", 12, U.BLUE)
	U.label(header, "%d\n游戏" % c.state.owned.size(), 24, Color.WHITE)
	U.label(header, "%d\n愿望单" % c.state.wishlist.size(), 24, U.MUTED)
	heading(root, "最近游戏动态")
	if c.state.activity.is_empty():
		U.label(root, "还没有游玩记录。安装一款游戏，开始您的第一段旅程。", 12, U.MUTED, true)
	for event: Dictionary in c.state.activity.slice(0, 8):
		var entry: Dictionary = c.state.game(event["id"])
		var row := U.hbox(U.panel(root, "16202d", 14))
		U.image(row, entry, 140, 62)
		U.label(row, "游玩了 %s\n本次 %d 分钟" % [entry["title"], event["minutes"]], 12, U.TEXT, true)
	U.label(root, "游戏收藏", 24, Color.WHITE)
	var shelf := U.hbox(root, 12)
	for game_id: String in c.state.owned.slice(0, 4):
		var id: String = game_id
		U.tile(shelf, c.state.game(id), "已收藏", func() -> void: c.navigate({"kind": "library", "id": id}))

func community() -> void:
	var root := root_box()
	var game_id: String = str(c.route.get("id", ""))
	var entry: Dictionary = c.state.game(game_id)
	heading(root, "%s · 社区中心" % entry["title"] if not entry.is_empty() else "社区动态", "游戏世界中的新闻与玩家记忆。")
	var entries: Array = [entry] if not entry.is_empty() else c.available_games().slice(0, 4)
	for game: Dictionary in entries:
		var id: String = game["id"]
		var row := U.hbox(U.panel(root, "202f40", 18), 20)
		U.image(row, game, 210, 100)
		var text := U.vbox(row, 6)
		U.label(text, "%s · 开发者来信" % game["title"], 24, Color.WHITE)
		U.label(text, game["feature"] + " 感谢每一位愿意驻足的玩家。", 12, U.TEXT, true)
		U.button(text, "查看游戏", func() -> void: c.open_product(id), "flat")
