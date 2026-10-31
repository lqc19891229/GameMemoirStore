extends SubViewportContainer
var input_enabled := false
## Godot supplies pointer positions in this container's LOCAL coordinates.
## Use the event position so screen hit testing also works with synthetic input.
func _propagate_input_event(event: InputEvent) -> bool:
	if not input_enabled or not is_visible_in_tree(): return false
	if event is InputEventMouseButton:
		return not event.pressed or Rect2(Vector2.ZERO, size).has_point(event.position)
	if event is InputEventMouseMotion:
		return Rect2(Vector2.ZERO, size).has_point(event.position) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return true
