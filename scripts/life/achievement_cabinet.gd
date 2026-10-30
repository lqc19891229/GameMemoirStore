extends Control
signal dismissed
const U = preload("res://scripts/client_ui.gd")
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
var rows: VBoxContainer
var status: Label
var pending := false

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.04, 0.85)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := U.margin(self, 60)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := U.vbox(U.panel(margin, "25342f", 24), 14)
	var header := U.hbox(layout)
	U.label(header, "成就陈列室", 24, Color("ecd5a5"))
	U.button(header, "返回房间", func() -> void: dismissed.emit(), "flat", 120)
	status = U.label(layout, "", 12, U.TEXT, true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	rows = U.vbox(scroll, 10)
	session.changed.connect(_queue_refresh)
	refresh()

func _queue_refresh() -> void:
	if not pending:
		pending = true
		refresh.call_deferred()

func refresh() -> void:
	pending = false
	if not is_instance_valid(rows): return
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var equipped: String = session.state.life["equipped"]["cabinet"]
	status.text = "%s · 展示位 %d / %d\n玩游戏获得成就，在这里选择希望留在房间里的奖杯。" % [Data.ITEMS[equipped]["name"], session.state.life["displayed"].size(), Data.ITEMS[equipped].get("capacity", 1)]
	var count: int = 0
	for id: String in session.state.owned:
		for milestone: Dictionary in Data.MILESTONES:
			if not session.state.life["achievements"].get(id, []).has(milestone["id"]): continue
			count += 1
			var row := U.hbox(U.panel(rows, "31423b", 14))
			U.label(row, "★  %s  /  %s" % [session.state.game(id)["title"], milestone["name"]], 12, Color("eddaae"), true)
			var game_id := id
			var key: String = milestone["id"]
			var selected: bool = session.state.life["displayed"].has({"game_id": id, "achievement": key})
			U.button(row, "收起" if selected else "展示", func() -> void: session.notice.emit(session.toggle_display(game_id, key)), "blue", 100).name = "Display_" + id + "_" + key
	if count == 0: U.label(rows, "展架还空着。启动一款游戏，获得第一枚纪念奖杯吧。", 24, U.MUTED, true)
