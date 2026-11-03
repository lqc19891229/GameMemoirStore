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
var swatches: PanelContainer
var hint: Label
var category_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var color_buttons: Array[Button] = []
var _current_selection := ""

const GROUP_KEYS := ["", "tables", "seating", "storage", "lighting", "decor", "hardware"]
const GROUP_LABELS := ["全部", "桌子", "座椅", "收纳", "灯具", "装饰", "设备"]
const ACTIONS := [
	{"id":"move", "hint":"拖拽移动 · G 切换移动手柄"},
	{"id":"rotate", "hint":"旋转家具 · Shift+拖动 / Q/E 微调"},
	{"id":"paint", "hint":"选择单件家具颜色"},
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
	if not host.world.layout.active or host.blueprint_mode: return
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
		action_strip.add_child(button)
		action_buttons[key] = button
		button.pressed.connect(func() -> void: perform_action(key))
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
	if not host.world.layout.active or host.blueprint_mode: return
	var layout = host.world.layout
	if not layout.placing_role.is_empty(): return
	match id:
		"move":
			layout.set_tool("move")
			hide_colors()
		"rotate":
			layout.set_tool("rotate")
			hide_colors()
		"paint":
			swatches.visible = not swatches.visible
		"duplicate":
			layout.duplicate_selected()
			hide_colors()
		"store":
			layout.store_selected()
			hide_colors()
	room_ui.sync()

func apply_color(index: int) -> void:
	if index < 0 or index >= color_buttons.size(): return
	host.world.layout.set_furniture_color(index)
	hide_colors()
	room_ui.sync()

func hide_colors() -> void:
	if is_instance_valid(swatches): swatches.hide()

func sync(active: bool) -> void:
	var furniture_mode: bool = active and room_ui.mode == "furniture" and not host.blueprint_mode
	rail.visible = furniture_mode
	hint.visible = active and host.get_viewport().get_visible_rect().size.x >= 1060
	for index in range(GROUP_KEYS.size()):
		var button: Button = category_buttons[GROUP_KEYS[index]]
		button.set_pressed_no_signal(host.get_node("%FurnitureCatalogGroup").selected == index and room_ui.catalog_open)
	if not furniture_mode or room_ui.catalog_open:
		action_strip.hide()
		hide_colors()
		return
	var layout = host.world.layout
	var role: String = str(layout.selected)
	if role != _current_selection:
		hide_colors()
		_current_selection = role
	var eligible: bool = layout.nodes.has(role) and layout.placed_instances.has(role) and InventoryData.is_room_furniture_role(layout.Data.base_role(role))
	if not eligible or not layout.placing_role.is_empty() or not layout.gesture.is_empty():
		action_strip.hide()
		hide_colors()
		return
	action_buttons["move"].button_pressed = layout.tool == "move" if action_buttons["move"].toggle_mode else false
	action_buttons["duplicate"].disabled = InventoryData.unused_uid(layout.available_inventory,layout.placed_instances,InventoryData.furniture_item_id(layout.Data.base_role(role))).is_empty()
	action_strip.show()
	_reposition()
	if swatches.visible:
		for i in range(color_buttons.size()):
			var style := color_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
			style.border_color = Color("317a56") if layout.color_for(role) == i else Color("b9c9b9")
			style.set_border_width_all(3 if layout.color_for(role) == i else 2)

func _process(_delta: float) -> void:
	if action_strip != null and action_strip.visible:
		_reposition()

func resize(view: Vector2) -> void:
	if rail == null: return
	rail.position = Vector2(10 if view.x < 800 else 15,139 if view.y < 660 else 149)
	hint.visible = host.world.layout.active and view.x >= 1060
	hint.position = Vector2(maxf(510,view.x-640),84)
	hint.size = Vector2(maxf(0.0,view.x - hint.position.x - 20),30)

func _reposition() -> void:
	if action_strip == null or not action_strip.visible: return
	var layout = host.world.layout
	var role: String = str(layout.selected)
	if not layout.nodes.has(role):
		action_strip.hide()
		hide_colors()
		return
	var node: Node3D = layout.nodes[role]
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var camera: Camera3D = host.world.camera
	var world_point: Vector3 = node.global_position + Vector3.UP * (layout.bounds_for(role).y + .24)
	if camera.is_position_behind(world_point):
		action_strip.hide()
		hide_colors()
		return
	var pixel: Vector2 = camera.unproject_position(world_point)
	if pixel.x < 0 or pixel.y < 0 or pixel.x > view.x or pixel.y > view.y:
		action_strip.hide()
		hide_colors()
		return
	var total_width := float(ACTIONS.size()) * 43.0 + float(ACTIONS.size()-1) * 5.0
	action_strip.position = Vector2(clampf(pixel.x-total_width*.5,8, maxf(8,view.x-total_width-8)),clampf(pixel.y-76,124,maxf(124,view.y-114)))
	if swatches.visible:
		swatches.position = Vector2(clampf(action_strip.position.x+35,8,maxf(8,view.x-210)),clampf(action_strip.position.y+55,125,maxf(125,view.y-105)))
