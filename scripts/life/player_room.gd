extends Control
signal computer_requested
signal inventory_requested
signal cabinet_requested
const U = preload("res://scripts/client_ui.gd")
const Data = preload("res://scripts/life/life_data.gd")
const Furniture = preload("res://scenes/life/furniture_item.tscn")
var session: MemoirGameSession
var wallet: Label
var activity_label: Label
var attributes: Label
var furniture: Dictionary = {}

func _ready() -> void:
	var header := U.hbox(U.panel(self, "263e3b", 18), 16)
	header.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	U.label(header, "游戏回忆录", 24, Color("efdfba"))
	wallet = U.label(header, "", 12, Color("c6d1b2"))
	U.button(header, "使用电脑  >", func() -> void: computer_requested.emit(), "blue", 150).name = "RoomComputer"
	var panel := U.panel(self, "263e3b", 14)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -116
	var footer := U.vbox(panel, 4)
	var tools := U.hbox(footer)
	activity_label = U.label(tools, "", 12, Color("e6d6b7"), true)
	U.button(tools, "物品与设备", func() -> void: inventory_requested.emit(), "flat", 140).name = "RoomInventory"
	U.button(tools, "成就展示柜", func() -> void: cabinet_requested.emit(), "flat", 140).name = "RoomCabinet"
	U.button(tools, "换个布置", func() -> void:
		session.state.life["room_layout"] = 1 - int(session.state.life["room_layout"])
		session.state.save_state()
	, "flat", 110).name = "RoomLayout"
	attributes = U.label(footer, "", 12, Color("a7b9ab"), true)
	U.label(footer, "点击电脑进入桌面 · 选购与安装的物品会出现在房间 · 1 秒推进 1 分钟模拟时间", 12, Color("90a79a"), true)
	for kind: String in ["desk", "computer", "peripheral", "cabinet", "decor"]:
		var item = Furniture.instantiate()
		item.kind = kind
		item.name = "Furniture_" + kind
		item.tooltip_text = {"computer": "使用电脑", "desk": "更换家具", "peripheral": "更换外设", "cabinet": "打开成就展示柜", "decor": "更换装饰"}[kind]
		var key := kind
		item.pressed.connect(func() -> void:
			if key == "computer": computer_requested.emit()
			elif key == "cabinet": cabinet_requested.emit()
			else: inventory_requested.emit()
		)
		add_child(item)
		furniture[kind] = item
	resized.connect(refresh)
	session.changed.connect(refresh)
	session.tick_updated.connect(_update_text)
	refresh()

func _update_text() -> void:
	wallet.text = "%s  ·  钱包 %d 点" % [session.state.date_text(), session.state.wallet]
	activity_label.text = session.activity_text()
	var values: Array[String] = []
	for key: String in Data.ATTRIBUTES: values.append("%s %d" % [key, int(session.state.life["attributes"][key])])
	attributes.text = "玩家能力   " + "   /   ".join(values)

func refresh() -> void:
	if furniture.is_empty(): return
	_update_text()
	var factor := Vector2(size.x / 640.0, maxf(1.0, size.y - 190.0) / 360.0)
	var shift: float = 18.0 if int(session.state.life["room_layout"]) == 1 else 0.0
	var positions := {"desk": Rect2(95 + shift, 230, 325, 115), "computer": Rect2(220 + shift, 128, 147, 112), "peripheral": Rect2(213 + shift, 219, 148, 26), "cabinet": Rect2(487 - shift, 100, 100, 220), "decor": Rect2(122 + shift, 158, 50, 82)}
	for key: String in furniture:
		var item = furniture[key]
		var rect: Rect2 = positions[key]
		item.position = Vector2(0, 74) + rect.position * factor
		item.size = rect.size * factor
		var equipped: String = session.state.life["equipped"].get(key, "")
		if key == "decor": item.visible = not equipped.is_empty()
		item.upgraded = not equipped.is_empty() and not equipped.begins_with("starter_")
		item.microphone = not str(session.state.life["equipped"]["audio"]).is_empty()
		item.trophy_count = session.state.life["displayed"].size()
		item.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("b4a28a"))
	var factor := Vector2(size.x / 640.0, maxf(1.0, size.y - 190.0) / 360.0)
	draw_set_transform(Vector2(0, 74), 0, factor)
	draw_rect(Rect2(0, 0, 640, 240), Color("bcae96"))
	draw_rect(Rect2(0, 240, 640, 120), Color("8f7964"))
	for y in range(240, 360, 24):
		draw_line(Vector2(0, y), Vector2(640, y), Color("786b5a"), 2)
		for x in range((y % 48) * 3, 640, 100): draw_line(Vector2(x, y), Vector2(x, y + 24), Color("786b5a"), 1)
	draw_rect(Rect2(0, 234, 640, 9), Color("6b6958"))
	# 窗外的像素城市与窗框。
	draw_rect(Rect2(45, 24, 147, 142), Color("6d7467"))
	draw_rect(Rect2(51, 30, 135, 129), Color("71959b"))
	for i in range(7):
		var height: float = float(25 + (i * 19) % 60)
		draw_rect(Rect2(54 + i * 18, 151 - height, 16, height), Color("506c76"))
	draw_rect(Rect2(114, 30, 6, 129), Color("d5c6a4"))
	draw_rect(Rect2(51, 92, 135, 5), Color("d5c6a4"))
	draw_rect(Rect2(36, 161, 165, 9), Color("717563"))
	# 地毯、墙上的收藏海报和游戏盒。
	draw_rect(Rect2(175, 288, 279, 50), Color("5d7772"))
	draw_rect(Rect2(185, 295, 259, 35), Color("7d9180"))
	draw_rect(Rect2(269, 18, 80, 84), Color("5c6256"))
	draw_rect(Rect2(274, 23, 70, 74), Color("254652"))
	draw_rect(Rect2(284, 38, 49, 5), Color("b5b488"))
	draw_rect(Rect2(295, 51, 27, 27), Color("648d81"))
	draw_rect(Rect2(388, 60, 67, 6), Color("73715f"))
	for i in range(5): draw_rect(Rect2(393 + i * 11, 35 + i % 2 * 5, 8, 25 - i % 2 * 5), Color("667b70") if i % 2 else Color("aa956d"))
