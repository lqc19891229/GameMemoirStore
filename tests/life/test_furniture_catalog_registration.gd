extends SceneTree
## Non-destructive catalog registration checks (never writes the real catalog).
const Registrar = preload("res://addons/furniture_manager/furniture_catalog_registrar.gd")
const RegistrationPanel = preload("res://addons/furniture_manager/furniture_registration_panel.gd")
const SCENE := "res://scenes/room/tables/side_table_oak.tscn"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fields := {
		"item_id": "test_furniture_approval", "name": "审核测试家具",
		"role": "side_table", "group": "tables", "type": "side_table",
		"price": 100, "description": "仅用于校验"
	}
	var empty_catalog := MemoirItemCatalog.new()
	_check(Registrar.validate_registration(SCENE, fields, empty_catalog).is_empty(), "complete reviewed furniture metadata passes")
	var missing_id := fields.duplicate()
	missing_id.item_id = ""
	_check(not Registrar.validate_registration(SCENE, missing_id, empty_catalog).is_empty(), "reject missing item ID")
	var wrong_group := fields.duplicate()
	wrong_group.group = "hardware"
	_check(not Registrar.validate_registration(SCENE, wrong_group, empty_catalog).is_empty(), "reject non-furniture group")
	var wrong_role := fields.duplicate()
	wrong_role.role = ""
	_check(not Registrar.validate_registration(SCENE, wrong_role, empty_catalog).is_empty(), "reject missing placement role")
	var duplicate := MemoirItemDefinition.new()
	duplicate.item_id = fields.item_id
	duplicate.furniture_scene = load(SCENE)
	empty_catalog.items.append(duplicate)
	_check(not Registrar.validate_registration(SCENE, fields, empty_catalog).is_empty(), "reject duplicate ID and reused scene")
	_check(not Registrar.validate_registration("res://data/items/_catalog.tres", fields, empty_catalog).is_empty(), "reject catalog file as furniture scene")
	_check(not Registrar.validate_registration("res:" + "//scenes/room/../room/side_table_oak.tscn", fields, empty_catalog).is_empty(), "reject path traversal")
	_check(not Registrar.register(SCENE, fields, false).get("ok", false), "registration requires explicit confirmation")
	var original_bytes := FileAccess.get_file_as_bytes(Registrar.CATALOG_PATH)
	_check(not original_bytes.is_empty(), "existing authoritative catalog has bytes")
	_check(Registrar.catalog_matches_snapshot(original_bytes), "current catalog matches captured snapshot")
	var altered := original_bytes.duplicate()
	if not altered.is_empty():
		altered[0] = (int(altered[0]) + 1) % 256
		_check(not Registrar.catalog_matches_snapshot(altered), "stale or corrupted snapshot is rejected")
	_check(not Registrar.catalog_matches_snapshot(PackedByteArray()), "empty snapshot is rejected")
	var listed := Registrar.list_unregistered_scenes()
	_check(not listed.has(SCENE), "existing catalog scene never appears as unregistered")
	var panel := RegistrationPanel.new()
	root.add_child(panel)
	await process_frame
	_check(panel.register_button.disabled, "registration UI defaults to disabled")
	_check(not panel.confirmation.button_pressed, "confirmation defaults off")
	panel.queue_free()
	await process_frame
	print("FURNITURE_CATALOG_REGISTRATION_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
