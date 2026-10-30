extends SubViewportContainer
## SubViewportContainer maps real screen clicks to the desktop's logical coordinates.
## Keep input in the visible monitor; forward releases so drags never remain stuck.
func _propagate_input_event(event: InputEvent) -> bool:
	if not is_visible_in_tree(): return false
	if event is InputEventMouseButton:
		return not event.pressed or get_global_rect().has_point(get_global_mouse_position())
	if event is InputEventMouseMotion:
		return get_global_rect().has_point(get_global_mouse_position()) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return true
