extends Control
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
var tab := "shop"
var box: VBoxContainer
var message: Label
var pending := false
var wallet_label: Label
var purchase_buttons: Dictionary = {}

func _ready() -> void:
	box = %Rows
	message = %Message
	wallet_label = %Wallet
	%ShopTab.pressed.connect(func() -> void: set_tab("shop"))
	%InventoryTab.pressed.connect(func() -> void: set_tab("inventory"))
	if session == null: return
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
		if child == wallet_label: continue
		box.remove_child(child)
		child.queue_free()
	purchase_buttons.clear()
	_tick()
	for id: String in Data.ITEMS:
		var item: Dictionary = Data.ITEMS[id]
		var owned: bool = session.state.life["items"].has(id)
		if tab == "shop" and (int(item["price"]) == 0 or Data.ROOM_ONLY_SLOTS.has(item["slot"])): continue
		if tab == "inventory" and not owned: continue
		var row = preload("res://scenes/client/components/inventory_row.tscn").instantiate()
		box.add_child(row)
		row.get_node("%Title").text = item["name"]
		row.get_node("%Description").text = item["description"]
		var button: Button = row.get_node("%Action")
		var key := id
		row.get_node("%Price").visible = tab == "shop"
		if tab == "shop":
			row.get_node("%Price").text = "%d 点" % item["price"]
			button.text = "已拥有" if owned else "购买"
			button.pressed.connect(func() -> void: message.text = session.buy_item(key))
			purchase_buttons[id] = button
			button.name = "Buy_" + id
			button.disabled = owned or session.state.wallet < int(item["price"])
		else:
			var equipped: bool = session.state.life["equipped"].get(item["slot"], "") == id
			var room_item: bool = Data.ROOM_ONLY_SLOTS.has(item["slot"])
			button.text = "已收藏" if room_item else ("使用中" if equipped else "安装")
			if room_item: row.get_node("%Description").text = "保留的历史物品记录。"
			button.pressed.connect(func() -> void: message.text = session.equip_item(key))
			button.name = "Equip_" + id
			button.disabled = equipped or room_item

func _tick() -> void:
	if is_instance_valid(wallet_label): wallet_label.text = "钱包余额  %d 点   ·   %s" % [session.state.wallet, "所有物品即时加入库存" if tab == "shop" else "每种物品安装在对应位置"]
	for id: String in purchase_buttons:
		if is_instance_valid(purchase_buttons[id]): purchase_buttons[id].disabled = session.state.life["items"].has(id) or session.state.wallet < int(Data.ITEMS[id]["price"])
