extends Control
signal dismissed
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
var rows: VBoxContainer
var status: Label
var pending := false

func _ready() -> void:
	rows = %Rows
	status = %Status
	%ReturnRoom.pressed.connect(func() -> void: dismissed.emit())
	if session == null: return
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
			var row = preload("res://scenes/client/components/achievement_row.tscn").instantiate()
			rows.add_child(row)
			row.get_node("%Title").text = "★  %s  /  %s" % [session.state.game(id)["title"], milestone["name"]]
			var game_id := id
			var key: String = milestone["id"]
			var selected: bool = session.state.life["displayed"].has({"game_id": id, "achievement": key})
			var action: Button = row.get_node("%Action")
			action.text = "收起" if selected else "展示"
			action.pressed.connect(func() -> void: session.notice.emit(session.toggle_display(game_id, key)))
			action.name = "Display_" + id + "_" + key
	if count == 0:
		var label = preload("res://scenes/client/components/text_label.tscn").instantiate()
		label.text = "展架还空着。启动一款游戏，获得第一枚纪念奖杯吧。"
		rows.add_child(label)
