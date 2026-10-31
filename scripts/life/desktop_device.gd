@tool
extends Control
signal screen_geometry_changed
@export_enum("monitor", "computer", "keyboard", "mouse") var role := "monitor"
@export var visual: MemoirDeviceVisual:
	set(value):
		if visual != null and visual.changed.is_connected(_apply_visual): visual.changed.disconnect(_apply_visual)
		visual = value
		if visual != null: visual.changed.connect(_apply_visual)
		if is_node_ready(): _apply_visual()

func _ready() -> void:
	resized.connect(_apply_visual)
	_apply_visual()

func _apply_visual() -> void:
	if visual == null or visual.texture == null: return
	$Art.texture = visual.texture
	var screen := get_node_or_null("MonitorScreen") as Control
	if screen == null: return
	var source := visual.texture.get_size()
	var factor := minf(size.x / source.x, size.y / source.y)
	var art_size := source * factor
	var rect := Rect2((size - art_size) / 2.0 + art_size * visual.screen_rect.position, art_size * visual.screen_rect.size)
	screen.position = rect.position
	screen.size = rect.size
	var container := screen.get_node_or_null("ScreenViewport") as SubViewportContainer
	if container != null:
		var viewport := container.get_child(0) as SubViewport
		# Keep full OS resolution; only its display transform follows the screen.
		container.scale = rect.size / Vector2(viewport.size_2d_override)
	screen_geometry_changed.emit()
