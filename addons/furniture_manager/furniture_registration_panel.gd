@tool
extends VBoxContainer
## A separate, opt-in review step after furniture scene import.
signal catalog_changed

const Registrar = preload("res://addons/furniture_manager/furniture_catalog_registrar.gd")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
var scene_choice: OptionButton
var id_input: LineEdit
var name_input: LineEdit
var role_input: LineEdit
var group_choice: OptionButton
var type_choice: OptionButton
var price_input: SpinBox
var description_input: LineEdit
var surface_mount_choice: CheckBox
var confirmation: CheckBox
var status: Label
var register_button: Button
var scenes := PackedStringArray()


func _ready() -> void:
	custom_minimum_size = Vector2(480, 270)
	var heading := Label.new()
	heading.text = "家具场景审核 → 注册商品（不会自动注册）"
	add_child(heading)
	var row := HBoxContainer.new()
	add_child(row)
	scene_choice = OptionButton.new()
	scene_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scene_choice)
	var refresh := Button.new()
	refresh.text = "刷新未注册场景"
	refresh.pressed.connect(refresh_scenes)
	row.add_child(refresh)
	id_input = _field("商品 ID（全局唯一）", "")
	name_input = _field("商城显示名称", "")
	role_input = _field("摆放角色（例如 side_table）", "")
	group_choice = OptionButton.new()
	for group in Taxonomy.GROUPS:
		if group.id != "hardware":
			group_choice.add_item(group.name)
			group_choice.set_item_metadata(group_choice.item_count - 1, group.id)
	add_child(group_choice)
	type_choice = OptionButton.new()
	var types: Array = Taxonomy.TYPES.keys()
	types.sort()
	for kind in types:
		type_choice.add_item(Taxonomy.type_name(kind))
		type_choice.set_item_metadata(type_choice.item_count - 1, kind)
	add_child(type_choice)
	price_input = SpinBox.new()
	price_input.min_value = 0
	price_input.max_value = 10000000
	price_input.step = 1
	price_input.prefix = "价格 "
	add_child(price_input)
	description_input = _field("商品说明（可选）", "")
	surface_mount_choice = CheckBox.new()
	surface_mount_choice.text = "允许放置在其他家具的承载面（适用于小型摆件）"
	add_child(surface_mount_choice)
	confirmation = CheckBox.new()
	confirmation.text = "我已检查场景、摆放尺寸、角色和商品 ID，确认新增商品"
	add_child(confirmation)
	confirmation.toggled.connect(func(_enabled: bool) -> void: _update_button())
	register_button = Button.new()
	register_button.text = "确认写入商品目录"
	register_button.pressed.connect(_register_selected)
	add_child(register_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	scene_choice.item_selected.connect(func(_index: int) -> void: _scene_changed())
	refresh_scenes()


func _field(hint: String, initial: String) -> LineEdit:
	var line := LineEdit.new()
	line.placeholder_text = hint
	line.text = initial
	add_child(line)
	return line


func refresh_scenes() -> void:
	scenes = Registrar.list_unregistered_scenes()
	scene_choice.clear()
	for scene_path in scenes:
		scene_choice.add_item(scene_path.get_file())
		scene_choice.set_item_tooltip(scene_choice.item_count - 1, scene_path)
	_scene_changed()


func _scene_changed() -> void:
	confirmation.button_pressed = false
	if not scenes.is_empty() and scene_choice.selected >= 0:
		var filename := scenes[scene_choice.selected].get_file().get_basename()
		id_input.text = filename
		name_input.text = filename.replace("_", " ")
		role_input.text = ""
	surface_mount_choice.button_pressed = false
	status.text = "可选 %d 个未注册场景。注册前请在编辑器中打开并审核场景。" % scenes.size()
	_update_button()


func _update_button() -> void:
	register_button.disabled = scenes.is_empty() or scene_choice.selected < 0 or not confirmation.button_pressed


func _fields() -> Dictionary:
	return {
		"item_id": id_input.text, "name": name_input.text,
		"role": role_input.text,
		"group": group_choice.get_item_metadata(group_choice.selected),
		"type": type_choice.get_item_metadata(type_choice.selected),
		"price": int(price_input.value), "description": description_input.text,
		"allow_surface_mount": surface_mount_choice.button_pressed
	}


func _register_selected() -> void:
	if register_button.disabled:
		return
	var path := scenes[scene_choice.selected]
	var errors: PackedStringArray = Registrar.validate_registration(path, _fields())
	if not errors.is_empty():
		status.text = "无法注册：" + "；".join(errors)
		return
	var result: Dictionary = Registrar.register(path, _fields(), confirmation.button_pressed)
	if not result.get("ok", false):
		status.text = "注册失败：" + str(result.get("error", "未知错误"))
		return
	refresh_scenes()
	status.text = "已注册 %s。原目录备份：%s" % [result.item_id, result.backup]
	catalog_changed.emit()
