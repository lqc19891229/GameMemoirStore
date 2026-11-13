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
		"role": "side_table_oak", "group": "tables", "type": "side_table",
		"price": 100, "description": "仅用于校验"
	}
	var empty_catalog := MemoirItemCatalog.new()
	_check(Registrar.validate_registration(SCENE, fields, empty_catalog).is_empty(), "complete reviewed furniture metadata passes")
	var mountable := fields.duplicate()
	mountable["allow_surface_mount"] = true
	_check(Registrar.validate_registration(SCENE, mountable, empty_catalog).is_empty(), "explicit mountable SKU metadata is valid")
	mountable["allow_surface_mount"] = "yes"
	_check(not Registrar.validate_registration(SCENE, mountable, empty_catalog).is_empty(), "reject non-boolean mountable SKU metadata")
	var missing_id := fields.duplicate()
	missing_id.item_id = ""
	_check(not Registrar.validate_registration(SCENE, missing_id, empty_catalog).is_empty(), "reject missing item ID")
	var wrong_group := fields.duplicate()
	wrong_group.group = "hardware"
	_check(not Registrar.validate_registration(SCENE, wrong_group, empty_catalog).is_empty(), "reject non-furniture group")
	var wrong_role := fields.duplicate()
	wrong_role.role = ""
	_check(not Registrar.validate_registration(SCENE, wrong_role, empty_catalog).is_empty(), "reject missing placement role")
	var mismatched_scene_role := fields.duplicate()
	mismatched_scene_role.role = "unrelated_role"
	_check(not Registrar.validate_registration(SCENE, mismatched_scene_role, empty_catalog).is_empty(), "reject scene root role mismatch")
	var reserved_role := fields.duplicate()
	reserved_role.role = "chair__instance__item_1"
	_check(not Registrar.validate_registration(SCENE, reserved_role, empty_catalog).is_empty(), "reject reserved role separator")
	var role_collision_catalog := MemoirItemCatalog.new()
	var role_collision := MemoirItemDefinition.new()
	role_collision.item_id = "another_furniture_sku"
	role_collision.category = "furniture"
	role_collision.subcategory = "side_table_oak"
	role_collision_catalog.items.append(role_collision)
	var role_errors := Registrar.validate_registration(SCENE, fields, role_collision_catalog)
	_check("摆放角色已被其他家具商品占用" in role_errors, "reject distinct SKU with duplicate placement role")
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
	_check(panel.group_choice.get_item_count() == 5, "only furniture primary categories are registered")
	var table_index := -1
	var seating_index := -1
	for i in range(panel.group_choice.item_count):
	    var group_id := str(panel.group_choice.get_item_metadata(i))
	    if group_id == "tables": table_index = i
	    if group_id == "seating": seating_index = i
	_check(table_index >= 0 and seating_index >= 0, "table and seating primary categories exist")
	if table_index >= 0 and seating_index >= 0:
	    panel.group_choice.select(table_index)
	    panel.group_choice.item_selected.emit(table_index)
	    var table_types := []
	    for i in range(panel.type_choice.item_count):
	        table_types.append(str(panel.type_choice.get_item_metadata(i)))
	    _check("computer_desk" in table_types and not "office_chair" in table_types, "table category only shows table secondary types")
	    panel.group_choice.select(seating_index)
	    panel.group_choice.item_selected.emit(seating_index)
	    var seating_types := []
	    for i in range(panel.type_choice.item_count):
	        seating_types.append(str(panel.type_choice.get_item_metadata(i)))
	    _check("office_chair" in seating_types and not "computer_desk" in seating_types, "seating category excludes table secondary types")
	    _check(panel.type_choice.selected >= 0 and str(panel.type_choice.get_item_metadata(panel.type_choice.selected)) in seating_types, "secondary choice resets to a valid type after primary change")
	    var mismatch := fields.duplicate()
	    mismatch.group = "seating"
	    mismatch.type = "computer_desk"
	    _check("二级分类不属于选定的一级分类" in Registrar.validate_registration(SCENE, mismatch, empty_catalog), "registration rejects cross-category secondary types")

	_check(panel.register_button.disabled, "registration UI defaults to disabled")
	_check(not panel.confirmation.button_pressed, "confirmation defaults off")
	_check(not panel.surface_mount_choice.button_pressed, "surface mounting defaults off for newly registered furniture")
	panel.queue_free()
	await process_frame
	print("FURNITURE_CATALOG_REGISTRATION_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
