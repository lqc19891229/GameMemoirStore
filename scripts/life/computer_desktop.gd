extends Control
signal room_requested
const WindowScene = preload("res://scenes/life/app_window.tscn")
const APPS := {"platform": ["游戏平台", "res://scenes/store.tscn"], "browser": ["回忆生活 · 购物网页", "res://scenes/life/browser.tscn"], "game": ["正在游玩", "res://scenes/life/game_player.tscn"]}
var session: MemoirGameSession
var area: Control
var tasks: HBoxContainer
var resume_button: Button
var status: Label
var windows: Dictionary = {}

func _ready() -> void:
	area = %ApplicationArea
	tasks = %Tasks
	resume_button = %DesktopResume
	status = %Status
	%DesktopPlatform.pressed.connect(func() -> void: open_app("platform"))
	%DesktopBrowser.pressed.connect(func() -> void: open_app("browser"))
	resume_button.pressed.connect(func() -> void: open_app("game"))
	%DesktopRoom.pressed.connect(func() -> void: room_requested.emit())
	%TaskbarPlatform.pressed.connect(func() -> void: open_app("platform"))
	%TaskbarBrowser.pressed.connect(func() -> void: open_app("browser"))
	if session == null: return
	session.changed.connect(refresh)
	session.tick_updated.connect(_update_status)
	area.resized.connect(func() -> void:
		for id: String in windows: windows[id].fit()
	)
	refresh()

func open_app(id: String, tab: String = "") -> Control:
	if not APPS.has(id): return null
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
	if is_instance_valid(resume_button): resume_button.disabled = session.active().get("kind") != "play"
	if is_instance_valid(status): status.text = "%d 点 · %s" % [session.state.wallet, "直播中" if session.active().get("streaming", false) else ("游玩中" if session.active().get("kind") == "play" else "在线")]

func refresh() -> void:
	if not is_instance_valid(tasks): return
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
