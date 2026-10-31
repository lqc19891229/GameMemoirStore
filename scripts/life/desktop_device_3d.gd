@tool
extends Node3D
@export_enum("monitor", "computer", "keyboard", "mouse") var role := "monitor"
@export var appearance: MemoirDeviceModel:
	set(value):
		if appearance != null and appearance.changed.is_connected(_apply_appearance): appearance.changed.disconnect(_apply_appearance)
		appearance = value
		if appearance != null: appearance.changed.connect(_apply_appearance)
		if is_node_ready(): _apply_appearance()

func _ready() -> void:
	_apply_appearance()

func _apply_appearance() -> void:
	if appearance == null or appearance.model == null: return
	for model: Node3D in $Models.get_children():
		model.visible = model.scene_file_path == appearance.model.resource_path
	var shape: BoxShape3D = $PickArea/CollisionShape3D.shape
	shape.size = appearance.bounds + Vector3(0.04, 0.04, 0.04)
	$PickArea.position.y = appearance.bounds.y / 2.0
	var screen := get_node_or_null("Screen") as MeshInstance3D
	if screen != null:
		screen.position = appearance.screen_position
		(screen.mesh as QuadMesh).size = appearance.screen_size
	var backlight := get_node_or_null("Backlight") as OmniLight3D
	if backlight != null:
		backlight.position = Vector3(appearance.screen_position.x, appearance.screen_position.y, -appearance.bounds.z * 0.5 - 0.05)
