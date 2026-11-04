extends SceneTree
## Drag handle geometry and the editor preview's staged editing handshake.
const Drag = preload("res://addons/furniture_manager/support_surface_drag.gd")
const Manager = preload("res://addons/furniture_manager/furniture_manager_panel.gd")
const Surfaces = preload("res://scripts/room/furniture_support_surfaces.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original := {"id": "test", "center": Vector3(0, 0.8, 0), "size": Vector2(1.0, 0.4)}
	var moved: Dictionary = Drag.changed_anchor(original, "move", Vector2(0.25, -0.12))
	_check(moved.center == Vector3(0.25, 0.8, -0.12), "drag center updates XZ without changing shelf height")
	_check(moved.size == Vector2(1, 0.4), "moving does not resize")
	var right: Dictionary = Drag.changed_anchor(original, "right", Vector2(0.2, 0))
	_check(is_equal_approx(right.size.x, 1.2), "right handle changes width")
	_check(is_equal_approx(right.center.x, 0.1), "right handle keeps left edge fixed")
	var left: Dictionary = Drag.changed_anchor(original, "left", Vector2(0.2, 0))
	_check(is_equal_approx(left.size.x, 0.8), "left handle changes width")
	_check(is_equal_approx(left.center.x, 0.1), "left handle keeps right edge fixed")
	var far: Dictionary = Drag.changed_anchor(original, "far", Vector2(0, 0.16))
	_check(is_equal_approx(far.size.y, 0.56) and is_equal_approx(far.center.z, 0.08), "far handle changes depth with opposite edge fixed")
	var near: Dictionary = Drag.changed_anchor(original, "near", Vector2(0, 0.10))
	_check(is_equal_approx(near.size.y, 0.30) and is_equal_approx(near.center.z, 0.05), "near handle changes depth with opposite edge fixed")
	var minimum: Dictionary = Drag.changed_anchor(original, "right", Vector2(-10, 0))
	_check(minimum.size.x >= Drag.MIN_SIZE - 0.0001, "drag cannot invert rectangle or shrink below 2cm")
	_check(Surfaces.clean_anchor(minimum) != {}, "resized surface remains valid")
	_check(original.center == Vector3(0, 0.8, 0), "source anchor remains unchanged")

	var panel := Manager.new()
	root.add_child(panel)
	await process_frame
	var bookcase := panel.catalog.lookup("room_bookcase")
	_check(bookcase != null, "bookcase is available in catalog")
	if bookcase != null:
		panel.selected_item = bookcase
		panel._update_details()
		_check(panel.preview.edit_surfaces, "selected editable furniture enables 3D handles")
		_check(panel.preview.support_anchors.size() == 4, "legacy bookcase has 4 default shelves")
		panel.preview.size = Vector2(360, 220)
		await process_frame
		var index := 3
		var point: Vector2 = panel.preview.anchor_handle_screen_position(index, "move")
		var picked: Dictionary = panel.preview._pick_anchor_handle(point)
		_check(not picked.is_empty(), "projected center handle is pickable")
		var pressed := InputEventMouseButton.new()
		pressed.button_index = MOUSE_BUTTON_LEFT
		pressed.position = point
		pressed.pressed = true
		panel.preview._gui_input(pressed)
		_check(panel.preview.drag_index >= 0, "mouse down starts a drag")
		var before: Dictionary = panel.surface_editor.anchors[index].duplicate(true)
		var moved_event := InputEventMouseMotion.new()
		moved_event.position = point + Vector2(24, 0)
		panel.preview._gui_input(moved_event)
		_check(panel.surface_editor.anchors[index] != before, "viewport drag updates staged anchor")
		_check(panel.surface_editor.anchors[index] == panel.preview.support_anchors[index], "list and preview remain synchronized")
		_check(panel.surface_editor.list.get_selected_items()[0] == index, "3D selection synchronizes list")
		var released := InputEventMouseButton.new()
		released.button_index = MOUSE_BUTTON_LEFT
		released.position = moved_event.position
		released.pressed = false
		panel.preview._gui_input(released)
		_check(panel.preview.drag_index == -1, "mouse release ends drag")
		var untouched := bookcase.furniture_scene.instantiate() as Node3D
		root.add_child(untouched)
		await process_frame
		_check(Surfaces.anchors_for(untouched).size() == 4, "dragging preview does not mutate actual scene")
		untouched.queue_free()
	panel.queue_free()
	await process_frame
	print("FURNITURE_DRAG_HANDLES_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
