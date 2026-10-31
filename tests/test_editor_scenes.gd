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
	for dir in ["life", "life/hardware", "client/pages", "client/components"]:
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
	check(closeup.get_node("Workstation3D") is Node3D, "workspace uses a genuine authored 3D scene")
	check(closeup is Node3D, "ComputerDesktop opens directly in the 3D editor")
	check(not closeup.has_node("WorldView") and closeup.get_node("HUD") is CanvasLayer, "3D content is native; only HUD uses a canvas layer")
	check(closeup.get_child_count() == 3, "workspace separates native 3D world, desktop texture and HUD")
	check(closeup.get_node("Workstation3D/Equipment").get_child_count() == 4, "workspace has four independent 3D device slots")
	for role in ["Monitor", "Computer", "Keyboard", "Mouse"]:
		var device: Node3D = closeup.get_node("Workstation3D/Equipment/" + role)
		check(device.appearance.model is PackedScene and not device.find_children("*", "MeshInstance3D", true, false).is_empty(), "device has saved model geometry before ready: " + role)
	closeup.free()
	var game = load("res://scenes/game_root.tscn").instantiate()
	check(game.get_child_count() == 2, "main scene only contains shared session and desktop")
	check(not game.has_node("PlayerRoom") and not game.has_node("AchievementCabinet"), "room presentation has been removed")
	check(game.get_node("ComputerDesktop").visible, "desktop is visible in the authored main scene")
	check(game.has_node("ComputerDesktop/DesktopViewport/DesktopScreen/ApplicationArea"), "desktop shell exists before running")
	var keyboard: Node3D = game.get_node("ComputerDesktop/Workstation3D/Equipment/Keyboard")
	keyboard.position.x += 0.1
	var original_position := keyboard.position
	root.add_child(game)
	game.session.timer.stop()
	game.desktop.refresh()
	check(keyboard.position.is_equal_approx(original_position), "refresh preserves editor-authored 3D device placement")
	game.desktop.select_device("keyboard", false)
	game.desktop.set_screen_focused(false, false)
	check(keyboard.position.is_equal_approx(original_position), "inspection restores editor-authored 3D placement")
	var client = load("res://scenes/store.tscn").instantiate()
	client.get_node("%ClientHeader").custom_minimum_size.y = 120
	var original_home: Node = client.get_node("%PageContent").get_child(0)
	root.add_child(client)
	client.download_timer.stop()
	check(client.get_node("%PageContent").get_child(0) == original_home, "initial page uses authored scene instance")
	client.refresh_client()
	check(client.get_node("%PageContent").get_child(0) == original_home, "data refresh keeps static page nodes")
	check(client.get_node("%ClientHeader").custom_minimum_size.y == 120, "runtime preserves inspector layout changes")
	var constructors := RegEx.new()
	constructors.compile("\\b(?:Button|Label|ColorRect)\\.new\\(")
	for script in ["client.gd", "client_pages.gd", "client_ui.gd", "life/game_root.gd", "life/computer_desktop.gd"]:
		var source := FileAccess.get_file_as_string("res://scripts/" + script)
		check(not source.contains("func _draw") and constructors.search(source) == null, "no procedural layout: " + script)
	client.queue_free()
	game.queue_free()
	await process_frame
	print("EDITOR_SCENE_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
