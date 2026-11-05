@tool
extends EditorPlugin

const MATERIAL_DIR := "res://assets/materials/furniture"

var dock: ScrollContainer
var content: VBoxContainer
var scene_label: Label
var slot_list: ItemList
var preset_list: ItemList
var message_label: Label
var slots: Array[Dictionary] = []
var presets: Array[String] = []


func _enter_tree() -> void:
	# Keep the dock's minimum height at zero. Two tall ItemLists previously
	# propagated their minimum sizes to the editor dock; on a short window
	# this can hide the bottom panel and other editor docks entirely.
	dock = ScrollContainer.new()
	dock.name = "Furniture Materials"
	dock.custom_minimum_size = Vector2(270, 0)
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(content)

	var heading := Label.new()
	heading.text = "Furniture Material Library"
	content.add_child(heading)

	scene_label = Label.new()
	scene_label.text = "Open a furniture scene (.tscn)"
	content.add_child(scene_label)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh)
	content.add_child(refresh_button)

	var slot_heading := Label.new()
	slot_heading.text = "1. Mesh / surface"
	content.add_child(slot_heading)

	slot_list = ItemList.new()
	slot_list.custom_minimum_size.y = 180
	slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(slot_list)

	var preset_heading := Label.new()
	preset_heading.text = "2. Shared material"
	content.add_child(preset_heading)

	preset_list = ItemList.new()
	preset_list.custom_minimum_size.y = 190
	preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(preset_list)

	var apply_button := Button.new()
	apply_button.text = "Apply surface override"
	apply_button.pressed.connect(_apply_override)
	content.add_child(apply_button)

	var clear_button := Button.new()
	clear_button.text = "Clear surface override"
	clear_button.pressed.connect(_clear_override)
	content.add_child(clear_button)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.text = "For GLB instances, enable Editable Children, then save the .tscn (Ctrl+S)."
	content.add_child(message_label)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	_refresh.call_deferred()


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()
	dock = null
	content = null


func _refresh() -> void:
	_refresh_slots()
	_refresh_presets()


func _refresh_slots() -> void:
	var selected_key := ""
	var selected := slot_list.get_selected_items()
	if not selected.is_empty() and selected[0] < slots.size():
		selected_key = str(slots[selected[0]]["key"])

	slot_list.clear()
	slots.clear()
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		scene_label.text = "Open a furniture scene (.tscn)"
		return
	scene_label.text = "Scene: " + root.name
	_collect_slots(root, root)
	for i in range(slots.size()):
		var slot := slots[i]
		var mesh := slot["node"] as MeshInstance3D
		var index: int = slot["surface"]
		var marker := "* " if mesh.get_surface_override_material(index) != null else "  "
		slot_list.add_item(marker + str(slot["label"]))
		if slot["key"] == selected_key:
			slot_list.select(i)
	if slots.is_empty():
		_set_message("No mesh surfaces found. Enable Editable Children on imported GLB instances.")


func _collect_slots(node: Node, root: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for index in range(mesh_instance.mesh.get_surface_count()):
				var surface_name: String = mesh_instance.mesh.surface_get_name(index)
				if surface_name.is_empty():
					surface_name = "Surface %d" % index
				var node_path := str(root.get_path_to(node))
				slots.append({
					"node": mesh_instance,
					"surface": index,
					"key": "%s:%d" % [node_path, index],
					"label": "%s / %s [%d]" % [node_path, surface_name, index],
				})
	for child in node.get_children():
		_collect_slots(child, root)


func _refresh_presets() -> void:
	preset_list.clear()
	presets.clear()
	_scan_directory(MATERIAL_DIR)
	presets.sort()
	for path in presets:
		preset_list.add_item(path.trim_prefix(MATERIAL_DIR + "/").trim_suffix(".tres"))
	if presets.is_empty():
		_set_message("No .tres resources found under " + MATERIAL_DIR)


func _scan_directory(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := folder.path_join(entry)
			if dir.current_is_dir():
				_scan_directory(path)
			elif entry.ends_with(".tres"):
				presets.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _selected_slot() -> Dictionary:
	var selected := slot_list.get_selected_items()
	if selected.is_empty() or selected[0] >= slots.size():
		_set_message("Select a mesh surface first.")
		return {}
	var slot := slots[selected[0]]
	if not is_instance_valid(slot["node"]):
		_set_message("Scene changed. Click Refresh.")
		return {}
	return slot


func _apply_override() -> void:
	var slot := _selected_slot()
	if slot.is_empty():
		return
	var selected := preset_list.get_selected_items()
	if selected.is_empty() or selected[0] >= presets.size():
		_set_message("Select a shared material first.")
		return
	var material := load(presets[selected[0]]) as Material
	if material == null:
		_set_message("Cannot load selected material.")
		return
	var mesh := slot["node"] as MeshInstance3D
	var index: int = slot["surface"]
	var previous := mesh.get_surface_override_material(index)
	var history := get_undo_redo()
	history.create_action("Apply shared furniture material")
	history.add_do_method(mesh, "set_surface_override_material", index, material)
	history.add_undo_method(mesh, "set_surface_override_material", index, previous)
	history.commit_action()
	_set_message("Applied %s. Save the .tscn (Ctrl+S)." % material.resource_path.get_file())
	_refresh_slots()


func _clear_override() -> void:
	var slot := _selected_slot()
	if slot.is_empty():
		return
	var mesh := slot["node"] as MeshInstance3D
	var index: int = slot["surface"]
	var previous := mesh.get_surface_override_material(index)
	if previous == null:
		_set_message("Surface has no override.")
		return
	var history := get_undo_redo()
	history.create_action("Clear shared furniture material")
	history.add_do_method(mesh, "set_surface_override_material", index, null)
	history.add_undo_method(mesh, "set_surface_override_material", index, previous)
	history.commit_action()
	_set_message("Surface override cleared. Save the .tscn (Ctrl+S).")
	_refresh_slots()


func _set_message(message: String) -> void:
	message_label.text = message
