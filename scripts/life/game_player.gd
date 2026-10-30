extends Control
const U = preload("res://scripts/client_ui.gd")
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
var picture: TextureRect
var info: Label
var progress_box: VBoxContainer
var stream: Button
var shot := 0
var slideshow: Timer
var game_id := ""

func _ready() -> void:
	game_id = str(session.active().get("game_id", ""))
	var background := ColorRect.new()
	background.color = Color("0c141b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := U.vbox(U.margin(self, 20), 12)
	layout.get_parent().set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := U.hbox(layout)
	U.label(header, session.state.game(game_id).get("title", "游戏已结束"), 24, Color.WHITE)
	stream = U.button(header, "开始直播", func() -> void: session.notice.emit(session.toggle_stream()), "green", 140)
	stream.name = "PlayStream"
	U.button(header, "结束游玩", session.stop_play, "danger", 140).name = "StopPlay"
	var body := U.hbox(layout, 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(aspect)
	picture = U.image(aspect, session.state.game(game_id), 0, 0)
	picture.name = "RunningScreenshot"
	picture.texture = U.screenshot(session.state.game(game_id), shot)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var side := U.vbox(U.panel(body, "172735", 18), 10)
	side.get_parent().custom_minimum_size.x = 260
	side.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_END
	U.label(side, "正在创造回忆", 24, U.BLUE)
	info = U.label(side, "", 12, U.TEXT, true)
	progress_box = U.vbox(side, 8)
	U.label(layout, "模拟游玩 · 展示图每 4 秒轮播 · 最小化或返回房间后，活动继续进行", 12, U.MUTED, true)
	slideshow = Timer.new()
	slideshow.wait_time = 4
	slideshow.timeout.connect(func() -> void:
		shot = (shot + 1) % 4
		picture.texture = U.screenshot(session.state.game(game_id), shot)
	)
	add_child(slideshow)
	slideshow.start()
	session.tick_updated.connect(refresh)
	session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_instance_valid(info): return
	info.text = "本次游玩 %d 分钟\n累计游玩 %d 分钟\n\n成就进度倍率 %.2f\n直播累计收入 %d 点\n关注者 %d" % [session.active().get("minutes", 0), session.state.play_minutes.get(game_id, 0), session.challenge_rate(game_id), session.state.life["stream_income"], session.state.life["followers"]]
	stream.text = "结束直播" if session.active().get("streaming", false) else "开始直播"
	for child: Node in progress_box.get_children():
		progress_box.remove_child(child)
		child.queue_free()
	var progress: float = float(session.state.life["progress"].get(game_id, 0))
	for milestone: Dictionary in Data.MILESTONES:
		var done: bool = session.state.life["achievements"].get(game_id, []).has(milestone["id"])
		U.label(progress_box, ("★ " if done else "☆ ") + milestone["name"], 12, U.GREEN if done else U.TEXT)
		var bar := ProgressBar.new()
		bar.max_value = milestone["target"]
		bar.value = progress
		bar.custom_minimum_size.y = 14
		progress_box.add_child(bar)
