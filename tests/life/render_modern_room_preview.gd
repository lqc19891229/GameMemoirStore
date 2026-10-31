extends SceneTree

const PREVIEW_FILENAME := "modern-room-preview.png"
const PREVIEW_SIZE := Vector2i(1280, 800)

func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	root.size = PREVIEW_SIZE
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	if packed == null:
		push_error("Could not load game_root.tscn for modern room preview")
		quit(1)
		return

	var game := packed.instantiate()
	root.add_child(game)
	game.session.timer.stop()

	for frame in range(45):
		await process_frame
	await physics_frame
	await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Modern room preview viewport returned an empty image")
		game.queue_free()
		quit(1)
		return

	var workspace := OS.get_environment("GITHUB_WORKSPACE")
	if workspace.is_empty():
		workspace = ProjectSettings.globalize_path("res://")
	var output_path := workspace.path_join(PREVIEW_FILENAME)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save modern room preview: %s" % error_string(error))
		game.queue_free()
		quit(1)
		return

	print("MODERN_ROOM_PREVIEW=%s SIZE=%s" % [output_path, image.get_size()])
	game.queue_free()
	await process_frame
	quit(0)
