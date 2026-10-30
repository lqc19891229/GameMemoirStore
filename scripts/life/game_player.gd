extends Control
const U = preload("res://scripts/client_ui.gd")
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
@onready var picture: TextureRect = %RunningScreenshot
@onready var info: Label = %Info
@onready var stream: Button = %PlayStream
@onready var slideshow: Timer = %Slideshow
var shot := 0
var game_id := ""

func _ready() -> void:
	if session == null: return
	game_id = str(session.active().get("game_id", ""))
	%GameTitle.text = session.state.game(game_id).get("title", "游戏已结束")
	stream.pressed.connect(func() -> void: session.notice.emit(session.toggle_stream()))
	%StopPlay.pressed.connect(session.stop_play)
	picture.texture = U.screenshot(session.state.game(game_id), shot)
	slideshow.timeout.connect(func() -> void:
		shot = (shot + 1) % 4
		picture.texture = U.screenshot(session.state.game(game_id), shot)
	)
	slideshow.start()
	session.tick_updated.connect(refresh)
	session.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if session == null: return
	info.text = "本次游玩 %d 分钟\n累计游玩 %d 分钟\n\n成就进度倍率 %.2f\n直播累计收入 %d 点\n关注者 %d" % [session.active().get("minutes", 0), session.state.play_minutes.get(game_id, 0), session.challenge_rate(game_id), session.state.life["stream_income"], session.state.life["followers"]]
	stream.text = "结束直播" if session.active().get("streaming", false) else "开始直播"
	var progress: float = float(session.state.life["progress"].get(game_id, 0))
	for i in range(Data.MILESTONES.size()):
		var milestone: Dictionary = Data.MILESTONES[i]
		var done: bool = session.state.life["achievements"].get(game_id, []).has(milestone["id"])
		var label: Label = get_node("%Milestone" + str(i))
		label.text = ("★ " if done else "☆ ") + milestone["name"]
		label.modulate = U.GREEN if done else Color.WHITE
		var bar: ProgressBar = get_node("%MilestoneBar" + str(i))
		bar.max_value = milestone["target"]
		bar.value = progress
