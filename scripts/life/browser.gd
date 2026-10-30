extends Control
const U = preload("res://scripts/client_ui.gd")
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
var tab := "shop"
var box: VBoxContainer
var message: Label
var pending := false
var wallet_label: Label
var purchase_buttons: Dictionary = {}

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("ebe6db")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := U.vbox(U.margin(self, 20), 12)
	layout.get_parent().set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var nav := U.hbox(layout)
	U.label(nav, "回忆生活  /  HOME & HARDWARE", 24, Color("354951"))
	U.button(nav, "购物", func() -> void: set_tab("shop"), "blue").name = "ShopTab"
	U.button(nav, "我的物品", func() -> void: set_tab("inventory"), "blue").name = "InventoryTab"
	message = U.label(layout, "选购一件陪伴你的物品。购买后到「我的物品」安装。", 12, Color("526369"), true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	box = U.vbox(scroll, 12)
	session.tick_updated.connect(_tick)
	session.changed.connect(_queue_refresh)
	refresh()

func set_tab(value: String) -> void:
	tab = value
	if is_node_ready(): refresh()

func _queue_refresh() -> void:
	if not pending:
		pending = true
		refresh.call_deferred()

func refresh() -> void:
	pending = false
	if not is_instance_valid(box): return
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	purchase_buttons.clear()
	wallet_label = U.label(box, "", 12, Color("455961"))
	_tick()
	for id: String in Data.ITEMS:
		var item: Dictionary = Data.ITEMS[id]
		var owned: bool = session.state.life["items"].has(id)
		if tab == "shop" and int(item["price"]) == 0: continue
		if tab == "inventory" and not owned: continue
		var row := U.hbox(U.panel(box, "faf7ef", 14), 18)
		var text := U.vbox(row, 4)
		U.label(text, item["name"], 24, Color("31464f"))
		U.label(text, item["description"], 12, Color("637176"), true)
		var key := id
		if tab == "shop":
			U.label(row, "%d 点" % item["price"], 12, Color("556a41")).size_flags_horizontal = Control.SIZE_SHRINK_END
			var button := U.button(row, "已拥有" if owned else "购买", func() -> void: message.text = session.buy_item(key), "green", 100)
			purchase_buttons[id] = button
			button.name = "Buy_" + id
			button.disabled = owned or session.state.wallet < int(item["price"])
		else:
			var equipped: bool = session.state.life["equipped"].get(item["slot"], "") == id
			var button := U.button(row, "使用中" if equipped else "安装 / 摆放", func() -> void: message.text = session.equip_item(key), "blue", 140)
			button.name = "Equip_" + id
			button.disabled = equipped

func _tick() -> void:
	if is_instance_valid(wallet_label): wallet_label.text = "钱包余额  %d 点   ·   %s" % [session.state.wallet, "所有物品即时加入库存" if tab == "shop" else "每种物品安装在对应位置"]
	for id: String in purchase_buttons:
		if is_instance_valid(purchase_buttons[id]): purchase_buttons[id].disabled = session.state.life["items"].has(id) or session.state.wallet < int(Data.ITEMS[id]["price"])
