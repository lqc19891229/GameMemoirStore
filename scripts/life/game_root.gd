extends Control
var session: MemoirGameSession
var desktop: Node3D

func _enter_tree() -> void:
	# Inject before child _ready; the GameSession sibling is initialized first.
	session = $GameSession
	desktop = $ComputerDesktop
	desktop.session = session

func _ready() -> void:
	session.play_requested.connect(func(_id: String) -> void: desktop.open_app("game"))
	session.notice.connect(desktop.show_notice)
	_capture.call_deferred()

func _capture() -> void:
	var output := ""
	var view := "desktop"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--life-capture="): output = arg.trim_prefix("--life-capture=")
		if arg.begins_with("--life-view="): view = arg.trim_prefix("--life-view=")
	if output.is_empty(): return
	session.timer.stop()
	if view != "desktop": desktop.set_screen_focused(true, false)
	if view in ["platform", "browser"]: desktop.open_app(view)
	if view in ["game", "creation"] and not session.state.catalog.is_empty():
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
	for _frame in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("LIFE_CAPTURE ", view, " error=", error)
	get_tree().quit(0 if error == OK else 1)
