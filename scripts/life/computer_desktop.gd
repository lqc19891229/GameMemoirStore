extends Node3D
const WindowScene = preload("res://scenes/computer/ui/app_window.tscn")
const ItemCatalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
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
var screen_mouse_down := false
var last_screen_point := Vector2.ZERO
var furniture_buttons: Dictionary = {}
var furniture_palette: OptionButton
var blueprint_mode := false
var wall_drag_button := 0
var last_wall_cell := Vector2(INF, INF)
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
	%BlueprintFloorTool.item_selected.connect(func(_index: int) -> void:
		wall_drag_button = 0
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
	var styles := {
		"wall":["墙面 · 鼠尾草","墙面 · 奶油米","墙面 · 雾蓝"],
		"floor":["地板 · 原木","地板 · 浅灰木","地板 · 深胡桃"],
		"light":["灯光 · 午后暖阳","灯光 · 清晨冷光","灯光 · 夜间暖灯"],
		"rgb":["冰青","深蓝","紫罗兰","洋红","琥珀","薄荷","玫瑰"],
		"effect":["常亮","呼吸","彩虹循环"]
	}
	for key: String in styles:
		var selector: OptionButton = get_node("%Style_" + key)
		for label: String in styles[key]: selector.add_item(label)
		selector.item_selected.connect(func(index: int) -> void: world.layout.set_style(key, index))
	%Style_brightness.value_changed.connect(func(value: float) -> void: world.layout.set_style("brightness", roundi(value)))
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
	world.layout.load_saved(session.state.life.get("workstation_layout", {}))
	world.layout.load_colors(session.state.life.get("furniture_colors", {}))
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
	if not world.layout.finish(apply): return
	if blueprint_mode: set_blueprint_mode(false)
	_set_mode("overview", false)
	if apply and session != null:
		session.state.life["workstation_layout"] = world.layout.export_layout()
		session.state.life["placements"] = world.layout.committed_placements.duplicate()
		session.state.life["furniture_colors"] = world.layout.committed_colors.duplicate()
		session.state.life["room_style"] = world.layout.committed_style.duplicate()
		session.state.life["room_blueprint"] = world.layout.committed_blueprint.duplicate()
		session.state.save_state()

func _start_purchased_furniture_placement(item_id: String, uid: String) -> void:
	if world.layout.active: return
	set_screen_focused(false, false)
	begin_layout()
	if not world.layout.start_place(item_id, uid): finish_layout(false)

func _build_furniture_catalog() -> void:
	for role: String in InventoryData.ROOM_DEFAULTS:
		var item_id: String = InventoryData.ROOM_DEFAULTS[role]
		var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
		var button: Button = get_node("%Place_" + role)
		button.text = item.name if item != null else role
		var selected_id := item_id
		button.pressed.connect(func() -> void: _start_inventory_placement(selected_id))
		furniture_buttons[item_id] = button
	furniture_palette = %FurniturePalette
	for label: String in world.layout.FURNITURE_COLOR_LABELS:
		furniture_palette.add_item(label)
	furniture_palette.item_selected.connect(func(index: int) -> void: world.layout.set_furniture_color(index))

func _start_inventory_placement(item_id: String) -> void:
	var uid := InventoryData.unused_uid(world.layout.available_inventory, world.layout.placed_instances, item_id)
	if uid.is_empty(): return
	world.layout.start_place(item_id, uid)

func set_blueprint_mode(enabled: bool) -> void:
	if enabled and not world.layout.active: return
	if enabled and not world.layout.placing_role.is_empty(): world.layout.cancel_placement()
	blueprint_mode = enabled
	wall_drag_button = 0
	_hide_wall_preview()
	world.get_node("Room").set_partition_editing(enabled)
	%BlueprintToggle.set_pressed_no_signal(enabled)
	%Content.visible = not enabled
	%BlueprintPanel.visible = enabled
	world.set_blueprint_camera(enabled)
	if world.layout.active: world.layout.update()
	if enabled: world.layout.gizmo.hide()
	_sync_blueprint_ui()

func _sync_blueprint_ui() -> void:
	var blueprint: Dictionary = world.layout.blueprint
	%BlueprintShape.select(2 if blueprint.shape == "custom" else 1 if blueprint.shape == "l" else 0)
	%BlueprintNotchWidth.editable = blueprint.shape == "l"
	%BlueprintNotchDepth.editable = blueprint.shape == "l"
	%BlueprintFloorTool.disabled = blueprint.shape != "custom" and %BlueprintFloorTool.selected != 0
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
	%BlueprintStatus.text = world.layout.message if world.layout.message.begins_with("调整失败") or world.layout.message.begins_with("建造失败") or world.layout.message.begins_with("绘制失败") else "%s · %.1f × %.1f 米 · 内墙 %d 段 · 缺口 %d 格" % ["自由轮廓" if blueprint.shape == "custom" else "L 型" if blueprint.shape == "l" else "矩形", blueprint.width, blueprint.depth, blueprint.partitions.size(), blueprint.removed_cells.size()]

func _wall_axis() -> String:
	return "z" if %WallAxis.selected == 1 else "x"

func _wall_kind() -> String:
	return "door" if %WallKind.selected == 1 else "wall"

func _hide_wall_preview() -> void:
	if is_instance_valid(world):
		world.get_node("WallPreview").hide()

func _blueprint_floor_hit(pixel: Vector2) -> Variant:
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	if hit == null: return null
	return Vector2(snappedf(hit.x, BlueprintData.WALL_GRID), snappedf(hit.z, BlueprintData.WALL_GRID))

func _wall_action(at: Vector2, button: int) -> void:
	var remove: bool = button == MOUSE_BUTTON_RIGHT or %WallRemoveMode.button_pressed
	if remove:
		world.layout.remove_partition(at)
	else:
		world.layout.add_partition(at, _wall_axis(), _wall_kind())

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
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_overview(.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			wall_drag_button = event.button_index if event.pressed else 0
			last_wall_cell = Vector2(INF, INF)
			if event.pressed:
				var at: Variant = _blueprint_floor_hit(event.position)
				if at != null:
					if %BlueprintFloorTool.selected == 0:
						_wall_action(at, event.button_index)
						last_wall_cell = at
					else:
						var grid_cell: Dictionary = BlueprintData.cell_at(world.layout.blueprint, at)
						_floor_action(at, event.button_index)
						last_wall_cell = Vector2(grid_cell.ix, grid_cell.iz)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if %BlueprintFloorTool.selected == 0: _wall_hover(event.position)
		else: _floor_hover(event.position)
		if wall_drag_button != 0:
			var at: Variant = _blueprint_floor_hit(event.position)
			if at != null:
				if %BlueprintFloorTool.selected == 0 and at != last_wall_cell:
					_wall_action(at, wall_drag_button)
					last_wall_cell = at
				elif %BlueprintFloorTool.selected != 0:
					var grid_cell: Dictionary = BlueprintData.cell_at(world.layout.blueprint, at)
					var cell_id := Vector2(grid_cell.ix, grid_cell.iz)
					if cell_id != last_wall_cell:
						_floor_action(at, wall_drag_button)
						last_wall_cell = cell_id
		get_viewport().set_input_as_handled()

func _sync_layout() -> void:
	if not world.layout.active: return
	var layout = world.layout
	%LayoutSelection.text = "选中：" + layout.name_for(layout.selected)
	var node: Node3D = layout.nodes[layout.selected]
	%LayoutPose.text = "X %.2f   Z %.2f\n旋转 %.0f°" % [node.position.x,node.position.z,rad_to_deg(node.rotation.y)]
	%LayoutMessage.text = layout.message
	_sync_blueprint_ui()
	if blueprint_mode: layout.gizmo.hide()
	%LayoutMessage.modulate = Color.WHITE if layout.valid else Color("ff756a")
	%ApplyLayout.disabled = not layout.valid or not layout.placing_role.is_empty()
	%MoveTool.set_pressed_no_signal(layout.tool == "move")
	%RotateTool.set_pressed_no_signal(layout.tool == "rotate")
	%CopyFurniture.disabled = not layout.templates.has(layout.Data.base_role(layout.selected)) or not layout.placing_role.is_empty()
	%DeleteFurniture.disabled = not InventoryData.ROOM_DEFAULTS.has(layout.Data.base_role(layout.selected)) or not layout.placing_role.is_empty()
	for item_id: String in furniture_buttons:
		var unused := InventoryData.unused_uid(layout.available_inventory, layout.placed_instances, item_id)
		furniture_buttons[item_id].disabled = unused.is_empty() or not layout.placing_role.is_empty()
		var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
		var count := InventoryData.count(layout.available_inventory, item_id)
		furniture_buttons[item_id].text = "%s · 空闲 %d/%d" % [item.name, _count_unused(item_id), count]
	if furniture_palette != null:
		var colorable := InventoryData.ROOM_DEFAULTS.has(layout.Data.base_role(layout.selected))
		furniture_palette.disabled = not colorable
		furniture_palette.select(layout.color_for(layout.selected) if colorable else 0)
	%UndoLayout.disabled = layout.undo_stack.is_empty()
	%RedoLayout.disabled = layout.redo_stack.is_empty()
	var style: Dictionary = world.get_node("Room").style
	for key: String in ["wall","floor","light","rgb","effect"]:
		(get_node("%Style_" + key) as OptionButton).select(int(style.get(key, 0)))
	(%Style_brightness as HSlider).set_value_no_signal(float(style.get("brightness", 70)))
	for role: String in layout.NAMES: get_node("%Layout_" + role).set_pressed_no_signal(layout.selected == role)

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
	%ViewTitle.text = {"overview": "我的游戏房间", "screen": "屏幕操作", "layout":"布置房间"}[world.mode]

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

func _input(event: InputEvent) -> void:
	if modal_input_guard:
		get_viewport().set_input_as_handled()
		return
	# GUI can consume a release over the header; always end the camera gesture.
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_clear_gesture.call_deferred()
	if not event is InputEventKey or world.transitioning: return
	if world.layout.active:
		if event.pressed and not event.echo and blueprint_mode and event.keycode == KEY_ESCAPE:
			set_blueprint_mode(false)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo:
			if event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y]:
				if event.keycode == KEY_Y or event.shift_pressed: world.layout.redo()
				else: world.layout.undo()
				get_viewport().set_input_as_handled()
				return
			if event.ctrl_pressed and event.keycode == KEY_D:
				world.layout.duplicate_selected()
				get_viewport().set_input_as_handled()
				return
			match event.keycode:
				KEY_DELETE: world.layout.delete_selected()
				KEY_ESCAPE:
					if not world.layout.placing_role.is_empty(): world.layout.cancel_placement()
					else: finish_layout(false)
				KEY_G: world.layout.set_tool("move")
				KEY_R: world.layout.set_tool("rotate")
				KEY_Q: world.layout.rotate_step(-1)
				KEY_E: world.layout.rotate_step(1)
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

func _layout_input(event: InputEvent) -> void:
	var layout = world.layout
	if event is InputEventMouseButton:
		if not layout.placing_role.is_empty():
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				layout.preview_at(event.position)
				layout.confirm_placement()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				layout.cancel_placement()
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				world.zoom_overview(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed: layout.end_drag()
			else:
				var handle: String = layout.pick_handle(event.position)
				if not handle.is_empty():
					layout.begin_drag(event.position,"rotate" if handle == "rotate" else "move",handle,true)
				else:
					var role: String = world.pick_at(event.position)
					if not role.is_empty():
						layout.select(role)
						layout.begin_drag(event.position,layout.tool)
		elif event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_overview(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if not layout.placing_role.is_empty():
			layout.preview_at(event.position)
			get_viewport().set_input_as_handled()
		elif orbiting: world.orbit_overview(event.relative)
		else: layout.drag_to(event.position)
		if orbiting or not layout.gesture.is_empty(): get_viewport().set_input_as_handled()

func _clear_gesture() -> void:
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
