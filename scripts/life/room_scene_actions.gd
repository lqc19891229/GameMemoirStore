extends Node
## Scene-first room interactions: compact left catalog categories and actions that
## travel with the selected piece of furniture. Existing layout APIs remain the
## only owners of inventory, undo, collisions and saved transformations.
const Icons = preload("res://scripts/life/room_ui_icons.gd")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
const Finishes = preload("res://scripts/items/furniture_finishes.gd")
const InventoryData = preload("res://scripts/items/inventory_data.gd")

var host
var room_ui
var rail: VBoxContainer
var action_strip: HBoxContainer
var selection_chip: Label
var swatches: PanelContainer
var arrange_panel: PanelContainer
var arrange_summary: Label
var arrange_buttons: Dictionary = {}
var hint: Label
var category_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var color_buttons: Array[Button] = []
var _current_selection := ""
var _current_group_size := 0

const GROUP_KEYS := ["", "tables", "seating", "storage", "lighting", "decor", "hardware"]
const GROUP_LABELS := ["全部", "桌子", "座椅", "收纳", "灯具", "装饰", "设备"]
const ACTIONS := [
	{"id":"move", "hint":"拖拽移动 · G 切换移动手柄"},
	{"id":"rotate", "hint":"旋转家具 · Shift+拖动 / Q/E 微调"},
	{"id":"paint", "hint":"选择单件家具颜色"},
	{"id":"arrange", "hint":"附近家具对齐 · 同类家具等距排列"},
	{"id":"duplicate", "hint":"复制一件库存中的同款家具 · Ctrl+D"},
	{"id":"store", "hint":"收纳这件家具 · Delete"}
]

func setup(owner: Node3D, controller: Node, canvas: Control) -> void:
	host = owner
	room_ui = controller
	_build_categories(canvas)
	_build_object_actions(canvas)
	_build_hint(canvas)
	set_process(true)

func _round_button(icon_id: String, tooltip: String, side: int = 43) -> Button:
	var button := Button.new()
	button.name = icon_id.capitalize()
	button.text = ""
	button.icon = Icons.texture(icon_id)
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(side,side)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("f3f5f0",0.96)
	surface.border_color = Color("b7c9b9",0.86)
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(side/2)
	button.add_theme_stylebox_override("normal",surface)
	var hover := surface.duplicate()
	hover.bg_color = Color("d7e7da")
	button.add_theme_stylebox_override("hover",hover)
	var pressed := surface.duplicate()
	pressed.bg_color = Color("cbe3d1")
	pressed.border_color = Color("317a56")
	pressed.set_border_width_all(2)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("hover_pressed",pressed)
	var disabled := surface.duplicate()
	disabled.bg_color = Color("eceeeb",0.88)
	disabled.border_color = Color("d3dad2")
	button.add_theme_stylebox_override("disabled",disabled)
	return button

func _build_categories(canvas: Control) -> void:
	rail = VBoxContainer.new()
	rail.name = "RoomCategoryRail"
	rail.position = Vector2(14,150)
	rail.add_theme_constant_override("separation",6)
	rail.visible = false
	canvas.add_child(rail)
	for index in range(GROUP_KEYS.size()):
		var key: String = GROUP_KEYS[index]
		var button := _round_button("all" if key.is_empty() else key, GROUP_LABELS[index],43)
		button.name = "Category_" + ("all" if key.is_empty() else key)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: open_category(index))
		category_buttons[key] = button
		rail.add_child(button)

func open_category(index: int) -> void:
	if index < 0 or index >= GROUP_KEYS.size(): return
	if not host.world.layout.active or host.blueprint_mode or not host.world.layout.placing_role.is_empty(): return
	var group: OptionButton = host.get_node("%FurnitureCatalogGroup")
	group.select(index)
	host._update_catalog_types()
	room_ui.mode = "furniture"
	room_ui.catalog_open = true
	hide_colors()
	room_ui.sync()

func _build_object_actions(canvas: Control) -> void:
	action_strip = HBoxContainer.new()
	action_strip.name = "RoomObjectActions"
	action_strip.add_theme_constant_override("separation",5)
	# Container must participate in hit testing for its real Button children.
	# Mouse-ignore here made the contextual tools look clickable but allowed
	# clicks to fall through into the 3D room instead.
	action_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	action_strip.visible = false
	canvas.add_child(action_strip)
	for spec: Dictionary in ACTIONS:
		var key: String = spec.id
		var button := _round_button(key,str(spec.hint),43)
		button.name = "Action_" + key
		button.toggle_mode = key in ["move","rotate","paint","arrange"]
		action_strip.add_child(button)
		action_buttons[key] = button
		button.pressed.connect(func() -> void: perform_action(key))
	# Display the current selection without blocking object picking or buttons.
	selection_chip = Label.new()
	selection_chip.name = "SelectedFurnitureChip"
	selection_chip.visible = false
	selection_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_chip.clip_text = true
	selection_chip.custom_minimum_size = Vector2(170,31)
	selection_chip.add_theme_font_size_override("font_size",12)
	selection_chip.add_theme_color_override("font_color",Color("315341"))
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color("f4f6f2",0.95)
	tag_style.border_color = Color("b7c9b9",0.86)
	tag_style.set_border_width_all(1)
	tag_style.set_corner_radius_all(9)
	tag_style.content_margin_left = 9.0
	tag_style.content_margin_right = 9.0
	tag_style.content_margin_top = 6.0
	tag_style.content_margin_bottom = 6.0
	selection_chip.add_theme_stylebox_override("normal",tag_style)
	canvas.add_child(selection_chip)
	swatches = PanelContainer.new()
	swatches.name = "ObjectColorPalette"
	swatches.visible = false
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("f4f6f2",0.97)
	shell.border_color = Color("b3c6b5")
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(10)
	shell.content_margin_left = 9
	shell.content_margin_top = 9
	shell.content_margin_right = 9
	shell.content_margin_bottom = 9
	swatches.add_theme_stylebox_override("panel",shell)
	canvas.add_child(swatches)
	var grid := GridContainer.new()
	grid.name = "SwatchGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	swatches.add_child(grid)
	for i in range(Finishes.LABELS.size()):
		var color_index := i
		var button := Button.new()
		button.name = "Finish_" + str(i)
		button.custom_minimum_size = Vector2(31,31)
		button.text = "原" if i == 0 else ""
		button.tooltip_text = Finishes.LABELS[i]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f4f2eb") if i == 0 else Color(Finishes.HEX[i])
		style.set_corner_radius_all(17)
		style.set_border_width_all(2)
		style.border_color = Color("b9c9b9")
		button.add_theme_stylebox_override("normal",style)
		button.add_theme_stylebox_override("hover",style)
		grid.add_child(button)
		color_buttons.append(button)
		button.pressed.connect(func() -> void: apply_color(color_index))
	_build_arrangement(canvas)

func _build_arrangement(canvas: Control) -> void:
	arrange_panel = PanelContainer.new()
	arrange_panel.name = "ObjectArrangementPanel"
	arrange_panel.visible = false
	arrange_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	arrange_panel.custom_minimum_size = Vector2(294,0)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("f4f6f2",0.97)
	surface.border_color = Color("b3c6b5",0.96)
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(10)
	surface.content_margin_left = 10
	surface.content_margin_top = 10
	surface.content_margin_right = 10
	surface.content_margin_bottom = 10
	arrange_panel.add_theme_stylebox_override("panel",surface)
	canvas.add_child(arrange_panel)
	var column := VBoxContainer.new()
	column.name = "ArrangementContent"
	column.add_theme_constant_override("separation",7)
	arrange_panel.add_child(column)
	arrange_summary = Label.new()
	arrange_summary.name = "ArrangementSummary"
	arrange_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arrange_summary.custom_minimum_size = Vector2(268,38)
	arrange_summary.add_theme_font_size_override("font_size",12)
	arrange_summary.add_theme_color_override("font_color",Color("315341"))
	column.add_child(arrange_summary)
	var grid := GridContainer.new()
	grid.name = "ArrangementButtons"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	column.add_child(grid)
	for spec: Dictionary in [
		{"id":"align_x","label":"X 轴对齐","hint":"将选中家具与附近家具沿 X 中心线对齐"},
		{"id":"align_z","label":"Z 轴对齐","hint":"将选中家具与附近家具沿 Z 中心线对齐"},
		{"id":"space_x","label":"X 轴等距","hint":"将三件以上同类家具沿 X 方向等间距排列"},
		{"id":"space_z","label":"Z 轴等距","hint":"将三件以上同类家具沿 Z 方向等间距排列"}
	]:
		var id: String = str(spec.id)
		var button := Button.new()
		button.name = "Arrange_" + id
		button.text = str(spec.label)
		button.tooltip_text = str(spec.hint)
		button.custom_minimum_size = Vector2(130,34)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		grid.add_child(button)
		arrange_buttons[id] = button
		button.pressed.connect(func() -> void: perform_arrangement(id))

func _build_hint(canvas: Control) -> void:
	hint = Label.new()
	hint.name = "RoomInteractionHint"
	hint.text = "左侧选择家具  ·  拖动移动  ·  Shift+拖动旋转  ·  Tab 蓝图  ·  B 物品"
	hint.add_theme_font_size_override("font_size",12)
	hint.add_theme_color_override("font_color",Color("455b4b"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	canvas.add_child(hint)

func perform_action(id: String) -> void:
	if not host.world.layout.active or host.blueprint_mode or room_ui.catalog_open: return
	var layout = host.world.layout
	if not layout.placing_role.is_empty() or not layout.gesture.is_empty(): return
	if layout.group_selection.size() > 1 and id not in ["move","rotate"]: return
	if id != "arrange": hide_arrange()
	if id != "paint": hide_colors()
	match id:
		"move":
			layout.set_tool("move")
		"rotate":
			layout.set_tool("rotate")
		"paint":
			swatches.visible = not swatches.visible
		"arrange":
			hide_colors()
			arrange_panel.visible = not arrange_panel.visible
		"duplicate":
			layout.duplicate_selected()
		"store":
			layout.store_selected()
	room_ui.sync()

func perform_arrangement(id: String) -> void:
	if not arrange_buttons.has(id) or not arrange_panel.visible: return
	if not host.world.layout.active or host.blueprint_mode or room_ui.mode != "furniture" or room_ui.catalog_open: return
	var layout = host.world.layout
	if not layout.placing_role.is_empty() or not layout.gesture.is_empty() or layout.group_selection.size() > 1: return
	var role: String = str(layout.selected)
	if not layout.nodes.has(role) or not layout.placed_instances.has(role): return
	var is_alignment := id.begins_with("align_")
	var axis := "x" if id.ends_with("_x") else "z"
	var changed: bool = layout.align_selected(axis) if is_alignment else layout.distribute_matching_furniture(axis)
	if changed:
		room_ui.show_keyboard_feedback("%s 轴%s完成 · Ctrl+Z 撤销" % [axis.to_upper(),"对齐" if is_alignment else "等距排列"])
	else:
		var reason := "附近没有可安全对齐的家具" if is_alignment else "至少需要 3 件已摆放的同类家具" if layout._matching_furniture(role).size() < 3 else "位置已均匀或移动受到阻挡"
		room_ui.show_keyboard_feedback("未改变布局 · " + reason)
	room_ui.sync()

func apply_color(index: int) -> void:
	if index < 0 or index >= color_buttons.size(): return
	host.world.layout.set_furniture_color(index)
	hide_colors()
	room_ui.sync()

func hide_colors() -> void:
	if is_instance_valid(swatches): swatches.hide()

func hide_arrange() -> void:
	if is_instance_valid(arrange_panel): arrange_panel.hide()

func _hide_object_actions() -> void:
	action_strip.hide()
	selection_chip.hide()
	hide_arrange()

func _refresh_arrangement(role: String) -> void:
	var layout = host.world.layout
	var matching: Array[String] = layout._matching_furniture(role)
	arrange_summary.text = "附近家具对齐 · 同类 %d 件%s" % [matching.size()," · 可等距排列" if matching.size() >= 3 else " · 等距需至少 3 件"]
	for axis in ["x","z"]:
		arrange_buttons["align_" + axis].disabled = layout.nearest_alignment(role,axis).is_empty()
		arrange_buttons["space_" + axis].disabled = matching.size() < 3

func sync(active: bool) -> void:
	var furniture_mode: bool = active and room_ui.mode == "furniture" and not host.blueprint_mode
	rail.visible = furniture_mode and host.world.layout.placing_role.is_empty()
	hint.visible = active and host.get_viewport().get_visible_rect().size.x >= 1060
	hint.text = ("Ctrl+单击 多选 · 拖动整组 · Shift+拖动 旋转 · Esc 单选" if host.world.layout.group_selection.size() > 1 else "Ctrl+单击 多选 · 方向键 微调 · Shift+方向键 1cm · Q/E 旋转 · S 网格%s" % ("开" if host.world.layout.snapping else "关"))
	for index in range(GROUP_KEYS.size()):
		var button: Button = category_buttons[GROUP_KEYS[index]]
		button.set_pressed_no_signal(host.get_node("%FurnitureCatalogGroup").selected == index and room_ui.catalog_open)
	if not furniture_mode or room_ui.catalog_open:
		_hide_object_actions()
		hide_colors()
		return
	var layout = host.world.layout
	var role: String = str(layout.selected)
	var group_size: int = layout.group_selection.size()
	if role != _current_selection or group_size != _current_group_size:
		hide_colors()
		hide_arrange()
		_current_selection = role
		_current_group_size = group_size
	var eligible: bool = layout.nodes.has(role) and layout.placed_instances.has(role) and InventoryData.is_room_furniture_role(layout.Data.base_role(role))
	if not eligible or not layout.placing_role.is_empty() or not layout.gesture.is_empty():
		_hide_object_actions()
		hide_colors()
		return
	action_buttons["move"].set_pressed_no_signal(layout.tool == "move")
	action_buttons["rotate"].set_pressed_no_signal(layout.tool == "rotate")
	action_buttons["paint"].set_pressed_no_signal(swatches.visible)
	action_buttons["arrange"].set_pressed_no_signal(arrange_panel.visible)
	var multi: bool = group_size > 1
	for action_id in ["paint","arrange","store"]:
		action_buttons[action_id].disabled = multi
		action_buttons[action_id].tooltip_text = "多选时仅支持整组移动与旋转 · Esc 返回单选" if multi else str(ACTIONS.filter(func(spec: Dictionary) -> bool: return spec.id == action_id)[0].hint)
	if arrange_panel.visible: _refresh_arrangement(role)
	var has_copy: bool = not InventoryData.unused_uid(layout.available_inventory,layout.placed_instances,InventoryData.furniture_item_id(layout.Data.base_role(role))).is_empty()
	action_buttons["duplicate"].disabled = multi or not has_copy
	action_buttons["duplicate"].tooltip_text = "多选时仅支持整组移动与旋转" if multi else "复制一件库存中的同款家具 · Ctrl+D" if has_copy else "同款家具没有可用库存 · 请先购买"
	_reposition()
	if swatches.visible:
		for i in range(color_buttons.size()):
			var style := color_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
			style.border_color = Color("317a56") if layout.color_for(role) == i else Color("b9c9b9")
			style.set_border_width_all(3 if layout.color_for(role) == i else 2)

func _process(_delta: float) -> void:
	if action_strip == null or not is_instance_valid(host): return
	if not host.world.layout.active or host.blueprint_mode or room_ui.mode != "furniture" or room_ui.catalog_open: return
	var layout = host.world.layout
	var role: String = str(layout.selected)
	if not layout.nodes.has(role) or not layout.placed_instances.has(role): return
	if not InventoryData.is_room_furniture_role(layout.Data.base_role(role)): return
	if not layout.placing_role.is_empty() or not layout.gesture.is_empty(): return
	# Re-project even while hidden, so orbiting the camera back into view
	# restores object actions without needing to reselect the furniture.
	_reposition()

func resize(view: Vector2) -> void:
	if rail == null: return
	rail.position = Vector2(10 if view.x < 800 else 15,139 if view.y < 660 else 149)
	hint.visible = host.world.layout.active and view.x >= 1060
	hint.position = Vector2(maxf(510,view.x-640),84)
	hint.size = Vector2(maxf(0.0,view.x - hint.position.x - 20),30)

func _reposition() -> void:
	if action_strip == null: return
	var layout = host.world.layout
	var role: String = str(layout.selected)
	if not layout.nodes.has(role):
		_hide_object_actions()
		hide_colors()
		return
	var node: Node3D = layout.nodes[role]
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var camera: Camera3D = host.world.camera
	var world_point: Vector3 = node.global_position + Vector3.UP * (layout.bounds_for(role).y + .24)
	if camera.is_position_behind(world_point):
		_hide_object_actions()
		hide_colors()
		return
	var pixel: Vector2 = camera.unproject_position(world_point)
	if pixel.x < 0 or pixel.y < 0 or pixel.x > view.x or pixel.y > view.y:
		_hide_object_actions()
		hide_colors()
		return
	var total_width := float(ACTIONS.size()) * 43.0 + float(ACTIONS.size()-1) * 5.0
	action_strip.position = Vector2(clampf(pixel.x-total_width*.5,8, maxf(8,view.x-total_width-8)),clampf(pixel.y-76,164,maxf(164,view.y-114)))
	selection_chip.text = "已选 %d 件 · %s" % [layout.group_selection.size(),layout.name_for(role)] if layout.group_selection.size() > 1 else "已选 · %s" % layout.name_for(role)
	selection_chip.tooltip_text = "整组：" + "、".join(layout.group_selection) if layout.group_selection.size() > 1 else layout.name_for(role)
	selection_chip.position = Vector2(clampf(action_strip.position.x+(total_width-170.0)*.5,8.0,maxf(8.0,view.x-178.0)),action_strip.position.y-36.0)
	selection_chip.show()
	action_strip.show()
	if swatches.visible:
		swatches.position = Vector2(clampf(action_strip.position.x+35,8,maxf(8,view.x-210)),clampf(action_strip.position.y+55,125,maxf(125,view.y-105)))
	if arrange_panel.visible:
		var panel_width := maxf(294.0,arrange_panel.size.x)
		var panel_height := maxf(174.0,arrange_panel.size.y)
		var below := action_strip.position.y + 53.0
		var panel_y := below if below+panel_height+10.0 <= view.y else action_strip.position.y-panel_height-8.0
		arrange_panel.position = Vector2(
			clampf(action_strip.position.x + (total_width-panel_width)*.5,8.0,maxf(8.0,view.x-panel_width-8.0)),
			clampf(panel_y,125.0,maxf(125.0,view.y-panel_height-8.0))
		)
