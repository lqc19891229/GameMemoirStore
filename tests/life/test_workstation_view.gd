extends SceneTree
## Run with Godot 4.6: --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh
## Exercises input through the monitor container, not by directly emitting OS button signals.
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for _i in range(5): await process_frame

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
	await frames()

func click_screen(desktop: Control, target: Control) -> void:
	var viewport: SubViewport = desktop.get_node("%DesktopViewport")
	var container: SubViewportContainer = desktop.get_node("%ScreenViewport")
	var logical: Vector2 = target.get_global_rect().get_center()
	var scaled := logical * Vector2(viewport.size) / Vector2(viewport.size_2d_override)
	await click_at(container.get_global_transform_with_canvas() * scaled)

func run() -> void:
	var game = load("res://scenes/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	check(game.room.get_node("RoomCanvas/Art/LeftWall") is Polygon2D, "left wall is an authored polygon")
	check(game.room.get_node("RoomCanvas/Art/RightWall") is Polygon2D, "right wall is an authored polygon")
	var room_screen: Button = game.room.furniture["computer"]
	await click_at(room_screen.get_global_rect().get_center())
	check(game.desktop.visible, "clicking the computer enters its close-up")
	var desktop: Control = game.desktop
	var viewport: SubViewport = desktop.get_node("%DesktopViewport")
	var container: SubViewportContainer = desktop.get_node("%ScreenViewport")
	check(viewport.gui_embed_subwindows, "menus and dialogs stay in the monitor")
	check(viewport.size_2d_override == Vector2i(1280, 800), "OS retains a readable logical resolution")
	for dimensions: Vector2 in [Vector2(1280, 800), Vector2(960, 600)]:
		desktop.anchor_right = 0.0
		desktop.anchor_bottom = 0.0
		desktop.size = dimensions
		await frames()
		check(container.size.x > 0 and container.size.y > 0, "screen remains visible after resizing")
		await click_at(desktop.global_position + dimensions * Vector2(0.89, 0.40))
		check(desktop.windows.is_empty(), "clicking the case does not open applications")
		await click_screen(desktop, desktop.screen_node("DesktopPlatform"))
		check(desktop.windows.has("platform"), "screen coordinates reach platform shortcut")
		if desktop.windows.has("platform"):
			var window = desktop.windows["platform"]
			check(window.get_viewport() == viewport, "application is inside desktop viewport")
			check(window.get_parent() == desktop.area, "application uses the screen's application area")
			window.content.settings()
			await frames()
			check(window.content.popup.is_embedded(), "settings dialog is embedded in the monitor")
			window.content.popup.hide()
			desktop.minimize_app("platform")
			await frames()
			await click_screen(desktop, desktop.screen_node("TaskbarPlatform"))
			check(window.visible, "screen taskbar restores minimized application")
			desktop.close_app("platform")
			await frames()
		await click_screen(desktop, desktop.screen_node("DesktopBrowser"))
		check(desktop.windows.has("browser"), "screen coordinates reach browser shortcut")
		if desktop.windows.has("browser"): desktop.close_app("browser")
		await frames()
	desktop.show_notice("screen notification")
	check(desktop.screen_node("ScreenToast").visible, "notifications are displayed inside the screen")
	await click_screen(desktop, desktop.screen_node("DesktopRoom"))
	check(game.room.visible and not desktop.visible, "screen taskbar returns to the room")
	game.queue_free()
	await frames()
	print("WORKSTATION_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
