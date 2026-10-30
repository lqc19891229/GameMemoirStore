class_name MemoirLifeData
extends RefCounted
## 初版生活系统的商品、属性与通用成就模板；与 Excel 游戏目录分开。
const ATTRIBUTES := ["反应", "操作", "思考", "探索", "规划", "协作"]
# Legacy room items remain defined for lossless version-3 save loading.
const ROOM_ONLY_SLOTS := ["desk", "cabinet", "decor"]
const ITEMS := {
	"starter_pc": {"name": "旧日主机", "slot": "computer", "price": 0, "speed": 1.0, "description": "陪你开始收藏的第一台电脑。"},
	"starter_mouse": {"name": "有线键鼠", "slot": "peripheral", "price": 0, "speed": 1.0, "description": "可靠的入门外设。"},
	"starter_desk": {"name": "旧木书桌", "slot": "desk", "price": 0, "description": "留下过许多游戏时光。"},
	"starter_cabinet": {"name": "纪念小架", "slot": "cabinet", "price": 0, "capacity": 1, "description": "可以展示一枚成就奖杯。"},
	"precise_mouse": {"name": "精准键鼠套装", "slot": "peripheral", "price": 28, "speed": 1.15, "description": "成就挑战进度增加 15%。"},
	"stream_mic": {"name": "桌面麦克风", "slot": "audio", "price": 45, "income": 1, "description": "直播每次结算额外获得 1 点。"},
	"workstation": {"name": "进阶游戏主机", "slot": "computer", "price": 120, "speed": 1.2, "income": 1, "description": "成就进度增加 20%，直播每次结算额外获得 1 点。"},
	"oak_desk": {"name": "橡木工作台", "slot": "desk", "price": 60, "description": "宽敞温暖的工作台，改变房间外观。"},
	"reading_lamp": {"name": "暖光台灯", "slot": "decor", "price": 24, "description": "为夜间的游戏时光添一盏暖光。"},
	"display_cabinet": {"name": "玻璃成就柜", "slot": "cabinet", "price": 80, "capacity": 3, "description": "可以同时展示三枚成就奖杯。"},
}
const MILESTONES := [
	{"id": "first_memory", "name": "初次启程", "target": 10.0, "description": "在一款游戏中积累 10 点挑战进度。"},
	{"id": "getting_better", "name": "渐入佳境", "target": 60.0, "description": "在一款游戏中积累 60 点挑战进度。"},
	{"id": "complete_memory", "name": "完整的回忆", "target": 180.0, "description": "在一款游戏中积累 180 点挑战进度。"},
]

static func defaults() -> Dictionary:
	return {"items": ["starter_pc", "starter_mouse", "starter_desk", "starter_cabinet"],
		"equipped": {"computer": "starter_pc", "peripheral": "starter_mouse", "desk": "starter_desk", "cabinet": "starter_cabinet", "audio": "", "decor": ""},
		"attributes": {"反应": 10.0, "操作": 10.0, "思考": 10.0, "探索": 10.0, "规划": 10.0, "协作": 10.0},
		"progress": {}, "achievements": {}, "displayed": [], "guides": {}, "active": {},
		"elapsed": 0, "stream_income": 0, "guide_income": 0, "followers": 0, "room_layout": 0}

static func number(value: Variant, maximum: float = 9999999.0) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return 0.0
	return clampf(float(value), 0.0, maximum)

static func clean(raw: Variant, owned: Array[String], installed: Array[String]) -> Dictionary:
	var result := defaults()
	if not raw is Dictionary:
		return result
	if raw.get("items") is Array:
		for id: Variant in raw["items"]:
			if id is String and ITEMS.has(id) and not result["items"].has(id): result["items"].append(id)
	if raw.get("equipped") is Dictionary:
		for slot: String in result["equipped"]:
			var id := str(raw["equipped"].get(slot, result["equipped"][slot]))
			if result["items"].has(id) and ITEMS[id]["slot"] == slot: result["equipped"][slot] = id
	if raw.get("attributes") is Dictionary:
		for key: String in ATTRIBUTES:
			result["attributes"][key] = number(raw["attributes"].get(key, 10.0), 100.0)
	for key: String in ["elapsed", "stream_income", "guide_income", "followers"]:
		result[key] = int(number(raw.get(key, 0)))
	result["room_layout"] = int(number(raw.get("room_layout", 0), 1))
	for id: String in owned:
		if raw.get("progress") is Dictionary: result["progress"][id] = number(raw["progress"].get(id, 0))
		if raw.get("achievements") is Dictionary and raw["achievements"].get(id) is Array:
			var ids: Array = []
			for milestone: Dictionary in MILESTONES:
				if raw["achievements"][id].has(milestone["id"]): ids.append(milestone["id"])
			result["achievements"][id] = ids
		if raw.get("guides") is Dictionary and raw["guides"].get(id) is Dictionary:
			var guide: Dictionary = raw["guides"][id]
			result["guides"][id] = {"quality": int(number(guide.get("quality", 1), 3)), "royalties": int(number(guide.get("royalties", 0), 60)), "published_at": int(number(guide.get("published_at", result["elapsed"]), float(result["elapsed"])))}
	if raw.get("displayed") is Array:
		for value: Variant in raw["displayed"]:
			if not value is Dictionary: continue
			var id := str(value.get("game_id", ""))
			var achievement := str(value.get("achievement", ""))
			var item := {"game_id": id, "achievement": achievement}
			if result["achievements"].get(id, []).has(achievement) and not result["displayed"].has(item): result["displayed"].append(item)
	var capacity: int = int(ITEMS[result["equipped"]["cabinet"]].get("capacity", 1))
	if result["displayed"].size() > capacity: result["displayed"].resize(capacity)
	if raw.get("active") is Dictionary:
		var active: Dictionary = raw["active"]
		var id := str(active.get("game_id", ""))
		var kind := str(active.get("kind", ""))
		if owned.has(id) and ((kind == "play" and installed.has(id)) or (kind == "guide" and not result["guides"].has(id))):
			result["active"] = {"kind": kind, "game_id": id, "minutes": int(number(active.get("minutes", 0), 99999)), "streaming": bool(active.get("streaming", false)) if kind == "play" else false}
	return result

static func weights(genres: Array) -> Dictionary:
	var result: Dictionary
	if genres.has("射击"): result = {"反应": 0.6, "操作": 0.4}
	elif genres.has("动作") or genres.has("竞速") or genres.has("音乐节奏") or genres.has("音乐") or genres.has("平台跳跃") or genres.has("体育"): result = {"操作": 0.6, "反应": 0.4}
	elif genres.has("策略") or genres.has("策略战术") or genres.has("模拟经营") or genres.has("生活模拟") or genres.has("模拟") or genres.has("经营"): result = {"规划": 0.6, "思考": 0.4}
	elif genres.has("角色扮演") or genres.has("生存制作") or genres.has("生存"): result = {"规划": 0.5, "探索": 0.5}
	else: result = {"探索": 0.5, "思考": 0.5}
	if genres.has("多人") or genres.has("合作"):
		for key: String in result: result[key] = float(result[key]) * 0.8
		result["协作"] = 0.2
	return result
