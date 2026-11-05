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
var quick_buttons: Dictionary = {}
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
	quick_buttons.clear()
	thumbnail_cache.forget_requests()
	_tick()
	var inventory: Array = session.state.life["inventory"]
	var placements: Dictionary = session.state.life["placements"]
	for item in Catalog.items:
		if not Catalog.matches_filters(item,_category(),_item_type(),%ShopCatalogSearch.text): continue
		var id := item.item_id
		var summary: Dictionary = InventoryData.stock_summary(inventory,placements,id)
		var count: int = int(summary.owned)
		if tab == "shop" and (item.price <= 0 or item.retired): continue
		if tab == "inventory" and count == 0: continue
		var row = preload("res://scenes/apps/browser/components/inventory_row.tscn").instantiate()
		box.add_child(row)
		row.get_node("%Title").text = item.name + (" ×%d" % count if tab == "inventory" and count > 1 else "")
		row.get_node("%Description").text = item.description
		var category_name := Taxonomy.group_name(Taxonomy.group_for(item))
		var type_name := Taxonomy.type_name(Taxonomy.type_for(item))
		var meta: Label = row.get_node("%FurnitureMeta")
		var stock_label: Label = row.get_node("%StockStatus")
		if item.category == "furniture":
			stock_label.text = "已拥有 %d · 可摆放 %d · 已摆放 %d" % [count,int(summary.available),int(summary.placed)]
		else:
			stock_label.text = "已拥有 %d" % count
		var preview_frame: Control = row.get_node("%ThumbnailBackdrop")
		preview_frame.visible = item.category == "furniture" and item.furniture_scene != null and not item.retired
		if preview_frame.visible:
			var model: Node3D = item.furniture_scene.instantiate()
			var bounds: Vector3 = model.get("bounds")
			model.free()
			meta.text = "%s / %s · %.2f × %.2f × %.2f m" % [category_name, type_name, bounds.x, bounds.y, bounds.z]
			row.get_node("%ThumbnailPlaceholder").text = type_name
			thumbnail_cache.request(item, row.get_node("%Thumbnail"), %ShopPreviewFinish.selected)
			# Expand the same real 3D preview with the selected finish on demand;
			# it shares a single render cache with all product thumbnails.
			var preview_toggle := Button.new()
			preview_toggle.name = "PreviewToggle"
			preview_toggle.text = "查看 3D 大图"
			preview_toggle.custom_minimum_size = Vector2(0,28)
			preview_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var enlarged := TextureRect.new()
			enlarged.name = "LargePreview"
			enlarged.visible = false
			enlarged.custom_minimum_size = Vector2(260,192)
			enlarged.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			enlarged.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			enlarged.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var details: VBoxContainer = row.get_node("%Text")
			details.add_child(preview_toggle)
			details.add_child(enlarged)
			preview_toggle.pressed.connect(func() -> void:
				enlarged.visible = not enlarged.visible
				preview_toggle.text = "收起 3D 大图" if enlarged.visible else "查看 3D 大图"
				if enlarged.visible: thumbnail_cache.request(item,enlarged,%ShopPreviewFinish.selected)
			)
		else:
			meta.text = "%s / %s" % [category_name, type_name]
		var button: Button = row.get_node("%Action")
		var quick: Button = row.get_node("%QuickAction")
		quick.visible = false
		var key := id
		row.get_node("%Price").visible = tab == "shop"
		if tab == "shop":
			row.get_node("%Price").text = "%d 点" % item.price
			var repeatable := item.category == "furniture"
			button.text = "购买" if repeatable or count == 0 else "已拥有"
			button.pressed.connect(func() -> void: message.text = session.buy_item(key))
			if item.category == "furniture" and item.placement_surface == "floor":
				quick.visible = true
				quick.text = "购买并摆放"
				quick.name = "BuyPlace_" + id
				quick.disabled = session.state.wallet < item.price
				quick.tooltip_text = "余额不足，还差 %d 点" % (item.price - session.state.wallet) if session.state.wallet < item.price else ""
				quick.pressed.connect(func() -> void: message.text = session.buy_and_place_furniture(key,%ShopPreviewFinish.selected))
				quick_buttons[id] = quick
			purchase_buttons[id] = button
			button.name = "Buy_" + id
			button.disabled = (count > 0 and not repeatable) or session.state.wallet < item.price
			button.tooltip_text = "余额不足，还差 %d 点" % (item.price - session.state.wallet) if session.state.wallet < item.price else ""
		else:
			button.name = "Equip_" + id
			if item.retired:
				button.text = "已收藏"
				button.disabled = true
				row.get_node("%Description").text = "保留的历史物品记录。"
			elif item.category == "furniture":
				var available: bool = int(summary.available) > 0
				var placed: bool = int(summary.placed) > 0
				button.text = "摆放" if available else "查看已摆放" if placed else "暂无库存"
				button.disabled = not available and not placed
				if available:
					button.pressed.connect(func() -> void:
						var finish: int = %ShopPreviewFinish.selected
						message.text = session.request_place_furniture(key,finish if finish > 0 else -1)
					)
				elif placed:
					button.pressed.connect(func() -> void: message.text = session.focus_placed_furniture(key))
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
		var shortfall: int = maxi(0, item.price - session.state.wallet)
		purchase_buttons[id].disabled = (owned and item.category != "furniture") or shortfall > 0
		purchase_buttons[id].text = "差 %d 点" % shortfall if shortfall > 0 else "已拥有" if owned and item.category != "furniture" else "购买"
		purchase_buttons[id].tooltip_text = "余额不足，还差 %d 点才能购买 %s" % [shortfall, item.name] if shortfall > 0 else ""
	for id: String in quick_buttons:
		if not is_instance_valid(quick_buttons[id]): continue
		var item: MemoirItemDefinition = Catalog.lookup(id)
		var shortfall: int = maxi(0, item.price - session.state.wallet)
		quick_buttons[id].disabled = shortfall > 0
		quick_buttons[id].text = "差 %d 点" % shortfall if shortfall > 0 else "购买并摆放"
		quick_buttons[id].tooltip_text = "余额不足，还差 %d 点才能购买并摆放 %s" % [shortfall, item.name] if shortfall > 0 else ""
