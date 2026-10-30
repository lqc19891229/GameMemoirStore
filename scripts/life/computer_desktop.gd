extends Control
signal room_requested
const U = preload("res://scripts/client_ui.gd")
const WindowScene = preload("res://scenes/life/app_window.tscn")
const APPS := {"platform": ["游戏平台", "res://scenes/store.tscn"], "browser": ["回忆生活 · 购物网页", "res://scenes/life/browser.tscn"], "game": ["正在游玩", "res://scenes/life/game_player.tscn"]}
var session: MemoirGameSession
var area: Control
var tasks: HBoxContainer
var resume_button: Button
var status: Label
var windows: Dictionary = {}

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("40636b")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shortcuts := U.vbox(U.margin(self, 28), 16)
	U.label(shortcuts, "MEMOIR OS", 36, Color("c9d9cc"))
	U.label(shortcuts, "欢迎回来，像素收藏家。", 12, Color("b1c5bc"))
	U.button(shortcuts, "▣  游戏平台", func() -> void: open_app("platform"), "dark", 180).name = "DesktopPlatform"
	U.button(shortcuts, "▤  购物与物品", func() -> void: open_app("browser"), "dark", 180).name = "DesktopBrowser"
	resume_button = U.button(shortcuts, "▷  继续游玩", func() -> void: open_app("game"), "dark", 180)
	resume_button.name = "DesktopResume"
	area = Control.new()
	area.name = "ApplicationArea"
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.offset_bottom = -52
	var bar := U.panel(self, "192d33", 8)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -52
	var row := U.hbox(bar, 8)
	U.button(row, "< 房间", func() -> void: room_requested.emit(), "flat", 100).name = "DesktopRoom"
	U.button(row, "平台", func() -> void: open_app("platform"), "flat", 80)
	U.button(row, "网页", func() -> void: open_app("browser"), "flat", 80)
	tasks = U.hbox(row, 4)
	status = U.label(row, "", 12, Color("b6cac1"))
	status.size_flags_horizontal = Control.SIZE_SHRINK_END
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
		U.button(tasks, ("● " if windows[id].visible else "○ ") + APPS[id][0], func() -> void: open_app(key), "flat").name = "Task_" + id
	_update_status()
