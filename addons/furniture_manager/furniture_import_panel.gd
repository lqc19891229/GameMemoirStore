@tool
extends VBoxContainer
## Batch import existing GLB/GLTF models as furniture PackedScene templates.
## No catalog writes, no overwrite, and no player-save changes.
signal scenes_created(paths: PackedStringArray)

const Importer = preload("res://addons/furniture_manager/furniture_importer.gd")
var folder_input: LineEdit
var model_list: ItemList
var summary: Label
var create_button: Button
var candidate_paths := PackedStringArray()
var candidate_destinations := PackedStringArray()


func _ready() -> void:
	custom_minimum_size = Vector2(480, 240)
	var label := Label.new()
	label.text = "批量模型导入 → 家具场景模板"
	add_child(label)
	var row := HBoxContainer.new()
	add_child(row)
	folder_input = LineEdit.new()
	folder_input.text = "res://assets/models/room"
	folder_input.placeholder_text = "res://assets/models/room/"
	folder_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(folder_input)
	var scan := Button.new()
	scan.text = "扫描"
	scan.pressed.connect(scan_models)
	row.add_child(scan)
	model_list = ItemList.new()
	model_list.select_mode = ItemList.SELECT_MULTI
	model_list.custom_minimum_size.y = 110
	model_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_list.multi_selected.connect(func(_index: int, _selected: bool) -> void: _update_status())
	add_child(model_list)
	create_button = Button.new()
	create_button.text = "为已选模型生成家具场景"
	create_button.disabled = true
	create_button.pressed.connect(create_selected)
	add_child(create_button)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	scan_models()


func scan_models() -> void:
	model_list.clear()
	candidate_paths.clear()
	candidate_destinations.clear()
	var results := Importer.list_models(folder_input.text.strip_edges())
	var unique_targets := {}
	for path in results:
		var target: String = Importer.scene_path_for(path)
		if target.is_empty():
			continue
		var legacy := "res://scenes/room/" + path.get_file().get_basename() + ".tscn"
		var already_exists := FileAccess.file_exists(target) or ResourceLoader.exists(target) or FileAccess.file_exists(legacy) or ResourceLoader.exists(legacy)
		var duplicates := unique_targets.has(target)
		unique_targets[target] = true
		var index := model_list.item_count
		model_list.add_item("%s  →  %s%s" % [
			path.get_file(), target.get_file(),
			" （已存在）" if already_exists else (" （名称冲突）" if duplicates else "")
		])
		candidate_paths.append(path)
		candidate_destinations.append(target)
		var blocked := already_exists or duplicates
		model_list.set_item_disabled(index, blocked)
		model_list.set_item_tooltip(index, "%s\n%s" % [path, target])
	_update_status()


func _update_status() -> void:
	var possible := 0
	for i in range(model_list.item_count):
		if not model_list.is_item_disabled(i):
			possible += 1
	create_button.disabled = model_list.get_selected_items().is_empty()
	summary.text = "扫描 %d 个模型，%d 个可生成。不会覆盖已有场景，也不会自动添加商品。" % [candidate_paths.size(), possible]


func create_selected() -> void:
	var selected := model_list.get_selected_items()
	if selected.is_empty():
		return
	var created := PackedStringArray()
	var errors := PackedStringArray()
	for index in selected:
		if model_list.is_item_disabled(index):
			continue
		var result: Dictionary = Importer.create_scene(candidate_paths[index], candidate_destinations[index])
		if result.get("ok", false):
			created.append(result.path)
		else:
			errors.append("%s：%s" % [candidate_paths[index].get_file(), result.get("error", "未知错误")])
	if not created.is_empty():
		EditorInterface.get_resource_filesystem().scan()
		scenes_created.emit(created)
	scan_models()
	summary.text = "生成 %d 个家具场景。%s" % [created.size(), "；".join(errors) if not errors.is_empty() else "可在文件系统中打开场景并调整参数。"]
