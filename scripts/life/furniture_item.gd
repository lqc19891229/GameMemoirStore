extends Button
## 可替换为正式像素贴图的房间交互物件；绘制坐标统一为 100×100。
@export_enum("computer", "desk", "peripheral", "cabinet", "decor") var kind := "computer"
var upgraded := false
var trophy_count := 0
var microphone := false

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func block(rect: Rect2, color: String) -> void:
	draw_rect(rect, Color(color))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(100, 100))
	var wood := "b58159" if upgraded else "775c49"
	match kind:
		"desk":
			block(Rect2(0, 12, 100, 15), "463b35")
			block(Rect2(0, 6, 100, 12), wood)
			block(Rect2(5, 27, 7, 70), "4a423d")
			block(Rect2(86, 27, 8, 70), "4a423d")
			block(Rect2(64, 30, 24, 36), wood)
			block(Rect2(72, 40, 9, 4), "d4b687")
		"computer":
			block(Rect2(3, 3, 67, 64), "263b40")
			block(Rect2(8, 8, 57, 51), "70a4a4" if upgraded else "628b80")
			block(Rect2(12, 12, 49, 43), "223f4c")
			block(Rect2(20, 22, 28, 5), "88bac1")
			block(Rect2(20, 34, 20, 4), "cdce8c")
			block(Rect2(30, 67, 12, 18), "2d3c3c")
			block(Rect2(19, 85, 35, 7), "263b40")
			block(Rect2(77, 25, 22, 70), "2f3a3d")
			for y in [37, 45, 53]: block(Rect2(81, y, 13, 3), "5b7274")
			block(Rect2(86, 77, 5, 5), "a5ce8a")
			if microphone:
				block(Rect2(4, 74, 7, 14), "c3c5aa")
				block(Rect2(6, 88, 3, 8), "434c47")
				block(Rect2(1, 95, 14, 3), "434c47")
		"peripheral":
			block(Rect2(0, 12, 77, 70), "30434a")
			for x in range(7, 70, 12):
				for y in [24, 43, 62]: block(Rect2(x, y, 8, 9), "8b9b89" if not upgraded else "c4ba8e")
			block(Rect2(84, 18, 15, 64), "b8c3a5" if upgraded else "738a83")
		"cabinet":
			block(Rect2(2, 0, 96, 100), "695b4b")
			block(Rect2(10, 7, 80, 85), "324744" if upgraded else "454840")
			for y in [31, 61, 91]: block(Rect2(7, y, 86, 4), "a88b66")
			for i in range(trophy_count):
				var y := 18 + i * 30
				block(Rect2(33, y, 34, 9), "d9b66f")
				block(Rect2(43, y + 7, 14, 7), "ba914c")
				block(Rect2(35, y + 13, 30, 4), "e8cd90")
		"decor":
			block(Rect2(44, 34, 6, 57), "6b6658")
			block(Rect2(27, 90, 40, 6), "494d44")
			block(Rect2(17, 18, 60, 28), "e1b779" if upgraded else "52625b")
			if upgraded: block(Rect2(26, 45, 42, 7), "efd79a")
	if is_hovered() or has_focus(): draw_rect(Rect2(0, 0, 100, 100), Color("efdba8"), false, 1.0)
