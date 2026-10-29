extends Control
## 所有固定界面均保存在 store.tscn，运行时只更新数据与购物车内容。

const State = preload("res://scripts/store_state.gd")
const PAGE_SIZE := 4
const GREEN := Color("b3ce8f")
const MUTED := Color("849995")

var state = State.new()
var current_view: String = "store"
var current_filter: String = "all"
var current_page: int = 0
var current_game_id: String = "distant_signal"
var filtered: Array = []
var receipt: Dictionary = {}
var modal_kind: String = ""
var toast_timer: Timer
var reset_dialog: ConfirmationDialog

func _ready() -> void:
	state.persistence_enabled = not OS.get_cmdline_user_args().has("--fresh")
	state.load_state()
	_wire_buttons()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 3.2
	toast_timer.timeout.connect(func() -> void: %Toast.hide())
	add_child(toast_timer)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "重置演示存档"
	reset_dialog.dialog_text = "将恢复初始预算、日期、游戏库和愿望单。是否继续？"
	reset_dialog.ok_button_text = "重置"
	reset_dialog.cancel_button_text = "取消"
	reset_dialog.confirmed.connect(_reset_demo)
	add_child(reset_dialog)
	refresh()
	_capture_if_requested.call_deferred()

func _wire_buttons() -> void:
	%StoreTab.pressed.connect(func() -> void: set_view("store"))
	%LibraryTab.pressed.connect(func() -> void: set_view("library"))
	%WishTab.pressed.connect(func() -> void: set_view("wishlist"))
	%CartButton.pressed.connect(open_cart)
	%HeroInspect.pressed.connect(func() -> void: open_detail("distant_signal"))
	%HeroAdd.pressed.connect(func() -> void: add_to_cart("distant_signal"))
	%HeroWish.pressed.connect(func() -> void: toggle_wish("distant_signal"))
	%DetailAdd.pressed.connect(func() -> void: add_to_cart(current_game_id))
	%DetailWish.pressed.connect(func() -> void: toggle_wish(current_game_id))
	for close_button: Button in [%DetailClose, %CartClose, %AboutClose]:
		close_button.pressed.connect(close_modal)
	%CheckoutButton.pressed.connect(_checkout_pressed)
	%NextMonthButton.pressed.connect(_next_month)
	%NextButton.pressed.connect(func() -> void: _change_page(1))
	%PrevButton.pressed.connect(func() -> void: _change_page(-1))
	%SearchBox.text_changed.connect(func(_text: String) -> void:
		current_page = 0
		refresh()
	)
	var filters := {"FilterAll": "all", "FilterSale": "sale", "FilterAdventure": "探索冒险", "FilterStrategy": "策略战术", "FilterLife": "生活模拟", "FilterComing": "coming"}
	for node_name: String in filters:
		var filter_value: String = filters[node_name]
		get_node("%" + node_name).pressed.connect(func() -> void: set_filter(filter_value))
	for index: int in range(PAGE_SIZE):
		get_node("%%Card%d" % index).pressed.connect(func() -> void:
			var item_index := current_page * PAGE_SIZE + index
			if item_index < filtered.size():
				open_detail(str(filtered[item_index]["id"]))
		)
	%AboutButton.pressed.connect(func() -> void: _show_modal("about"))
	%ResetButton.pressed.connect(func() -> void: reset_dialog.popup_centered())
	%QuitButton.pressed.connect(func() -> void:
		state.save_state()
		get_tree().quit()
	)

func set_view(view: String) -> void:
	current_view = view
	current_page = 0
	current_filter = "all"
	%SearchBox.clear()
	close_modal()
	refresh()

func set_filter(filter_value: String) -> void:
	current_view = "store"
	current_filter = filter_value
	current_page = 0
	refresh()

func refresh() -> void:
	%WalletValue.text = "%d 点" % state.wallet
	%DateLabel.text = state.date_text()
	%CollectionStatus.text = "游戏库 %d 款   /   愿望单 %d 款   /   本月预算 +60 点" % [state.owned.size(), state.wishlist.size()]
	%CartButton.text = "购物车  %d  ·  %d 点" % [state.cart.size(), state.cart_total()]
	%LibraryTab.text = "游戏库 %d" % state.owned.size() if state.owned.size() > 0 else "游戏库"
	%WishTab.text = "愿望单 %d" % state.wishlist.size() if state.wishlist.size() > 0 else "愿望单"
	%NextMonthButton.disabled = state.month_index >= State.MAX_MONTH
	%NextMonthButton.text = "本次演示已结束" if %NextMonthButton.disabled else "进入下个月  >"
	_update_nav_styles()
	_update_featured()
	filtered = _filter_catalog()
	var page_count := maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))
	current_page = clampi(current_page, 0, page_count - 1)
	%PageLabel.text = "%02d / %02d" % [current_page + 1, page_count]
	%PrevButton.disabled = current_page == 0
	%NextButton.disabled = current_page >= page_count - 1
	%ResultCount.text = "%d 款游戏" % filtered.size()
	var store_view := current_view == "store"
	%Hero.visible = store_view
	%PageEyebrow.text = {"store": "THE STORE  /  商店", "library": "YOUR COLLECTION  /  游戏库", "wishlist": "FOR THE FUTURE  /  愿望单"}[current_view]
	%PageHeading.text = {"store": "发现你的下一段回忆", "library": "收藏属于你的游戏时光", "wishlist": "把期待留给下一次相遇"}[current_view]
	%SectionTitle.text = {"store": "即将推出" if current_filter == "coming" else "本月精选", "library": "我的游戏库", "wishlist": "我的愿望单"}[current_view]
	for control: Control in [%SectionTitle, %ResultCount, %PageLabel, %PrevButton, %NextButton]:
		control.position.y = 504 if store_view else 242
	for index: int in range(PAGE_SIZE):
		var card: Button = get_node("%%Card%d" % index)
		card.position.y = 542 if store_view else 280
		var entry_index := current_page * PAGE_SIZE + index
		card.visible = entry_index < filtered.size()
		if card.visible:
			_bind_card(index, filtered[entry_index])
	%EmptyResults.visible = filtered.is_empty()
	%EmptyResults.position.y = 564 if store_view else 326
	if filtered.is_empty():
		if not %SearchBox.text.strip_edges().is_empty():
			%EmptyResults.text = "没有找到匹配的作品。\n试试名称、类型或制作组。"
		else:
			%EmptyResults.text = {"store": "这里暂时没有符合条件的游戏。", "library": "你的第一份收藏，正在等你。\n前往商店，开启这段游戏时光。", "wishlist": "把心动的游戏，留在愿望单里。\n游戏详情中可以添加关注。"}[current_view]
	if modal_kind == "detail":
		_bind_detail()

func _filter_catalog() -> Array:
	var results: Array = []
	var search: String = %SearchBox.text.strip_edges().to_lower()
	for entry: Dictionary in state.catalog:
		var game_id := str(entry["id"])
		if current_view == "library" and not state.owned.has(game_id):
			continue
		if current_view == "wishlist" and not state.wishlist.has(game_id):
			continue
		if current_view == "store":
			if current_filter == "coming":
				if state.is_available(game_id):
					continue
			else:
				if not state.is_available(game_id):
					continue
				if current_filter == "sale" and int(entry.get("discount", 0)) <= 0:
					continue
				if not current_filter in ["all", "sale"] and str(entry["genre"]) != current_filter:
					continue
		var haystack := (str(entry["title"]) + " " + str(entry["english"]) + " " + str(entry["studio"]) + " " + str(entry["genre"]) + " " + " ".join(entry["tags"])).to_lower()
		if not search.is_empty() and not haystack.contains(search):
			continue
		results.append(entry)
	return results

func _bind_card(index: int, entry: Dictionary) -> void:
	var game_id := str(entry["id"])
	get_node("%%CardArt%d" % index).texture = _art(entry)
	get_node("%%CardTitle%d" % index).text = entry["title"]
	get_node("%%CardGenre%d" % index).text = "%s · %s" % [entry["genre"], entry["tags"][0]]
	var price_label: Label = get_node("%%CardPrice%d" % index)
	if state.owned.has(game_id):
		price_label.text = "已在游戏库中"
	elif not state.is_available(game_id):
		price_label.text = "%s 上架" % entry["release_label"]
	elif int(entry.get("discount", 0)) > 0:
		price_label.text = "-%d%%   %d 点" % [entry["discount"], state.price(game_id)]
	else:
		price_label.text = "%d 点" % state.price(game_id)
	get_node("%%Card%d" % index).tooltip_text = "%s\n%s" % [entry["title"], entry["feature"]]

func _update_nav_styles() -> void:
	for item: Array in [[%StoreTab, "store"], [%LibraryTab, "library"], [%WishTab, "wishlist"]]:
		_set_active(item[0], current_view == item[1])
	var values := {"FilterAll": "all", "FilterSale": "sale", "FilterAdventure": "探索冒险", "FilterStrategy": "策略战术", "FilterLife": "生活模拟", "FilterComing": "coming"}
	for node_name: String in values:
		_set_active(get_node("%" + node_name), current_view == "store" and current_filter == values[node_name])

func _set_active(button: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2b4947") if active else Color(0, 0, 0, 0)
	box.border_color = Color("91b5a0") if active else Color(0, 0, 0, 0)
	box.set_border_width_all(1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	button.add_theme_stylebox_override("normal", box)

func _update_featured() -> void:
	%HeroPrice.text = "%d 点" % state.price("distant_signal")
	%HeroAdd.disabled = state.owned.has("distant_signal")
	%HeroAdd.text = "已在游戏库中" if %HeroAdd.disabled else ("已加入购物车" if state.cart.has("distant_signal") else "加入购物车")
	%HeroWish.text = "已关注" if state.wishlist.has("distant_signal") else "+ 愿望单"

func _art(entry: Dictionary) -> Texture2D:
	return load("res://assets/art/%s.png" % entry["art"]) as Texture2D

func add_to_cart(game_id: String) -> void:
	var message: String = state.add_to_cart(game_id)
	refresh()
	_toast(message)

func toggle_wish(game_id: String) -> void:
	var added: bool = state.toggle_wishlist(game_id)
	refresh()
	_toast("已加入愿望单，期待下一次相遇。" if added else "已从愿望单中移除。")

func open_detail(game_id: String) -> void:
	if state.game(game_id).is_empty():
		return
	current_game_id = game_id
	_show_modal("detail")
	_bind_detail()
	%DetailClose.grab_focus()

func _bind_detail() -> void:
	var entry: Dictionary = state.game(current_game_id)
	%DetailArt.texture = _art(entry)
	%DetailTitle.text = entry["title"]
	%DetailMeta.text = "%s  /  %s  /  %s" % [entry["genre"], entry["studio"], entry["release_label"]]
	%DetailDescription.text = entry["description"]
	%DetailInfo.text = "%s · %s\n%s  ·  %d 条模拟玩家评价" % [entry["edition"], entry["playtime"], entry["rating"], entry["rating_count"]]
	var owned: bool = state.owned.has(current_game_id)
	var available: bool = state.is_available(current_game_id)
	%DetailPrice.text = "已收藏" if owned else ("%d 点" % state.price(current_game_id) if available else "即将推出")
	%DetailAdd.disabled = owned or not available
	%DetailAdd.text = "已在游戏库中" if owned else ("已加入购物车" if state.cart.has(current_game_id) else ("加入购物车" if available else "%s 上架" % entry["release_label"]))
	%DetailWish.text = "已加入愿望单 · 点击移除" if state.wishlist.has(current_game_id) else "+ 加入愿望单"

func _show_modal(kind: String) -> void:
	modal_kind = kind
	%ModalShade.show()
	%DetailPanel.visible = kind == "detail"
	%CartPanel.visible = kind in ["cart", "receipt"]
	%AboutPanel.visible = kind == "about"
	%Toast.hide()

func close_modal() -> void:
	modal_kind = ""
	%ModalShade.hide()
	%SearchBox.release_focus()

func open_cart() -> void:
	_show_modal("cart")
	_render_cart()
	%CartClose.grab_focus()

func _clear_cart_rows() -> void:
	for child: Node in %CartRows.get_children():
		%CartRows.remove_child(child)
		child.queue_free()

func _render_cart() -> void:
	_clear_cart_rows()
	%CartTitle.text = "你的购物车"
	if state.cart.is_empty():
		var empty := Label.new()
		empty.text = "购物车还是空的。\n去挑选你的下一段回忆吧。"
		empty.custom_minimum_size = Vector2(550, 200)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		%CartRows.add_child(empty)
	for game_id: String in state.cart:
		_add_cart_row(game_id, true)
	var total: int = state.cart_total()
	var remaining: int = state.wallet - total
	%CartSummary.text = "合计 %d 点    /    当前预算 %d 点\n%s" % [total, state.wallet, "购买后剩余 %d 点" % remaining if remaining >= 0 else "预算不足，还差 %d 点；可移除部分游戏或等待下月。" % -remaining]
	%CheckoutButton.disabled = state.cart.is_empty() or remaining < 0
	%CheckoutButton.text = "确认购买 · %d 点" % total if not state.cart.is_empty() else "先去商店逛逛吧"

func _add_cart_row(game_id: String, removable: bool) -> void:
	var entry: Dictionary = state.game(game_id)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(548, 68)
	row.add_theme_constant_override("separation", 14)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(116, 58)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.texture = _art(entry)
	row.add_child(thumbnail)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = entry["title"]
	text_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%s  ·  %d 点" % [entry["edition"], state.price(game_id)]
	subtitle.add_theme_color_override("font_color", MUTED)
	text_box.add_child(subtitle)
	row.add_child(text_box)
	if removable:
		var remove_button := Button.new()
		remove_button.text = "移除"
		remove_button.custom_minimum_size = Vector2(66, 32)
		remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remove_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		remove_button.pressed.connect(func() -> void:
			state.remove_from_cart(game_id)
			refresh()
			_render_cart()
		)
		row.add_child(remove_button)
	else:
		var badge := Label.new()
		badge.text = "已入库"
		badge.add_theme_color_override("font_color", GREEN)
		row.add_child(badge)
	%CartRows.add_child(row)

func _checkout_pressed() -> void:
	if modal_kind == "receipt":
		set_view("library")
		return
	receipt = state.checkout()
	if not bool(receipt.get("ok", false)):
		_toast(str(receipt["message"]))
		_render_cart()
		return
	refresh()
	_show_modal("receipt")
	_clear_cart_rows()
	%CartTitle.text = "新的回忆，已入库"
	for game_id: String in receipt["purchased"]:
		_add_cart_row(game_id, false)
	%CartSummary.text = "已收藏 %d 款游戏 · 本次支出 %d 点\n剩余预算 %d 点，慢慢收藏属于你的游戏时光。" % [receipt["purchased"].size(), receipt["total"], state.wallet]
	%CheckoutButton.disabled = false
	%CheckoutButton.text = "查看我的游戏库  >"
	%CheckoutButton.grab_focus()

func _next_month() -> void:
	if state.advance_month():
		current_page = 0
		refresh()
		_toast("来到 %s · 本月预算 +60 点。" % state.date_text())

func _change_page(amount: int) -> void:
	current_page += amount
	refresh()

func _reset_demo() -> void:
	var persistence: bool = state.persistence_enabled
	state = State.new()
	state.persistence_enabled = persistence
	state.save_state()
	set_view("store")
	_toast("已重置演示，可以重新开始收藏了。")

func _toast(message: String) -> void:
	%ToastText.text = message
	%Toast.show()
	toast_timer.start()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		close_modal()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.keycode == KEY_F and event.ctrl_pressed:
		%SearchBox.grab_focus()
		get_viewport().set_input_as_handled()

func _capture_if_requested() -> void:
	var output_path: String = ""
	var capture_view: String = "store"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--view="):
			capture_view = argument.trim_prefix("--view=")
	if output_path.is_empty():
		return
	match capture_view:
		"detail": open_detail("mist_valley")
		"cart":
			state.add_to_cart("distant_signal")
			state.add_to_cart("mist_valley")
			refresh()
			open_cart()
		"library":
			state.add_to_cart("distant_signal")
			state.add_to_cart("mist_valley")
			state.checkout()
			set_view("library")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(output_path)
	print("SCENE_CAPTURE: %s (error %d)" % [output_path, result])
	get_tree().quit(0 if result == OK else 1)
