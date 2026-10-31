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
func scene_paths(directory: String) -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".tscn"): paths.append(directory.path_join(file))
	for folder in DirAccess.get_directories_at(directory):
		paths.append_array(scene_paths(directory.path_join(folder)))
	return paths
func run() -> void:
	var paths := scene_paths("res://scenes")
	for path in paths:
		var scene: PackedScene = load(path)
		check(scene != null, "scene loads: " + path)
		if scene == null: continue
		var node := scene.instantiate()
		if node is Control and not node is Label and not node is Button:
			check(node.get_child_count() > 0, "visible layout exists before ready: " + path)
		node.free()
	var closeup = load("res://scenes/computer/computer_desktop.tscn").instantiate()
	check(closeup.get_node("Workstation3D") is Node3D, "workspace uses a genuine authored 3D scene")
	check(closeup is Node3D, "ComputerDesktop opens directly in the 3D editor")
	check(not closeup.has_node("WorldView") and closeup.get_node("HUD") is CanvasLayer, "3D content is native; only HUD uses a canvas layer")
	check(closeup.get_child_count() == 3, "workspace separates native 3D world, desktop texture and HUD")
	check(closeup.get_node("Workstation3D/TableGroup/Equipment").get_child_count() == 4, "workspace has four independent 3D device slots")
	for role in ["Monitor", "Computer", "Keyboard", "Mouse"]:
		var device: Node3D = closeup.get_node("Workstation3D/TableGroup/Equipment/" + role)
		check(device.appearance.model is PackedScene and not device.find_children("*", "MeshInstance3D", true, false).is_empty(), "device has saved model geometry before ready: " + role)
	check(closeup.get_node("Workstation3D/Room/Shell").get_child_count() > 0, "complete room shell exists in editor before ready")
	check(closeup.get_node("Workstation3D/Room/Furniture").get_child_count() == 5, "five authored furniture instances exist before ready")
	closeup.free()
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	check(game.get_child_count() == 2, "main scene only contains shared session and desktop")
	check(not game.has_node("PlayerRoom") and not game.has_node("AchievementCabinet"), "legacy room and cabinet screens are not duplicated")
	check(game.get_node("ComputerDesktop").visible, "desktop is visible in the authored main scene")
	check(game.has_node("ComputerDesktop/DesktopViewport/DesktopScreen/ApplicationArea"), "desktop shell exists before running")
	var keyboard: Node3D = game.get_node("ComputerDesktop/Workstation3D/TableGroup/Equipment/Keyboard")
	keyboard.position.x += 0.1
	var original_position := keyboard.position
	root.add_child(game)
	game.session.timer.stop()
	game.desktop.refresh()
	check(keyboard.position.is_equal_approx(original_position), "refresh preserves editor-authored 3D device placement")
	game.desktop.set_screen_focused(true, false)
	game.desktop.set_screen_focused(false, false)
	check(keyboard.position.is_equal_approx(original_position), "screen round trip preserves editor-authored 3D placement")
	var client = load("res://scenes/apps/platform/store.tscn").instantiate()
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
