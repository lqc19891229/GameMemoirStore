extends SceneTree
## Import tool regression: scanning, non-overwrite, scene creation and cleanup.
const Importer = preload("res://addons/furniture_manager/furniture_importer.gd")
const ImportPanel = preload("res://addons/furniture_manager/furniture_import_panel.gd")
const SOURCE := "res://assets/models/room/catalog/side_table_oak.glb"
const TEMP_SCENE := "res:" + "//scenes/room/__furniture_import_regression__.tscn"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(Importer.valid_model_path(SOURCE), "known source is valid")
	_check(not Importer.valid_model_path("res://data/items/_catalog.tres"), "disallow resources outside model directory")
	_check(not Importer.valid_model_path("res:" + "//assets/models/room/../items/a.glb"), "disallow relative path traversal")
	_check(Importer.scene_path_for(SOURCE) == "res://scenes/room/side_table_oak.tscn", "stable default scene naming")
	_check(Importer.scene_path_for("res:" + "//assets/models/room/a.txt").is_empty(), "reject non-model files")
	var found := Importer.list_models("res://assets/models/room/catalog")
	_check(found.has(SOURCE), "scanner discovers existing catalog models")
	_check(found.size() >= 15, "recursive catalog scan finds existing collection")
	_check(Importer.list_models("res://").is_empty(), "scanner enforces model root")
	var blocked := Importer.create_scene(SOURCE)
	_check(not blocked.ok, "existing furniture scene is not overwritten")
	_check(ResourceLoader.exists(SOURCE), "test source is imported")

	if FileAccess.file_exists(TEMP_SCENE):
		_check(false, "regression destination must not overwrite a pre-existing scene")
	else:
		var result: Dictionary = Importer.create_scene(SOURCE, TEMP_SCENE)
		_check(result.get("ok", false), "generate a new standalone furniture PackedScene")
		if result.get("ok", false):
			_check(FileAccess.file_exists(TEMP_SCENE), "generated scene exists on disk")
			var packed := ResourceLoader.load(TEMP_SCENE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			_check(packed != null, "new scene can be loaded")
			if packed != null:
				var instance := packed.instantiate() as Node3D
				_check(instance != null, "new scene instantiates as Node3D")
				if instance != null:
					_check(instance.has_node("Model"), "original model is instanced as Model")
					_check(instance.has_node("PickArea/Hit"), "pick collision shape is generated")
					var bounds: Vector3 = instance.get("bounds")
					_check(bounds.x > 0.0 and bounds.y > 0.0 and bounds.z > 0.0, "auto bounds are positive")
					var pick := instance.get_node("PickArea/Hit") as CollisionShape3D
					_check(pick.shape is BoxShape3D, "hit shape is BoxShape3D")
					_check(pick.shape.size.is_equal_approx(bounds), "collision matches authored bounds")
					instance.free()
			var second := Importer.create_scene(SOURCE, TEMP_SCENE)
			_check(not second.ok, "re-import never overwrites just-generated scenes")
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SCENE))
			_check(err == OK, "test fixture scene is removed after verification")

	var panel := ImportPanel.new()
	root.add_child(panel)
	await process_frame
	_check(panel.model_list.item_count >= 15, "import UI shows scanned model candidates")
	var model_index := -1
	for i in range(panel.candidate_paths.size()):
		if panel.candidate_paths[i] == SOURCE:
			model_index = i
			break
	_check(model_index >= 0, "known model is visible in import panel")
	if model_index >= 0:
		_check(panel.model_list.is_item_disabled(model_index), "existing scenes are disabled in batch importer")
	panel.queue_free()
	await process_frame
	print("FURNITURE_IMPORT_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
