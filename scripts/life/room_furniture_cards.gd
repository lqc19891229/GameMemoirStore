extends Node
## Compact visual inventory backed by the same shared offscreen renderer as shop.
## All stock actions and item IDs are still owned by computer_desktop.gd.
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Thumbnails = preload("res://scripts/life/furniture_thumbnail_cache.gd")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
const Icons = preload("res://scripts/life/room_ui_icons.gd")
var host
var renderer
var cards: Dictionary = {}
var scroller: ScrollContainer
var last_requested: Dictionary = {}

func setup(desktop: Node3D) -> void:
	host = desktop
	renderer = Thumbnails.new()
	renderer.name = "RoomCardThumbnailCache"
	add_child(renderer)
	scroller = host.get_node("%FurnitureCatalogItems").get_parent() as ScrollContainer
	scroller.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: request_visible.call_deferred())
	for item: MemoirItemDefinition in Catalog.room_furniture():
		var button: Button = host.furniture_buttons.get(item.item_id)
		if button == null: continue
		button.text = ""
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(174, 152)
		button.clip_text = true
		var body := VBoxContainer.new()
		body.name = "VisualCard"
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.add_theme_constant_override("separation", 2)
		button.add_child(body)
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var thumb := TextureRect.new()
		thumb.name = "FurniturePreview"
		thumb.custom_minimum_size = Vector2(150, 91)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(thumb)
		var name_label := Label.new()
		name_label.name = "CardName"
		name_label.text = item.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.clip_text = true
		body.add_child(name_label)
		var stock := Label.new()
		stock.name = "StockStatus"
		stock.text = "库存检查中"
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock.add_theme_font_size_override("font_size", 11)
		stock.add_theme_color_override("font_color", Color("52705e"))
		stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(stock)
		cards[item.item_id] = {"button":button,"image":thumb,"stock":stock,"name":name_label}
	for role: String in host.catalog_special_buttons:
		var entry: Dictionary = host.catalog_special_buttons[role]
		var special: Button = entry.button
		special.custom_minimum_size = Vector2(174, 50)
		special.clip_text = true
		special.icon = Icons.texture(role)
	refresh_counts()

func refresh_counts() -> void:
	if not is_instance_valid(host): return
	for id: String in cards:
		var count: int = InventoryData.count(host.world.layout.available_inventory, id)
		var free: int = host._count_unused(id)
		var info: Dictionary = cards[id]
		var badge: Label = info.stock
		if count == 0:
			badge.text = "未拥有"
			badge.add_theme_color_override("font_color",Color("7e8580"))
		elif free == 0:
			badge.text = "已摆放 %d · 点击选中" % count
			badge.add_theme_color_override("font_color",Color("52705e"))
		else:
			badge.text = "可摆放 %d / 已拥有 %d" % [free, count]
			badge.add_theme_color_override("font_color",Color("286d4a"))

func request_visible() -> void:
	if not is_instance_valid(scroller) or not scroller.is_visible_in_tree(): return
	var frame: Rect2 = scroller.get_global_rect().grow(35)
	for id: String in cards:
		var info: Dictionary = cards[id]
		var button: Button = info.button
		if not button.visible: continue
		if not frame.intersects(button.get_global_rect()): continue
		if last_requested.has(id): continue
		var item: MemoirItemDefinition = Catalog.lookup(id)
		if item == null: continue
		renderer.request(item, info.image)
		last_requested[id] = true
