extends SceneTree
## Graphical Xvfb regression for actual screen-space contextual buttons.
## Headless Godot uses a tiny 64x64 window with a 0.05 content scale and
## cannot meaningfully hit-test GUI located at 1280x800 logical pixels.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func frames(n: int = 3) -> void:
	for i in range(n): await process_frame

func click(control: Control) -> void:
	var pos: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	root.push_input(move,true)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down,true)
	await process_frame
	down.pressed = false
	root.push_input(down,true)
	await frames()

func run() -> void:
	var scale_x: float = root.get_final_transform().x.length()
	check(scale_x >= 0.6, "graphical viewport uses full-size GUI hit testing rather than the 64px headless fallback")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	desktop.begin_layout()
	var layout = desktop.world.layout
	var ui = desktop.room_ui
	var actions = ui.scene_actions
	layout.select("chair")
	await frames(3)
	check(actions.action_strip.is_visible_in_tree(), "selected furniture has a visible compact context ribbon")
	check(not desktop.get_node("%LayoutPanel").is_visible_in_tree(), "right inspector does not block the primary 3D pointer target")
	var paint: Button = actions.action_buttons["paint"]
	check(paint.get_global_rect().has_point(paint.get_global_rect().get_center()), "color button has a valid screen-space input rectangle")
	await click(paint)
	check(actions.swatches.is_visible_in_tree(), "real mouse click on object-side color button opens palette")
	if actions.swatches.is_visible_in_tree():
		await click(actions.color_buttons[2])
	check(layout.color_for("chair") == 2, "real mouse click on palette swatch recolors selected furniture")
	check(not actions.swatches.visible, "palette closes after real color selection")
	await click(actions.action_buttons["rotate"])
	check(layout.tool == "rotate", "real mouse click on rotation shortcut switches existing gizmo")
	await click(actions.action_buttons["move"])
	check(layout.tool == "move", "real mouse click on movement shortcut restores existing gizmo")
	desktop.finish_layout(false)
	check(not actions.action_strip.is_visible_in_tree(), "context buttons are hidden again outside editor")
	check(not game.session.state.life.furniture_colors.has("starter_chair"), "GUI selection and swatches remain draft-only until room is saved")
	game.queue_free()
	await frames()
	print("ROOM_SCENE_POINTER_CHECKS: %d / %d passed" % [checks - failures,checks])
	quit(1 if failures else 0)
