class_name MemoirAppWindow
extends PanelContainer
signal close_requested
signal minimize_requested
var content: Control
var body: MarginContainer
var window_title := "应用"
var dragging := false
var drag_origin := Vector2.ZERO

func _ready() -> void:
	%WindowTitle.text = "  " + window_title
	%WindowTitle.gui_input.connect(_drag)
	%Minimize.pressed.connect(func() -> void: minimize_requested.emit())
	%Maximize.pressed.connect(fit)
	%Close.pressed.connect(func() -> void: close_requested.emit())
	body = %Body
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
		drag_origin = get_parent().get_local_mouse_position() - position
		move_to_front()
	elif event is InputEventMouseMotion and dragging:
		var bounds: Vector2 = get_parent().size
		var target: Vector2 = get_parent().get_local_mouse_position() - drag_origin
		position = Vector2(clampf(target.x, 0.0, maxf(0.0, bounds.x - size.x)), clampf(target.y, 0.0, maxf(0.0, bounds.y - size.y)))
