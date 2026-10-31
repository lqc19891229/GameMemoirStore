extends Control
const WindowScene = preload("res://scenes/life/app_window.tscn")
const APPS := {"platform": ["游戏平台", "res://scenes/store.tscn"], "browser": ["回忆生活 · 购物网页", "res://scenes/life/browser.tscn"], "game": ["正在游玩", "res://scenes/life/game_player.tscn"]}
const Data = preload("res://scripts/life/life_data.gd")
@export var hardware_catalog: MemoirHardwareCatalog
var session: MemoirGameSession
var area: Control
var tasks: HBoxContainer
var resume_button: Button
var status: Label
var windows: Dictionary = {}
var selected_role := "monitor"
var modal_input_guard := false
var dragging := false
var orbiting := false
var screen_mouse_down := false
var last_screen_point := Vector2.ZERO
@onready var world: Node3D = %Workstation3D
var screen_focused: bool:
	get: return is_instance_valid(world) and world.mode == "screen"

func screen_node(key: String) -> Node:
	return %DesktopScreen.get_node("%" + key)

func _ready() -> void:
	get_window().window_input.connect(_forward_modal_input)
	world.set_screen_texture(%DesktopViewport.get_texture())
	%WorldViewport.size_changed.connect(_reframe_screen)
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
			reposition = reposition or (screen_focused and role == "monitor") or (world.mode == "inspect" and role == selected_role)
	if reposition: world.set_mode(world.mode, selected_role, false)
	_update_device_info()

func _update_device_info() -> void:
	if session == null: return
	var slot := "peripheral" if selected_role in ["keyboard", "mouse"] else selected_role
	var id: String = session.state.life["equipped"].get(slot, "")
	var item: Dictionary = Data.ITEMS.get(id, {})
	var label: String = {"monitor": "显示器", "computer": "机箱", "keyboard": "键盘", "mouse": "鼠标"}[selected_role]
	%DeviceName.text = label + "  /  " + str(item.get("name", ""))
	var hint := "拖动旋转 · 滚轮缩放 · Esc 返回工作台" if world.mode == "inspect" else "点击设备检视 · 点击屏幕使用电脑 · 右键拖动环顾"
	%DeviceDescription.text = str(item.get("description", "")) + "  ·  " + hint

func select_device(role: String, animate: bool = true) -> void:
	selected_role = role
	_set_mode("inspect", animate)

func set_screen_focused(value: bool, animate: bool = true) -> void:
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
	%WorldView.stretch_shrink = 2 if value == "overview" else 1
	world.set_mode(value, selected_role, animate)
	_sync_mode()

func _sync_mode() -> void:
	%ReturnOverview.visible = world.mode != "overview"
	%FocusToggle.visible = not screen_focused
	%ManageDevices.visible = not screen_focused
	%DeviceInfo.visible = not screen_focused
	%ViewTitle.text = {"overview": "我的 3D 工作台", "inspect": "设备检视", "screen": "屏幕操作"}[world.mode]
	_update_device_info()

func _view_point(point: Vector2) -> Vector2:
	return (point - %WorldView.global_position) * Vector2(%WorldViewport.size) / %WorldView.size

func _reframe_screen() -> void:
	if not screen_focused: return
	if world.transitioning:
		if not world.motion.finished.is_connected(_reframe_screen): world.motion.finished.connect(_reframe_screen, CONNECT_ONE_SHOT)
	else:
		world.set_mode("screen", selected_role, false)

func canvas_point_for_screen(logical: Vector2) -> Vector2:
	var pixel: Vector2 = world.pixel_for_screen(logical / Vector2(%DesktopViewport.size))
	return %WorldView.global_position + pixel * %WorldView.size / Vector2(%WorldViewport.size)

func _push_screen_input(event: InputEvent, allow_outside: bool = false) -> bool:
	var mapped := event.duplicate() as InputEvent
	if event is InputEventMouse:
		var uv: Variant = world.screen_uv(_view_point(event.position), not allow_outside)
		if uv == null: return false
		mapped.position = uv * Vector2(%DesktopViewport.size)
		mapped.global_position = mapped.position
		last_screen_point = mapped.position
		if mapped is InputEventMouseMotion:
			var previous: Variant = world.screen_uv(_view_point(event.position - event.relative), false)
			if previous != null: mapped.relative = (uv - previous) * Vector2(%DesktopViewport.size)
	%DesktopViewport.push_input(mapped, true)
	return true

func _input(event: InputEvent) -> void:
	if modal_input_guard:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or world.transitioning: return
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
	if screen_focused:
		if event is InputEventMouse:
			var forwarded := _push_screen_input(event, screen_mouse_down or event is InputEventMouseMotion)
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				screen_mouse_down = event.pressed and forwarded
			if forwarded: get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed and world.mode == "overview":
				var role: String = world.pick_at(_view_point(event.position))
				if role == "monitor" and world.screen_uv(_view_point(event.position)) != null: set_screen_focused(true)
				elif not role.is_empty(): select_device(role)
		elif event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		elif event.pressed and world.mode == "inspect":
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: world.zoom_product(0.9)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: world.zoom_product(1.1)
	elif event is InputEventMouseMotion:
		if dragging: world.rotate_product(event.relative)
		if orbiting: world.orbit_overview(event.relative)

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
	if session == null or not is_instance_valid(tasks): return
	_update_equipment()
	if windows.has("game") and session.active().get("kind") != "play":
		close_app("game")
		return
	for child: Node in tasks.get_children():
		tasks.remove_child(child)
		child.queue_free()
	for id: String in windows:
		var key := id
		var task = preload("res://scenes/client/components/text_button.tscn").instantiate()
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
