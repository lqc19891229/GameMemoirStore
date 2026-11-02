extends Control
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
const Finishes = preload("res://scripts/items/furniture_finishes.gd")
const ThumbnailCache = preload("res://scripts/life/furniture_thumbnail_cache.gd")
var session: MemoirGameSession
var tab := "shop"
var box: VBoxContainer
var message: Label
var pending := false
var wallet_label: Label
var purchase_buttons: Dictionary = {}
var catalog_group_ids: Array[String] = [""]
var catalog_type_ids: Array[String] = [""]
var thumbnail_cache

func _ready() -> void:
	box = %Rows
	message = %Message
	wallet_label = %Wallet
	thumbnail_cache = ThumbnailCache.new()
	thumbnail_cache.name = "FurnitureThumbnailCache"
	add_child(thumbnail_cache)
	for label: String in Finishes.LABELS:
		%ShopPreviewFinish.add_item(label)
	%ShopPreviewFinish.item_selected.connect(func(_index: int) -> void: refresh())
	%ShopCatalogGroup.add_item("全部分类")
	for entry: Dictionary in Taxonomy.GROUPS:
		%ShopCatalogGroup.add_item(str(entry.name))
		catalog_group_ids.append(str(entry.id))
	%ShopCatalogGroup.item_selected.connect(func(_i: int) -> void: _update_catalog_types())
	%ShopCatalogType.item_selected.connect(func(_i: int) -> void: refresh())
	%ShopCatalogSearch.text_changed.connect(func(_query: String) -> void: refresh())
	_update_catalog_types()
	%ShopTab.pressed.connect(func() -> void: set_tab("shop"))
	%InventoryTab.pressed.connect(func() -> void: set_tab("inventory"))
	if session == null: return
	session.tick_updated.connect(_tick)
	session.changed.connect(_queue_refresh)
	refresh()

func _category() -> String:
	var index: int = %ShopCatalogGroup.selected
	return catalog_group_ids[index] if index >= 0 and index < catalog_group_ids.size() else ""

func _item_type() -> String:
	var index: int = %ShopCatalogType.selected
	return catalog_type_ids[index] if index >= 0 and index < catalog_type_ids.size() else ""

func _update_catalog_types() -> void:
	var group: String = _category()
	var kinds: Dictionary = {}
	for item in Catalog.items:
		if not group.is_empty() and Taxonomy.group_for(item) != group: continue
		kinds[Taxonomy.type_for(item)] = true
	%ShopCatalogType.clear()
	%ShopCatalogType.add_item("全部类型")
	catalog_type_ids = [""]
	for key: String in Taxonomy.TYPES:
		if kinds.has(key):
			%ShopCatalogType.add_item(Taxonomy.type_name(key))
			catalog_type_ids.append(key)
	%ShopCatalogType.select(0)
	if session != null: refresh()

func set_tab(value: String) -> void:
	tab = value
	if is_node_ready(): refresh()

func _queue_refresh() -> void:
	if not pending:
		pending = true
		refresh.call_deferred()

func refresh() -> void:
	pending = false
	if session == null or not is_instance_valid(box): return
	for child: Node in box.get_children():
		if child == wallet_label: continue
		box.remove_child(child)
		child.queue_free()
	purchase_buttons.clear()
	thumbnail_cache.forget_requests()
	_tick()
	var inventory: Array = session.state.life["inventory"]
	var placements: Dictionary = session.state.life["placements"]
	for item in Catalog.items:
		if not Catalog.matches_filters(item,_category(),_item_type(),%ShopCatalogSearch.text): continue
		var id := item.item_id
		var count := InventoryData.count(inventory, id)
		if tab == "shop" and (item.price <= 0 or item.retired): continue
		if tab == "inventory" and count == 0: continue
		var row = preload("res://scenes/apps/browser/components/inventory_row.tscn").instantiate()
		box.add_child(row)
		row.get_node("%Title").text = item.name + (" ×%d" % count if tab == "inventory" and count > 1 else "")
		row.get_node("%Description").text = item.description
		var category_name := Taxonomy.group_name(Taxonomy.group_for(item))
		var type_name := Taxonomy.type_name(Taxonomy.type_for(item))
		var meta: Label = row.get_node("%FurnitureMeta")
		var preview_frame: Control = row.get_node("%ThumbnailBackdrop")
		preview_frame.visible = item.category == "furniture" and item.furniture_scene != null and not item.retired
		if preview_frame.visible:
			var model: Node3D = item.furniture_scene.instantiate()
			var bounds: Vector3 = model.get("bounds")
			model.free()
			meta.text = "%s / %s · %.2f × %.2f × %.2f m" % [category_name, type_name, bounds.x, bounds.y, bounds.z]
			row.get_node("%ThumbnailPlaceholder").text = type_name
			thumbnail_cache.request(item, row.get_node("%Thumbnail"), %ShopPreviewFinish.selected)
		else:
			meta.text = "%s / %s" % [category_name, type_name]
		var button: Button = row.get_node("%Action")
		var key := id
		row.get_node("%Price").visible = tab == "shop"
		if tab == "shop":
			row.get_node("%Price").text = "%d 点" % item.price
			var repeatable := item.category == "furniture"
			button.text = "购买" if repeatable or count == 0 else "已拥有"
			button.pressed.connect(func() -> void: message.text = session.buy_item(key))
			purchase_buttons[id] = button
			button.name = "Buy_" + id
			button.disabled = (count > 0 and not repeatable) or session.state.wallet < item.price
		else:
			button.name = "Equip_" + id
			if item.retired:
				button.text = "已收藏"
				button.disabled = true
				row.get_node("%Description").text = "保留的历史物品记录。"
			elif item.category == "furniture":
				var available := InventoryData.unused_uid(inventory, placements, id) != ""
				button.text = "摆放" if available else "已摆放"
				button.disabled = not available
				button.pressed.connect(func() -> void: message.text = session.request_place_furniture(key))
			else:
				var equipped: bool = session.state.life["equipped"].get(item.slot, "") == id
				button.text = "使用中" if equipped else "安装"
				button.disabled = equipped
				button.pressed.connect(func() -> void: message.text = session.equip_item(key))

func _tick() -> void:
	if session == null: return
	if is_instance_valid(wallet_label):
		wallet_label.text = "钱包余额  %d 点   ·   %s" % [session.state.wallet, "购买立即加入库存" if tab == "shop" else "家具摆放 / 电脑设备安装"]
	for id: String in purchase_buttons:
		if not is_instance_valid(purchase_buttons[id]): continue
		var item: MemoirItemDefinition = Catalog.lookup(id)
		var owned := InventoryData.owns(session.state.life["inventory"], id)
		purchase_buttons[id].disabled = (owned and item.category != "furniture") or session.state.wallet < item.price
