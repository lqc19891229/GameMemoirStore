@tool
extends VBoxContainer
## Editor-only viewer for existing MemoirItemDefinition resources.
## The catalog is authoritative; this tool never creates replacement item IDs.

const CATALOG_PATH := "res://data/items/_catalog.tres"
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")

var search_field: LineEdit
var group_filter: OptionButton
var show_retired: CheckBox
var item_tree: Tree
var info_label: RichTextLabel
var status_label: Label
var inspector_button: Button
var scene_button: Button
var catalog: MemoirItemCatalog
var selected_item: MemoirItemDefinition
var total_furniture := 0
var invalid_furniture := 0


func _ready() -> void:
	custom_minimum_size = Vector2(600, 270)
	_build_ui()
	refresh_catalog()


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	var title := Label.new()
	title.text = "家具资源库"
	toolbar.add_child(title)

	search_field = LineEdit.new()
	search_field.placeholder_text = "搜索名称、ID 或说明..."
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(search_field)
	search_field.text_changed.connect(func(_value: String) -> void: _populate_list())

	group_filter = OptionButton.new()
	group_filter.add_item("全部分类")
	for group in Taxonomy.GROUPS:
		if group.id != "hardware":
			group_filter.add_item(group.name)
			group_filter.set_item_metadata(group_filter.item_count - 1, group.id)
	toolbar.add_child(group_filter)
	group_filter.item_selected.connect(func(_index: int) -> void: _populate_list())

	show_retired = CheckBox.new()
	show_retired.text = "显示停用"
	toolbar.add_child(show_retired)
	show_retired.toggled.connect(func(_value: bool) -> void: _populate_list())

	var reload := Button.new()
	reload.text = "刷新"
	reload.tooltip_text = "重新读取 data/items/_catalog.tres"
	reload.pressed.connect(refresh_catalog)
	toolbar.add_child(reload)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	item_tree = Tree.new()
	item_tree.columns = 4
	item_tree.hide_root = true
	item_tree.set_column_title(0, "名称")
	item_tree.set_column_title(1, "分类")
	item_tree.set_column_title(2, "物品 ID")
	item_tree.set_column_title(3, "检查")
	item_tree.set_column_titles_visible(true)
	item_tree.set_column_expand(0, true)
	item_tree.set_column_expand(1, false)
	item_tree.set_column_custom_minimum_width(1, 85)
	item_tree.set_column_expand(2, true)
	item_tree.set_column_expand(3, false)
	item_tree.set_column_custom_minimum_width(3, 80)
	item_tree.custom_minimum_size.x = 400
	split.add_child(item_tree)
	item_tree.item_selected.connect(_on_item_selected)
	item_tree.item_activated.connect(_inspect_selected)

	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 215
	split.add_child(detail)

	var detail_title := Label.new()
	detail_title.text = "资源详情"
	detail.add_child(detail_title)

	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = false
	info_label.fit_content = false
	info_label.scroll_active = true
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_label.text = "从列表选择一件家具。"
	detail.add_child(info_label)

	inspector_button = Button.new()
	inspector_button.text = "在检查器中编辑商品"
	inspector_button.disabled = true
	inspector_button.pressed.connect(_inspect_selected)
	detail.add_child(inspector_button)

	scene_button = Button.new()
	scene_button.text = "打开家具场景"
	scene_button.disabled = true
	scene_button.pressed.connect(_open_scene)
	detail.add_child(scene_button)

	status_label = Label.new()
	add_child(status_label)


func refresh_catalog() -> void:
	catalog = ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirItemCatalog
	selected_item = null
	_populate_list()


func get_furniture_items() -> Array[MemoirItemDefinition]:
	var result: Array[MemoirItemDefinition] = []
	if catalog == null:
		return result
	for item: MemoirItemDefinition in catalog.items:
		if item != null and item.category == "furniture":
			result.append(item)
	return result


func validate_item(item: MemoirItemDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(item.item_id).strip_edges().is_empty():
		errors.append("缺少 item_id")
	if str(item.name).strip_edges().is_empty():
		errors.append("缺少名称")
	if str(item.subcategory).strip_edges().is_empty():
		errors.append("缺少摆放角色")
	if str(item.catalog_group) != "" and not Taxonomy.valid_group(item.catalog_group):
		errors.append("分类无效")
	if str(item.catalog_type) != "" and not Taxonomy.TYPES.has(item.catalog_type):
		errors.append("二级分类无效")
	if item.furniture_scene == null and not item.retired:
		errors.append("缺少家具场景")
	elif item.furniture_scene != null and str(item.furniture_scene.resource_path).is_empty():
		errors.append("家具场景缺少资源路径")
	return errors


func _populate_list() -> void:
	if item_tree == null:
		return
	item_tree.clear()
	var root := item_tree.create_item()
	total_furniture = 0
	invalid_furniture = 0
	var visible_count := 0
	var ids := {}
	var furniture := get_furniture_items()
	for item in furniture:
		var id := str(item.item_id)
		ids[id] = int(ids.get(id, 0)) + 1
	for item in furniture:
		total_furniture += 1
		var issues := validate_item(item)
		if int(ids.get(str(item.item_id), 0)) > 1:
			issues.append("重复 item_id")
		if not issues.is_empty():
			invalid_furniture += 1
		if item.retired and not show_retired.button_pressed:
			continue
		var selected_group := str(group_filter.get_item_metadata(group_filter.selected)) if group_filter.selected > 0 else ""
		if not selected_group.is_empty() and Taxonomy.group_for(item) != selected_group:
			continue
		var term := search_field.text.strip_edges().to_lower()
		var searchable := ("%s %s %s" % [item.name, item.item_id, item.description]).to_lower()
		if not term.is_empty() and not searchable.contains(term):
			continue
		var row := item_tree.create_item(root)
		row.set_text(0, item.name)
		row.set_text(1, Taxonomy.group_name(Taxonomy.group_for(item)))
		row.set_text(2, item.item_id)
		row.set_text(3, "问题 %d" % issues.size() if not issues.is_empty() else ("已停用" if item.retired else "正常"))
		row.set_metadata(0, item)
		row.set_tooltip_text(3, "\n".join(issues) if not issues.is_empty() else "资源检查通过")
		if not issues.is_empty():
			row.set_custom_color(3, Color(1.0, 0.48, 0.32))
		visible_count += 1
	selected_item = null
	_update_details()
	if catalog == null:
		status_label.text = "无法读取家具目录：%s" % CATALOG_PATH
	else:
		status_label.text = "家具 %d 件 · 当前显示 %d 件 · 存在问题 %d 件（含停用）" % [total_furniture, visible_count, invalid_furniture]


func _on_item_selected() -> void:
	var row := item_tree.get_selected()
	selected_item = row.get_metadata(0) as MemoirItemDefinition if row != null else null
	_update_details()


func _update_details() -> void:
	inspector_button.disabled = selected_item == null
	scene_button.disabled = selected_item == null or selected_item.furniture_scene == null
	if selected_item == null:
		info_label.text = "从列表选择一件家具。\n\n此管理器直接读取现有商品目录，不会改变玩家存档。"
		return
	var item := selected_item
	var issues := validate_item(item)
	var scene_path := "（未关联）"
	if item.furniture_scene != null:
		scene_path = item.furniture_scene.resource_path
	info_label.text = "名称：%s\n物品 ID：%s\n一级分类：%s\n二级类型：%s\n摆放角色：%s\n价格：%d\n是否停用：%s\n场景：%s\n\n资源检查：%s" % [
		item.name, item.item_id, Taxonomy.group_name(Taxonomy.group_for(item)),
		Taxonomy.type_name(Taxonomy.type_for(item)), item.subcategory,
		item.price, "是" if item.retired else "否",
		scene_path, "通过" if issues.is_empty() else "\n".join(issues)
	]


func _inspect_selected() -> void:
	if selected_item != null:
		EditorInterface.edit_resource(selected_item)


func _open_scene() -> void:
	if selected_item == null or selected_item.furniture_scene == null:
		return
	var path := selected_item.furniture_scene.resource_path
	if path.begins_with("res://") and ResourceLoader.exists(path):
		EditorInterface.open_scene_from_path(path)
