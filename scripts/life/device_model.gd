@tool
class_name MemoirDeviceModel
extends Resource
@export var model: PackedScene:
	set(value):
		model = value
		emit_changed()
@export var bounds := Vector3.ONE:
	set(value):
		bounds = value
		emit_changed()
@export var screen_size := Vector2.ZERO:
	set(value):
		screen_size = value
		emit_changed()
@export var screen_position := Vector3.ZERO:
	set(value):
		screen_position = value
		emit_changed()
