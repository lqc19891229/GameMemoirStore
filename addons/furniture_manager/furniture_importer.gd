@tool
extends RefCounted
## Safe, editor-only model-to-scene generation. Never changes the item catalog.
const FURNITURE_SCRIPT = preload("res://scripts/room/room_furniture.gd")
const INPUT_ROOT := "res://assets/models/room/"
const OUTPUT_ROOT := "res://scenes/room/"
const MODEL_EXTENSIONS := [".glb", ".gltf"]
const MIN_DIMENSION := 0.02


static func valid_model_path(path: String) -> bool:
	if not path.begins_with(INPUT_ROOT) or path.contains(".."):
		return false
	var lower := path.to_lower()
	return lower.ends_with(".glb") or lower.ends_with(".gltf")


static func scene_path_for(model_path: String) -> String:
	if not valid_model_path(model_path):
		return ""
	var basename := model_path.get_file().get_basename()
	if not basename.is_valid_filename() or basename.is_empty():
		return ""
	return OUTPUT_ROOT + basename + ".tscn"


static func list_models(directory_path: String) -> PackedStringArray:
	var results := PackedStringArray()
	if not directory_path.begins_with(INPUT_ROOT) and directory_path != INPUT_ROOT.trim_suffix("/"):
		return results
	if directory_path.contains(".."):
		return results
	_scan_recursive(directory_path, results)
	results.sort()
	return results


static func _scan_recursive(path: String, results: PackedStringArray) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		return
	folder.list_dir_begin()
	var name := folder.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child_path := path.path_join(name)
			if folder.current_is_dir():
				_scan_recursive(child_path, results)
			elif valid_model_path(child_path):
				results.append(child_path)
		name = folder.get_next()
	folder.list_dir_end()


static func geometry_bounds(root: Node3D) -> AABB:
	var state := {"found": false, "box": AABB()}
	_collect_geometry(root, Transform3D.IDENTITY, state)
	return state.box if state.found else AABB()


static func _collect_geometry(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box := (node as MeshInstance3D).get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var point := transform * Vector3(x, y, z)
					if not state.found:
						state.box = AABB(point, Vector3.ZERO)
						state.found = true
					else:
						state.box = (state.box as AABB).expand(point)
	for child in node.get_children():
		_collect_geometry(child, transform, state)


static func create_scene(model_path: String, target_path: String = "") -> Dictionary:
	if not valid_model_path(model_path):
		return {"ok": false, "error": "模型必须位于 assets/models/room/ 且为 GLB/GLTF"}
	if not ResourceLoader.exists(model_path):
		return {"ok": false, "error": "模型尚未导入或文件不存在"}
	var expected := scene_path_for(model_path)
	if expected.is_empty():
		return {"ok": false, "error": "无效文件名称"}
	var destination := expected if target_path.is_empty() else target_path
	if not destination.begins_with(OUTPUT_ROOT) or destination.contains("..") or not destination.ends_with(".tscn"):
		return {"ok": false, "error": "输出必须是 scenes/room/ 目录下的 .tscn"}
	if FileAccess.file_exists(destination) or ResourceLoader.exists(destination):
		return {"ok": false, "error": "目标场景已存在，拒绝覆盖：" + destination}
	var model_resource := ResourceLoader.load(model_path) as PackedScene
	if model_resource == null:
		return {"ok": false, "error": "GLB/GLTF 没有导入为 PackedScene"}
	var model_instance := model_resource.instantiate()
	if not model_instance is Node3D:
		model_instance.free()
		return {"ok": false, "error": "模型根节点不是 Node3D"}

	var imported := model_instance as Node3D
	var box := geometry_bounds(imported)
	if box.size.length_squared() < 0.000001:
		model_instance.free()
		return {"ok": false, "error": "没有可测量的 MeshInstance3D"}
	var dimensions := Vector3(
		maxf(box.size.x, MIN_DIMENSION),
		maxf(box.size.y, MIN_DIMENSION),
		maxf(box.size.z, MIN_DIMENSION)
	).snapped(Vector3(0.01, 0.01, 0.01))

	var root := Node3D.new()
	root.name = destination.get_file().get_basename()
	root.set_script(FURNITURE_SCRIPT)
	root.set("role", root.name)
	root.set("bounds", dimensions)
	root.set("blocking", true)

	# Mesh may be exported with an arbitrary origin. Normalize at the model
	# child only; the furniture root stays on the floor at (0, 0, 0).
	model_instance.name = "Model"
	imported.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	root.add_child(model_instance)
	model_instance.owner = root

	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.position = Vector3(0, dimensions.y * 0.5, 0)
	pick_area.collision_layer = 1
	pick_area.collision_mask = 0
	root.add_child(pick_area)
	pick_area.owner = root

	var shape_node := CollisionShape3D.new()
	shape_node.name = "Hit"
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	pick_area.add_child(shape_node)
	shape_node.owner = root

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		root.free()
		return {"ok": false, "error": "生成 PackedScene 失败"}
	var save_result := ResourceSaver.save(packed, destination)
	root.free()
	if save_result != OK:
		return {"ok": false, "error": "保存场景失败，错误码 %d" % save_result}
	return {"ok": true, "path": destination, "bounds": dimensions}
