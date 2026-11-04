@tool
extends EditorPlugin

const Panel = preload("res://addons/furniture_manager/furniture_manager_panel.gd")
var panel: Control


func _enter_tree() -> void:
	panel = Panel.new()
	panel.name = "家具资源"
	add_control_to_bottom_panel(panel, "家具资源")


func _exit_tree() -> void:
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
