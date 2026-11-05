extends Node3D
const WindowScene = preload("res://scenes/computer/ui/app_window.tscn")
const RoomMinimalUI = preload("res://scripts/life/room_minimal_ui.gd")
const RoomCards = preload("res://scripts/life/room_furniture_cards.gd")
const ItemCatalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
const BlueprintData = preload("res://scripts/room/room_blueprint_data.gd")
const APPS := {"platform": ["游戏平台", "res://scenes/apps/platform/store.tscn"], "browser": ["回忆生活 · 购物网页", "res://scenes/apps/browser/browser.tscn"], "game": ["正在游玩", "res://scenes/apps/game/game_player.tscn"]}
@export var hardware_catalog: MemoirHardwareCatalog
var session: MemoirGameSession
var area: Control
var tasks: HBoxContainer
var resume_button: Button
var status: Label
var windows: Dictionary = {}
var modal_input_guard := false
var dragging := false
var orbiting := false
var pointer_origin := Vector2.ZERO
var camera_dragged := false
const DRAG_THRESHOLD := 6.0
# Click-select begins immediately, while freehand movement only activates once
# the pointer has travelled far enough to distinguish a drag from a click.
var pending_drag_role := ""
var pending_drag_start := Vector2.ZERO
var pending_drag_operation := ""
var marquee_origin := Vector2.ZERO
var marquee_pending := false
var marquee_active := false
var marquee_additive := false
var screen_mouse_down := false
var last_screen_point := Vector2.ZERO
var furniture_buttons: Dictionary = {}
var catalog_special_buttons: Dictionary = {}
var catalog_group_ids: Array[String] = [""]
var catalog_type_ids: Array[String] = [""]
var furniture_palette: OptionButton
var blueprint_mode := false
var room_ui
var furniture_cards
var wall_drag_button := 0
var last_wall_cell := Vector2(INF, INF)
var dragging_aperture := false
var dragging_custom_edge := false
var wall_stroke_good: Array[Vector2] = []
var wall_stroke_bad: Array[Vector2] = []
const BLUEPRINT_KEYS := {"BlueprintWidth":"width", "BlueprintDepth":"depth", "BlueprintDoorX":"door_x", "BlueprintWindowZ":"window_z", "BlueprintNotchWidth":"notch_width", "BlueprintNotchDepth":"notch_depth"}
@onready var world: Node3D = %Workstation3D
var screen_focused: bool:
	get: return is_instance_valid(world) and world.mode == "screen"

func screen_node(key: String) -> Node:
	return %DesktopScreen.get_node("%" + key)

func _ready() -> void:
	get_window().window_input.connect(_forward_modal_input)
	get_window().focus_exited.connect(_clear_gesture)
	world.set_screen_texture(%DesktopViewport.get_texture())
	get_viewport().size_changed.connect(_reframe_screen)
	%ResetView.pressed.connect(world.reset_overview)
	%EditLayout.pressed.connect(begin_layout)
	%BlueprintToggle.pressed.connect(func() -> void: set_blueprint_mode(not blueprint_mode))
	%BlueprintShape.add_item("矩形房间")
	%BlueprintShape.add_item("L 型房间 · 右前角缺口")
	%BlueprintShape.add_item("自由轮廓 · 网格地板")
	%BlueprintShape.item_selected.connect(func(index: int) -> void:
		if blueprint_mode: world.layout.set_blueprint_shape(["rectangle","l","custom"][index])
	)
	%BlueprintFloorTool.add_item("内墙绘制")
	%BlueprintFloorTool.add_item("挖除地板")
	%BlueprintFloorTool.add_item("恢复地板")
	%BlueprintFloorTool.add_item("地板材质画笔")
	%BlueprintFloorTool.add_item("自定义外墙装修 / 门窗")
	%BlueprintFloorTool.add_item("内墙独立改色")
	%BlueprintFloorTool.add_item("拖动原有门窗位置")
	%BlueprintFloorTool.add_item("移动自定义外墙门窗")
	%BlueprintQuickWall.pressed.connect(func() -> void: _select_blueprint_tool(0))
	%BlueprintQuickFloor.pressed.connect(func() -> void: _select_blueprint_tool(1))
	%BlueprintQuickOpening.pressed.connect(func() -> void: _select_blueprint_tool(6))
	%BlueprintQuickEdgeMove.pressed.connect(func() -> void: _select_blueprint_tool(7))
	%BlueprintGridToggle.toggled.connect(func(enabled: bool) -> void:
		world.get_node("BlueprintOverlay").set_grid_visible(enabled)
	)
	%BlueprintApertureTarget.add_item("后墙门")
	%BlueprintApertureTarget.add_item("左墙窗")
	%BlueprintApertureTarget.item_selected.connect(func(_index: int) -> void: _hide_wall_preview())
	for label: String in ["跟随房间材质", "奶油白 / 浅石砖", "鼠尾草绿", "雾蓝 / 胡桃木"]:
		%BlueprintWallFinish.add_item(label)
		%BlueprintTileFinish.add_item(label)
	for label: String in ["保留实体墙", "窗户", "门洞"]:
		%BlueprintOpeningKind.add_item(label)
	for n in range(1,5):
		%BlueprintOpeningWidth.add_item("%.1f 米 / %d 段" % [float(n)*BlueprintData.FLOOR_GRID,n])
	%WallSnapToggle.toggled.connect(world.layout.set_wall_snap)
	%InnerWallSnapToggle.toggled.connect(world.layout.set_inner_wall_snap)
	%AlignFurnitureX.pressed.connect(func() -> void: world.layout.align_selected("x"))
	%AlignFurnitureZ.pressed.connect(func() -> void: world.layout.align_selected("z"))
	%DistributeFurnitureX.pressed.connect(func() -> void: world.layout.distribute_matching_furniture("x"))
	%DistributeFurnitureZ.pressed.connect(func() -> void: world.layout.distribute_matching_furniture("z"))
	%BlueprintFloorTool.item_selected.connect(func(_index: int) -> void:
		if dragging_aperture:
			world.layout.end_aperture_drag()
			dragging_aperture = false
		if dragging_custom_edge:
			world.layout.end_custom_edge_drag()
			dragging_custom_edge = false
		world.layout.end_wall_stroke()
		_reset_wall_stroke()
		wall_drag_button = 0
		world.get_node("BlueprintOverlay").clear_region()
		_hide_wall_preview()
		_sync_quick_tools()
	)
	for option: OptionButton in [%BlueprintTileFinish, %BlueprintWallFinish, %BlueprintOpeningKind, %BlueprintOpeningWidth]:
		option.item_selected.connect(func(_index: int) -> void:
			_hide_wall_preview()
		)
	%WallAxis.add_item("横向墙 · X")
	%WallAxis.add_item("纵向墙 · Z")
	%WallKind.add_item("实体墙")
	%WallKind.add_item("门洞")
	%WallAxis.item_selected.connect(func(_index: int) -> void: _hide_wall_preview())
	%WallKind.item_selected.connect(func(_index: int) -> void: _hide_wall_preview())
	%WallRemoveMode.toggled.connect(func(_active: bool) -> void: _hide_wall_preview())
	var wall_ghost: MeshInstance3D = world.get_node("WallPreview")
	wall_ghost.material_override = wall_ghost.material_override.duplicate()
	for slider_name: String in BLUEPRINT_KEYS:
		var slider: HSlider = get_node("%" + slider_name)
		var key: String = BLUEPRINT_KEYS[slider_name]
		slider.value_changed.connect(func(value: float) -> void:
			if blueprint_mode:
				world.layout.set_blueprint_value(key, value)
		)
	%ApplyLayout.pressed.connect(func() -> void: finish_layout(true))
	%CancelLayout.pressed.connect(func() -> void: finish_layout(false))
	%RestoreLayout.pressed.connect(world.layout.reset_layout)
	%UndoLayout.pressed.connect(world.layout.undo)
	%RedoLayout.pressed.connect(world.layout.redo)
	%CopyFurniture.pressed.connect(world.layout.duplicate_selected)
	%DeleteFurniture.pressed.connect(world.layout.store_selected)
	_build_furniture_catalog()
	room_ui = RoomMinimalUI.new()
	add_child(room_ui)
	room_ui.setup(self)
	furniture_cards = RoomCards.new()
	add_child(furniture_cards)
	furniture_cards.setup(self)
	var styles := {
		"wall":["墙面 · 鼠尾草","墙面 · 奶油米","墙面 · 雾蓝"],
		"floor":["地板 · 原木","地板 · 浅灰木","地板 · 深胡桃"],
		"light":["灯光 · 午后暖阳","灯光 · 清晨冷光","灯光 · 夜间暖灯"],
		"rgb":["冰青","深蓝","紫罗兰","洋红","琥珀","薄荷","玫瑰"],
		"effect":["常亮","呼吸","彩虹循环"],
		"wall_pattern":["纯色粉刷","细纹亚麻","错缝砖纹"],
		"floor_pattern":["基础地板","橡木纹理","石材地砖"],
		"atmosphere":["晴昼","日落","夜晚","雨天"]
	}
	for key: String in styles:
		var selector: OptionButton = get_node("%Style_" + key)
		for label: String in styles[key]: selector.add_item(label)
		selector.item_selected.connect(func(index: int) -> void: world.layout.set_style(key, index, key == "atmosphere"))
	%Style_brightness.value_changed.connect(func(value: float) -> void: world.layout.set_style("brightness", roundi(value)))
	%Style_ambience_volume.value_changed.connect(func(value: float) -> void:
		world.layout.set_style("ambience_volume", roundi(value))
		%AmbienceVolumeLabel.text = "雨声音量 · %d%%（0 为静音）" % roundi(value)
	)
	%MoveTool.pressed.connect(func() -> void: world.layout.set_tool("move"))
	%RotateTool.pressed.connect(func() -> void: world.layout.set_tool("rotate"))
	%SnapLayout.toggled.connect(func(enabled: bool) -> void: world.layout.snapping = enabled)
	%RotateLeft.pressed.connect(func() -> void: world.layout.rotate_step(-1))
	%RotateRight.pressed.connect(func() -> void: world.layout.rotate_step(1))
	for role: String in world.layout.NAMES:
		var key := role
		get_node("%Layout_" + role).pressed.connect(func() -> void: world.layout.select(key))
	world.layout.changed.connect(_sync_layout)
	%FocusToggle.pressed.connect(func() -> void: set_screen_focused(true))
	%ReturnOverview.pressed.connect(func() -> void: set_screen_focused(false))
	%ManageDevices.pressed.connect(func() -> void:
		set_screen_focused(true)
		open_app("browser", "inventory")
	)
	area = screen_node("ApplicationArea")
	tasks = screen_node("Tasks")
	resume_button = screen_node("DesktopResume")
	status = screen_node("Status")
	screen_node("ScreenToastTimer").timeout.connect(screen_node("ScreenToast").hide)
	screen_node("DesktopPlatform").pressed.connect(func() -> void: open_app("platform"))
	screen_node("DesktopBrowser").pressed.connect(func() -> void: open_app("browser"))
	resume_button.pressed.connect(func() -> void: open_app("game"))
	screen_node("TaskbarPlatform").pressed.connect(func() -> void: open_app("platform"))
	screen_node("TaskbarBrowser").pressed.connect(func() -> void: open_app("browser"))
	_sync_mode()
	if session == null: return
	session.changed.connect(refresh)
	session.furniture_place_requested.connect(_start_purchased_furniture_placement)
	session.furniture_focus_requested.connect(_focus_purchased_furniture)
	session.tick_updated.connect(_update_status)
	refresh()

func _update_equipment() -> void:
	if session == null or hardware_catalog == null: return
	var reposition := false
	for role: String in world.devices:
		var id: String = str(session.state.life["equipped"].get(role, ""))
		var item: MemoirItemDefinition = ItemCatalog.lookup(id)
		var visual_id := item.visual_id if item != null else id
		var model := hardware_catalog.visual_for(role, visual_id)
		if model != null and world.devices[role].appearance != model:
			world.devices[role].appearance = model
			reposition = reposition or (screen_focused and role == "monitor")
	world.layout.load_placements(session.state.life.get("placements", {}), session.state.life.get("inventory", []))
	world.layout.load_blueprint(session.state.life.get("room_blueprint", {}))
	world.layout.load_saved(session.state.life.get("workstation_layout", {}),session.state.life.get("furniture_mounts", {}),session.state.life.get("wall_mounts", {}))
	# Loading an invalid legacy layout may remove scene instances. Persist the
	# matching placement/pose state immediately; otherwise the shop would still
	# consider their inventory UIDs occupied until the user edits the room.
	if not world.layout.active and session.state.life.get("placements", {}) != world.layout.committed_placements:
		session.state.life["placements"] = world.layout.committed_placements.duplicate()
		session.state.life["workstation_layout"] = world.layout.export_layout()
		session.state.life["furniture_mounts"] = world.layout.export_mounts()
		session.state.life["wall_mounts"] = world.layout.export_wall_mounts()
		session.state.save_state(false)
	world.layout.load_colors(session.state.life.get("furniture_colors", {}))
	world.layout.load_materials(session.state.life.get("furniture_materials", {}))
	world.layout.load_style(session.state.life.get("room_style", {}))
	if world.layout.active: world.layout.update()
	if reposition: world.set_mode("screen", false)

func begin_layout() -> void:
	if world.transitioning or world.layout.active: return
	blueprint_mode = false
	_set_mode("layout", false)
	world.layout.begin()
	_sync_layout()

func finish_layout(apply: bool) -> void:
	_cancel_pending_furniture_drag()
	_cancel_marquee()
	if world.layout.group_copy_preview_active: world.layout.cancel_group_copy_preview()
	if not world.layout.finish(apply): return
	if blueprint_mode: set_blueprint_mode(false)
	_set_mode("overview", false)
	if apply and session != null:
		session.state.life["workstation_layout"] = world.layout.export_layout()
		session.state.life["placements"] = world.layout.committed_placements.duplicate()
		session.state.life["furniture_colors"] = world.layout.committed_colors.duplicate()
		session.state.life["furniture_materials"] = world.layout.committed_materials.duplicate(true)
		session.state.life["furniture_mounts"] = world.layout.export_mounts()
		session.state.life["wall_mounts"] = world.layout.export_wall_mounts()
		session.state.life["room_style"] = world.layout.committed_style.duplicate()
		session.state.life["room_blueprint"] = world.layout.committed_blueprint.duplicate()
		session.state.save_state()

func _start_purchased_furniture_placement(item_id: String, uid: String) -> void:
	if world.layout.active: return
	set_screen_focused(false, false)
	begin_layout()
	if not world.layout.start_place(item_id, uid):
		finish_layout(false)
		return
	# The shop's preview finish is committed only with the room edit. Canceling
	# the placement or editor discards it; no inventory color is written early.
	var finish: int = session.pending_furniture_finish if session != null else -1
	if finish >= 0:
		world.layout.set_furniture_color(finish)

func _focus_purchased_furniture(item_id: String) -> void:
	if world.layout.active: return
	var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
	if item == null: return
	var target_role := ""
	for role: String in world.layout.placed_instances:
		if world.layout.Data.base_role(role) == item.subcategory:
			target_role = role
			break
	if target_role.is_empty(): return
	set_screen_focused(false, false)
	begin_layout()
	world.layout.select(target_role)
	world.focus_selected(false)

func _build_furniture_catalog() -> void:
	%FurnitureCatalogGroup.add_item("全部分类")
	for entry: Dictionary in Taxonomy.GROUPS:
		%FurnitureCatalogGroup.add_item(str(entry.name))
		catalog_group_ids.append(str(entry.id))
	%FurnitureCatalogGroup.item_selected.connect(func(_index: int) -> void: _update_catalog_types())
	%FurnitureCatalogType.item_selected.connect(func(_index: int) -> void: _filter_furniture_catalog())
	%FurnitureCatalogSearch.text_changed.connect(func(_value: String) -> void: _filter_furniture_catalog())
	# Legacy authored placement controls remain for scene compatibility.
	for role: String in InventoryData.ROOM_DEFAULTS:
		var old := get_node_or_null("%Place_" + role) as Button
		if old != null:
			old.hide()
			var item_id: String = InventoryData.ROOM_DEFAULTS[role]
			old.pressed.connect(func() -> void: _start_inventory_placement(item_id))
	for item in ItemCatalog.room_furniture():
		var id: String = item.item_id
		var button: Button = %FurnitureCatalogTemplate.duplicate() as Button
		button.show()
		button.name = "Catalog_" + id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = item.description
		button.custom_minimum_size = Vector2(180, 42)
		button.clip_text = true
		%FurnitureCatalogItems.add_child(button)
		button.pressed.connect(func() -> void: _start_inventory_placement(id))
		furniture_buttons[id] = button
	for entry: Dictionary in [
		{"role":"desk","type":"computer_desk","group":"tables","label":"电脑桌 · 调整位置"},
		{"role":"monitor","type":"monitor","group":"hardware","label":"显示器 · 已安装设备"},
		{"role":"computer","type":"computer","group":"hardware","label":"机箱 · 已安装设备"},
		{"role":"keyboard","type":"keyboard","group":"hardware","label":"键盘 · 已安装设备"},
		{"role":"mouse","type":"mouse","group":"hardware","label":"鼠标 · 已安装设备"}
	]:
		var role: String = entry.role
		var button: Button = %FurnitureCatalogTemplate.duplicate() as Button
		button.show()
		button.name = "CatalogSelect_" + role
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = entry.label
		%FurnitureCatalogItems.add_child(button)
		button.pressed.connect(func() -> void: world.layout.select(role))
		catalog_special_buttons[role] = {"button":button,"group":entry.group,"type":entry.type,"label":entry.label}
	furniture_palette = %FurniturePalette
	for label: String in world.layout.FURNITURE_COLOR_LABELS:
		furniture_palette.add_item(label)
	furniture_palette.item_selected.connect(func(index: int) -> void: world.layout.set_furniture_color(index))
	_update_catalog_types()

func _catalog_group() -> String:
	var index: int = %FurnitureCatalogGroup.selected
	return catalog_group_ids[index] if index >= 0 and index < catalog_group_ids.size() else ""

func _catalog_type() -> String:
	var index: int = %FurnitureCatalogType.selected
	return catalog_type_ids[index] if index >= 0 and index < catalog_type_ids.size() else ""

func _update_catalog_types() -> void:
	var group: String = _catalog_group()
	var types: Dictionary = {}
	for item in ItemCatalog.room_furniture():
		if group.is_empty() or Taxonomy.group_for(item) == group:
			types[Taxonomy.type_for(item)] = true
	for role: String in catalog_special_buttons:
		var info: Dictionary = catalog_special_buttons[role]
		if group.is_empty() or info.group == group: types[info.type] = true
	%FurnitureCatalogType.clear()
	%FurnitureCatalogType.add_item("全部类型")
	catalog_type_ids = [""]
	for key: String in Taxonomy.TYPES:
		if types.has(key):
			%FurnitureCatalogType.add_item(Taxonomy.type_name(key))
			catalog_type_ids.append(key)
	%FurnitureCatalogType.select(0)
	_filter_furniture_catalog()

func _filter_furniture_catalog() -> void:
	var group: String = _catalog_group()
	var kind: String = _catalog_type()
	var query: String = %FurnitureCatalogSearch.text.strip_edges().to_lower()
	for item_id: String in furniture_buttons:
		var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
		furniture_buttons[item_id].visible = item != null and ItemCatalog.matches_filters(item,group,kind,query)
	for role: String in catalog_special_buttons:
		var info: Dictionary = catalog_special_buttons[role]
		var label: String = info.label
		info.button.visible = (group.is_empty() or group == info.group) and (kind.is_empty() or kind == info.type) and (query.is_empty() or label.to_lower().contains(query))
	%FurnitureCatalogStatus.text = "%d 种家具商品 · 支持分类和名称搜索" % ItemCatalog.room_furniture().size()
	if furniture_cards != null: furniture_cards.request_visible.call_deferred()

func _start_inventory_placement(item_id: String) -> void:
	var uid := InventoryData.unused_uid(world.layout.available_inventory, world.layout.placed_instances, item_id)
	if not uid.is_empty():
		world.layout.start_place(item_id, uid)
		return
	# Once all owned copies are placed, the catalog doubles as a furniture selector.
	# Avoid forcing players to find a small object by clicking the 3D scene.
	var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
	if item == null: return
	for role: String in world.layout.placed_instances:
		if world.layout.Data.base_role(role) == item.subcategory:
			world.layout.select(role)
			return

func set_blueprint_mode(enabled: bool) -> void:
	if enabled and not world.layout.active: return
	_cancel_pending_furniture_drag()
	_cancel_marquee()
	if dragging_custom_edge:
		world.layout.end_custom_edge_drag()
		dragging_custom_edge = false
	world.layout.end_wall_stroke()
	_reset_wall_stroke()
	if dragging_aperture:
		world.layout.end_aperture_drag()
		dragging_aperture = false
	if enabled and not world.layout.placing_role.is_empty(): world.layout.cancel_placement()
	if enabled and world.layout.group_copy_preview_active: world.layout.cancel_group_copy_preview()
	if enabled: world.layout.clear_group_selection()
	blueprint_mode = enabled
	wall_drag_button = 0
	_hide_wall_preview()
	world.get_node("Room").set_partition_editing(enabled)
	var overlay = world.get_node("BlueprintOverlay")
	overlay.visible = enabled
	if enabled: overlay.configure(world.layout.blueprint)
	else: overlay.clear_region()
	%BlueprintToggle.set_pressed_no_signal(enabled)
	%Content.visible = not enabled
	%BlueprintPanel.visible = enabled
	world.set_blueprint_camera(enabled)
	if world.layout.active: world.layout.update()
	if enabled: world.layout.gizmo.hide()
	_sync_blueprint_ui()
	if room_ui != null:
		if enabled: room_ui.mode = "build"
		elif room_ui.mode == "build": room_ui.mode = "furniture"
		room_ui.sync()

func _sync_blueprint_ui() -> void:
	var blueprint: Dictionary = world.layout.blueprint
	%BlueprintShape.select(2 if blueprint.shape == "custom" else 1 if blueprint.shape == "l" else 0)
	%BlueprintNotchWidth.editable = blueprint.shape == "l"
	%BlueprintNotchDepth.editable = blueprint.shape == "l"
	%BlueprintFloorTool.disabled = false
	%BlueprintNotchWidth.max_value = minf(4.0, float(blueprint.width) - 3.0)
	%BlueprintNotchDepth.max_value = minf(4.0, float(blueprint.depth) - 2.5)
	for name: String in BLUEPRINT_KEYS:
		var key: String = BLUEPRINT_KEYS[name]
		var slider: HSlider = get_node("%" + name)
		if key == "door_x":
			slider.min_value = -float(blueprint.width) / 2.0 + .7
			slider.max_value = float(blueprint.width) / 2.0 - .7
		elif key == "window_z":
			slider.min_value = -float(blueprint.depth) / 2.0 + 1.35
			slider.max_value = float(blueprint.depth) / 2.0 - 1.35
		slider.set_value_no_signal(float(blueprint[key]))
		var label_key: String = {"width":"BlueprintWidthLabel", "depth":"BlueprintDepthLabel", "door_x":"BlueprintDoorLabel", "window_z":"BlueprintWindowLabel", "notch_width":"BlueprintNotchWidthLabel", "notch_depth":"BlueprintNotchDepthLabel"}[key]
		var label: Label = get_node("%" + label_key)
		var display: String = {"width":"房间宽度", "depth":"房间深度", "door_x":"后墙门位置", "window_z":"左墙窗位置", "notch_width":"缺口宽度", "notch_depth":"缺口深度"}[key]
		label.text = "%s：%.2f 米" % [display, float(blueprint[key])]
	_sync_quick_tools()
	if blueprint_mode: world.get_node("BlueprintOverlay").configure(blueprint)
	%BlueprintStatus.text = world.layout.message if world.layout.message.begins_with("调整失败") or world.layout.message.begins_with("建造失败") or world.layout.message.begins_with("绘制失败") else "%s · %.1f × %.1f 米 · 内墙 %d 段 · 缺口 %d 格" % ["自由轮廓" if blueprint.shape == "custom" else "L 型" if blueprint.shape == "l" else "矩形", blueprint.width, blueprint.depth, blueprint.partitions.size(), blueprint.removed_cells.size()]

func _select_blueprint_tool(index: int) -> void:
	if not blueprint_mode: return
	%BlueprintFloorTool.select(index)
	world.layout.end_wall_stroke()
	if dragging_custom_edge:
		world.layout.end_custom_edge_drag()
		dragging_custom_edge = false
	_reset_wall_stroke()
	wall_drag_button = 0
	world.get_node("BlueprintOverlay").clear_region()
	_hide_wall_preview()
	_sync_quick_tools()

func _sync_quick_tools() -> void:
	for key: String in {"BlueprintQuickWall":0,"BlueprintQuickFloor":1,"BlueprintQuickOpening":6,"BlueprintQuickEdgeMove":7}:
		var button: Button = get_node("%" + key)
		button.set_pressed_no_signal(%BlueprintFloorTool.selected == int({"BlueprintQuickWall":0,"BlueprintQuickFloor":1,"BlueprintQuickOpening":6,"BlueprintQuickEdgeMove":7}[key]))

func _aperture_key() -> String:
	return "window_z" if %BlueprintApertureTarget.selected == 1 else "door_x"

func _aperture_handle_point() -> Vector2:
	var room: Dictionary = world.layout.blueprint
	if _aperture_key() == "window_z": return Vector2(-float(room.width)*.5+.17,float(room.window_z))
	return Vector2(float(room.door_x),-float(room.depth)*.5+.17)

func _aperture_hover(pixel: Vector2) -> void:
	var ghost: MeshInstance3D = world.get_node("WallPreview")
	var hit: Variant = _floor_hit(pixel)
	if hit == null:
		ghost.hide()
		return
	var pos: Vector2 = _aperture_handle_point()
	var close: bool = pos.distance_to(hit) < .65
	ghost.position = Vector3(pos.x,.105,pos.y)
	(ghost.mesh as BoxMesh).size = Vector3(.9,.10,.14) if _aperture_key() == "door_x" else Vector3(.14,.10,1.3)
	(ghost.material_override as StandardMaterial3D).albedo_color = Color("6ed9ab",.65) if close else Color("f2c978",.50)
	ghost.show()

func _aperture_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit: Variant = _floor_hit(event.position)
				if hit != null and hit.distance_to(_aperture_handle_point()) < .65:
					world.layout.begin_aperture_drag()
					dragging_aperture = true
			elif dragging_aperture:
				world.layout.end_aperture_drag()
				dragging_aperture = false
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_overview(.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if dragging_aperture:
			var hit: Variant = _floor_hit(event.position)
			if hit != null:
				var value: float = hit.y if _aperture_key() == "window_z" else hit.x
				world.layout.drag_aperture(_aperture_key(),value)
		_aperture_hover(event.position)
		get_viewport().set_input_as_handled()

func _reset_wall_stroke() -> void:
	wall_stroke_good.clear()
	wall_stroke_bad.clear()
	if is_instance_valid(world): world.get_node("BlueprintOverlay").clear_wall_stroke()

func _stroke_wall_step(at: Vector2, button: int) -> bool:
	var allowed: bool = _wall_action(at, button)
	if allowed: wall_stroke_good.append(at)
	else: wall_stroke_bad.append(at)
	world.get_node("BlueprintOverlay").show_wall_stroke(wall_stroke_good,wall_stroke_bad,_wall_axis())
	%BlueprintStrokeInfo.text = "本次绘制：有效 %d 段 / 阻挡 %d 段" % [wall_stroke_good.size(),wall_stroke_bad.size()]
	return allowed

func _continue_wall_stroke(target: Vector2, button: int) -> void:
	var start: Vector2 = last_wall_cell
	var axis: String = _wall_axis()
	if not is_finite(start.x) or not is_finite(start.y): return
	var end := Vector2(target.x,start.y) if axis == "x" else Vector2(start.x,target.y)
	var distance: float = end.x-start.x if axis == "x" else end.y-start.y
	var steps: int = mini(48,roundi(absf(distance)/BlueprintData.WALL_GRID))
	if steps <= 0: return
	var signum: float = signf(distance)
	for index in range(1,steps+1):
		var at := start + (Vector2(signum*BlueprintData.WALL_GRID*index,0) if axis == "x" else Vector2(0,signum*BlueprintData.WALL_GRID*index))
		_stroke_wall_step(at,button)
	last_wall_cell = start + (Vector2(signum*BlueprintData.WALL_GRID*steps,0) if axis == "x" else Vector2(0,signum*BlueprintData.WALL_GRID*steps))

func _edge_move_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit: Variant = _floor_hit(event.position)
				if hit != null:
					dragging_custom_edge = world.layout.begin_custom_edge_drag(hit)
			elif dragging_custom_edge:
				world.layout.end_custom_edge_drag()
				dragging_custom_edge = false
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if dragging_custom_edge:
				world.layout.end_custom_edge_drag(true)
				dragging_custom_edge = false
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_overview(.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var hit: Variant = _floor_hit(event.position)
		var ghost: MeshInstance3D = world.get_node("WallPreview")
		if hit == null:
			ghost.hide()
			return
		var edge: Dictionary = BlueprintData.nearest_edge(world.layout.blueprint,hit,.36)
		if not edge.is_empty():
			var point: Vector2 = BlueprintData.edge_center(world.layout.blueprint,edge)
			ghost.position = Vector3(point.x,.105,point.y)
			(ghost.mesh as BoxMesh).size = Vector3(.16,.11,.48) if edge.dx != 0 else Vector3(.48,.11,.16)
			var reason: String = world.layout.edge_drag_blocker(hit) if dragging_custom_edge else ""
			var current: Dictionary = BlueprintData.edge_edit(world.layout.blueprint,edge)
			var selectable: bool = str(current.kind) in ["door","window"]
			(ghost.material_override as StandardMaterial3D).albedo_color = Color("ef7775",.70) if not reason.is_empty() else Color("67daac",.70) if dragging_custom_edge or selectable else Color("f5ca78",.45)
			ghost.show()
		else:
			ghost.hide()
		if dragging_custom_edge:
			world.layout.drag_custom_edge_to(hit)
		get_viewport().set_input_as_handled()

func _wall_axis() -> String:
	return "z" if %WallAxis.selected == 1 else "x"

func _wall_kind() -> String:
	return "door" if %WallKind.selected == 1 else "wall"

func _hide_wall_preview() -> void:
	if is_instance_valid(world):
		world.get_node("WallPreview").hide()

func _floor_hit(pixel: Vector2) -> Variant:
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	if hit == null: return null
	return Vector2(hit.x, hit.z)

func _blueprint_floor_hit(pixel: Vector2) -> Variant:
	var hit: Variant = _floor_hit(pixel)
	if hit == null: return null
	return hit.snapped(Vector2.ONE * BlueprintData.WALL_GRID)

func _wall_action(at: Vector2, button: int) -> bool:
	var remove: bool = button == MOUSE_BUTTON_RIGHT or %WallRemoveMode.button_pressed
	if remove:
		return world.layout.remove_partition(at)
	return world.layout.add_partition(at, _wall_axis(), _wall_kind())

func _floor_action(at: Vector2, button: int) -> void:
	var removing: bool = %BlueprintFloorTool.selected == 1
	if button == MOUSE_BUTTON_RIGHT: removing = not removing
	world.layout.paint_floor_cell(at, removing)

func _floor_hover(pixel: Vector2) -> void:
	var ghost: MeshInstance3D = world.get_node("WallPreview")
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	if hit == null:
		ghost.hide()
		return
	var at := Vector2(hit.x, hit.z)
	var cell: Dictionary = BlueprintData.cell_at(world.layout.blueprint, at)
	if not BlueprintData.valid_cell(world.layout.blueprint, cell):
		ghost.hide()
		return
	var center: Vector2 = BlueprintData.cell_center(world.layout.blueprint, cell)
	ghost.position = Vector3(center.x, .08, center.y)
	(ghost.mesh as BoxMesh).size = Vector3(BlueprintData.FLOOR_GRID, .07, BlueprintData.FLOOR_GRID)
	var removing: bool = %BlueprintFloorTool.selected == 1
	if wall_drag_button == MOUSE_BUTTON_RIGHT: removing = not removing
	var eligible: bool = world.layout.floor_cell_blocker(cell, removing).is_empty()
	(ghost.material_override as StandardMaterial3D).albedo_color = Color("6ed9ab", .48) if eligible else Color("f27777", .48)
	ghost.show()

func _partition_at(at: Vector2) -> Dictionary:
	var best := {}
	var distance := .36
	for part: Dictionary in world.layout.blueprint.partitions:
		var delta := Vector2(float(part.x), float(part.z)).distance_to(at)
		if delta < distance:
			distance = delta
			best = part
	return best

func _paint_action(at: Vector2, button: int) -> void:
	var erase := button == MOUSE_BUTTON_RIGHT
	match %BlueprintFloorTool.selected:
		3:
			world.layout.paint_floor_finish(at, 0 if erase else %BlueprintTileFinish.selected)
		4:
			var kind: String = ["wall","window","door"][%BlueprintOpeningKind.selected]
			if erase or %BlueprintOpeningWidth.selected == 0:
				world.layout.paint_exterior_edge(at, "wall" if erase else kind, 0 if erase else %BlueprintWallFinish.selected)
			else:
				world.layout.paint_exterior_span(at, %BlueprintOpeningWidth.selected+1, kind, %BlueprintWallFinish.selected)
		5:
			world.layout.paint_partition_finish(at, 0 if erase else %BlueprintWallFinish.selected)

func _paint_hover(pixel: Vector2) -> void:
	var ghost: MeshInstance3D = world.get_node("WallPreview")
	var at: Variant = _floor_hit(pixel)
	if at == null:
		ghost.hide()
		world.get_node("BlueprintOverlay").clear_region()
		return
	var tool: int = %BlueprintFloorTool.selected
	var good := false
	var center := Vector2.ZERO
	var size := Vector3(BlueprintData.FLOOR_GRID,.07,BlueprintData.FLOOR_GRID)
	if tool == 3:
		var cell: Dictionary = BlueprintData.cell_at(world.layout.blueprint, at)
		good = world.layout.blueprint.shape == "custom" and BlueprintData.valid_cell(world.layout.blueprint,cell) and not BlueprintData.has_cell(world.layout.blueprint,cell)
		if good: center = BlueprintData.cell_center(world.layout.blueprint,cell)
	elif tool == 4:
		var edge: Dictionary = BlueprintData.nearest_edge(world.layout.blueprint,at)
		good = not edge.is_empty()
		if good:
			var span: Array = BlueprintData.edge_span(world.layout.blueprint,edge,%BlueprintOpeningWidth.selected+1)
			if not span.is_empty():
				var first: Vector2 = BlueprintData.edge_center(world.layout.blueprint,span[0])
				var last: Vector2 = BlueprintData.edge_center(world.layout.blueprint,span[-1])
				center = (first+last)*.5
				var length: float = float(span.size())*BlueprintData.FLOOR_GRID
				size = Vector3(.14,.10,length) if edge.dx != 0 else Vector3(length,.10,.14)
				good = world.layout.exterior_span_blocker(at,span.size(),["wall","window","door"][%BlueprintOpeningKind.selected],%BlueprintWallFinish.selected).is_empty()
			else:
				good = false
	else:
		var part: Dictionary = _partition_at(at)
		good = not part.is_empty()
		if good:
			center = Vector2(float(part.x),float(part.z))
			size = Vector3(1,.10,.14) if part.axis == "x" else Vector3(.14,.10,1)
	if not good:
		ghost.hide()
		world.get_node("BlueprintOverlay").clear_region()
		return
	ghost.position = Vector3(center.x,.08,center.y)
	(ghost.mesh as BoxMesh).size = size
	(ghost.material_override as StandardMaterial3D).albedo_color = Color("6ed9ab",.48)
	ghost.show()

func _brush_key(at: Vector2) -> Vector2:
	var tool: int = %BlueprintFloorTool.selected
	if tool == 0 or tool == 5: return at.snapped(Vector2.ONE * BlueprintData.WALL_GRID)
	if tool == 4:
		var edge: Dictionary = BlueprintData.nearest_edge(world.layout.blueprint,at)
		if edge.is_empty(): return Vector2(INF,INF)
		return BlueprintData.edge_center(world.layout.blueprint,edge)
	var cell: Dictionary = BlueprintData.cell_at(world.layout.blueprint,at)
	return Vector2(cell.ix,cell.iz)

func _brush_action(at: Vector2, button: int) -> void:
	match %BlueprintFloorTool.selected:
		0: _wall_action(at,button)
		1,2: _floor_action(at,button)
		3,4,5: _paint_action(at,button)

func _wall_hover(pixel: Vector2) -> void:
	var ghost: MeshInstance3D = world.get_node("WallPreview")
	var at: Variant = _blueprint_floor_hit(pixel)
	if at == null:
		ghost.hide()
		return
	var along_x := _wall_axis() == "x"
	ghost.position = Vector3(at.x, .08, at.y)
	(ghost.mesh as BoxMesh).size = Vector3(1.0, .10, .14) if along_x else Vector3(.14, .10, 1.0)
	var part: Dictionary = BlueprintData.clean_partition({"x":at.x, "z":at.y, "axis":_wall_axis(), "kind":_wall_kind()})
	var valid_wall: bool = world.layout.partition_blocker(part).is_empty()
	var tint := Color("6ed9ab", .48) if valid_wall else Color("f27777", .48)
	(ghost.material_override as StandardMaterial3D).albedo_color = tint
	ghost.show()

func _blueprint_input(event: InputEvent) -> void:
	if %BlueprintFloorTool.selected == 7:
		_edge_move_input(event)
		return
	if %BlueprintFloorTool.selected == 6:
		_aperture_input(event)
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_overview(.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if not event.pressed and %BlueprintFloorTool.selected == 0:
				world.layout.end_wall_stroke()
				%BlueprintStrokeInfo.text = "完成：有效 %d 段 / 阻挡 %d 段" % [wall_stroke_good.size(),wall_stroke_bad.size()]
				_reset_wall_stroke()
			wall_drag_button = event.button_index if event.pressed else 0
			last_wall_cell = Vector2(INF,INF)
			if event.pressed:
				if %BlueprintFloorTool.selected == 0:
					_reset_wall_stroke()
					world.layout.begin_wall_stroke()
				var at: Variant = _blueprint_floor_hit(event.position) if %BlueprintFloorTool.selected == 0 else _floor_hit(event.position)
				if at != null:
					if %BlueprintFloorTool.selected == 0: _stroke_wall_step(at,event.button_index)
					else: _brush_action(at,event.button_index)
					last_wall_cell = _brush_key(at)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if %BlueprintFloorTool.selected == 0: _wall_hover(event.position)
		elif %BlueprintFloorTool.selected in [1,2]: _floor_hover(event.position)
		else: _paint_hover(event.position)
		if wall_drag_button != 0:
			var at: Variant = _blueprint_floor_hit(event.position) if %BlueprintFloorTool.selected == 0 else _floor_hit(event.position)
			if at != null:
				var key := _brush_key(at)
				if key != last_wall_cell:
					if %BlueprintFloorTool.selected == 0: _continue_wall_stroke(at,wall_drag_button)
					else:
						_brush_action(at,wall_drag_button)
						last_wall_cell = key
		get_viewport().set_input_as_handled()

func _sync_layout() -> void:
	if not world.layout.active: return
	var layout = world.layout
	%LayoutSelection.text = "选中：" + layout.name_for(layout.selected)
	var node: Node3D = layout.nodes[layout.selected]
	%LayoutPose.text = "X %.2f   Z %.2f\n旋转 %.0f°" % [node.position.x,node.position.z,rad_to_deg(node.rotation.y)]
	var dims: Vector3 = layout.bounds_for(layout.selected) * node.scale.abs()
	var placement: String = "位置有效" if layout.valid else "碰撞：%s" % layout.message
	var wall_distance: float = layout.wall_clearance(layout.selected)
	%LayoutSize.text = "占地 %.2f × %.2f 米 · 高 %.2f 米\n%s%s" % [dims.x,dims.z,dims.y,placement, "\n距外墙约 %.2f 米" % wall_distance if wall_distance >= 0.0 else ""]
	%LayoutSize.modulate = Color("ff9688") if not layout.valid else Color("b9e9d5")
	var inner_distance: float = layout.inner_wall_clearance(layout.selected)
	%FurnitureAssistHint.text = ("最近内墙约 %.2f 米 · " % inner_distance if inner_distance >= 0.0 else "附近无内墙 · ") + layout.furniture_spacing_summary(layout.selected)
	var floor_furniture: bool = layout.is_floor(layout.selected) and layout.placed_instances.has(layout.selected)
	%InnerWallSnapToggle.disabled = not floor_furniture
	for axis: String in ["X","Z"]:
		get_node("%AlignFurniture"+axis).disabled = not floor_furniture or layout.nearest_alignment(layout.selected,axis.to_lower()).is_empty()
		get_node("%DistributeFurniture"+axis).disabled = not floor_furniture or layout._matching_furniture(layout.selected).size() < 3
	%LayoutMessage.text = layout.message
	_sync_blueprint_ui()
	if blueprint_mode: layout.gizmo.hide()
	%LayoutMessage.modulate = Color.WHITE if layout.valid else Color("ff756a")
	%ApplyLayout.disabled = not layout.valid or not layout.placing_role.is_empty()
	%MoveTool.set_pressed_no_signal(layout.tool == "move")
	%RotateTool.set_pressed_no_signal(layout.tool == "rotate")
	%CopyFurniture.disabled = not layout.templates.has(layout.Data.base_role(layout.selected)) or not layout.placing_role.is_empty()
	%DeleteFurniture.disabled = not InventoryData.is_room_furniture_role(layout.Data.base_role(layout.selected)) or not layout.placing_role.is_empty()
	for item_id: String in furniture_buttons:
		var unused := InventoryData.unused_uid(layout.available_inventory, layout.placed_instances, item_id)
		var existing := false
		for role: String in layout.placed_instances:
			if layout.Data.base_role(role) == ItemCatalog.lookup(item_id).subcategory:
				existing = true
				break
		furniture_buttons[item_id].disabled = (unused.is_empty() and not existing) or not layout.placing_role.is_empty()
		var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
		var count := InventoryData.count(layout.available_inventory, item_id)
		var status_text: String = "%s · 空闲 %d/%d" % [item.name, _count_unused(item_id), count]
		if furniture_cards == null:
			furniture_buttons[item_id].text = status_text
		if InventoryData.ROOM_DEFAULTS.values().has(item_id):
			var legacy_role: String = item.subcategory
			var legacy: Button = get_node_or_null("%Place_" + legacy_role) as Button
			if legacy != null:
				legacy.text = status_text
				legacy.disabled = furniture_buttons[item_id].disabled
	if furniture_palette != null:
		var colorable := InventoryData.is_room_furniture_role(layout.Data.base_role(layout.selected))
		furniture_palette.disabled = not colorable
		furniture_palette.select(layout.color_for(layout.selected) if colorable else 0)
	%UndoLayout.disabled = layout.undo_stack.is_empty()
	%RedoLayout.disabled = layout.redo_stack.is_empty()
	var style: Dictionary = world.get_node("Room").style
	for key: String in ["wall","floor","light","rgb","effect","wall_pattern","floor_pattern","atmosphere"]:
		(get_node("%Style_" + key) as OptionButton).select(int(style.get(key, 0)))
	(%Style_brightness as HSlider).set_value_no_signal(float(style.get("brightness", 70)))
	(%Style_ambience_volume as HSlider).set_value_no_signal(float(style.get("ambience_volume", 70)))
	%AmbienceVolumeLabel.text = "雨声音量 · %d%%（0 为静音）" % int(style.get("ambience_volume", 70))
	for role: String in layout.NAMES: get_node("%Layout_" + role).set_pressed_no_signal(layout.selected == role)
	for role: String in catalog_special_buttons:
		var info: Dictionary = catalog_special_buttons[role]
		info.button.disabled = not layout.active or not layout.placing_role.is_empty()
		info.button.text = str(info.label) + (" · 已选中" if layout.selected == role else "")
	if furniture_cards != null: furniture_cards.refresh_counts()
	if room_ui != null: room_ui.sync()

func _count_unused(item_id: String) -> int:
	var total := 0
	for entry: Dictionary in world.layout.available_inventory:
		if entry.item_id == item_id and not world.layout.placed_instances.values().has(entry.uid):
			total += 1
	return total

func set_screen_focused(value: bool, animate: bool = true) -> void:
	if world.layout.active: return
	_set_mode("screen" if value else "overview", animate)

func _set_mode(value: String, animate: bool) -> void:
	if screen_mouse_down:
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = last_screen_point
		%DesktopViewport.push_input(release, true)
	screen_mouse_down = false
	dragging = false
	orbiting = false
	if value != "screen":
		for dialog: Window in %DesktopViewport.get_embedded_subwindows(): dialog.hide()
	world.set_mode(value, animate)
	_sync_mode()

func _sync_mode() -> void:
	%ReturnOverview.visible = screen_focused
	%ResetView.visible = world.mode in ["overview", "layout"]
	%EditLayout.visible = world.mode == "overview"
	%BlueprintToggle.visible = world.mode == "layout"
	%ApplyLayout.visible = world.mode == "layout"
	%CancelLayout.visible = world.mode == "layout"
	%LayoutPanel.visible = world.mode == "layout"
	%FocusToggle.visible = world.mode == "overview"
	%ManageDevices.visible = world.mode == "overview"
	%OverviewHelp.visible = world.mode == "overview"
	%ViewTitle.text = {"overview": "我的空间", "screen": "屏幕操作", "layout":"房间设计"}[world.mode]
	if room_ui != null: room_ui.sync()

func _reframe_screen() -> void:
	if not screen_focused: return
	if world.transitioning:
		if not world.motion.finished.is_connected(_reframe_screen): world.motion.finished.connect(_reframe_screen, CONNECT_ONE_SHOT)
	else:
		world.set_mode("screen", false)

func canvas_point_for_screen(logical: Vector2) -> Vector2:
	return world.pixel_for_screen(logical / Vector2(%DesktopViewport.size))

func _push_screen_input(event: InputEvent, allow_outside: bool = false) -> bool:
	var mapped := event.duplicate() as InputEvent
	if event is InputEventMouse:
		var uv: Variant = world.screen_uv(event.position, not allow_outside)
		if uv == null: return false
		mapped.position = uv * Vector2(%DesktopViewport.size)
		mapped.global_position = mapped.position
		last_screen_point = mapped.position
		if mapped is InputEventMouseMotion:
			var previous: Variant = world.screen_uv(event.position - event.relative, false)
			if previous != null: mapped.relative = (uv - previous) * Vector2(%DesktopViewport.size)
	%DesktopViewport.push_input(mapped, true)
	return true

func _handle_room_precision_key(event: InputEventKey) -> bool:
	# Scene-only hotkeys: preserve inventory navigation, blueprint tools,
	# text input and browser/desktop app shortcuts.
	if blueprint_mode or room_ui.mode != "furniture" or room_ui.catalog_open: return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return false
	var layout = world.layout
	if not layout.gesture.is_empty() or not pending_drag_role.is_empty(): return false
	var direction := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: direction = Vector2.LEFT
		KEY_RIGHT: direction = Vector2.RIGHT
		KEY_UP: direction = Vector2.UP
		KEY_DOWN: direction = Vector2.DOWN
	if not direction.is_zero_approx():
		var moved: bool = layout.nudge_selected(direction,event.shift_pressed)
		room_ui.show_keyboard_feedback(("已微调 1 cm" if event.shift_pressed else "已移动一个网格") if moved else "已到达边界 · 无法继续移动")
		return true
	# Continuous arrow-key nudges are useful, but holding S/Q/E should not
	# rapidly toggle snapping or cause unexpected multiple rotations.
	if event.echo: return false
	match event.keycode:
		KEY_S:
			layout.set_snapping(not layout.snapping)
			room_ui.show_keyboard_feedback("网格吸附：%s · S 切换" % ("开启" if layout.snapping else "关闭"))
			return true
		KEY_Q, KEY_E:
			layout.rotate_step(-1 if event.keycode == KEY_Q else 1,event.shift_pressed)
			room_ui.show_keyboard_feedback("精细旋转 1°" if event.shift_pressed else "旋转 %.0f°" % layout.angle_step)
			return true
	return false

func _input(event: InputEvent) -> void:
	if modal_input_guard:
		get_viewport().set_input_as_handled()
		return
	# GUI can consume a release over the header; always end the camera gesture.
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_clear_gesture.call_deferred()
	if not event is InputEventKey or world.transitioning: return
	if world.layout.active:
		# Focused text, drop-down and numeric controls retain their own keys.
		# Escape still cancels the current room action.
		var focused: Control = get_viewport().gui_get_focus_owner()
		if (focused is LineEdit or focused is TextEdit or focused is OptionButton or focused is Range) and event.keycode != KEY_ESCAPE:
			return
		if world.layout.group_copy_preview_active:
			if event.pressed and not event.meta_pressed:
				var preview = world.layout
				if event.keycode == KEY_ESCAPE or event.ctrl_pressed and event.keycode in [KEY_Z,KEY_Y]:
					if not event.echo: preview.cancel_group_copy_preview()
				elif not event.ctrl_pressed and not event.alt_pressed:
					if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not event.echo:
						room_ui.scene_actions.confirm_group_copy_preview()
					elif event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
						var direction := Vector2.ZERO
						match event.keycode:
							KEY_LEFT: direction = Vector2.LEFT
							KEY_RIGHT: direction = Vector2.RIGHT
							KEY_UP: direction = Vector2(0,-1)
							KEY_DOWN: direction = Vector2(0,1)
						preview.nudge_group_copy_preview(direction,event.shift_pressed)
					elif event.keycode in [KEY_Q,KEY_E] and not event.echo:
						preview.rotate_group_copy_preview_step(-1 if event.keycode == KEY_Q else 1,event.shift_pressed)
					elif event.keycode == KEY_F and not event.echo and not event.shift_pressed:
						preview.find_group_copy_preview_space()
					elif event.keycode == KEY_S and not event.echo and not event.shift_pressed:
						preview.set_snapping(not preview.snapping)
						preview.set_group_copy_preview_offset(preview.group_copy_preview_offset,true)
					elif event.keycode == KEY_TAB and not event.echo and not event.shift_pressed:
						preview.cancel_group_copy_preview()
						set_blueprint_mode(true)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo and blueprint_mode and event.keycode == KEY_ESCAPE:
			set_blueprint_mode(false)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo and event.keycode in [KEY_1,KEY_2,KEY_3] and not event.meta_pressed:
			var slot: int = int(event.keycode)-int(KEY_1)+1
			if event.ctrl_pressed and event.shift_pressed and not event.alt_pressed:
				if room_ui.scene_actions.perform_quick_slot("save",slot):
					get_viewport().set_input_as_handled()
					return
			elif event.alt_pressed and not event.ctrl_pressed and not event.shift_pressed:
				if room_ui.scene_actions.perform_quick_slot("recall",slot):
					get_viewport().set_input_as_handled()
					return
		if event.pressed and _handle_room_precision_key(event):
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo:
			if event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y]:
				if event.keycode == KEY_Y or event.shift_pressed: world.layout.redo()
				else: world.layout.undo()
				get_viewport().set_input_as_handled()
				return
			if event.ctrl_pressed and event.keycode == KEY_D:
				if not blueprint_mode and room_ui.mode == "furniture" and not room_ui.catalog_open and world.layout.group_selection.size() > 1:
					room_ui.scene_actions.perform_action("duplicate")
				elif world.layout.group_selection.size() <= 1:
					world.layout.duplicate_selected()
				get_viewport().set_input_as_handled()
				return
			# Same low-friction blueprint switching as common room builders.
			# Input fields keep Tab/letter keys for ordinary text entry.
			if event.keycode == KEY_TAB:
				set_blueprint_mode(not blueprint_mode)
				get_viewport().set_input_as_handled()
				return
			match event.keycode:
				KEY_DELETE:
					if not blueprint_mode and room_ui.mode == "furniture" and not room_ui.catalog_open and world.layout.group_selection.size() > 1:
						room_ui.scene_actions.perform_action("store")
					elif world.layout.group_selection.size() <= 1:
						world.layout.delete_selected()
				KEY_ESCAPE:
					if not world.layout.placing_role.is_empty():
						world.layout.cancel_placement()
					elif room_ui.scene_actions.swatches.visible:
						room_ui.scene_actions.hide_colors()
						room_ui.sync()
					elif room_ui.scene_actions.arrange_panel.visible:
						room_ui.scene_actions.hide_arrange()
						room_ui.sync()
					elif room_ui.scene_actions.group_panel.visible:
						room_ui.scene_actions.hide_group_members()
						room_ui.sync()
					elif room_ui.scene_actions.quick_groups_panel.visible:
						room_ui.scene_actions.hide_quick_groups()
						room_ui.sync()
					elif room_ui.catalog_open:
						room_ui.catalog_open = false
						room_ui.sync()
					elif world.layout.group_selection.size() > 1:
						world.layout.clear_group_selection()
					else:
						finish_layout(false)
				KEY_B:
					if not blueprint_mode and world.layout.placing_role.is_empty():
						room_ui.catalog_open = not room_ui.catalog_open
						room_ui.sync()
				KEY_G: world.layout.set_tool("move")
				KEY_R: world.layout.set_tool("rotate")
				KEY_F:
					# Keep the furniture search box usable while in edit mode.
					if not blueprint_mode and not get_viewport().gui_get_focus_owner() is LineEdit:
						world.focus_selected()
		get_viewport().set_input_as_handled()
		return
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE and world.mode != "overview":
		if %DesktopViewport.get_embedded_subwindows().any(func(window: Window) -> bool: return window.visible): return
		set_screen_focused(false)
		get_viewport().set_input_as_handled()
	elif screen_focused:
		_push_screen_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if world.transitioning:
		if event is InputEventMouseButton and not event.pressed:
			dragging = false
			orbiting = false
		return
	if world.layout.active:
		if blueprint_mode: _blueprint_input(event)
		else: _layout_input(event)
		return
	if screen_focused:
		if event is InputEventMouse:
			var forwarded := _push_screen_input(event, screen_mouse_down or event is InputEventMouseMotion)
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				screen_mouse_down = event.pressed and forwarded
			if forwarded: get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var was_dragging := dragging
			dragging = event.pressed
			if event.pressed:
				pointer_origin = event.position
				camera_dragged = false
			elif was_dragging and world.mode == "overview" and not camera_dragged and pointer_origin.distance_to(event.position) < DRAG_THRESHOLD:
				var role: String = world.pick_at(event.position)
				if role == "monitor" and world.screen_uv(event.position) != null: set_screen_focused(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var amount := pow(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1, event.factor if event.factor > 0 else 1.0)
			world.zoom_overview(amount)
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if dragging and pointer_origin.distance_to(event.position) >= DRAG_THRESHOLD: camera_dragged = true
		if (dragging and camera_dragged) or orbiting: world.orbit_overview(event.relative)
		if dragging or orbiting: get_viewport().set_input_as_handled()

func _cancel_pending_furniture_drag() -> void:
	pending_drag_role = ""
	pending_drag_operation = ""

func _begin_marquee(point: Vector2, additive: bool) -> void:
	marquee_origin = point
	marquee_pending = true
	marquee_active = false
	marquee_additive = additive

func _cancel_marquee() -> void:
	marquee_pending = false
	marquee_active = false
	marquee_additive = false
	if room_ui != null and room_ui.scene_actions != null:
		room_ui.scene_actions.hide_marquee()

func _finish_marquee(point: Vector2) -> void:
	if marquee_active:
		var window: Rect2 = Rect2(marquee_origin,point-marquee_origin).abs()
		# Left-to-right selects whole projected objects; right-to-left selects
		# every object that crosses the selection window.
		world.layout.marquee_select(window,point.x < marquee_origin.x,marquee_additive)
	_cancel_marquee()

func _layout_input(event: InputEvent) -> void:
	var layout = world.layout
	if layout.group_copy_preview_active:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				layout.snap_bypass = event.alt_pressed
				layout.group_copy_preview_at(event.position)
				room_ui.scene_actions.confirm_group_copy_preview()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				layout.cancel_group_copy_preview()
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				world.zoom_overview(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
		elif event is InputEventMouseMotion:
			layout.snap_bypass = event.alt_pressed
			layout.group_copy_preview_at(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if not layout.placing_role.is_empty():
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				layout.snap_bypass = event.alt_pressed
				layout.preview_at(event.position)
				layout.confirm_placement()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				layout.cancel_placement()
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				if event.shift_pressed or event.ctrl_pressed:
					layout.rotate_step(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
				else:
					world.zoom_overview(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				if marquee_pending:
					_finish_marquee(event.position)
				else:
					_cancel_pending_furniture_drag()
					layout.end_drag()
			else:
				_cancel_pending_furniture_drag()
				_cancel_marquee()
				layout.snap_bypass = event.alt_pressed
				if event.ctrl_pressed and not blueprint_mode and room_ui.mode == "furniture":
					# Ctrl+click on furniture toggles it; Ctrl+drag blank floor
					# adds screen-rectangle members without moving objects.
					var clicked: String = world.pick_at(event.position)
					if not clicked.is_empty():
						layout.toggle_group_member(clicked)
					else:
						_begin_marquee(event.position,true)
				else:
					var handle: String = layout.pick_handle(event.position)
					if not handle.is_empty():
						# Gizmo handles move/rotate the entire current selection.
						layout.begin_drag(event.position,"rotate" if handle == "rotate" else "move",handle,true)
					else:
						var role: String = world.pick_at(event.position)
						if not role.is_empty():
							layout.select(role,true)
							# A click selects without touching the pose. Dragging
							# starts after a short screen-space movement threshold.
							pending_drag_role = role
							pending_drag_start = event.position
							pending_drag_operation = "rotate" if event.shift_pressed else "move"
						elif room_ui.mode == "furniture":
							_begin_marquee(event.position,false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_cancel_pending_furniture_drag()
				_cancel_marquee()
			orbiting = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_overview(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		layout.snap_bypass = event.alt_pressed
		if not layout.placing_role.is_empty():
			layout.preview_at(event.position)
			get_viewport().set_input_as_handled()
		elif orbiting: world.orbit_overview(event.relative)
		elif marquee_pending:
			if not marquee_active and marquee_origin.distance_to(event.position) >= DRAG_THRESHOLD:
				marquee_active = true
			if marquee_active: room_ui.scene_actions.show_marquee(marquee_origin,event.position)
		elif not pending_drag_role.is_empty():
			if pending_drag_start.distance_to(event.position) >= DRAG_THRESHOLD:
				var selected_role: String = pending_drag_role
				var operation: String = pending_drag_operation
				_cancel_pending_furniture_drag()
				if layout.selected == selected_role and layout.nodes.has(selected_role):
					layout.begin_drag(pending_drag_start,operation)
					layout.drag_to(event.position)
		else: layout.drag_to(event.position)
		if orbiting or marquee_pending or not layout.gesture.is_empty() or not pending_drag_role.is_empty(): get_viewport().set_input_as_handled()

func _clear_gesture() -> void:
	_cancel_pending_furniture_drag()
	_cancel_marquee()
	world.layout.end_wall_stroke()
	if dragging_custom_edge:
		world.layout.end_custom_edge_drag()
		dragging_custom_edge = false
	_reset_wall_stroke()
	if dragging_aperture:
		world.layout.end_aperture_drag()
		dragging_aperture = false
	dragging = false
	orbiting = false
	world.layout.end_drag()

func _forward_modal_input(event: InputEvent) -> void:
	if not screen_focused or world.transitioning: return
	if not %DesktopViewport.get_embedded_subwindows().any(func(window: Window) -> bool: return window.visible and window.exclusive): return
	modal_input_guard = true
	var local_event: InputEvent = event.xformed_by(get_viewport().get_final_transform().affine_inverse())
	_push_screen_input(local_event, true)
	set_deferred("modal_input_guard", false)

func open_app(id: String, tab: String = "") -> Control:
	if session == null or not APPS.has(id): return null
	if id == "game" and session.active().get("kind") != "play":
		session.notice.emit("从游戏库启动一款游戏后，这里会显示游玩窗口。")
		return null
	if windows.has(id):
		var existing = windows[id]
		existing.show()
		existing.move_to_front()
		if id == "browser" and not tab.is_empty(): existing.content.set_tab(tab)
		if id == "platform": existing.content.refresh_client(true)
		refresh()
		return existing.content
	var window = WindowScene.instantiate()
	window.window_title = APPS[id][0]
	window.name = "App_" + id
	area.add_child(window)
	var app = load(APPS[id][1]).instantiate()
	app.session = session
	if id == "platform": app.state = session.state
	if id == "browser" and not tab.is_empty(): app.tab = tab
	window.mount(app)
	windows[id] = window
	window.close_requested.connect(func() -> void: close_app(id))
	window.minimize_requested.connect(func() -> void: minimize_app(id))
	if id == "platform":
		app.host_requested.connect(func(action: String) -> void:
			if action == "close": close_app(id)
			else: minimize_app(id)
		)
	refresh()
	return app

func minimize_app(id: String) -> void:
	if windows.has(id): windows[id].hide()
	refresh()

func close_app(id: String) -> void:
	if not windows.has(id): return
	var window = windows[id]
	windows.erase(id)
	window.hide()
	window.queue_free()
	if id == "game": session.stop_play()
	refresh()

func _update_status() -> void:
	if session == null: return
	if is_instance_valid(resume_button): resume_button.disabled = session.active().get("kind") != "play"
	if is_instance_valid(status): status.text = "%d 点 · %s" % [session.state.wallet, "直播中" if session.active().get("streaming", false) else ("游玩中" if session.active().get("kind") == "play" else "在线")]

func refresh() -> void:
	if session == null or not is_inside_tree() or not is_instance_valid(tasks): return
	_update_equipment()
	if windows.has("game") and session.active().get("kind") != "play":
		close_app("game")
		return
	for child: Node in tasks.get_children():
		tasks.remove_child(child)
		child.queue_free()
	for id: String in windows:
		var key := id
		var task = preload("res://scenes/shared/text_button.tscn").instantiate()
		task.text = ("● " if windows[id].visible else "○ ") + APPS[id][0]
		task.name = "Task_" + id
		task.pressed.connect(func() -> void: open_app(key))
		tasks.add_child(task)
	_update_status()

func show_notice(message: String) -> void:
	var toast: Label = screen_node("ScreenToast")
	toast.text = message
	toast.show()
	toast.move_to_front()
	screen_node("ScreenToastTimer").start()
