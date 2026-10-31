extends Control
const WindowScene = preload("res://scenes/life/app_window.tscn")
const APPS := {"platform": ["游戏平台", "res://scenes/store.tscn"], "browser": ["回忆生活 · 购物网页", "res://scenes/life/browser.tscn"], "game": ["正在游玩", "res://scenes/life/game_player.tscn"]}
@export var hardware_catalog: MemoirHardwareCatalog
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
var area: Control
var tasks: HBoxContainer
var resume_button: Button
var status: Label
var windows: Dictionary = {}
var screen_focused := false
var transition: Tween
var selected_role := "monitor"
var devices: Dictionary = {}
var modal_input_guard := false

func screen_node(key: String) -> Node:
	return %DesktopScreen.get_node("%" + key)

func _ready() -> void:
	get_window().window_input.connect(_forward_modal_input)
	devices = {"monitor": %Monitor, "computer": %Computer, "keyboard": %Keyboard, "mouse": %Mouse}
	for role: String in devices:
		var key := role
		devices[role].get_node("HitArea").pressed.connect(func() -> void: select_device(key))
	%FocusScreen.pressed.connect(func() -> void: set_screen_focused(true))
	%FocusToggle.pressed.connect(func() -> void: set_screen_focused(not screen_focused))
	%ManageDevices.pressed.connect(func() -> void:
		set_screen_focused(true)
		open_app("browser", "inventory")
	)
	%Monitor.screen_geometry_changed.connect(_layout_view)
	resized.connect(_layout_view)
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
	if session == null:
		_layout_view()
		return
	session.changed.connect(refresh)
	session.tick_updated.connect(_update_status)
	area.resized.connect(func() -> void:
		for id: String in windows: windows[id].fit()
	)
	refresh()
	_layout_view()

func select_device(role: String) -> void:
	selected_role = role
	_update_device_info()

func _update_equipment() -> void:
	if session == null or hardware_catalog == null: return
	for role: String in devices:
		var slot := "peripheral" if role in ["keyboard", "mouse"] else role
		var id: String = session.state.life["equipped"].get(slot, "")
		var visual := hardware_catalog.visual_for(role, id)
		if visual != null and devices[role].visual != visual: devices[role].visual = visual
	_update_device_info()

func _update_device_info() -> void:
	if session == null: return
	var slot := "peripheral" if selected_role in ["keyboard", "mouse"] else selected_role
	var id: String = session.state.life["equipped"].get(slot, "")
	var item: Dictionary = Data.ITEMS.get(id, {})
	var label: String = {"monitor": "显示器", "computer": "机箱", "keyboard": "键盘", "mouse": "鼠标"}[selected_role]
	%DeviceName.text = label + "  /  " + str(item.get("name", ""))
	%DeviceDescription.text = str(item.get("description", ""))

func _layout_view() -> void:
	if not is_node_ready(): return
	set_screen_focused(screen_focused, false)

func set_screen_focused(value: bool, animate: bool = true) -> void:
	screen_focused = value
	if transition != null and transition.is_valid(): transition.kill()
	var equipment: Control = %Equipment
	var target_scale := Vector2.ONE
	var target_position := Vector2.ZERO
	if value:
		var screen := Rect2(%Monitor.position + %MonitorScreen.position, %MonitorScreen.size)
		if screen.size.x <= 0 or screen.size.y <= 0: return
		var margin_y := maxf(56.0, size.y * 0.09)
		var bounds := Rect2(Vector2(size.x * 0.04, margin_y), Vector2(size.x * 0.92, maxf(1.0, size.y - margin_y * 2.0)))
		var factor := minf(bounds.size.x / screen.size.x, bounds.size.y / screen.size.y)
		target_scale = Vector2.ONE * factor
		target_position = bounds.get_center() - screen.get_center() * factor
	%FocusScreen.visible = not value
	%ScreenViewport.input_enabled = false
	%FocusToggle.text = "查看设备 · Esc" if value else "使用电脑  >"
	%ViewTitle.text = "屏幕操作" if value else "我的工作台"
	%DeviceInfo.visible = not value
	%ManageDevices.visible = not value
	if animate:
		transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		transition.tween_property(equipment, "scale", target_scale, 0.28)
		transition.tween_property(equipment, "position", target_position, 0.28)
		transition.finished.connect(func() -> void:
			%ScreenViewport.input_enabled = screen_focused
			if screen_focused: %ScreenViewport.grab_focus()
		)
	else:
		equipment.scale = target_scale
		equipment.position = target_position
		%ScreenViewport.input_enabled = value
		if value: %ScreenViewport.grab_focus()

func _input(event: InputEvent) -> void:
	if modal_input_guard:
		get_viewport().set_input_as_handled()
		return
	if not screen_focused or not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE: return
	# Embedded dialogs keep their own Escape behavior before leaving the screen.
	if %DesktopViewport.get_embedded_subwindows().any(func(window: Window) -> bool: return window.visible): return
	set_screen_focused(false)
	get_viewport().set_input_as_handled()

func _forward_modal_input(event: InputEvent) -> void:
	if not screen_focused or not %ScreenViewport.input_enabled: return
	var viewport: SubViewport = %DesktopViewport
	if not viewport.get_embedded_subwindows().any(func(window: Window) -> bool: return window.visible and window.exclusive): return
	# Godot's exclusive child blocks the host Window before the container can forward
	# input. Feed its owning viewport, which retains native dialog/menu dispatch.
	modal_input_guard = true
	var to_screen: Transform2D = %ScreenViewport.get_global_transform_with_canvas().affine_inverse() * get_viewport().get_final_transform().affine_inverse()
	viewport.push_input(event.xformed_by(to_screen), true)
	# Closing a dialog must not also activate the control behind it or leave focus mode.
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
