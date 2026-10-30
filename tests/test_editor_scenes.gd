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
	for dir in ["life", "client/pages", "client/components", "life/furniture"]:
		for file in DirAccess.get_files_at("res://scenes/" + dir):
			if file.ends_with(".tscn"): paths.append("res://scenes/" + dir + "/" + file)
	for path in paths:
		var scene: PackedScene = load(path)
		check(scene != null, "scene loads: " + path)
		if scene == null: continue
		var node := scene.instantiate()
		if node is Control and not node is Label and not node is Button:
			check(node.get_child_count() > 0, "visible layout exists before ready: " + path)
		if "furniture/" in path:
			check(node.get_child_count() > 0, "furniture contains real art nodes: " + path)
		node.free()
	var game = load("res://scenes/game_root.tscn").instantiate()
	check(game.has_node("PlayerRoom/RoomCanvas/Furniture_computer"), "main scene contains room and furniture instances")
	check(game.has_node("ComputerDesktop/ApplicationArea"), "desktop shell exists before running")
	var furniture: Control = game.get_node("PlayerRoom/RoomCanvas/Furniture_computer")
	var anchor := furniture.anchor_left + 0.025
	furniture.anchor_left = anchor
	furniture.anchor_right += 0.025
	root.add_child(game)
	game.session.timer.stop()
	check(is_equal_approx(furniture.anchor_left, anchor), "ready preserves editor-authored furniture anchors")
	game.room.refresh()
	check(is_equal_approx(furniture.anchor_left, anchor), "refresh preserves editor-authored furniture anchors")
	var client = load("res://scenes/store.tscn").instantiate()
	client.get_node("%ClientHeader").custom_minimum_size.y = 120
	var original_home: Node = client.get_node("%PageContent").get_child(0)
	root.add_child(client)
	client.download_timer.stop()
	check(client.get_node("%PageContent").get_child(0) == original_home, "initial page uses authored scene instance")
	client.refresh_client()
	check(client.get_node("%PageContent").get_child(0) == original_home, "data refresh keeps static page nodes")
	check(client.get_node("%ClientHeader").custom_minimum_size.y == 120, "runtime preserves inspector layout changes")
	for script in ["client.gd", "client_pages.gd", "client_ui.gd", "life/player_room.gd", "life/furniture_item.gd"]:
		var source := FileAccess.get_file_as_string("res://scripts/" + script)
		check(not source.contains("func _draw") and not source.contains("Button.new()") and not source.contains("Label.new()") and not source.contains("ColorRect.new()"), "no procedural layout or room drawing: " + script)
	client.queue_free()
	game.queue_free()
	await process_frame
	print("EDITOR_SCENE_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
