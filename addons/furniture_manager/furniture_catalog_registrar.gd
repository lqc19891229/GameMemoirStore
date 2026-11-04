@tool
extends RefCounted
## Explicit, single-item registration into the one authoritative catalog.
const CATALOG_PATH := "res://data/items/_catalog.tres"
const SCENE_ROOT := "res://scenes/room/"
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")

static func list_unregistered_scenes() -> PackedStringArray:
	var output := PackedStringArray()
	var catalog := ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirItemCatalog
	if catalog == null:
		return output
	var registered := {}
	for item in catalog.items:
		if item != null and item.furniture_scene != null:
			registered[item.furniture_scene.resource_path] = true
	_collect_scenes(SCENE_ROOT, registered, output)
	output.sort()
	return output


static func _collect_scenes(folder_path: String, registered: Dictionary, output: PackedStringArray) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := folder_path.path_join(entry)
			if dir.current_is_dir():
				_collect_scenes(path, registered, output)
			elif entry.ends_with(".tscn") and not registered.has(path):
				output.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func validate_registration(scene_path: String, fields: Dictionary, catalog: MemoirItemCatalog = null) -> PackedStringArray:
	var errors := PackedStringArray()
	var id := str(fields.get("item_id", "")).strip_edges()
	var display_name := str(fields.get("name", "")).strip_edges()
	var role := str(fields.get("role", "")).strip_edges()
	var group := str(fields.get("group", "")).strip_edges()
	var kind := str(fields.get("type", "")).strip_edges()
	var price: Variant = fields.get("price", -1)
	if id.is_empty() or not id.is_valid_identifier():
		errors.append("商品 ID 只能使用非空的字母、数字和下划线，且不能以数字开头")
	if display_name.is_empty():
		errors.append("需要商品名称")
	if role.is_empty() or not role.is_valid_identifier() or role.contains("__instance__"):
		errors.append("摆放角色必须为有效标识符，不能包含保留的 __instance__ 标记")
	if group.is_empty() or group == "hardware" or not Taxonomy.valid_group(group):
		errors.append("需要有效的家具一级分类")
	if kind.is_empty() or not Taxonomy.TYPES.has(kind):
		errors.append("需要有效的二级分类")
	if not (price is int or price is float) or price < 0 or price > 10000000:
		errors.append("价格必须在 0 至 10000000 之间")
	if not scene_path.begins_with(SCENE_ROOT) or scene_path.contains("..") or not scene_path.ends_with(".tscn"):
		errors.append("只能注册 scenes/room/ 内的独立家具场景")
	elif not ResourceLoader.exists(scene_path):
		errors.append("家具场景不存在")
	else:
		var scene := ResourceLoader.load(scene_path) as PackedScene
		if scene == null:
			errors.append("家具场景不是 PackedScene")
		else:
			var instance := scene.instantiate()
			if not instance is Node3D or not instance.get("bounds") is Vector3 or not instance.get("role") is String:
				errors.append("场景必须是包含 bounds 和 role 的家具根节点")
			else:
				var bounds: Variant = instance.get("bounds")
				if not bounds is Vector3 or bounds.x <= 0 or bounds.y <= 0 or bounds.z <= 0:
					errors.append("家具摆放边界无效")
				var scene_role := str(instance.get("role")).strip_edges()
				if not role.is_empty() and scene_role != role:
					errors.append("商品摆放角色必须与家具场景根节点的 role 一致")
			instance.free()
	if catalog == null:
		catalog = ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirItemCatalog
	if catalog == null:
		errors.append("无法读取唯一商品目录")
	else:
		for item in catalog.items:
			if item == null:
				continue
			if item.item_id == id:
				errors.append("商品 ID 已存在，禁止覆盖")
			if item.category == "furniture" and item.subcategory == role and not role.is_empty():
				errors.append("摆放角色已被其他家具商品占用")
			if item.furniture_scene != null and item.furniture_scene.resource_path == scene_path:
				errors.append("场景已被商品引用，禁止重复注册")
	return errors


static func register(scene_path: String, fields: Dictionary, confirmed: bool = false) -> Dictionary:
	if not confirmed:
		return {"ok": false, "error": "请先审核场景并明确确认注册"}
	var catalog := ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirItemCatalog
	var errors := validate_registration(scene_path, fields, catalog)
	if not errors.is_empty():
		return {"ok": false, "error": "；".join(errors)}
	var scene := ResourceLoader.load(scene_path) as PackedScene
	var item := MemoirItemDefinition.new()
	item.item_id = str(fields.item_id).strip_edges()
	item.name = str(fields.name).strip_edges()
	item.category = "furniture"
	item.subcategory = str(fields.role).strip_edges()
	item.catalog_group = str(fields.group).strip_edges()
	item.catalog_type = str(fields.type).strip_edges()
	item.price = int(fields.price)
	item.description = str(fields.get("description", "")).strip_edges()
	item.placement_surface = "floor"
	item.furniture_scene = scene
	# Serialize a candidate on the same filesystem. Never truncate the live
	# catalog: a failed rename must leave its original bytes intact.
	var pending := "res:" + "//data/items/__furniture_catalog_pending__.tres"
	if FileAccess.file_exists(pending):
		return {"ok": false, "error": "发现未清理的候选目录文件，请人工检查"}
	var original := FileAccess.get_file_as_bytes(CATALOG_PATH)
	if original.is_empty():
		return {"ok": false, "error": "读取原商品目录失败"}
	catalog.items.append(item)
	var save_err := ResourceSaver.save(catalog, pending)
	if save_err != OK:
		_cleanup_pending(pending)
		return {"ok": false, "error": "候选商品目录保存失败 (%d)" % save_err}
	# Ensure the serialized candidate can actually be loaded before replacing
	# the authoritative resource.
	var candidate := ResourceLoader.load(pending, "", ResourceLoader.CACHE_MODE_IGNORE) as MemoirItemCatalog
	if candidate == null or candidate.lookup(item.item_id) == null or candidate.items.size() != catalog.items.size():
		_cleanup_pending(pending)
		return {"ok": false, "error": "候选目录校验失败，原目录未修改"}
	var replacement := FileAccess.get_file_as_bytes(pending)
	if replacement.is_empty():
		_cleanup_pending(pending)
		return {"ok": false, "error": "候选文件无内容，原目录未修改"}
	# A concurrent editor/user edit must not be lost between read and commit.
	if not catalog_matches_snapshot(original):
		_cleanup_pending(pending)
		return {"ok": false, "error": "商品目录已被其他操作修改，请刷新后重试"}
	# Use an individually named immutable snapshot, rather than overwriting
	# the previous registration backup.
	var backup_path := "user://furniture_catalog_backup_%d_%d.tres" % [
		int(Time.get_unix_time_from_system()), Time.get_ticks_usec()
	]
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		_cleanup_pending(pending)
		return {"ok": false, "error": "无法创建备份，原目录未修改"}
	backup.store_buffer(original)
	backup.flush()
	var backup_error := backup.get_error()
	backup.close()
	if backup_error != OK or FileAccess.get_file_as_bytes(backup_path) != original:
		_cleanup_pending(pending)
		return {"ok": false, "error": "备份校验失败，原目录未修改"}
	if not catalog_matches_snapshot(original):
		_cleanup_pending(pending)
		return {"ok": false, "error": "备份期间商品目录发生变化，原目录未修改"}
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(pending),
		ProjectSettings.globalize_path(CATALOG_PATH)
	)
	if rename_error != OK:
		_cleanup_pending(pending)
		return {"ok": false, "error": "安全替换目录失败 (%d)；原目录未主动截断。备份：%s" % [rename_error, backup_path]}
	ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	return {"ok": true, "item_id": item.item_id, "backup": backup_path}


static func catalog_matches_snapshot(expected: PackedByteArray) -> bool:
	return not expected.is_empty() and FileAccess.get_file_as_bytes(CATALOG_PATH) == expected


static func _cleanup_pending(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
