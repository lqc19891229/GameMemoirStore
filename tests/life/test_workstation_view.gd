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

func dispatch_input(event: InputEvent) -> void:
	# Model native host Window delivery before viewport-local input for embedded modals.
	root.window_input.emit(event.xformed_by(root.get_final_transform()))
	root.push_input(event, true)

func finish_transition() -> void:
	await create_timer(0.35).timeout
	await frames()

func escape_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	dispatch_input(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	dispatch_input(event)
	await finish_transition()

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	dispatch_input(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	dispatch_input(event)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	dispatch_input(event)
	await frames()

func click_screen(desktop: Control, target: Control) -> void:
	var viewport: SubViewport = desktop.get_node("%DesktopViewport")
	var container: SubViewportContainer = desktop.get_node("%ScreenViewport")
	var logical: Vector2 = target.get_global_rect().get_center()
	if target.get_viewport() is Window and target.get_viewport() != root: logical += Vector2(target.get_viewport().position)
	var scaled := logical * Vector2(viewport.size) / Vector2(viewport.size_2d_override)
	await click_at(container.get_global_transform_with_canvas() * scaled)

func run() -> void:
	var game = load("res://scenes/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	check(game.desktop.visible, "game starts directly at the computer close-up")
	check(not game.has_node("PlayerRoom"), "main scene has no room instance")
	check(game.desktop.screen_node("TaskbarRow").get_node_or_null("DesktopRoom") == null, "taskbar has no room return button")
	var desktop: Control = game.desktop
	var viewport: SubViewport = desktop.get_node("%DesktopViewport")
	var container: SubViewportContainer = desktop.get_node("%ScreenViewport")
	check(viewport.gui_embed_subwindows, "menus and dialogs stay in the monitor")
	check(not desktop.screen_focused and not container.input_enabled, "overview shows equipment without sending input to small OS buttons")
	check(viewport.size_2d_override == Vector2i(1280, 800), "OS retains a readable logical resolution")
	game.session.state.wallet = 1000
	for item in ["lcd_monitor", "workstation", "precise_mouse"]: game.session.buy_item(item)
	for configuration: Array in [[Vector2(1280, 800), "starter_monitor"], [Vector2(1280, 800), "lcd_monitor"], [Vector2(960, 600), "starter_monitor"], [Vector2(960, 600), "lcd_monitor"]]:
		var dimensions: Vector2 = configuration[0]
		desktop.anchor_right = 0.0
		desktop.anchor_bottom = 0.0
		desktop.size = dimensions
		game.session.equip_item(configuration[1])
		await frames()
		check(container.size.x > 0 and container.size.y > 0, "screen remains visible after resizing")
		await click_at(desktop.get_node("%Computer").get_global_rect().get_center())
		check(desktop.windows.is_empty(), "clicking the case does not open applications")
		check(desktop.get_node("%DeviceName").text.contains("机箱"), "hardware selection shows item information")
		await click_at(desktop.get_node("%FocusScreen").get_global_rect().get_center())
		await finish_transition()
		check(desktop.screen_focused and container.input_enabled, "clicking monitor enters screen mode after transition")
		check(desktop.windows.is_empty(), "enter-screen click never also opens an OS shortcut")
		var screen: Rect2 = desktop.get_node("%MonitorScreen").get_global_rect()
		check(screen.size.x > dimensions.x * 0.80 and Rect2(Vector2.ZERO, dimensions).encloses(screen), "focused screen is wide and remains inside the window")
		check(viewport.size == Vector2i(1280, 800), "zoom preserves full OS render resolution")
		await click_screen(desktop, desktop.screen_node("DesktopPlatform"))
		check(desktop.windows.has("platform"), "screen coordinates reach platform shortcut")
		if desktop.windows.has("platform"):
			var window = desktop.windows["platform"]
			check(window.get_viewport() == viewport, "application is inside desktop viewport")
			check(window.get_parent() == desktop.area, "application uses the screen's application area")
			window.content.settings()
			await frames()
			check(window.content.popup.is_embedded(), "settings dialog is embedded in the monitor")
			await escape_key()
			check(desktop.screen_focused and not window.content.popup.visible, "Escape dismisses embedded dialog without leaving screen mode")
			window.content.settings()
			await frames()
			await click_screen(desktop, window.content.popup.get_ok_button())
			check(not window.content.popup.visible and desktop.screen_focused, "scaled input reaches embedded dialog close button without clicking through")
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
		await escape_key()
		check(not desktop.screen_focused and not container.input_enabled, "Escape returns to equipment overview")
		check(desktop.get_node("%Equipment").scale.is_equal_approx(Vector2.ONE), "return restores original authored equipment scale")
		# An interrupted zoom must not leave stale scale, input or hit areas.
		desktop.set_screen_focused(true)
		desktop.set_screen_focused(false)
		await finish_transition()
		check(not desktop.screen_focused and not container.input_enabled, "rapid toggle finishes in requested overview mode")
	# Upgrades replace independent sprites while retaining live windows and screen state.
	await click_at(desktop.get_node("%ManageDevices").get_global_rect().get_center())
	await finish_transition()
	check(desktop.screen_focused and desktop.windows.has("browser"), "manage devices opens inventory in focused screen")
	var browser = desktop.windows["browser"].content
	check(browser.tab == "inventory", "device management opens installed inventory")
	var previous: Dictionary = {}
	for role in ["Computer", "Keyboard", "Mouse"]: previous[role] = desktop.get_node("%" + role).visual.texture
	game.session.equip_item("workstation")
	game.session.equip_item("precise_mouse")
	await frames()
	for role in previous:
		check(desktop.get_node("%" + role).visual.texture != previous[role], "upgraded inventory item changes sprite: " + role)
	var live_window = desktop.windows["browser"]
	game.session.equip_item("starter_monitor")
	await frames()
	check(desktop.windows["browser"] == live_window and browser.tab == "inventory", "monitor replacement preserves live app and current tab")
	check(desktop.get_node("%Monitor").visual == desktop.hardware_catalog.monitors["starter_monitor"], "monitor appearance follows equipped item")
	# Install the alternate monitor through actual scaled-screen inventory input.
	await click_screen(desktop, browser.find_child("Equip_lcd_monitor", true, false))
	check(game.session.state.life["equipped"]["monitor"] == "lcd_monitor" and desktop.get_node("%Monitor").visual == desktop.hardware_catalog.monitors["lcd_monitor"], "inventory input installs alternate monitor and recalibrates the live screen")
	var state = game.session.state
	state.save_path = "user://memoir_hardware_test.json"
	state.persistence_enabled = true
	check(state.save_state(), "hardware selection saves")
	var restored = load("res://scripts/store_state.gd").new()
	restored.save_path = state.save_path
	restored.load_state()
	check(restored.life["equipped"]["monitor"] == "lcd_monitor" and restored.life["equipped"]["computer"] == "workstation", "saved monitor and case selections survive loading")
	state.persistence_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	await escape_key()
	await click_at(desktop.get_node("%FocusScreen").get_global_rect().get_center())
	await finish_transition()
	check(desktop.windows["browser"] == live_window, "overview round trip preserves window instance")
	desktop.close_app("browser")
	desktop.show_notice("screen notification")
	check(desktop.screen_node("ScreenToast").visible, "notifications are displayed inside the screen")
	await escape_key()
	check(desktop.visible, "Escape never hides the only desktop view")
	game.queue_free()
	await frames()
	print("WORKSTATION_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
