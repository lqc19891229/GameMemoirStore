extends Control
var session: MemoirGameSession
var room: Control
var desktop: Control
var cabinet: Control
var toast: Label
var toast_timer: Timer

func _enter_tree() -> void:
	# Inject before child _ready; the GameSession sibling is initialized first.
	session = $GameSession
	room = $PlayerRoom
	desktop = $ComputerDesktop
	cabinet = $AchievementCabinet
	for view in [room, desktop, cabinet]: view.session = session

func _ready() -> void:
	room.computer_requested.connect(show_desktop)
	room.inventory_requested.connect(func() -> void:
		show_desktop()
		desktop.open_app("browser", "inventory")
	)
	room.cabinet_requested.connect(show_cabinet)
	desktop.room_requested.connect(show_room)
	cabinet.dismissed.connect(cabinet.hide)
	session.play_requested.connect(func(_id: String) -> void:
		show_desktop()
		desktop.open_app("game")
	)
	toast = %Toast
	toast_timer = %ToastTimer
	toast_timer.timeout.connect(toast.hide)
	session.notice.connect(show_notice)
	_capture.call_deferred()

func show_room() -> void:
	desktop.hide()
	room.show()
	room.refresh()

func show_desktop() -> void:
	room.hide()
	if is_instance_valid(cabinet): cabinet.hide()
	desktop.show()

func show_cabinet() -> void:
	cabinet.show()
	cabinet.move_to_front()
	cabinet.refresh()

func show_notice(message: String) -> void:
	toast.text = message
	toast.show()
	toast.move_to_front()
	toast_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(cabinet) and cabinet.visible: cabinet.hide()
			elif desktop.visible: show_room()
			else: show_desktop()
			get_viewport().set_input_as_handled()

func _capture() -> void:
	var output := ""
	var view := "room"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--life-capture="): output = arg.trim_prefix("--life-capture=")
		if arg.begins_with("--life-view="): view = arg.trim_prefix("--life-view=")
	if output.is_empty(): return
	session.timer.stop()
	if view != "room": show_desktop()
	if view in ["platform", "browser"]: desktop.open_app(view)
	if view in ["game", "cabinet", "creation"] and not session.state.catalog.is_empty():
		var id: String = session.state.catalog[0]["id"]
		session.state.add_to_cart(id)
		session.state.checkout()
		session.state.start_install(id)
		session.tick(5)
		session.start_play(id)
		session.tick(12)
		if view == "creation":
			session.stop_play()
			session.start_guide(id)
			var client = desktop.open_app("platform")
			client.navigate({"kind": "community"})
		if view == "cabinet":
			session.stop_play()
			session.toggle_display(id, "first_memory")
			show_room()
			show_cabinet()
	for _frame in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("LIFE_CAPTURE ", view, " error=", error)
	get_tree().quit(0 if error == OK else 1)
