extends SceneTree
## Headless checks for the editor's scene-backed surface-authoring contract.
const SurfaceHelper = preload("res://scripts/room/furniture_support_surfaces.gd")
const Manager = preload("res://addons/furniture_manager/furniture_manager_panel.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/room/storage/bookcase.tscn")
	var bookcase := scene.instantiate() as Node3D
	root.add_child(bookcase)
	await process_frame
	_check(SurfaceHelper.anchors_for(bookcase).size() == 4, "bookcase loads four authored shelves from its scene")
	var custom: Array[Dictionary] = [
		{"id": "top_custom", "center": Vector3(0, 2.35, 0), "size": Vector2(1.0, 0.38)}
	]
	bookcase.call("apply_custom_support_surfaces", true, custom)
	_check(SurfaceHelper.anchors_for(bookcase).size() == 1, "edited anchors replace authored shelves")
	_check(SurfaceHelper.anchors_for(bookcase)[0].id == "top_custom", "authored ID is preserved")
	_check(bookcase.get("custom_support_surfaces").size() == 1, "edit stored as exported scene property")
	bookcase.call("apply_custom_support_surfaces", true, [])
	_check(SurfaceHelper.anchors_for(bookcase).is_empty(), "explicit empty surfaces disable stacking")
	bookcase.call("apply_custom_support_surfaces", false, [])
	_check(SurfaceHelper.anchors_for(bookcase).is_empty(), "disabled surfaces have no role-generated fallback")
	bookcase.call("apply_custom_support_surfaces", true, custom)
	_check(SurfaceHelper.anchors_for(bookcase).size() == 1, "re-enabling saved anchors restores editable surfaces")
	bookcase.queue_free()

	var panel := Manager.new()
	root.add_child(panel)
	await process_frame
	var selected := panel.catalog.lookup("room_bookcase")
	_check(selected != null and selected.furniture_scene != null, "bookcase is in shared catalog")
	panel.selected_item = selected
	panel._update_details()
	_check(panel.surface_editor.visible, "scene with authored bounds is editable")
	_check(panel.surface_editor.anchors.size() == 4, "editor starts from existing shelf metadata")
	panel.surface_editor.id_input.text = "added_slot"
	panel.surface_editor.center_inputs[0].value = 0
	panel.surface_editor.center_inputs[1].value = 2.35
	panel.surface_editor.center_inputs[2].value = 0
	panel.surface_editor.size_inputs[0].value = 0.8
	panel.surface_editor.size_inputs[1].value = 0.32
	panel.surface_editor._add_anchor()
	_check(panel.surface_editor.anchors.size() == 5, "editor can stage another shelf")
	_check(panel.preview.support_anchors.size() == 5, "preview shows staged placement surface")
	var untouched := selected.furniture_scene.instantiate() as Node3D
	root.add_child(untouched)
	await process_frame
	_check(SurfaceHelper.anchors_for(untouched).size() == 4, "editing preview does not mutate runtime scene")
	untouched.queue_free()

	panel.queue_free()
	await process_frame
	print("FURNITURE_SUPPORT_AUTHORING_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, name: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + name)
