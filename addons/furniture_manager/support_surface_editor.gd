@tool
extends VBoxContainer
## A small staged editor. Only the Apply signal can mutate the opened furniture scene.
signal apply_requested(anchors: Array[Dictionary])
signal preview_changed(anchors: Array[Dictionary])
signal selection_changed(index: int)

const Surfaces = preload("res://scripts/room/furniture_support_surfaces.gd")
var anchors: Array[Dictionary] = []
var list: ItemList
var id_input: LineEdit
var center_inputs: Array[SpinBox] = []
var size_inputs: Array[SpinBox] = []
var apply_button: Button
var enabled_for_scene := false


func _ready() -> void:
	var heading := Label.new()
	heading.text = "承载面编辑（单位：米）"
	add_child(heading)
	list = ItemList.new()
	list.custom_minimum_size.y = 90
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_select_anchor)
	list.item_selected.connect(func(index: int) -> void: selection_changed.emit(index))
	add_child(list)

	var fields := GridContainer.new()
	fields.columns = 2
	add_child(fields)
	var id_label := Label.new()
	id_label.text = "锚点 ID"
	fields.add_child(id_label)
	id_input = LineEdit.new()
	id_input.placeholder_text = "例如 shelf_0"
	id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(id_input)
	for title in ["中心 X", "高度 Y", "中心 Z"]:
		_add_number(fields, title, center_inputs, -20.0, 20.0, 0.01)
	for title in ["宽度 X", "深度 Z"]:
		_add_number(fields, title, size_inputs, 0.01, 40.0, 0.01)

	var actions := HBoxContainer.new()
	add_child(actions)
	var add_button := Button.new()
	add_button.text = "新增"
	add_button.pressed.connect(_add_anchor)
	actions.add_child(add_button)
	var update_button := Button.new()
	update_button.text = "更新所选"
	update_button.pressed.connect(_update_anchor)
	actions.add_child(update_button)
	var remove_button := Button.new()
	remove_button.text = "删除所选"
	remove_button.pressed.connect(_remove_anchor)
	actions.add_child(remove_button)

	apply_button = Button.new()
	apply_button.text = "应用并保存当前家具场景"
	apply_button.disabled = true
	apply_button.pressed.connect(_request_apply)
	add_child(apply_button)


func _add_number(parent: Control, title: String, target: Array[SpinBox], low: float, high: float, step_value: float) -> void:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var spinner := SpinBox.new()
	spinner.min_value = low
	spinner.max_value = high
	spinner.step = step_value
	spinner.rounded = false
	spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if low > 0:
		spinner.value = 0.5
	parent.add_child(spinner)
	target.append(spinner)


func set_anchors(values: Array, can_apply: bool) -> void:
	anchors.clear()
	for raw in values:
		if raw is Dictionary:
			anchors.append(raw.duplicate(true))
	enabled_for_scene = can_apply
	_refresh_list()


func _refresh_list() -> void:
	if list == null:
		return
	list.clear()
	for anchor in anchors:
		list.add_item(str(anchor.id))
	apply_button.disabled = not enabled_for_scene
	if not anchors.is_empty():
		list.select(0)
		_select_anchor(0)
	else:
		id_input.text = ""
		for field in center_inputs:
			field.value = 0.0
		for field in size_inputs:
			field.value = 0.5


func _select_anchor(index: int) -> void:
	if index < 0 or index >= anchors.size():
		return
	var a := anchors[index]
	var c: Vector3 = a.center
	var sz: Vector2 = a.size
	id_input.text = a.id
	for i in range(3):
		center_inputs[i].value = c[i]
	size_inputs[0].value = sz.x
	size_inputs[1].value = sz.y


func select_anchor_index(index: int) -> void:
	if index < 0 or index >= anchors.size():
		return
	list.select(index)
	_select_anchor(index)


func update_from_preview(index: int, anchor: Dictionary) -> void:
	# Keep the numeric fields synchronized with dragging, but do not emit
	# preview_changed (the viewport has already applied this staged change).
	if index < 0 or index >= anchors.size():
		return
	var cleaned := Surfaces.clean_anchor(anchor)
	if cleaned.is_empty():
		return
	anchors[index] = cleaned
	list.set_item_text(index, str(cleaned.id))
	select_anchor_index(index)


func _build_anchor() -> Dictionary:
	return Surfaces.clean_anchor({
		"id": id_input.text.strip_edges(),
		"center": Vector3(center_inputs[0].value, center_inputs[1].value, center_inputs[2].value),
		"size": Vector2(size_inputs[0].value, size_inputs[1].value)
	})


func _add_anchor() -> void:
	var a := _build_anchor()
	if a.is_empty() or anchors.size() >= Surfaces.MAX_ANCHORS or _id_in_use(a.id):
		return
	anchors.append(a)
	_refresh_list()
	preview_changed.emit(anchors.duplicate(true))
	list.select(anchors.size() - 1)
	_select_anchor(anchors.size() - 1)


func _update_anchor() -> void:
	var indices := list.get_selected_items()
	if indices.is_empty():
		return
	var index: int = indices[0]
	var a := _build_anchor()
	if a.is_empty() or _id_in_use(a.id, index):
		return
	anchors[index] = a
	_refresh_list()
	preview_changed.emit(anchors.duplicate(true))
	list.select(index)
	_select_anchor(index)


func _remove_anchor() -> void:
	var indices := list.get_selected_items()
	if indices.is_empty():
		return
	anchors.remove_at(indices[0])
	_refresh_list()
	preview_changed.emit(anchors.duplicate(true))


func _id_in_use(id: String, except_index: int = -1) -> bool:
	for i in range(anchors.size()):
		if i != except_index and str(anchors[i].id) == id:
			return true
	return false


func validated_anchors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if anchors.size() > Surfaces.MAX_ANCHORS:
		return []
	var ids := {}
	for raw in anchors:
		var a := Surfaces.clean_anchor(raw)
		if a.is_empty() or ids.has(a.id):
			return []
		ids[a.id] = true
		result.append(a)
	return result


func _request_apply() -> void:
	if not enabled_for_scene or validated_anchors().size() != anchors.size():
		return
	apply_requested.emit(validated_anchors())
