extends Node3D
const WindowScene = preload("res://scenes/computer/ui/app_window.tscn")
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
	%ApplyLayout.pressed.connect(func() -> void: finish_layout(true))
	%CancelLayout.pressed.connect(func() -> void: finish_layout(false))
	%RestoreLayout.pressed.connect(world.layout.reset_layout)
	%UndoLayout.pressed.connect(world.layout.undo)
	%RedoLayout.pressed.connect(world.layout.redo)
	%CopyFurniture.pressed.connect(world.layout.duplicate_selected)
	%DeleteFurniture.pressed.connect(world.layout.delete_selected)
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
	session.tick_updated.connect(_update_status)
	refresh()

func _update_equipment() -> void:
	if session == null or hardware_catalog == null: return
	var reposition := false
	for role: String in world.devices:
		var slot := "peripheral" if role in ["keyboard", "mouse"] else role
		var id: String = session.state.life["equipped"].get(slot, "")
		var model := hardware_catalog.visual_for(role, id)
		if model != null and world.devices[role].appearance != model:
			world.devices[role].appearance = model
			reposition = reposition or (screen_focused and role == "monitor")
	world.layout.load_saved(session.state.life.get("workstation_layout", {}))
	world.layout.load_style(session.state.life.get("room_style", {}))
	if world.layout.active: world.layout.update()
	if reposition: world.set_mode("screen", false)

func begin_layout() -> void:
	if world.transitioning or world.layout.active: return
	_set_mode("layout", false)
	world.layout.begin()
	_sync_layout()

func finish_layout(apply: bool) -> void:
	if not world.layout.finish(apply): return
	_set_mode("overview", false)
	if apply and session != null:
		session.state.life["workstation_layout"] = world.layout.export_layout()
		session.state.life["room_style"] = world.layout.committed_style.duplicate()
		session.state.save_state()

func _sync_layout() -> void:
	if not world.layout.active: return
	var layout = world.layout
	%LayoutSelection.text = "选中：" + layout.name_for(layout.selected)
	var node: Node3D = layout.nodes[layout.selected]
	%LayoutPose.text = "X %.2f   Z %.2f\n旋转 %.0f°" % [node.position.x,node.position.z,rad_to_deg(node.rotation.y)]
	%LayoutMessage.text = layout.message
	%LayoutMessage.modulate = Color.WHITE if layout.valid else Color("ff756a")
	%ApplyLayout.disabled = not layout.valid
	%MoveTool.set_pressed_no_signal(layout.tool == "move")
	%RotateTool.set_pressed_no_signal(layout.tool == "rotate")
	%CopyFurniture.disabled = not layout.templates.has(layout.Data.base_role(layout.selected))
	%DeleteFurniture.disabled = not layout.Data.is_copy(layout.selected)
	%UndoLayout.disabled = layout.undo_stack.is_empty()
	%RedoLayout.disabled = layout.redo_stack.is_empty()
	var style: Dictionary = world.get_node("Room").style
	for key: String in ["wall","floor","light","rgb","effect"]:
		(get_node("%Style_" + key) as OptionButton).select(int(style.get(key, 0)))
	(%Style_brightness as HSlider).set_value_no_signal(float(style.get("brightness", 70)))
	for role: String in layout.NAMES: get_node("%Layout_" + role).set_pressed_no_signal(layout.selected == role)

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
				KEY_ESCAPE: finish_layout(false)
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
		_layout_input(event)
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
		if orbiting: world.orbit_overview(event.relative)
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
