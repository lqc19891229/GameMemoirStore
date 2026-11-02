extends Node
const Icons = preload("res://scripts/life/room_ui_icons.gd")
## Room-only presentation layer. Existing controls keep their unique Godot names,
## signals, item IDs and save contracts. PC apps retain the original client theme.
var host # Dynamic controller: the room desktop owns its custom world/layout API.
var mode := "furniture"
var advanced := false
var catalog_open := true
var last_selected := "desk"
var was_active := false
var dock: PanelContainer
var bar: HBoxContainer
var catalog_toggle: Button
var advanced_toggle: Button
var mode_buttons: Dictionary = {}
var inspector_content: VBoxContainer
var blueprint_content: VBoxContainer
var _last_dock_visible := false
var _last_mode := ""
var _last_dimensions := Vector2.ZERO
var _catalog_scroller: ScrollContainer
var _filter_row: HBoxContainer
var _filter_parent: VBoxContainer
var _inspector: PanelContainer

const CORE_INSPECTOR := {
	"furniture": ["LayoutSelection","Tools","Copies","FurniturePaletteLabel","FurniturePalette","LayoutMessage"],
	"decor": ["StyleLabel","Style_wall","Style_floor","Style_wall_pattern","Style_floor_pattern"],
	"lighting": ["StyleLabel","Style_light","Style_rgb","Style_effect","Style_brightness","Style_atmosphere"]
}
const ADVANCED_INSPECTOR := ["Objects","Angles","SnapLayout","LayoutPose","LayoutSize","WallSnapToggle","FurnitureAssistsTitle","InnerWallSnapToggle","FurnitureAssistHint","FurnitureAlignmentTools","FurnitureDistributeTools","RestoreLayout","Layout_sofa","Layout_stool"]
const CORE_BLUEPRINT := ["BlueprintTitle","BlueprintQuickTools","BlueprintGridToggle","BlueprintFloorTool","BlueprintShapeLabel","BlueprintShape","BlueprintStatus"]

func setup(owner_node: Node3D) -> void:
	host = owner_node
	var canvas: Control = host.get_node("HUD/Interface")
	var header: ColorRect = canvas.get_node("HeaderBackground")
	header.color = Color("f4f5f0", .96)
	var title: Label = host.get_node("%ViewTitle")
	title.text = "我的空间"
	for name: String in ["ResetView","EditLayout","CancelLayout","ReturnOverview","ManageDevices","BlueprintToggle"]:
		var button: Button = host.get_node("%"+name)
		button.theme_type_variation = ""
	for name: String in ["FocusToggle","ApplyLayout"]:
		var button: Button = host.get_node("%"+name)
		button.theme_type_variation = "MinimalAccentButton"
	var inspector: PanelContainer = host.get_node("%LayoutPanel")
	_inspector = inspector
	inspector.anchor_left = 1.0
	inspector.anchor_right = 1.0
	inspector.anchor_top = 0.0
	inspector.anchor_bottom = 1.0
	inspector.offset_left = -326.0
	inspector.offset_right = -22.0
	inspector.offset_top = 137.0
	inspector.offset_bottom = -18.0
	inspector_content = host.get_node("%Content")
	blueprint_content = host.get_node("%BlueprintPanel")
	_build_bar(canvas)
	_build_dock(canvas)
	host.get_viewport().size_changed.connect(_resize_layout)
	_resize_layout()
	sync()

func _button(text_value: String, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 38)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _build_bar(canvas: Control) -> void:
	bar = HBoxContainer.new()
	bar.name = "RoomModeBar"
	bar.position = Vector2(27, 79)
	bar.size = Vector2(775, 45)
	bar.add_theme_constant_override("separation", 8)
	canvas.add_child(bar)
	for entry: Dictionary in [
		{"id":"furniture","label":"家具"},
		{"id":"decor","label":"装修"},
		{"id":"lighting","label":"灯光"},
		{"id":"build","label":"建造"}
	]:
		var id: String = entry.id
		var button := _button(str(entry.label))
		button.toggle_mode = true
		button.icon = Icons.texture(id)
		button.custom_minimum_size.x = 69
		button.pressed.connect(func() -> void: choose_mode(id))
		bar.add_child(button)
		mode_buttons[id] = button
	var space := Control.new()
	space.custom_minimum_size.x = 15
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(space)
	catalog_toggle = _button("收起目录", "显示或隐藏底部家具目录")
	catalog_toggle.icon = Icons.texture("catalog")
	catalog_toggle.pressed.connect(func() -> void:
		catalog_open = not catalog_open
		sync()
	)
	bar.add_child(catalog_toggle)
	advanced_toggle = _button("高级", "展开完整坐标、吸附、对齐、蓝图等精细选项")
	advanced_toggle.icon = Icons.texture("advanced")
	advanced_toggle.pressed.connect(func() -> void:
		advanced = not advanced
		sync()
	)
	bar.add_child(advanced_toggle)
	# The original undo/redo controls remain wired to the existing transaction
	# stack; only their physical location changes to the top bar.
	var history: HBoxContainer = inspector_content.get_node("History")
	history.reparent(bar)
	for child: Control in history.get_children():
		child.custom_minimum_size.x = 60
		if child is Button:
			child.icon = Icons.texture("undo" if child.name == "UndoLayout" else "redo")

func _build_dock(canvas: Control) -> void:
	dock = PanelContainer.new()
	dock.name = "RoomCatalogDock"
	dock.anchor_left = 0.0
	dock.anchor_top = 1.0
	dock.anchor_right = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = 27.0
	dock.offset_top = -296.0
	dock.offset_right = -348.0
	dock.offset_bottom = -18.0
	canvas.add_child(dock)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	dock.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	margin.add_child(body)
	var inventory: VBoxContainer = host.get_node("HUD/Interface/LayoutPanel/Margin/Scroll/Content/FurnitureInventory")
	inventory.reparent(body)
	inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A compact single-line filter row replaces stacked filters.
	var controls: VBoxContainer = inventory.get_node("FurnitureCatalogControls")
	_filter_parent = controls
	var filter_row := HBoxContainer.new()
	_filter_row = filter_row
	filter_row.add_theme_constant_override("separation", 8)
	controls.add_child(filter_row)
	for key: String in ["FurnitureCatalogGroup","FurnitureCatalogType","FurnitureCatalogSearch"]:
		var control: Control = host.get_node("%"+key)
		control.reparent(filter_row)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.x = 156 if key == "FurnitureCatalogSearch" else 110
	host.get_node("%FurnitureCatalogStatus").hide()
	var list: GridContainer = host.get_node("%FurnitureCatalogItems")
	var scroller := ScrollContainer.new()
	scroller.name = "RoomCatalogScroll"
	scroller.custom_minimum_size = Vector2(0, 162)
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_catalog_scroller = scroller
	inventory.add_child(scroller)
	list.reparent(scroller)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Button in list.get_children():
		if item.visible:
			item.custom_minimum_size = Vector2(174, 152) if item.name.begins_with("Catalog_room_") else Vector2(174, 46)
			item.clip_text = true
	# The room's individual finish selection belongs to the right inspector,
	# not to the all-products catalog drawer.
	var palette_label: Label = inventory.get_node("FurniturePaletteLabel")
	palette_label.reparent(inspector_content)
	var palette: OptionButton = host.get_node("%FurniturePalette")
	palette.reparent(inspector_content)
	var catalog_label: Label = inventory.get_node("FurnitureCatalogLabel")
	catalog_label.text = "家居目录 · 已拥有的物品"
	catalog_label.add_theme_font_size_override("font_size", 16)

func _resize_layout() -> void:
	if not is_instance_valid(host) or not is_instance_valid(dock): return
	_apply_layout_size(host.get_viewport().get_visible_rect().size)

func _apply_layout_size(area: Vector2) -> void:
	if area == _last_dimensions: return
	_last_dimensions = area
	var compact := area.x < 890.0
	var tiny := area.x < 600.0
	bar.position = Vector2(16,77) if compact else Vector2(27,79)
	bar.size = Vector2(maxf(320.0,area.x - 30.0),43) if compact else Vector2(785,45)
	bar.add_theme_constant_override("separation",3 if tiny else 6 if compact else 8)
	for id: String in mode_buttons:
		var button: Button = mode_buttons[id]
		var long_names := {"furniture":"家具","decor":"装修","lighting":"灯光","build":"建造"}
		var short_names := {"furniture":"家","decor":"装","lighting":"光","build":"建"}
		button.text = str(short_names[id] if tiny else long_names[id])
		button.custom_minimum_size.x = 46 if tiny else 58 if compact else 69
		button.tooltip_text = str(long_names[id])
	catalog_toggle.custom_minimum_size.x = 48 if tiny else 70 if compact else 91
	advanced_toggle.custom_minimum_size.x = 48 if tiny else 70 if compact else 66
	for action: Button in bar.get_node("History").get_children():
		action.custom_minimum_size.x = 42 if tiny else 50 if compact else 60
		action.text = "" if tiny else ("撤销" if action.name == "UndoLayout" else "重做")
	var list: GridContainer = host.get_node("%FurnitureCatalogItems")
	list.columns = 2 if area.x < 970.0 else 3 if area.x < 1480.0 else 4
	dock.offset_left = 14.0 if compact else 27.0
	dock.offset_right = -14.0 if compact else -348.0
	dock.offset_top = -317.0 if tiny else -296.0
	dock.offset_bottom = -12.0 if compact else -18.0
	_inspector.offset_left = -minf(304.0,area.x - 32.0)
	_inspector.offset_right = -14.0 if compact else -22.0
	_inspector.offset_top = 130.0 if compact else 137.0
	_inspector.offset_bottom = -333.0 if tiny else -310.0 if compact else -18.0
	if tiny and _filter_row.get_child_count() > 0:
		for control: Control in _filter_row.get_children():
			control.reparent(_filter_parent)
			control.custom_minimum_size.x = 0
		_filter_row.hide()
	elif not tiny and _filter_row.get_child_count() == 0:
		for key: String in ["FurnitureCatalogGroup","FurnitureCatalogType","FurnitureCatalogSearch"]:
			var control: Control = host.get_node("%"+key)
			control.reparent(_filter_row)
			control.custom_minimum_size.x = 156 if key == "FurnitureCatalogSearch" else 110
		_filter_row.show()
	if area.x < 780:
		host.get_node("%ResetView").hide()
		host.get_node("%FocusToggle").text = "电脑"
	else:
		host.get_node("%ResetView").visible = host.world.mode in ["overview","layout"]
		host.get_node("%FocusToggle").text = "使用电脑  >"
	if host.furniture_cards != null:
		host.furniture_cards.request_visible.call_deferred()

func choose_mode(next_mode: String) -> void:
	if not mode_buttons.has(next_mode): return
	mode = next_mode
	host.set_blueprint_mode(mode == "build")
	sync()

func sync() -> void:
	if not is_instance_valid(host) or not is_instance_valid(bar): return
	var active: bool = host.world.mode == "layout" and host.world.layout.active
	if active and not was_active:
		mode = "furniture"
		advanced = false
		catalog_open = true
		last_selected = "desk"
	if active:
		var selected: String = str(host.world.layout.selected)
		# Once the player selects an object, free the central viewport for
		# the 3D gizmo. The catalog can be reopened at any time from the bar.
		if mode == "furniture" and selected != last_selected and selected != "desk":
			catalog_open = false
		last_selected = selected
	was_active = active
	bar.visible = active
	var show_dock: bool = active and mode == "furniture" and catalog_open and not host.blueprint_mode
	if show_dock != _last_dock_visible:
		dock.visible = show_dock
		if show_dock:
			dock.modulate.a = 0.0
			var appear := create_tween()
			appear.set_trans(Tween.TRANS_SINE)
			appear.tween_property(dock,"modulate:a",1.0,0.17)
			if host.furniture_cards != null:
				host.furniture_cards.request_visible.call_deferred()
		_last_dock_visible = show_dock
	catalog_toggle.visible = active and mode == "furniture"
	catalog_toggle.text = ("−" if catalog_open else "+") if _last_dimensions.x < 600 else "收起目录" if catalog_open else "显示目录"
	advanced_toggle.text = ("−" if advanced else "+") if _last_dimensions.x < 600 else "收起高级" if advanced else "高级"
	for id: String in mode_buttons:
		mode_buttons[id].set_pressed_no_signal(mode == id)
	if not active: return
	if mode != _last_mode and not host.blueprint_mode:
		_inspector.modulate.a = 0.65
		var fade := create_tween()
		fade.tween_property(_inspector,"modulate:a",1.0,0.14)
	_last_mode = mode
	var core: Array = CORE_INSPECTOR.get(mode, [])
	for child: Control in inspector_content.get_children():
		child.visible = not host.blueprint_mode and (
			core.has(child.name)
			or (advanced and (ADVANCED_INSPECTOR.has(child.name) if mode == "furniture" else child.name == "RestoreLayout"))
		)
		if child.name == "LayoutMessage" and host.world.layout.valid and not advanced:
			child.visible = false
	if host.blueprint_mode:
		for child: Control in blueprint_content.get_children():
			child.visible = advanced or CORE_BLUEPRINT.has(child.name)
