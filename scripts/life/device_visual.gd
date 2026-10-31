@tool
class_name MemoirDeviceVisual
extends Resource
## Screen coordinates are normalized to the entire source texture, including alpha padding.
@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
@export var screen_rect := Rect2():
	set(value):
		screen_rect = value
		emit_changed()
