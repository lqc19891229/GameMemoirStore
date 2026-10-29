class_name MemoirClientUI
extends RefCounted
## 原生 Godot UI 工厂；页面由 Container 布局，图像保持最近邻。

const TEXT := Color("c7d5e0")
const MUTED := Color("8f98a0")
const BLUE := Color("66c0f4")
const GREEN := Color("b3d87b")

static func style(bg: String, border: String = "00000000", width: int = 0, padding: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg)
	s.border_color = Color(border)
	s.set_border_width_all(width)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func vbox(parent: Node, gap: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation", gap)
	parent.add_child(node)
	return node

static func hbox(parent: Node, gap: int = 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation", gap)
	parent.add_child(node)
	return node

static func margin(parent: Node, amount: int = 16) -> MarginContainer:
	var node := MarginContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		node.add_theme_constant_override("margin_" + side, amount)
	parent.add_child(node)
	return node

static func panel(parent: Node, bg: String = "16202d", padding: int = 14) -> PanelContainer:
	var node := PanelContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("panel", style(bg, "00000000", 0, padding))
	parent.add_child(node)
	return node

static func label(parent: Node, text: String, font_size: int = 12, tint: Color = TEXT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", tint)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.custom_minimum_size.y = font_size + 10
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, action: Callable = Callable(), kind: String = "normal", minimum_width: int = 0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(minimum_width, 32)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 12)
	var bg := "2a475e"
	var hover := "417a9b"
	var text_color := TEXT
	if kind == "green":
		bg = "5c7e10"
		hover = "7ca51c"
		text_color = Color("d2efa9")
	elif kind == "blue":
		bg = "1a76a8"
		hover = "259ad2"
		text_color = Color.WHITE
	elif kind == "flat":
		bg = "00000000"
		hover = "293f52"
	elif kind == "dark":
		bg = "101923"
		hover = "263d50"
	elif kind == "danger":
		bg = "4a3038"
		hover = "74414c"
	node.add_theme_stylebox_override("normal", style(bg, "00000000", 0, 8))
	node.add_theme_stylebox_override("hover", style(hover, "00000000", 0, 8))
	node.add_theme_stylebox_override("pressed", style("182937", "66c0f4", 1, 7))
	node.add_theme_stylebox_override("disabled", style("202b35", "00000000", 0, 8))
	node.add_theme_stylebox_override("focus", style("00000000", "66c0f4", 1, 0))
	node.add_theme_color_override("font_color", text_color)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_disabled_color", Color("65717d"))
	if action.is_valid():
		node.pressed.connect(action)
	parent.add_child(node)
	return node

static func menu(parent: Node, text: String, entries: Array, action: Callable) -> MenuButton:
	var node := MenuButton.new()
	node.text = text
	node.flat = true
	node.custom_minimum_size.y = 28
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(node)
	var popup := node.get_popup()
	for index: int in range(entries.size()):
		popup.add_item(str(entries[index]), index)
	popup.id_pressed.connect(action)
	return node

static func image(parent: Node, entry: Dictionary, width: int, height: int, shot: int = 0) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(entry, shot)
	node.custom_minimum_size = Vector2(width, height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0 else Control.SIZE_SHRINK_BEGIN
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func screenshot(entry: Dictionary, shot: int = 0) -> Texture2D:
	var shots: Array = entry.get("screenshots", [])
	if not shots.is_empty():
		return shots[clampi(shot, 0, shots.size() - 1)] as Texture2D
	# Older single-cover resources retain their existing gallery crops.
	return texture(entry, shot)

static func texture(entry: Dictionary, shot: int = 0) -> Texture2D:
	var source: Texture2D
	if entry.has("capsule"):
		source = entry["capsule"] as Texture2D
	else:
		source = load("res://assets/art/%s.png" % entry.get("art", "icon")) as Texture2D
	if shot == 0 or source == null:
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var regions := [Rect2(0, 0, 320, 128), Rect2(110, 8, 200, 110), Rect2(12, 25, 230, 100), Rect2(155, 40, 150, 85)]
	var region: Rect2 = regions[clampi(shot, 0, 3)]
	var scale := Vector2(float(source.get_width()) / 320.0, float(source.get_height()) / 128.0)
	atlas.region = Rect2(region.position * scale, region.size * scale)
	return atlas

static func cover(parent: Node, entry: Dictionary, height: int = 260, show_title: bool = true) -> Control:
	var frame := Control.new()
	frame.custom_minimum_size.y = height
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var art := TextureRect.new()
	art.texture = texture(entry)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if show_title:
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.05, 0.09, 0.2)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var title := label(frame, str(entry["title"]), 36, Color("edf5ed"))
		title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		title.offset_left = 24
		title.offset_right = -20
		title.offset_top = -65
		title.offset_bottom = -12
	return frame

static func rule(parent: Node) -> ColorRect:
	var node := ColorRect.new()
	node.color = Color("385065")
	node.custom_minimum_size.y = 1
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func spacer(parent: Node, height: int = 12) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)
	return node

static func spring(parent: Node) -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

static func passive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passive(child)

static func tile(parent: Node, entry: Dictionary, price_text: String, action: Callable) -> Button:
	var root := button(parent, "", action, "dark")
	root.custom_minimum_size = Vector2(0, 178)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	root.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image(inner, entry, 0, 112)
	var bottom := margin(inner, 10)
	var text := vbox(bottom, 4)
	label(text, entry["title"])
	var row := hbox(text)
	label(row, entry["genre"], 12, MUTED)
	var price := label(row, price_text, 12, GREEN)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	passive(root)
	root.tooltip_text = "%s\n%s\n%s · %d%% 好评" % [entry["title"], entry["feature"], entry["rating"], entry["review_percent"]]
	return root

static func option(parent: Node, choices: Array, selected: int, action: Callable) -> OptionButton:
	var node := OptionButton.new()
	for choice: Variant in choices:
		node.add_item(str(choice))
	node.select(selected)
	node.custom_minimum_size.y = 32
	node.item_selected.connect(action)
	parent.add_child(node)
	return node

static func progress(parent: Node, value: float) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size = Vector2(0, 14)
	node.show_percentage = false
	node.value = value
	node.add_theme_stylebox_override("background", style("101923", "00000000", 0, 0))
	node.add_theme_stylebox_override("fill", style("66c0f4", "00000000", 0, 0))
	parent.add_child(node)
	return node
