extends Node
const Icons = preload("res://scripts/life/room_ui_icons.gd")
const SceneActions = preload("res://scripts/life/room_scene_actions.gd")
## Room-only presentation layer. Existing controls keep their unique Godot names,
## signals, item IDs and save contracts. PC apps retain the original client theme.
var host # Dynamic controller: the room desktop owns its custom world/layout API.
var mode := "furniture"
var advanced := false
var catalog_open := false
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
var feedback: PanelContainer
var feedback_text: Label
var feedback_pose_text: Label
var feedback_state := "none"
var _preview_role := ""
var _confirmed_role := ""
var _confirmation_timer: Timer
var _keyboard_notice := ""
var _keyboard_role := ""
var _keyboard_notice_timer: Timer
var scene_actions: Node

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
	scene_actions = SceneActions.new()
	scene_actions.name = "RoomSceneActions"
	add_child(scene_actions)
	scene_actions.setup(host,self,canvas)
	_build_feedback(canvas)
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
	bar.position = Vector2(16,76)
	bar.size = Vector2(510,45)
	bar.add_theme_constant_override("separation", 5)
	canvas.add_child(bar)
	for entry: Dictionary in [
		{"id":"furniture","label":"家具"},
		{"id":"decor","label":"装修"},
		{"id":"lighting","label":"灯光"},
		{"id":"build","label":"建造"}
	]:
		var id: String = entry.id
		var button := _button("")
		button.toggle_mode = true
		button.icon = Icons.texture(id)
		button.tooltip_text = "%s模式" % str(entry.label)
		button.custom_minimum_size = Vector2(44,42)
		button.pressed.connect(func() -> void: choose_mode(id))
		bar.add_child(button)
		mode_buttons[id] = button
	var space := Control.new()
	space.custom_minimum_size.x = 7
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(space)
	catalog_toggle = _button("物品", "显示或收起左侧家具目录 · B")
	catalog_toggle.icon = Icons.texture("catalog")
	catalog_toggle.pressed.connect(func() -> void:
		catalog_open = not catalog_open
		sync()
	)
	bar.add_child(catalog_toggle)
	advanced_toggle = _button("精细", "展开完整坐标、吸附、对齐、蓝图等精细选项")
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
		child.custom_minimum_size.x = 44
		if child is Button:
			child.icon = Icons.texture("undo" if child.name == "UndoLayout" else "redo")

func _build_dock(canvas: Control) -> void:
	dock = PanelContainer.new()
	dock.name = "RoomCatalogDock"
	# The first room interaction is often screen mode, not edit mode.
	# Initialize hidden to avoid swallowing pointer events over the monitor taskbar.
	dock.visible = false
	dock.anchor_left = 0.0
	dock.anchor_top = 0.0
	dock.anchor_right = 0.0
	dock.anchor_bottom = 1.0
	dock.offset_left = 73.0
	dock.offset_top = 151.0
	dock.offset_right = 418.0
	dock.offset_bottom = -24.0
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
	inventory.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		control.custom_minimum_size.x = 150 if key == "FurnitureCatalogSearch" else 98
		if key == "FurnitureCatalogGroup": control.hide()
	host.get_node("%FurnitureCatalogStatus").hide()
	var list: GridContainer = host.get_node("%FurnitureCatalogItems")
	var scroller := ScrollContainer.new()
	scroller.name = "RoomCatalogScroll"
	scroller.custom_minimum_size = Vector2(0, 120)
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_catalog_scroller = scroller
	inventory.add_child(scroller)
	list.reparent(scroller)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Button in list.get_children():
		if item.visible:
			item.custom_minimum_size = Vector2(132, 138) if item.name.begins_with("Catalog_room_") else Vector2(132, 46)
			item.clip_text = true
	# The room's individual finish selection belongs to the right inspector,
	# not to the all-products catalog drawer.
	var palette_label: Label = inventory.get_node("FurniturePaletteLabel")
	palette_label.reparent(inspector_content)
	var palette: OptionButton = host.get_node("%FurniturePalette")
	palette.reparent(inspector_content)
	var catalog_label: Label = inventory.get_node("FurnitureCatalogLabel")
	catalog_label.text = "家具物品 · 点击开始摆放"
	catalog_label.add_theme_font_size_override("font_size", 16)

func _resize_layout() -> void:
	if not is_instance_valid(host) or not is_instance_valid(dock): return
	_apply_layout_size(host.get_viewport().get_visible_rect().size)

func _apply_layout_size(area: Vector2) -> void:
	if area == _last_dimensions: return
	_last_dimensions = area
	var compact: bool = area.x < 980.0
	var tiny: bool = area.x < 640.0
	bar.position = Vector2(12,75) if compact else Vector2(16,76)
	bar.size = Vector2(maxf(315.0,area.x-24.0),43) if compact else Vector2(520,45)
	bar.add_theme_constant_override("separation",2 if tiny else 4 if compact else 5)
	for id: String in mode_buttons:
		var button: Button = mode_buttons[id]
		button.text = ""
		button.custom_minimum_size.x = 40 if tiny else 43 if compact else 44
	catalog_toggle.text = "" if tiny else "物品"
	catalog_toggle.custom_minimum_size.x = 41 if tiny else 64
	advanced_toggle.text = "" if tiny else "精细"
	advanced_toggle.custom_minimum_size.x = 41 if tiny else 64
	for action: Button in bar.get_node("History").get_children():
		action.text = ""
		action.custom_minimum_size.x = 39 if tiny else 44
	var list: GridContainer = host.get_node("%FurnitureCatalogItems")
	list.columns = 1 if compact else 2
	dock.offset_left = 59.0 if compact else 73.0
	dock.offset_right = minf(area.x - 9.0,321.0) if compact else 418.0
	dock.offset_top = 134.0 if area.y < 660.0 else 151.0
	dock.offset_bottom = -12.0 if compact else -24.0
	_inspector.offset_left = -minf(326.0,area.x - 24.0)
	_inspector.offset_right = -10.0 if compact else -22.0
	_inspector.offset_top = 128.0 if compact else 137.0
	_inspector.offset_bottom = -14.0
	if tiny and _filter_row.get_child_count() > 0:
		for control: Control in _filter_row.get_children():
			control.reparent(_filter_parent)
			control.custom_minimum_size.x = 0
		_filter_row.hide()
	elif not tiny and _filter_row.get_child_count() == 0:
		for key: String in ["FurnitureCatalogGroup","FurnitureCatalogType","FurnitureCatalogSearch"]:
			var control: Control = host.get_node("%"+key)
			control.reparent(_filter_row)
			control.custom_minimum_size.x = 150 if key == "FurnitureCatalogSearch" else 98
		_filter_row.show()
		host.get_node("%FurnitureCatalogGroup").hide()
	if area.x < 780:
		host.get_node("%ResetView").hide()
		host.get_node("%FocusToggle").text = "电脑"
	else:
		host.get_node("%ResetView").visible = host.world.mode in ["overview","layout"]
		host.get_node("%FocusToggle").text = "使用电脑  >"
	if scene_actions != null:
		scene_actions.resize(area)
	if host.furniture_cards != null:
		host.furniture_cards.request_visible.call_deferred()

func _build_feedback(canvas: Control) -> void:
	# Never intercept clicks: this is a visual-only status tied to the 3D object.
	feedback = PanelContainer.new()
	feedback.name = "PlacementFeedback"
	feedback.visible = false
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.custom_minimum_size = Vector2(318,62)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("f7f8f3",0.94)
	surface.border_color = Color("bac9b9",0.74)
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(12)
	surface.content_margin_left = 13.0
	surface.content_margin_right = 13.0
	surface.content_margin_top = 9.0
	surface.content_margin_bottom = 9.0
	feedback.add_theme_stylebox_override("panel",surface)
	canvas.add_child(feedback)
	var contents := VBoxContainer.new()
	contents.name = "FeedbackContents"
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_theme_constant_override("separation",4)
	feedback.add_child(contents)
	feedback_text = Label.new()
	feedback_text.name = "Status"
	feedback_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_text.add_theme_font_size_override("font_size",12)
	feedback_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(feedback_text)
	feedback_pose_text = Label.new()
	feedback_pose_text.name = "TransformReadout"
	feedback_pose_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_pose_text.add_theme_font_size_override("font_size",11)
	feedback_pose_text.add_theme_color_override("font_color",Color("56695c"))
	feedback_pose_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(feedback_pose_text)
	_confirmation_timer = Timer.new()
	_confirmation_timer.name = "PlacementConfirmationTimer"
	_confirmation_timer.one_shot = true
	_confirmation_timer.wait_time = 1.8
	add_child(_confirmation_timer)
	_confirmation_timer.timeout.connect(func() -> void:
		_confirmed_role = ""
		_sync_feedback(host.world.layout.active and host.world.mode == "layout")
	)
	_keyboard_notice_timer = Timer.new()
	_keyboard_notice_timer.name = "KeyboardPrecisionFeedbackTimer"
	_keyboard_notice_timer.one_shot = true
	_keyboard_notice_timer.wait_time = 1.4
	add_child(_keyboard_notice_timer)
	_keyboard_notice_timer.timeout.connect(func() -> void:
		_keyboard_notice = ""
		_keyboard_role = ""
		_sync_feedback(host.world.layout.active and host.world.mode == "layout")
	)

func show_keyboard_feedback(message: String) -> void:
	if not host.world.layout.active or host.blueprint_mode or mode != "furniture": return
	_keyboard_notice = message
	_keyboard_role = str(host.world.layout.selected)
	_keyboard_notice_timer.start()
	_sync_feedback(true)

func _clear_keyboard_feedback() -> void:
	_keyboard_notice = ""
	_keyboard_role = ""
	if is_instance_valid(_keyboard_notice_timer): _keyboard_notice_timer.stop()

func _clear_confirmation() -> void:
	_confirmed_role = ""
	if is_instance_valid(_confirmation_timer): _confirmation_timer.stop()

func _track_placement_completion(active: bool) -> void:
	if not active:
		_preview_role = ""
		_clear_confirmation()
		_clear_keyboard_feedback()
		return
	var layout = host.world.layout
	if not _keyboard_role.is_empty() and (_keyboard_role != str(layout.selected) or not layout.gesture.is_empty()):
		_clear_keyboard_feedback()
	var preview: String = str(layout.placing_role)
	if not preview.is_empty():
		_preview_role = preview
		_clear_confirmation()
	elif not _preview_role.is_empty():
		var completed: String = _preview_role
		_preview_role = ""
		_clear_keyboard_feedback()
		# Cancel restores the pre-preview inventory mapping, whereas a real
		# confirmation keeps the placed UID under this role.
		if layout.placed_instances.has(completed):
			_confirmed_role = completed
			_confirmation_timer.start()

func _transform_readout(layout) -> String:
	# Read the actual constrained world-local transform, not the intended mouse
	# target. This remains accurate after grid rounding and collision clipping.
	var node: Node3D = layout.nodes[layout.selected]
	var pose := "X %.2f m  ·  Z %.2f m  ·  角度 %.0f°" % [
		node.position.x,node.position.z,rad_to_deg(node.rotation.y)
	]
	var precision := "网格 %.2f m  ·  旋转步长 %.0f°" % [layout.grid_step,layout.angle_step] if layout.snapping else "自由定位  ·  自由旋转"
	if layout.wall_magnet_active:
		precision = "墙面已吸附（范围 %.2f m） · Alt 跳过" % layout.WALL_SNAP_RADIUS
	elif layout.snap_bypass:
		precision += "  ·  Alt 已跳过贴墙吸附"
	if layout.group_selection.size() > 1:
		precision = "整组 %d 件 · 以组中心旋转 · %s" % [layout.group_selection.size(),precision]
	return pose + "\n" + precision

func _sync_feedback(active: bool) -> void:
	feedback_state = "none"
	if not active or host.blueprint_mode or mode != "furniture":
		feedback.hide()
		return
	var layout = host.world.layout
	var message: String = str(layout.message)
	var confirmed: bool = not _confirmed_role.is_empty() and _confirmed_role == str(layout.selected) and layout.placed_instances.has(_confirmed_role) and layout.gesture.is_empty() and layout.placing_role.is_empty() and layout.valid and not catalog_open
	if not confirmed and not _confirmed_role.is_empty() and (_confirmed_role != str(layout.selected) or not layout.gesture.is_empty()):
		_clear_confirmation()
	var keyboard_notice: bool = not _keyboard_notice.is_empty() and _keyboard_role == str(layout.selected) and not catalog_open
	var relevant: bool = confirmed or keyboard_notice or not layout.placing_role.is_empty() or not layout.gesture.is_empty() or not layout.valid or message.begins_with("已阻挡") or layout.wall_magnet_active
	if not relevant or not layout.nodes.has(layout.selected):
		feedback.hide()
		return
	var display_message := message
	if not layout.valid or message.begins_with("已阻挡"):
		feedback_state = "blocked"
		display_message = "无法放置 · %s" % message if not layout.placing_role.is_empty() else "移动受阻 · %s" % message
	elif confirmed:
		feedback_state = "confirmed"
		display_message = "已放置 · %s  ·  Ctrl+Z 撤销" % layout.name_for(_confirmed_role)
	elif layout.wall_magnet_active:
		feedback_state = "snapped"
		display_message = "已吸附 · Alt 临时关闭吸附  ·  %s" % ("左键确认" if not layout.placing_role.is_empty() else "松开鼠标完成")
	elif not layout.placing_role.is_empty():
		feedback_state = "ready"
		display_message = "可以放置 · 左键确认  ·  右键取消  ·  Q/E 旋转"
	elif keyboard_notice and layout.gesture.is_empty():
		feedback_state = "keyboard"
		display_message = _keyboard_notice
	else:
		feedback_state = "dragging"
	var object: Node3D = layout.nodes[layout.selected]
	var camera: Camera3D = host.world.camera
	var target: Vector3 = object.global_position + Vector3.UP * maxf(0.25, layout.bounds_for(layout.selected).y + .18)
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var pixel: Vector2 = camera.unproject_position(target)
	var in_view: bool = not camera.is_position_behind(target) and Rect2(Vector2.ZERO,view).has_point(pixel)
	if not in_view:
		# Invalid ghosts keep a visible warning even outside the camera.
		if feedback_state not in ["blocked","ready"] and layout.placing_role.is_empty():
			feedback_state = "none"
			feedback.hide()
			return
		feedback.position = Vector2(maxf(12.0,(view.x-340.0)*0.5),128.0)
	else:
		feedback.position = Vector2(clampf(pixel.x + 12.0, 12.0, maxf(12.0,view.x - 340.0)),clampf(pixel.y - 86.0, 127.0, maxf(127.0, view.y - 116.0)))
	var surface: StyleBoxFlat = feedback.get_theme_stylebox("panel") as StyleBoxFlat
	surface.border_color = Color("ce8d83") if feedback_state == "blocked" else Color("83b799") if feedback_state in ["ready","snapped","confirmed"] else Color("bac9b9")
	surface.bg_color = Color("fff1ec",0.96) if feedback_state == "blocked" else Color("f0f7ed",0.96) if feedback_state in ["ready","snapped","confirmed"] else Color("f7f8f3",0.94)
	feedback_text.text = display_message
	feedback_pose_text.text = _transform_readout(layout)
	feedback_text.add_theme_color_override("font_color",Color("a9433d") if feedback_state == "blocked" else Color("29694d") if feedback_state in ["ready","snapped","confirmed"] else Color("394f40"))
	feedback.show()

func choose_mode(next_mode: String) -> void:
	if not mode_buttons.has(next_mode): return
	# Never leave a ghost active under the decoration or lighting inspector:
	# mode switches discard only the unfinished preview, not purchased stock.
	if next_mode != "furniture" and not host.world.layout.placing_role.is_empty():
		host.world.layout.cancel_placement()
	mode = next_mode
	if next_mode != "furniture":
		_clear_keyboard_feedback()
		host.world.layout.clear_group_selection()
	if scene_actions != null:
		scene_actions.hide_colors()
		scene_actions.hide_arrange()
	if next_mode == "furniture": catalog_open = host.world.layout.placing_role.is_empty()
	host.set_blueprint_mode(mode == "build")
	sync()

func sync() -> void:
	if not is_instance_valid(host) or not is_instance_valid(bar): return
	var active: bool = host.world.mode == "layout" and host.world.layout.active
	if active and not was_active:
		mode = "furniture"
		advanced = false
		catalog_open = false
		last_selected = "desk"
	if active:
		# A pending placement needs an unobstructed 3D canvas. Do not let a
		# second category click or a mode refresh reopen the drawer over it.
		if not host.world.layout.placing_role.is_empty():
			catalog_open = false
		var selected: String = str(host.world.layout.selected)
		# Once the player selects an object, free the central viewport for
		# the 3D gizmo. The catalog can be reopened at any time from the bar.
		if mode == "furniture" and selected != last_selected and selected != "desk":
			catalog_open = false
		last_selected = selected
	was_active = active
	bar.visible = active
	# Scene-first tools are next to the object. The full inspector only appears
	# for decoration, lighting, blueprint or a deliberate "precise" request.
	_inspector.visible = active and (host.blueprint_mode or mode != "furniture" or advanced)
	_track_placement_completion(active)
	_sync_feedback(active)
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
	catalog_toggle.visible = active and mode == "furniture" and host.world.layout.placing_role.is_empty()
	catalog_toggle.text = "" if _last_dimensions.x < 640 else "收起" if catalog_open else "物品"
	advanced_toggle.text = "" if _last_dimensions.x < 640 else "收起" if advanced else "精细"
	for id: String in mode_buttons:
		mode_buttons[id].set_pressed_no_signal(mode == id)
	if scene_actions != null: scene_actions.sync(active)
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
