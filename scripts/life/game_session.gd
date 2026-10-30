class_name MemoirGameSession
extends Node
## 所有窗口共享此节点；关闭窗口不会销毁模拟时钟或另开一份玩家状态。
signal changed
signal tick_updated
signal notice(message: String)
signal play_requested(game_id: String)
const State = preload("res://scripts/store_state.gd")
const Data = preload("res://scripts/life/life_data.gd")
var state = State.new()
var timer: Timer

func _ready() -> void:
	state.persistence_enabled = not OS.get_cmdline_user_args().has("--fresh")
	state.load_state()
	state.changed.connect(_state_changed)
	timer = $SimulationTimer
	timer.timeout.connect(tick)
	timer.start()

func _exit_tree() -> void:
	state.save_state()

func _state_changed() -> void:
	var active: Dictionary = state.life["active"]
	if active.get("kind") == "play" and not state.installed.has(str(active["game_id"])):
		stop_play()
	changed.emit()

func active() -> Dictionary:
	return state.life["active"]

func activity_text() -> String:
	if active().is_empty(): return "闲暇时光 · 选一款游戏，开始今天的回忆"
	return "%s · %s · %d 分钟%s" % ["正在游玩" if active()["kind"] == "play" else "制作攻略", state.game(active()["game_id"])["title"], active()["minutes"], " · 直播中" if active().get("streaming", false) else ""]

func buy_item(id: String) -> String:
	if not Data.ITEMS.has(id) or int(Data.ITEMS[id]["price"]) <= 0: return "商品不存在。"
	if Data.ROOM_ONLY_SLOTS.has(Data.ITEMS[id]["slot"]): return "该商品已停售。"
	if state.life["items"].has(id): return "已经拥有这件物品。"
	var cost: int = int(Data.ITEMS[id]["price"])
	if state.wallet < cost: return "预算不足，还差 %d 点。" % (cost - state.wallet)
	state.wallet -= cost
	state.life["items"].append(id)
	state.save_state()
	return "已购买 %s，可在物品栏安装。" % Data.ITEMS[id]["name"]

func equip_item(id: String) -> String:
	if not state.life["items"].has(id) or not Data.ITEMS.has(id): return "尚未拥有这件物品。"
	var slot: String = Data.ITEMS[id]["slot"]
	state.life["equipped"][slot] = id
	if slot == "cabinet":
		var capacity: int = int(Data.ITEMS[id].get("capacity", 1))
		if state.life["displayed"].size() > capacity: state.life["displayed"].resize(capacity)
	state.save_state()
	return "已安装 %s。" % Data.ITEMS[id]["name"]

func start_play(game_id: String) -> String:
	if not state.owned.has(game_id) or not state.installed.has(game_id): return "请先购买并安装这款游戏。"
	if not active().is_empty():
		if active().get("kind") == "play" and active().get("game_id") == game_id:
			play_requested.emit(game_id)
			return "已返回正在运行的游戏。"
		return "请先结束当前活动。"
	state.life["active"] = {"kind": "play", "game_id": game_id, "minutes": 0, "streaming": false}
	state.save_state()
	play_requested.emit(game_id)
	return "游戏已启动。"

func stop_play() -> void:
	if active().get("kind") != "play": return
	var entry := active().duplicate()
	state.life["active"] = {}
	var id: String = entry["game_id"]
	if int(entry["minutes"]) > 0:
		state.play_sessions[id] = int(state.play_sessions.get(id, 0)) + 1
		state.activity.push_front({"id": id, "month": state.month_index, "minutes": entry["minutes"]})
		if state.activity.size() > 40: state.activity.resize(40)
	state.save_state()
	notice.emit("本次游玩已结束，进度和收入已保存。")

func toggle_stream() -> String:
	if active().get("kind") != "play": return "启动一款已安装游戏后即可直播。"
	active()["streaming"] = not bool(active().get("streaming", false))
	state.save_state()
	return "直播已开始，每 5 分钟模拟游玩结算一次收入。" if active()["streaming"] else "直播已结束。"

func start_guide(game_id: String) -> String:
	if not active().is_empty(): return "请先结束当前活动，再制作攻略。"
	if not state.owned.has(game_id) or int(state.play_minutes.get(game_id, 0)) < 10: return "至少游玩 10 分钟后才能整理这款游戏的攻略。"
	if state.life["guides"].has(game_id): return "这款游戏的攻略已经发布。"
	state.life["active"] = {"kind": "guide", "game_id": game_id, "minutes": 0, "streaming": false}
	state.save_state()
	return "开始整理攻略，需要 20 分钟模拟时间。"

func cancel_guide() -> void:
	if active().get("kind") == "guide":
		state.life["active"] = {}
		state.save_state()

func challenge_rate(game_id: String) -> float:
	var weights: Dictionary = Data.weights(state.game(game_id).get("genres", []))
	var ability: float = 0.0
	for key: String in weights: ability += float(state.life["attributes"][key]) * float(weights[key])
	var equipment: float = 1.0
	for slot: String in ["computer", "peripheral"]:
		equipment *= float(Data.ITEMS[state.life["equipped"][slot]].get("speed", 1.0))
	return (1.0 + ability / 100.0) * equipment

func tick(minutes: int = 1) -> void:
	for _minute in range(clampi(minutes, 0, 1440)):
		state.life["elapsed"] = int(state.life["elapsed"]) + 1
		state.tick_downloads(24)
		if not active().is_empty():
			active()["minutes"] = int(active()["minutes"]) + 1
			var id: String = active()["game_id"]
			if active()["kind"] == "play":
				state.play_minutes[id] = int(state.play_minutes.get(id, 0)) + 1
				state.life["progress"][id] = float(state.life["progress"].get(id, 0)) + challenge_rate(id)
				var weights: Dictionary = Data.weights(state.game(id)["genres"])
				for key: String in weights:
					state.life["attributes"][key] = minf(100.0, float(state.life["attributes"][key]) + 0.05 * float(weights[key]))
				var unlocked: Array = state.life["achievements"].get(id, [])
				for milestone: Dictionary in Data.MILESTONES:
					if float(state.life["progress"][id]) >= float(milestone["target"]) and not unlocked.has(milestone["id"]):
						unlocked.append(milestone["id"])
						state.life["achievements"][id] = unlocked
						notice.emit("成就解锁 · %s / %s" % [state.game(id)["title"], milestone["name"]])
						state.save_state()
				if active().get("streaming", false) and int(active()["minutes"]) % 5 == 0:
					var income: int = 2
					for slot: String in ["computer", "audio"]:
						income += int(Data.ITEMS.get(state.life["equipped"][slot], {}).get("income", 0))
					state.wallet += income
					state.life["stream_income"] = int(state.life["stream_income"]) + income
					state.life["followers"] = int(state.life["followers"]) + 1
			elif int(active()["minutes"]) >= 20:
				var quality: int = mini(3, 1 + state.life["achievements"].get(id, []).size())
				var income: int = 10 + quality * 5
				state.life["guides"][id] = {"quality": quality, "royalties": 0, "published_at": int(state.life["elapsed"])}
				state.wallet += income
				state.life["guide_income"] = int(state.life["guide_income"]) + income
				state.life["active"] = {}
				notice.emit("攻略已发布 · 获得 %d 点稿费" % income)
				state.save_state()
		for id: String in state.life["guides"]:
			var guide: Dictionary = state.life["guides"][id]
			var next_payment: int = int(guide["published_at"]) + 10 * (int(guide["royalties"]) + 1)
			if int(guide["royalties"]) < 60 and int(state.life["elapsed"]) >= next_payment:
				guide["royalties"] = int(guide["royalties"]) + 1
				state.wallet += 1
				state.life["guide_income"] = int(state.life["guide_income"]) + 1
		if int(state.life["elapsed"]) % 5 == 0: state.save_state(false)
	tick_updated.emit()

func reset_run() -> void:
	var persistent: bool = state.persistence_enabled
	var path: String = state.save_path
	state.persistence_enabled = false
	var fresh = State.new()
	fresh.persistence_enabled = persistent
	fresh.save_path = path
	fresh.save_state()
	get_tree().reload_current_scene.call_deferred()
