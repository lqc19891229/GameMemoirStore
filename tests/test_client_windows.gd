extends SceneTree
const State = preload("res://scripts/store_state.gd")
const FIXTURE_CATALOG = preload("res://tests/fixtures/catalog/_catalog.tres")
var count: int = 0
var errors: int = 0

func check(value: bool, text: String) -> void:
	count += 1
	if not value:
		errors += 1
		push_error(text)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var client = load("res://scenes/apps/platform/store.tscn").instantiate()
	client.state = State.new(FIXTURE_CATALOG)
	root.add_child(client)
	await process_frame
	client.download_timer.stop()
	client.state.add_to_cart("distant_signal")
	client.state.checkout()
	client.state.start_install("distant_signal")
	client.state.tick_downloads(100)
	client.navigate({"kind": "library", "id": "distant_signal"})
	await process_frame
	client.find_child("LibraryAction", true, false).pressed.emit()
	await process_frame
	check(is_instance_valid(client.running_window) and client.running_window.visible, "play opens native session window")
	client.running_window.get_ok_button().pressed.emit()
	await process_frame
	check(client.running_game_id.is_empty() and client.state.play_minutes.get("distant_signal", 0) == 45, "session window button ends play exactly once")
	client.library_context("distant_signal")
	await process_frame
	var menu: PopupMenu
	for child: Node in client.get_children():
		if child is PopupMenu: menu = child
	check(is_instance_valid(menu) and menu.item_count == 4, "native library context menu provides four actions")
	if is_instance_valid(menu):
		menu.id_pressed.emit(1)
		menu.hide()
	await process_frame
	check(client.state.favorites.has("distant_signal"), "context menu adds game to collection")
	client.settings()
	await process_frame
	check(client.popup.visible, "settings opens native dialog")
	client.popup.hide()
	client.account_details()
	await process_frame
	check(client.popup.visible and client.popup.dialog_text.contains("66"), "account details shows purchase spending")
	client.popup.hide()
	client.friends()
	await process_frame
	check(client.popup.visible and client.popup.dialog_text.contains("山间旅人"), "friend panel opens in-world contacts")
	client.popup.hide()
	client.navigate({"kind": "search"})
	await process_frame
	await process_frame
	await process_frame
	var scrollbar: VScrollBar = client.get_node("%ContentScroll").get_v_scroll_bar()
	var target_scroll := mini(80, int(scrollbar.max_value - scrollbar.page))
	client.get_node("%ContentScroll").scroll_vertical = target_scroll
	check(target_scroll > 0 and client.get_node("%ContentScroll").scroll_vertical == target_scroll, "search page can scroll to test position")
	client.open_product("mist_valley")
	await process_frame
	client.go_history(-1)
	await process_frame
	await process_frame
	await process_frame
	check(client.get_node("%ContentScroll").scroll_vertical == target_scroll, "back navigation restores scroll position")
	client.queue_free()
	await process_frame
	print("CLIENT_WINDOW_CHECKS: %d passed / %d checks" % [count - errors, count])
	quit(0 if errors == 0 else 1)
