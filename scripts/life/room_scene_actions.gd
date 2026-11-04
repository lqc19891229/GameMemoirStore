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
var group_button: Button
var group_panel: PanelContainer
var group_summary: Label
var group_member_list: VBoxContainer
var group_member_buttons: Dictionary = {}
var group_solo_button: Button
var _member_signature := ""
var quick_groups_button: Button
var quick_groups_panel: PanelContainer
var quick_slot_labels: Dictionary = {}
var quick_slot_buttons: Dictionary = {}
var swatches: PanelContainer
var arrange_panel: PanelContainer
var arrange_summary: Label
var arrange_buttons: Dictionary = {}
var hint: Label
var marquee_box: Panel
var group_copy_panel: PanelContainer
var group_copy_status: Label
var group_copy_readout: Label
var group_copy_rotate_left: Button
var group_copy_rotate_right: Button
var group_copy_find_space: Button
var group_copy_repeat_button: Button
var group_copy_confirm: Button
var group_copy_cancel: Button
var category_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var color_buttons: Array[Button] = []
var custom_color_picker: ColorPickerButton
var _picker_opening_color := Color.WHITE
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
	{"id":"mount", "hint":"把选中家具陈列到最近的空闲桌面或书架；再次点击取下"},
	{"id":"store", "hint":"收纳这件家具 · Delete"}
]

func setup(owner: Node3D, controller: Node, canvas: Control) -> void:
	host = owner
	room_ui = controller
	_build_categories(canvas)
	_build_quick_groups(canvas)
	_build_object_actions(canvas)
	_build_hint(canvas)
	_build_marquee(canvas)
	_build_group_copy_preview(canvas)
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

func _build_quick_groups(canvas: Control) -> void:
	# A fixed left-rail entry is reachable even after Esc collapses the group
	# or the current furniture is offscreen.
	quick_groups_button = _round_button("arrange","临时家具编组 · Ctrl+Shift+1～3 保存 / Alt+1～3 重选",43)
	quick_groups_button.name = "QuickFurnitureGroupsToggle"
	quick_groups_button.toggle_mode = true
	quick_groups_button.visible = true
	rail.add_child(quick_groups_button)
	rail.move_child(quick_groups_button,0)
	quick_groups_button.pressed.connect(func() -> void:
		quick_groups_panel.visible = not quick_groups_panel.visible
		hide_colors()
		hide_arrange()
		hide_group_members()
		_refresh_quick_groups()
		room_ui.sync()
	)
	quick_groups_panel = PanelContainer.new()
	quick_groups_panel.name = "QuickFurnitureGroupsPanel"
	quick_groups_panel.visible = false
	quick_groups_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	quick_groups_panel.custom_minimum_size = Vector2(346,0)
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("f4f6f2",0.98)
	shell.border_color = Color("9bbbaa")
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(10)
	shell.content_margin_left = 10
	shell.content_margin_right = 10
	shell.content_margin_top = 9
	shell.content_margin_bottom = 9
	quick_groups_panel.add_theme_stylebox_override("panel",shell)
	canvas.add_child(quick_groups_panel)
	var content := VBoxContainer.new()
	content.name = "QuickGroupsContent"
	content.add_theme_constant_override("separation",7)
	quick_groups_panel.add_child(content)
	var title := Label.new()
	title.name = "QuickGroupsTitle"
	title.text = "临时家具组合 · 本次编辑有效"
	title.add_theme_font_size_override("font_size",13)
	title.add_theme_color_override("font_color",Color("315341"))
	content.add_child(title)
	var note := Label.new()
	note.text = "Ctrl+Shift+数字 保存 · Alt+数字 重选"
	note.add_theme_font_size_override("font_size",11)
	note.add_theme_color_override("font_color",Color("556d5a"))
	content.add_child(note)
	for slot in range(1,4):
		var number: int = slot
		var row := HBoxContainer.new()
		row.name = "QuickGroupSlot_" + str(number)
		row.add_theme_constant_override("separation",4)
		content.add_child(row)
		var caption := Label.new()
		caption.name = "QuickGroupSummary_" + str(number)
		caption.custom_minimum_size = Vector2(142,32)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.clip_text = true
		caption.add_theme_font_size_override("font_size",11)
		row.add_child(caption)
		quick_slot_labels[number] = caption
		var controls := {}
		for action in ["save","recall","clear"]:
			var button := Button.new()
			button.name = "QuickSlot_%d_%s" % [number,action]
			button.text = {"save":"保存","recall":"重选","clear":"清空"}[action]
			button.custom_minimum_size = Vector2(52,32)
			button.tooltip_text = "%s快捷编组 %d" % [button.text,number]
			row.add_child(button)
			controls[action] = button
			var operation: String = action
			button.pressed.connect(func() -> void: perform_quick_slot(operation,number))
		quick_slot_buttons[number] = controls

func _refresh_quick_groups() -> void:
	if not is_instance_valid(quick_groups_panel): return
	var layout = host.world.layout
	for slot in range(1,4):
		var controls: Dictionary = quick_slot_buttons[slot]
		var summary: Label = quick_slot_labels[slot]
		summary.text = "%d · %s" % [slot,layout.quick_group_summary(slot)]
		summary.tooltip_text = summary.text
		controls["save"].disabled = layout.group_selection.size() < 2 or not layout.gesture.is_empty() or not layout.placing_role.is_empty()
		controls["recall"].disabled = layout.quick_group_size(slot) < 2
		controls["clear"].disabled = not layout.quick_groups.has(slot)

func perform_quick_slot(action: String, slot: int) -> bool:
	if not host.world.layout.active or host.blueprint_mode or room_ui.mode != "furniture" or room_ui.catalog_open: return false
	var layout = host.world.layout
	if not layout.gesture.is_empty() or not layout.placing_role.is_empty(): return false
	var ok := false
	match action:
		"save": ok = layout.save_quick_group(slot)
		"recall": ok = layout.recall_quick_group(slot)
		"clear": ok = layout.clear_quick_group(slot)
		_: return false
	if ok:
		var notice := ""
		match action:
			"save": notice = "已保存快捷编组 %d · %d 件" % [slot,layout.quick_group_size(slot)]
			"recall": notice = "已重选快捷编组 %d · %d 件" % [slot,layout.group_selection.size()]
			"clear": notice = "已清空快捷编组 %d" % slot
		room_ui.show_keyboard_feedback(notice)
		if action == "recall": hide_quick_groups()
	_refresh_quick_groups()
	room_ui.sync()
	return ok

func hide_quick_groups() -> void:
	if is_instance_valid(quick_groups_panel): quick_groups_panel.hide()
	if is_instance_valid(quick_groups_button): quick_groups_button.set_pressed_no_signal(false)

func open_category(index: int) -> void:
	if index < 0 or index >= GROUP_KEYS.size(): return
	if not host.world.layout.active or host.blueprint_mode or not host.world.layout.placing_role.is_empty(): return
	var group: OptionButton = host.get_node("%FurnitureCatalogGroup")
	group.select(index)
	host._update_catalog_types()
	room_ui.mode = "furniture"
	room_ui.catalog_open = true
	hide_colors()
	hide_quick_groups()
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
	# A small member manager appears only for actual multi-selection; the
	# existing solo ribbon keeps precisely its original six actions.
	group_button = Button.new()
	group_button.name = "GroupMembersToggle"
	group_button.text = "成员"
	group_button.tooltip_text = "查看多选家具 · 切换主控 · 移除成员"
	group_button.toggle_mode = true
	group_button.custom_minimum_size = Vector2(76,43)
	group_button.visible = false
	group_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_strip.add_child(group_button)
	group_button.pressed.connect(func() -> void:
		if host.world.layout.group_selection.size() < 2: return
		hide_colors()
		hide_arrange()
		group_panel.visible = not group_panel.visible
		_refresh_group_members()
		room_ui.sync()
	)
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
	var palette_content := VBoxContainer.new()
	palette_content.name = "PaletteContent"
	palette_content.add_theme_constant_override("separation", 7)
	swatches.add_child(palette_content)
	palette_content.add_child(grid)
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
	custom_color_picker = ColorPickerButton.new()
	custom_color_picker.name = "CustomRGBPicker"
	custom_color_picker.text = "自定义 RGB / HEX"
	custom_color_picker.color = Color("9fbed3")
	custom_color_picker.edit_alpha = false
	custom_color_picker.custom_minimum_size = Vector2(180, 34)
	custom_color_picker.tooltip_text = "选择自定义颜色，关闭选择器时提交一次，可撤销"
	palette_content.add_child(custom_color_picker)
	custom_color_picker.popup_closed.connect(func() -> void:
		if custom_color_picker.color.to_html(false) != _picker_opening_color.to_html(false):
			apply_custom_color(custom_color_picker.color)
	)
	_build_arrangement(canvas)
	_build_group_members(canvas)

func _build_group_members(canvas: Control) -> void:
	group_panel = PanelContainer.new()
	group_panel.name = "SelectedGroupMembersPanel"
	group_panel.visible = false
	group_panel.custom_minimum_size = Vector2(296,0)
	group_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("f4f6f2",0.98)
	shell.border_color = Color("9dbbaa")
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(10)
	shell.content_margin_left = 10
	shell.content_margin_right = 10
	shell.content_margin_top = 9
	shell.content_margin_bottom = 9
	group_panel.add_theme_stylebox_override("panel",shell)
	canvas.add_child(group_panel)
	var content := VBoxContainer.new()
	content.name = "GroupMembersContent"
	content.add_theme_constant_override("separation",6)
	group_panel.add_child(content)
	group_summary = Label.new()
	group_summary.name = "GroupMembersSummary"
	group_summary.add_theme_font_size_override("font_size",12)
	group_summary.add_theme_color_override("font_color",Color("315341"))
	content.add_child(group_summary)
	var scroll := ScrollContainer.new()
	scroll.name = "GroupMembersScroll"
	scroll.custom_minimum_size = Vector2(274,0)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(scroll)
	group_member_list = VBoxContainer.new()
	group_member_list.name = "GroupMembersList"
	group_member_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_member_list.add_theme_constant_override("separation",4)
	scroll.add_child(group_member_list)
	group_solo_button = Button.new()
	group_solo_button.name = "GroupRestoreSolo"
	group_solo_button.text = "仅保留主控家具 · Esc"
	group_solo_button.tooltip_text = "退出多选，不改变任何家具位置"
	group_solo_button.custom_minimum_size = Vector2(274,31)
	content.add_child(group_solo_button)
	group_solo_button.pressed.connect(func() -> void:
		host.world.layout.clear_group_selection()
		hide_group_members()
		room_ui.sync()
	)

func _refresh_group_members() -> void:
	var layout = host.world.layout
	if layout.group_selection.size() < 2:
		hide_group_members()
		return
	group_summary.text = "已选 %d 件 · 点击“设为主控”或移除成员" % layout.group_selection.size()
	var signature := "|".join(layout.group_selection)
	if signature != _member_signature:
		_member_signature = signature
		for old_row in group_member_list.get_children():
			group_member_list.remove_child(old_row)
			old_row.queue_free()
		group_member_buttons.clear()
		for role: String in layout.group_selection:
			var member_role := role
			var row := HBoxContainer.new()
			row.name = "GroupMember_" + member_role
			row.add_theme_constant_override("separation",5)
			group_member_list.add_child(row)
			var name_label := Label.new()
			name_label.text = layout.name_for(role)
			name_label.custom_minimum_size = Vector2(106,30)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.clip_text = true
			name_label.tooltip_text = role
			row.add_child(name_label)
			var primary := Button.new()
			primary.text = "设为主控"
			primary.custom_minimum_size = Vector2(75,30)
			primary.tooltip_text = "更换手柄的控制对象，不改变整组"
			row.add_child(primary)
			primary.pressed.connect(func() -> void:
				layout.set_primary_group_member(member_role)
				room_ui.sync()
			)
			var remove := Button.new()
			remove.text = "移除"
			remove.custom_minimum_size = Vector2(51,30)
			remove.tooltip_text = "仅从多选中移除，不收纳家具"
			row.add_child(remove)
			remove.pressed.connect(func() -> void:
				layout.remove_group_member(member_role)
				room_ui.sync()
			)
			group_member_buttons[member_role] = {"primary":primary,"remove":remove}
	for role: String in layout.group_selection:
		if not group_member_buttons.has(role): continue
		var primary: Button = group_member_buttons[role].primary
		primary.disabled = role == layout.selected
		primary.text = "主控中" if primary.disabled else "设为主控"
	var scroll: ScrollContainer = group_member_list.get_parent()
	scroll.custom_minimum_size.y = minf(196.0,float(layout.group_selection.size())*36.0)

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

func _build_marquee(canvas: Control) -> void:
	marquee_box = Panel.new()
	marquee_box.name = "FurnitureMarqueeBox"
	marquee_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marquee_box.visible = false
	var border := StyleBoxFlat.new()
	border.bg_color = Color("61d9ff",0.13)
	border.border_color = Color("35c4ed",0.92)
	border.set_border_width_all(2)
	border.set_corner_radius_all(3)
	marquee_box.add_theme_stylebox_override("panel",border)
	canvas.add_child(marquee_box)

func show_marquee(start: Vector2, finish: Vector2) -> void:
	if not is_instance_valid(marquee_box): return
	var rect := Rect2(start,finish-start).abs()
	var viewport: Vector2 = host.get_viewport().get_visible_rect().size
	var minimum: Vector2 = rect.position.max(Vector2.ZERO)
	var maximum: Vector2 = rect.end.min(viewport)
	marquee_box.position = minimum
	marquee_box.size = (maximum-minimum).max(Vector2.ONE)
	marquee_box.show()

func hide_marquee() -> void:
	if is_instance_valid(marquee_box): marquee_box.hide()

func _build_group_copy_preview(canvas: Control) -> void:
	group_copy_panel = PanelContainer.new()
	group_copy_panel.name = "GroupCopyConfirmPanel"
	group_copy_panel.custom_minimum_size = Vector2(424,0)
	group_copy_panel.visible = false
	group_copy_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("f4f8f3",.98)
	surface.border_color = Color("82bba4")
	surface.set_border_width_all(2)
	surface.set_corner_radius_all(10)
	surface.content_margin_left = 12
	surface.content_margin_right = 12
	surface.content_margin_top = 10
	surface.content_margin_bottom = 10
	group_copy_panel.add_theme_stylebox_override("panel",surface)
	canvas.add_child(group_copy_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",7)
	group_copy_panel.add_child(stack)
	var title := Label.new()
	title.name = "GroupCopyPreviewTitle"
	title.text = "整组复制预览 · 移动鼠标选择落点"
	title.add_theme_font_size_override("font_size",14)
	title.add_theme_color_override("font_color",Color("315341"))
	stack.add_child(title)
	group_copy_status = Label.new()
	group_copy_status.name = "GroupCopyPreviewStatus"
	group_copy_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group_copy_status.custom_minimum_size = Vector2(395,33)
	group_copy_status.add_theme_font_size_override("font_size",12)
	stack.add_child(group_copy_status)
	group_copy_readout = Label.new()
	group_copy_readout.name = "GroupCopyPreciseReadout"
	group_copy_readout.add_theme_font_size_override("font_size",12)
	group_copy_readout.add_theme_color_override("font_color",Color("455b4b"))
	stack.add_child(group_copy_readout)
	var precise := HBoxContainer.new()
	precise.name = "GroupCopyPrecisionActions"
	precise.add_theme_constant_override("separation",7)
	stack.add_child(precise)
	group_copy_rotate_left = Button.new()
	group_copy_rotate_left.name = "GroupCopyRotateLeft"
	group_copy_rotate_left.text = "左转 15° · Q"
	group_copy_rotate_left.custom_minimum_size = Vector2(125,32)
	precise.add_child(group_copy_rotate_left)
	group_copy_rotate_left.pressed.connect(func() -> void:
		host.world.layout.rotate_group_copy_preview_step(-1)
		room_ui.sync()
	)
	group_copy_rotate_right = Button.new()
	group_copy_rotate_right.name = "GroupCopyRotateRight"
	group_copy_rotate_right.text = "右转 15° · E"
	group_copy_rotate_right.custom_minimum_size = Vector2(125,32)
	precise.add_child(group_copy_rotate_right)
	group_copy_rotate_right.pressed.connect(func() -> void:
		host.world.layout.rotate_group_copy_preview_step(1)
		room_ui.sync()
	)
	group_copy_find_space = Button.new()
	group_copy_find_space.name = "GroupCopyFindSpace"
	group_copy_find_space.text = "寻找空位 · F"
	group_copy_find_space.custom_minimum_size = Vector2(130,32)
	group_copy_find_space.tooltip_text = "在当前落点附近寻找整组都能放下的位置；保持旋转角度"
	precise.add_child(group_copy_find_space)
	group_copy_find_space.pressed.connect(func() -> void:
		host.world.layout.find_group_copy_preview_space()
		room_ui.sync()
	)
	var precision_hint := Label.new()
	precision_hint.text = "方向键网格微调 · Shift+方向键 1cm · Shift+Q/E 1° · S 网格"
	precision_hint.add_theme_font_size_override("font_size",10)
	precision_hint.add_theme_color_override("font_color",Color("667c6d"))
	stack.add_child(precision_hint)
	group_copy_repeat_button = Button.new()
	group_copy_repeat_button.name = "GroupCopyRepeatToggle"
	group_copy_repeat_button.text = "连续复制：关闭 · 每次确认只复制一组"
	group_copy_repeat_button.toggle_mode = true
	group_copy_repeat_button.custom_minimum_size = Vector2(400,32)
	group_copy_repeat_button.tooltip_text = "开启后每次确认继续预览原来的家具组合；每组各占独立库存并分别可撤销"
	stack.add_child(group_copy_repeat_button)
	group_copy_repeat_button.pressed.connect(func() -> void:
		var layout = host.world.layout
		layout.set_group_copy_repeat(not layout.group_copy_repeat)
		room_ui.sync()
	)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",9)
	stack.add_child(actions)
	group_copy_confirm = Button.new()
	group_copy_confirm.name = "ConfirmGroupCopy"
	group_copy_confirm.text = "确认复制 · 左键 / Enter"
	group_copy_confirm.custom_minimum_size = Vector2(240,35)
	group_copy_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	actions.add_child(group_copy_confirm)
	group_copy_confirm.pressed.connect(func() -> void: confirm_group_copy_preview())
	group_copy_cancel = Button.new()
	group_copy_cancel.name = "CancelGroupCopy"
	group_copy_cancel.text = "取消 · Esc"
	group_copy_cancel.custom_minimum_size = Vector2(143,35)
	group_copy_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	actions.add_child(group_copy_cancel)
	group_copy_cancel.pressed.connect(func() -> void:
		host.world.layout.cancel_group_copy_preview()
		room_ui.sync()
	)

func confirm_group_copy_preview() -> void:
	var layout = host.world.layout
	if not layout.active or not layout.group_copy_preview_active: return
	if layout.confirm_group_copy_preview():
		var notice := "整组复制成功 · Ctrl+Z 撤销"
		if layout.group_copy_preview_active:
			notice = "已复制 %d 组 · 继续选择下一落点" % layout.group_copy_preview_placed_count
		elif not layout.group_copy_preview_end_reason.is_empty():
			notice = "连续复制已放置 %d 组 · 库存不足，自动结束" % layout.group_copy_preview_placed_count
		room_ui.show_keyboard_feedback(notice)
	room_ui.sync()

func _sync_group_copy_preview(view: Vector2) -> void:
	var layout = host.world.layout
	group_copy_panel.visible = layout.active and layout.group_copy_preview_active and not host.blueprint_mode and room_ui.mode == "furniture"
	if not group_copy_panel.visible: return
	group_copy_confirm.disabled = not layout.group_copy_preview_valid
	group_copy_repeat_button.set_pressed_no_signal(layout.group_copy_repeat)
	group_copy_repeat_button.text = "连续复制：开启 · 每组独立库存和撤销" if layout.group_copy_repeat else "连续复制：关闭 · 每次只放一组"
	group_copy_confirm.text = "确认并继续 · 左键 / Enter" if layout.group_copy_repeat else "确认复制 · 左键 / Enter"
	var pivot: Vector2 = layout.group_pivot()+layout.group_copy_preview_offset
	group_copy_readout.text = "组中心 X %.2f m · Z %.2f m · 旋转 %.0f° · 网格%s" % [
		pivot.x,pivot.y,rad_to_deg(layout.group_copy_preview_yaw),"开" if layout.snapping else "关"
	]
	group_copy_status.text = (
		"已放置 %d 组 · 下一组 %d 件 · 左键确认 · Esc 结束" % [layout.group_copy_preview_placed_count,layout.group_copy_preview_sources.size()]
		if layout.group_copy_repeat and layout.group_copy_preview_valid else
		"可复制 %d 件 · 左键放置 · 右键取消 · Alt 暂时关闭网格" % layout.group_copy_preview_sources.size()
		if layout.group_copy_preview_valid else
		"无法复制 · " + str(layout.group_copy_preview_error)
	)
	group_copy_status.add_theme_color_override("font_color",Color("2a7253") if layout.group_copy_preview_valid else Color("b24f49"))
	var surface: StyleBoxFlat = group_copy_panel.get_theme_stylebox("panel") as StyleBoxFlat
	surface.border_color = Color("82bba4") if layout.group_copy_preview_valid else Color("ce8d83")
	group_copy_panel.position = Vector2(
		clampf((view.x-424.0)*.5,8.0,maxf(8.0,view.x-432.0)),
		maxf(130.0,view.y-maxf(group_copy_panel.size.y,180.0)-20.0)
	)

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
	if not layout.placing_role.is_empty() or not layout.gesture.is_empty() or layout.group_copy_preview_active: return
	if layout.group_selection.size() > 1 and id not in ["move","rotate","paint","arrange","duplicate","store"]: return
	if id != "arrange": hide_arrange()
	if id != "paint": hide_colors()
	if id not in ["move","rotate"]: hide_group_members()
	match id:
		"move":
			layout.set_tool("move")
		"rotate":
			layout.set_tool("rotate")
		"paint":
			swatches.visible = not swatches.visible
			if swatches.visible:
				var current_finish: int = layout.group_color_index() if layout.group_selection.size() > 1 else layout.color_for(layout.selected)
				if current_finish >= 0:
					custom_color_picker.color = Finishes.color_for(current_finish)
				_picker_opening_color = custom_color_picker.color
		"arrange":
			hide_colors()
			arrange_panel.visible = not arrange_panel.visible
		"duplicate":
			if layout.group_selection.size() > 1:
				var started: bool = layout.begin_group_copy_preview()
				if not started: room_ui.show_keyboard_feedback("无法预览 · " + str(layout.message))
			else:
				layout.duplicate_selected()
		"mount":
			if layout.Data.base_role(layout.selected) == "poster_floor_frame":
				var wall_mounted: bool = layout.wall_mounts.has(layout.selected)
				var wall_success: bool = layout.take_down_selected_wall_mount() if wall_mounted else layout.hang_selected_on_wall()
				room_ui.show_keyboard_feedback(("已从墙上取下画框 · Ctrl+Z 撤销" if wall_mounted else "已挂到外墙 · Ctrl+Z 撤销") if wall_success else str(layout.message))
			else:
				var mounted: bool = layout.surface_mounts.has(layout.selected)
				var succeeded: bool = layout.unmount_selected() if mounted else layout.mount_selected_on_nearest_surface()
				room_ui.show_keyboard_feedback(("已取下陈列家具 · Ctrl+Z 撤销" if mounted else "已放上桌面/书架 · Ctrl+Z 撤销") if succeeded else str(layout.message))
		"store":
			if layout.group_selection.size() > 1:
				var count: int = layout.group_selection.size()
				if layout.store_group(): room_ui.show_keyboard_feedback("已收纳 %d 件 · Ctrl+Z 撤销" % count)
			else:
				layout.store_selected()
	room_ui.sync()

func perform_arrangement(id: String) -> void:
	if not arrange_buttons.has(id) or not arrange_panel.visible: return
	if not host.world.layout.active or host.blueprint_mode or room_ui.mode != "furniture" or room_ui.catalog_open: return
	var layout = host.world.layout
	if not layout.placing_role.is_empty() or not layout.gesture.is_empty(): return
	var role: String = str(layout.selected)
	if not layout.nodes.has(role) or not layout.placed_instances.has(role): return
	var multi: bool = layout.group_selection.size() > 1
	var is_alignment := id.begins_with("align_")
	var axis := "x" if id.ends_with("_x") else "z"
	var changed: bool
	if multi:
		changed = layout.align_group(axis) if is_alignment else layout.distribute_group(axis)
	else:
		changed = layout.align_selected(axis) if is_alignment else layout.distribute_matching_furniture(axis)
	if changed:
		room_ui.show_keyboard_feedback("%s · %s 轴%s完成 · Ctrl+Z 撤销" % ["整组" if multi else "家具",axis.to_upper(),"对齐" if is_alignment else "等距排列"])
	else:
		var reason := ""
		if multi:
			reason = str(layout.message) if str(layout.message).begins_with("整组排列受阻") else "已对齐、等距或目标会造成重叠"
		else:
			reason = "附近没有可安全对齐的家具" if is_alignment else "至少需要 3 件已摆放的同类家具" if layout._matching_furniture(role).size() < 3 else "位置已均匀或移动受到阻挡"
		room_ui.show_keyboard_feedback("未改变布局 · " + reason)
	room_ui.sync()

func apply_color(index: int) -> void:
	if index < 0 or index >= color_buttons.size(): return
	var layout = host.world.layout
	if layout.group_selection.size() > 1:
		var changed: bool = layout.set_group_furniture_color(index)
		if changed: room_ui.show_keyboard_feedback("已统一改色 %d 件 · Ctrl+Z 撤销" % layout.group_selection.size())
	else:
		layout.set_furniture_color(index)
	hide_colors()
	room_ui.sync()

func apply_custom_color(color: Color) -> void:
	var layout = host.world.layout
	var finish: int = Finishes.from_color(color)
	if layout.group_selection.size() > 1:
		if layout.set_group_furniture_color(finish):
			room_ui.show_keyboard_feedback("已为 %d 件家具应用自定义 RGB · Ctrl+Z 撤销" % layout.group_selection.size())
	else:
		layout.set_furniture_color(finish)
	hide_colors()
	room_ui.sync()

func hide_colors() -> void:
	if is_instance_valid(swatches): swatches.hide()

func hide_arrange() -> void:
	if is_instance_valid(arrange_panel): arrange_panel.hide()

func hide_group_members() -> void:
	if is_instance_valid(group_panel): group_panel.hide()
	if is_instance_valid(group_button): group_button.set_pressed_no_signal(false)

func _hide_object_actions() -> void:
	action_strip.hide()
	selection_chip.hide()
	hide_arrange()
	hide_group_members()

func _refresh_arrangement(role: String) -> void:
	var layout = host.world.layout
	var multi: bool = layout.group_selection.size() > 1
	var matching: Array[String] = layout._matching_furniture(role)
	if multi:
		var members: Array[String] = layout.group_selection
		arrange_summary.text = "当前多选 %d 件 · 与主控对齐 · 等距固定首尾" % members.size()
		for axis in ["x","z"]:
			var anchor: float = layout.nodes[role].position.x if axis == "x" else layout.nodes[role].position.z
			var needs_align := false
			var minimum := INF
			var maximum := -INF
			for member: String in members:
				var value: float = layout.nodes[member].position.x if axis == "x" else layout.nodes[member].position.z
				if absf(value-anchor) > .002: needs_align = true
				minimum = minf(minimum,value)
				maximum = maxf(maximum,value)
			arrange_buttons["align_" + axis].disabled = not needs_align
			arrange_buttons["space_" + axis].disabled = members.size() < 3 or maximum-minimum < .05
			arrange_buttons["align_" + axis].tooltip_text = "以主控家具为基准，沿 %s 轴对齐全部选中家具" % axis.to_upper()
			arrange_buttons["space_" + axis].tooltip_text = "沿 %s 轴等距排列当前多选家具，保持两端不动" % axis.to_upper()
	else:
		arrange_summary.text = "附近家具对齐 · 同类 %d 件%s" % [matching.size()," · 可等距排列" if matching.size() >= 3 else " · 等距需至少 3 件"]
		for axis in ["x","z"]:
			arrange_buttons["align_" + axis].disabled = layout.nearest_alignment(role,axis).is_empty()
			arrange_buttons["space_" + axis].disabled = matching.size() < 3
			arrange_buttons["align_" + axis].tooltip_text = "将选中家具与附近家具沿 %s 中心线对齐" % axis.to_upper()
			arrange_buttons["space_" + axis].tooltip_text = "将三件以上同类家具沿 %s 轴等间距排列" % axis.to_upper()

func sync(active: bool) -> void:
	var furniture_mode: bool = active and room_ui.mode == "furniture" and not host.blueprint_mode
	var preview: bool = host.world.layout.group_copy_preview_active
	_sync_group_copy_preview(host.get_viewport().get_visible_rect().size)
	rail.visible = furniture_mode and host.world.layout.placing_role.is_empty() and not preview
	quick_groups_button.set_pressed_no_signal(quick_groups_panel.visible)
	if not furniture_mode or room_ui.catalog_open or preview or not host.world.layout.gesture.is_empty() or not host.world.layout.placing_role.is_empty():
		hide_quick_groups()
	elif quick_groups_panel.visible:
		_refresh_quick_groups()
	hint.visible = active and not preview and host.get_viewport().get_visible_rect().size.x >= 1060
	hint.text = ("Ctrl+框选追加 · Alt+1～3 重选组合 · 拖动整组 · Esc 单选" if host.world.layout.group_selection.size() > 1 else "空白框选 · Ctrl+单击/框选 · Alt+1～3 重选组合 · Q/E 旋转 · S 网格%s" % ("开" if host.world.layout.snapping else "关"))
	for index in range(GROUP_KEYS.size()):
		var button: Button = category_buttons[GROUP_KEYS[index]]
		button.set_pressed_no_signal(host.get_node("%FurnitureCatalogGroup").selected == index and room_ui.catalog_open)
	if not furniture_mode or room_ui.catalog_open or preview:
		_hide_object_actions()
		hide_colors()
		hide_marquee()
		return
	var layout = host.world.layout
	var role: String = str(layout.selected)
	var group_size: int = layout.group_selection.size()
	if role != _current_selection or group_size != _current_group_size:
		hide_colors()
		hide_arrange()
		if group_size < 2: hide_group_members()
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
	group_button.visible = multi
	group_button.text = "成员 %d" % group_size if multi else "成员"
	group_button.set_pressed_no_signal(multi and group_panel.visible)
	if group_panel.visible: _refresh_group_members()
	action_buttons["paint"].disabled = false
	action_buttons["arrange"].disabled = false
	action_buttons["store"].disabled = false
	action_buttons["mount"].visible = not multi
	action_buttons["mount"].disabled = multi or layout._has_mounted_children(role)
	if layout.Data.base_role(role) == "poster_floor_frame":
		action_buttons["mount"].tooltip_text = "取下墙面画框并恢复原地面位置" if layout.wall_mounts.has(role) else "将画框挂到最近的可用内墙或外墙（避开门窗与已有装饰）"
	else:
		action_buttons["mount"].tooltip_text = "取下并恢复上次地面位置" if layout.surface_mounts.has(role) else "陈列到附近的空闲桌面或书架（需要足够空间）"
	action_buttons["move"].disabled = false
	action_buttons["rotate"].disabled = layout.wall_mounts.has(role)
	action_buttons["move"].tooltip_text = "拖动画框沿墙移动 · ←/→ 横移、↑/↓ 调高度 · Shift 精细调整 · Ctrl+Z 撤销" if layout.wall_mounts.has(role) else "沿当前承载面拖动或用方向键微调 · Ctrl+Z 撤销" if layout.surface_mounts.has(role) else "拖拽移动家具"
	action_buttons["rotate"].tooltip_text = "旋转陈列物 · Q/E 每次 15° · Shift 精细旋转" if layout.surface_mounts.has(role) else "旋转家具"
	action_buttons["arrange"].disabled = layout.surface_mounts.has(role)
	action_buttons["paint"].tooltip_text = "统一修改 %d 件家具的颜色" % group_size if multi else "选择单件家具颜色"
	action_buttons["arrange"].tooltip_text = "当前多选对齐与等距排列" if multi else "附近家具对齐 · 同类家具等距排列"
	action_buttons["store"].tooltip_text = "收纳全部 %d 件家具 · Delete · 可撤销" % group_size if multi else "收纳这件家具 · Delete"
	if arrange_panel.visible: _refresh_arrangement(role)
	if multi:
		var plan: Dictionary = layout.group_duplicate_plan()
		action_buttons["duplicate"].disabled = plan.has("error")
		action_buttons["duplicate"].tooltip_text = str(plan.error) if plan.has("error") else "预览 %d 件家具的复制落点 · Ctrl+D · 确认后一次撤销" % group_size
	else:
		var has_copy: bool = not InventoryData.unused_uid(layout.available_inventory,layout.placed_instances,InventoryData.furniture_item_id(layout.Data.base_role(role))).is_empty()
		action_buttons["duplicate"].disabled = not has_copy
		action_buttons["duplicate"].tooltip_text = "复制一件库存中的同款家具 · Ctrl+D" if has_copy else "同款家具没有可用库存 · 请先购买"
	_reposition()
	if swatches.visible:
		for i in range(color_buttons.size()):
			var style := color_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
			var selected_color: int = layout.group_color_index() if multi else layout.color_for(role)
			if Finishes.is_custom(selected_color):
				custom_color_picker.color = Finishes.color_for(selected_color)
			style.border_color = Color("317a56") if selected_color == i else Color("b9c9b9")
			style.set_border_width_all(3 if selected_color == i else 2)

func _process(_delta: float) -> void:
	if action_strip == null or not is_instance_valid(host): return
	if not host.world.layout.active or host.blueprint_mode or room_ui.mode != "furniture" or room_ui.catalog_open or host.world.layout.group_copy_preview_active: return
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
	_sync_group_copy_preview(view)
	rail.position = Vector2(10 if view.x < 800 else 15,139 if view.y < 660 else 149)
	hint.visible = host.world.layout.active and not host.world.layout.group_copy_preview_active and view.x >= 1060
	hint.position = Vector2(maxf(510,view.x-740),84)
	hint.size = Vector2(maxf(0.0,view.x - hint.position.x - 20),30)
	quick_groups_panel.position = Vector2(
		clampf(rail.position.x+54.0,8.0,maxf(8.0,view.x-356.0)),
		clampf(rail.position.y,120.0,maxf(120.0,view.y-quick_groups_panel.size.y-8.0))
	)

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
	# The full group ribbon stays above the shared pivot, independent of
	# which individual item is the primary selection.
	var world_point: Vector3 = layout.group_center_world_point() if layout.group_selection.size() > 1 else node.global_position + Vector3.UP * (layout.bounds_for(role).y + .24)
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
	if layout.group_selection.size() > 1: total_width += 76.0 + 5.0
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
	if group_panel.visible:
		var panel_width := maxf(296.0,group_panel.size.x)
		var panel_height := maxf(110.0,group_panel.size.y)
		var panel_y := action_strip.position.y + 53.0
		if panel_y+panel_height+8.0 > view.y: panel_y = action_strip.position.y-panel_height-8.0
		group_panel.position = Vector2(
			clampf(action_strip.position.x + (total_width-panel_width)*.5,8.0,maxf(8.0,view.x-panel_width-8.0)),
			clampf(panel_y,125.0,maxf(125.0,view.y-panel_height-8.0))
		)
