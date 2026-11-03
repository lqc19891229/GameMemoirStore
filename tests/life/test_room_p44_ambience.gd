extends SceneTree
## P44: rain ambience is presentation-only, without persistence changes.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	for i in range(5): await process_frame
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var room: MemoirRoomView = game.desktop.world.get_node("Room")
	var original: Dictionary = room.style.duplicate(true)
	check(int(room.style.ambience_volume) == 70, "default ambience volume is backward compatible")
	check(int(MemoirRoomView.clean_style({"ambience_volume":250}).ambience_volume) == 100, "volume is sanitized")
	check(int(MemoirRoomView.clean_style({"ambience_volume":-5}).ambience_volume) == 0, "negative volume is clamped")
	var layout: Dictionary = game.desktop.world.layout.snapshot()
	room.apply_style({"atmosphere":3})
	var rain: Node3D = room.get_node("Shell/Left_Wall/RainStreaks")
	check(rain.visible and rain.get_child_count() >= 10, "rain keeps authored exterior geometry")
	var player := room.get_node_or_null("RainAmbience") as AudioStreamPlayer
	check(player != null and player.stream is AudioStreamWAV, "rain creates local procedural audio")
	if player != null:
		var stream := player.stream as AudioStreamWAV
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.data.size() > 1000, "rain stream is looping PCM")
		check(player.playing and player.volume_db < -15.0, "rain ambience is low-volume and active")
	var first_drop := rain.get_child(0) as Node3D
	var before := first_drop.position.y
	await create_timer(.12).timeout
	check(not is_equal_approx(first_drop.position.y, before), "rain particles move without modifying blueprint")
	for streak: Node3D in rain.get_children():
		var box := (streak as MeshInstance3D).mesh as BoxMesh
		var height: float = box.size.y if box != null else .37
		check(streak.position.y - height * .5 >= 1.31 and streak.position.y + height * .5 <= 2.67, "animated raindrop remains inside window bounds: " + streak.name)
	room.apply_style({"atmosphere":3, "ambience_volume":0})
	check(player != null and not player.playing, "zero volume mutes rain")
	room.apply_style({"atmosphere":3, "ambience_volume":45})
	check(player != null and player.playing and player.volume_db < -30.0, "adjusting volume resumes quieter ambience")
	room.apply_style({"atmosphere":2})
	check(not rain.visible and player != null and not player.playing, "night stops rain audio and hides droplets")
	room.apply_style({"atmosphere":3})
	check(player != null and player.playing, "returning to rain resumes existing audio stream")
	room.apply_style(original)
	check(room.style == original and game.desktop.world.layout.snapshot() == layout, "ambient preview preserves original style and furniture layout")
	game.queue_free()
	for i in range(3): await process_frame
	print("ROOM_P44_AMBIENCE_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
