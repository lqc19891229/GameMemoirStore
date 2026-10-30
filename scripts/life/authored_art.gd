@tool
extends Node2D
## Only scales existing authored nodes. Geometry stays in the scene, including in the editor.
@export var reference_size := Vector2(1280, 610)

func _ready() -> void:
	if get_parent() is Control:
		get_parent().resized.connect(_fit)
		_fit()

func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null or reference_size.x <= 0 or reference_size.y <= 0: return
	scale = parent.size / reference_size
