extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame
	await physics_frame
	await process_frame
func finish_transition() -> void:
	await create_timer(0.42).timeout
	await frames()
func dispatch(event: InputEvent) -> void:
	root.window_input.emit(event.xformed_by(root.get_final_transform()))
	root.push_input(event, true)
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	dispatch(motion)
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	dispatch(press)
	press = press.duplicate() as InputEventMouseButton
	press.pressed = false
	dispatch(press)
	await frames()
func escape_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	dispatch(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	dispatch(event)
	await finish_transition()
func click_screen(desktop: Node3D, target: Control) -> void:
	var logical := target.get_global_rect().get_center()
	if target.get_viewport() is Window and target.get_viewport() != root: logical += Vector2(target.get_viewport().position)
	await click(desktop.canvas_point_for_screen(logical))
func device_point(desktop: Node3D, role: String) -> Vector2:
	var device: Node3D = desktop.world.devices[role]
	var center: Vector3 = device.to_global(Vector3(0, device.appearance.bounds.y / 2.0, 0))
	var pixel: Vector2 = desktop.world.camera.unproject_position(center)
	return pixel
func run() -> void:
	var game = load("res://scenes/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	var desktop: Node3D = game.desktop
	var world = desktop.world
	var viewport: SubViewport = desktop.get_node("%DesktopViewport")
	check(world is Node3D and world.camera is Camera3D, "workstation uses actual 3D scene and camera")
	check(world.mode == "overview" and not desktop.screen_focused, "new game starts at 3D overview")
	check(not game.has_node("PlayerRoom"), "room scene remains removed")
	check(desktop is Node3D and world.get_viewport() == root, "ComputerDesktop renders 3D directly in the main viewport")
	var original_view: Transform3D = world.camera.transform
	var original_distance: float = world.overview_distance
	var point := device_point(desktop, "computer")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	dispatch(press)
	var move := InputEventMouseMotion.new()
	move.position = point + Vector2(160,50)
	move.relative = Vector2(160,50)
	dispatch(move)
	press.position = move.position
	press.pressed = false
	dispatch(press)
	await frames()
	check(world.mode == "overview" and not world.camera.transform.is_equal_approx(original_view), "drag starting on a device orbits without entering inspection")
	check(world.overview_pitch > 0.3, "vertical dragging changes elevation")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = root.get_visible_rect().size / 2.0
	wheel.pressed = true
	dispatch(wheel)
	check(world.overview_distance < original_distance, "wheel zooms directly in desktop overview")
	var retained_view: Transform3D = world.camera.transform
	desktop.select_device("keyboard", false)
	desktop.set_screen_focused(false, false)
	check(world.camera.transform.is_equal_approx(retained_view), "return from inspection preserves overview orbit and zoom")
	desktop.set_screen_focused(true, false)
	desktop.set_screen_focused(false, false)
	check(world.camera.transform.is_equal_approx(retained_view), "return from screen preserves overview orbit and zoom")
	for i in range(100): dispatch(wheel)
	check(is_equal_approx(world.overview_distance, world.minimum_distance), "overview zoom has a near limit")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in range(100): dispatch(wheel)
	check(is_equal_approx(world.overview_distance, world.maximum_distance), "overview zoom has a far limit")
	var yaw: float = world.overview_yaw
	press.button_index = MOUSE_BUTTON_RIGHT
	press.position = wheel.position
	press.pressed = true
	dispatch(press)
	move.relative = Vector2(350,0)
	move.position = press.position + move.relative
	dispatch(move)
	press.pressed = false
	dispatch(press)
	await frames()
	check(absf(angle_difference(yaw, world.overview_yaw)) > 1.5, "right drag orbits beyond the previous narrow angle limit")
	var before_header: Transform3D = world.camera.transform
	wheel.position = desktop.get_node("%ResetView").get_global_rect().get_center()
	dispatch(wheel)
	wheel.pressed = false
	dispatch(wheel)
	check(world.camera.transform.is_equal_approx(before_header), "scrolling over HUD never zooms the 3D world")
	await click(desktop.get_node("%ResetView").get_global_rect().get_center())
	check(world.camera.transform.is_equal_approx(original_view), "reset view restores the authored camera")
	# A short movement is still a click, while a drag across the screen must not enter it.
	point = desktop.canvas_point_for_screen(Vector2(640,400))
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	dispatch(press)
	move.position = point + Vector2(35,0)
	move.relative = Vector2(35,0)
	dispatch(move)
	press.position = move.position
	press.pressed = false
	dispatch(press)
	await frames()
	check(world.mode == "overview", "dragging from the display never clicks through into screen operation")
	world.reset_overview()
	for role in ["computer", "keyboard", "mouse", "monitor"]:
		var placement: Transform3D = world.devices[role].transform
		await click(device_point(desktop, role) if role != "monitor" else desktop.canvas_point_for_screen(Vector2(640,400)))
		await finish_transition()
		if role == "monitor":
			check(desktop.screen_focused, "clicking 3D display enters screen mode")
		else:
			check(world.mode == "inspect" and world.selected == role, "ray picks product: " + role)
			check(not world.get_node("%Desk").visible and world.get_node("%Pedestal").visible, "inspection uses product stage")
			check(desktop.windows.is_empty(), "hardware inspection never launches apps")
			var product_yaw: float = world.devices[role].rotation.y
			point = root.get_visible_rect().size / 2.0
			press = InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.position = point
			press.pressed = true
			dispatch(press)
			move = InputEventMouseMotion.new()
			move.position = point + Vector2(90,20)
			move.relative = Vector2(90,20)
			dispatch(move)
			press.pressed = false
			dispatch(press)
			check(not is_equal_approx(world.devices[role].rotation.y, product_yaw), "drag rotates real geometry: " + role)
			var distance: float = world.inspect_distance
			wheel = InputEventMouseButton.new()
			wheel.position = point
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			dispatch(wheel)
			check(world.inspect_distance < distance, "wheel zooms selected product")
		await escape_key()
		check(world.mode == "overview" and world.devices[role].transform.is_equal_approx(placement), "return restores placement: " + role)
	game.session.state.wallet = 1000
	for id in ["lcd_monitor", "workstation", "precise_mouse"]: game.session.buy_item(id)
	for settings: Array in [[Vector2(1280,800),"starter_monitor"],[Vector2(1280,800),"lcd_monitor"],[Vector2(960,600),"starter_monitor"],[Vector2(960,600),"lcd_monitor"],[Vector2(1440,810),"lcd_monitor"],[Vector2(1024,768),"starter_monitor"]]:
		root.content_scale_size = settings[0]
		root.size = settings[0]
		game.session.equip_item(settings[1])
		await frames()
		await click(desktop.canvas_point_for_screen(Vector2(640,400)))
		await finish_transition()
		check(desktop.screen_focused and desktop.windows.is_empty(), "enter click never also launches app")
		check(viewport.size == Vector2i(1280,800) and viewport.gui_embed_subwindows, "screen retains OS resolution and embedded windows")
		var center: Vector2 = desktop.canvas_point_for_screen(Vector2(640,400))
		var uv: Vector2 = world.screen_uv(center)
		check(uv.distance_to(Vector2(.5,.5)) < .002, "3D projection and UV input agree")
		var top_left: Vector2 = desktop.canvas_point_for_screen(Vector2.ZERO)
		var bottom_right: Vector2 = desktop.canvas_point_for_screen(Vector2(1280,800))
		check(root.get_visible_rect().encloses(Rect2(top_left,bottom_right-top_left)), "screen framing remains inside wide and narrow windows")
		await click_screen(desktop, desktop.screen_node("DesktopPlatform"))
		check(desktop.windows.has("platform"), "3D screen input opens platform")
		if desktop.windows.has("platform"):
			var window = desktop.windows["platform"]
			check(window.get_viewport() == viewport, "platform stays in desktop viewport")
			window.content.settings()
			await frames()
			await escape_key()
			check(not window.content.popup.visible and desktop.screen_focused, "Escape closes modal without leaving screen")
			window.content.settings()
			await frames()
			await click_screen(desktop, window.content.popup.get_ok_button())
			check(not window.content.popup.visible, "3D pointer input reaches dialog button")
			desktop.minimize_app("platform")
			await click_screen(desktop, desktop.screen_node("TaskbarPlatform"))
			check(window.visible, "screen taskbar restores minimized app")
			desktop.close_app("platform")
			await frames()
		await click_screen(desktop, desktop.screen_node("DesktopBrowser"))
		check(desktop.windows.has("browser"), "3D screen opens shopping")
		if desktop.windows.has("browser"): desktop.close_app("browser")
		await frames()
		await escape_key()
		check(world.mode == "overview", "Escape returns to overview")
		desktop.set_screen_focused(true)
		desktop.set_screen_focused(false)
		await finish_transition()
		check(world.mode == "overview" and not world.transitioning, "interrupted camera transition settles correctly")
	await click(desktop.get_node("%ManageDevices").get_global_rect().get_center())
	await finish_transition()
	check(desktop.screen_focused and desktop.windows.has("browser"), "manage devices opens projected inventory")
	if not desktop.windows.has("browser"):
		game.queue_free()
		await frames()
		quit(1)
		return
	var browser = desktop.windows["browser"].content
	var active_window = desktop.windows["browser"]
	check(browser.tab == "inventory", "management selects inventory tab")
	game.session.equip_item("starter_monitor")
	await frames()
	await click_screen(desktop, browser.find_child("Equip_lcd_monitor",true,false))
	check(game.session.state.life["equipped"]["monitor"] == "lcd_monitor", "projected inventory input installs display")
	check(world.devices["monitor"].get_node("Models/UpgradeModel").visible and not world.devices["monitor"].get_node("Models/DefaultModel").visible, "equipping selects saved display model")
	game.session.equip_item("workstation")
	game.session.equip_item("precise_mouse")
	await frames()
	for role in ["computer","keyboard","mouse"]: check(world.devices[role].get_node("Models/UpgradeModel").visible, "equipping selects 3D upgrade: " + role)
	check(desktop.windows["browser"] == active_window and browser.tab == "inventory", "hardware change preserves app state")
	await escape_key()
	await click(desktop.canvas_point_for_screen(Vector2(640,400)))
	await finish_transition()
	check(desktop.windows["browser"] == active_window, "camera round trip preserves app instance")
	game.queue_free()
	await frames()
	print("WORKSTATION_3D_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
