@tool
extends EditorPlugin

const FurnitureManagerPanel = preload("res://addons/furniture_manager/furniture_manager_panel.gd")
const FurnitureImportPanel = preload("res://addons/furniture_manager/furniture_import_panel.gd")
const FurnitureRegistrationPanel = preload("res://addons/furniture_manager/furniture_registration_panel.gd")
var panel: Control
var import_panel: Control
var registration_panel: Control


func _enter_tree() -> void:
	panel = FurnitureManagerPanel.new()
	panel.name = "家具资源"
	add_control_to_bottom_panel(panel, "家具资源")
	import_panel = FurnitureImportPanel.new()
	import_panel.name = "家具导入"
	add_control_to_bottom_panel(import_panel, "家具导入")
	registration_panel = FurnitureRegistrationPanel.new()
	registration_panel.name = "家具注册"
	add_control_to_bottom_panel(registration_panel, "家具注册")
	import_panel.scenes_created.connect(func(_paths: PackedStringArray) -> void:
		if panel != null:
			panel.refresh_catalog()
		if registration_panel != null:
			registration_panel.refresh_scenes()
	)
	registration_panel.catalog_changed.connect(func() -> void:
		if panel != null:
			panel.refresh_catalog()
	)


func _exit_tree() -> void:
	if registration_panel != null:
		remove_control_from_bottom_panel(registration_panel)
		registration_panel.queue_free()
		registration_panel = null
	if import_panel != null:
		remove_control_from_bottom_panel(import_panel)
		import_panel.queue_free()
		import_panel = null
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
