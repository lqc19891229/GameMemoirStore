extends Control
signal computer_requested
signal inventory_requested
signal cabinet_requested
const Data = preload("res://scripts/life/life_data.gd")
var session: MemoirGameSession
@onready var wallet: Label = %Wallet
@onready var activity_label: Label = %Activity
@onready var attributes: Label = %Attributes
var furniture: Dictionary = {}
var authored_anchors: Dictionary = {}

func _ready() -> void:
	%RoomComputer.pressed.connect(func() -> void: computer_requested.emit())
	%RoomInventory.pressed.connect(func() -> void: inventory_requested.emit())
	%RoomCabinet.pressed.connect(func() -> void: cabinet_requested.emit())
	%RoomLayout.pressed.connect(func() -> void:
		session.state.life["room_layout"] = 1 - int(session.state.life["room_layout"])
		session.state.save_state()
	)
	for item in %RoomCanvas.get_children():
		if not item is Button: continue
		var key: String = item.kind
		furniture[key] = item
		authored_anchors[key] = Vector2(item.anchor_left, item.anchor_right)
		item.pressed.connect(func() -> void:
			if key == "computer": computer_requested.emit()
			elif key == "cabinet": cabinet_requested.emit()
			else: inventory_requested.emit()
		)
	if session == null: return
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
	if session == null: return
	_update_text()
	for key: String in furniture:
		var item = furniture[key]
		# Only the alternate layout adds a relative shift to the editor-authored position.
		var shift := (18.0 / 640.0) * int(session.state.life["room_layout"]) * (-1 if key == "cabinet" else 1)
		item.anchor_left = authored_anchors[key].x + shift
		item.anchor_right = authored_anchors[key].y + shift
		var equipped: String = session.state.life["equipped"].get(key, "")
		if key == "decor": item.visible = not equipped.is_empty()
		item.upgraded = not equipped.is_empty() and not equipped.begins_with("starter_")
		item.microphone = not str(session.state.life["equipped"]["audio"]).is_empty()
		item.trophy_count = session.state.life["displayed"].size()
		item.refresh_appearance()
