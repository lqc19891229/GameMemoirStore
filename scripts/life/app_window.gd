class_name MemoirAppWindow
extends PanelContainer
signal close_requested
signal minimize_requested
const U = preload("res://scripts/client_ui.gd")
var content: Control
var body: MarginContainer
var window_title := "应用"
var dragging := false
var drag_origin := Vector2.ZERO

func _ready() -> void:
	add_theme_stylebox_override("panel", U.style("182735", "668494", 2, 0))
	var box := U.vbox(self, 0)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var header := U.hbox(U.panel(box, "253d4d", 4), 6)
	header.get_parent().custom_minimum_size.y = 32
	var title := U.label(header, "  " + window_title, 12, Color("d9e9eb"))
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_drag)
	U.button(header, "—", func() -> void: minimize_requested.emit(), "flat", 36)
	U.button(header, "□", fit, "flat", 36)
	U.button(header, "×", func() -> void: close_requested.emit(), "danger", 36)
	body = U.margin(box, 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: move_to_front()
	)
	fit.call_deferred()

func mount(app: Control) -> void:
	content = app
	body.add_child(app)
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.size_flags_vertical = Control.SIZE_EXPAND_FILL

func fit() -> void:
	if is_instance_valid(get_parent()):
		position = Vector2.ZERO
		size = get_parent().size

func _drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_origin = get_global_mouse_position() - global_position
		move_to_front()
	elif event is InputEventMouseMotion and dragging:
		var target := get_global_mouse_position() - drag_origin
		global_position = Vector2(clampf(target.x, -size.x + 180, get_viewport_rect().size.x - 180), clampf(target.y, 0, get_viewport_rect().size.y - 100))
