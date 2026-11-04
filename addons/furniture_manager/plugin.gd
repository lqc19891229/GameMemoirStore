@tool
extends EditorPlugin

const FurnitureManagerPanel = preload("res://addons/furniture_manager/furniture_manager_panel.gd")
const FurnitureImportPanel = preload("res://addons/furniture_manager/furniture_import_panel.gd")
var panel: Control
var import_panel: Control


func _enter_tree() -> void:
	panel = FurnitureManagerPanel.new()
	panel.name = "家具资源"
	add_control_to_bottom_panel(panel, "家具资源")
	import_panel = FurnitureImportPanel.new()
	import_panel.name = "家具导入"
	add_control_to_bottom_panel(import_panel, "家具导入")
	import_panel.scenes_created.connect(func(_paths: PackedStringArray) -> void:
		if panel != null:
			panel.refresh_catalog()
	)


func _exit_tree() -> void:
	if import_panel != null:
		remove_control_from_bottom_panel(import_panel)
		import_panel.queue_free()
		import_panel = null
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
