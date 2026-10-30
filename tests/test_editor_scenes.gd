extends SceneTree
## Inspect PackedScenes before _ready: editor content must exist without game execution.
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var paths: Array[String] = ["res://scenes/game_root.tscn", "res://scenes/store.tscn"]
	for dir in ["life", "client/pages", "client/components"]:
		for file in DirAccess.get_files_at("res://scenes/" + dir):
			if file.ends_with(".tscn"): paths.append("res://scenes/" + dir + "/" + file)
	for path in paths:
		var scene: PackedScene = load(path)
		check(scene != null, "scene loads: " + path)
		if scene == null: continue
		var node := scene.instantiate()
		if node is Control and not node is Label and not node is Button:
			check(node.get_child_count() > 0, "visible layout exists before ready: " + path)
		node.free()
	var closeup = load("res://scenes/life/computer_desktop.tscn").instantiate()
	check(closeup.get_node("WorkstationArt") is TextureRect, "close-up uses one backdrop texture")
	check(closeup.get_child_count() == 2, "close-up only has art and live monitor screen")
	closeup.free()
	var game = load("res://scenes/game_root.tscn").instantiate()
	check(game.get_child_count() == 2, "main scene only contains shared session and desktop")
	check(not game.has_node("PlayerRoom") and not game.has_node("AchievementCabinet"), "room presentation has been removed")
	check(game.get_node("ComputerDesktop").visible, "desktop is visible in the authored main scene")
	check(game.has_node("ComputerDesktop/MonitorScreen/ScreenViewport/DesktopViewport/DesktopScreen/ApplicationArea"), "desktop shell exists before running")
	root.add_child(game)
	game.session.timer.stop()
	var client = load("res://scenes/store.tscn").instantiate()
	client.get_node("%ClientHeader").custom_minimum_size.y = 120
	var original_home: Node = client.get_node("%PageContent").get_child(0)
	root.add_child(client)
	client.download_timer.stop()
	check(client.get_node("%PageContent").get_child(0) == original_home, "initial page uses authored scene instance")
	client.refresh_client()
	check(client.get_node("%PageContent").get_child(0) == original_home, "data refresh keeps static page nodes")
	check(client.get_node("%ClientHeader").custom_minimum_size.y == 120, "runtime preserves inspector layout changes")
	for script in ["client.gd", "client_pages.gd", "client_ui.gd", "life/game_root.gd", "life/computer_desktop.gd"]:
		var source := FileAccess.get_file_as_string("res://scripts/" + script)
		check(not source.contains("func _draw") and not source.contains("Button.new()") and not source.contains("Label.new()") and not source.contains("ColorRect.new()"), "no procedural layout: " + script)
	client.queue_free()
	game.queue_free()
	await process_frame
	print("EDITOR_SCENE_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
