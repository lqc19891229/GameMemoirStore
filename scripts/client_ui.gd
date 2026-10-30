class_name MemoirClientUI
extends RefCounted
## 图片资源与交互辅助；控件结构全部保存在 scenes/ 下。
const TEXT := Color("c7d5e0")
const MUTED := Color("8f98a0")
const BLUE := Color("66c0f4")
const GREEN := Color("b3d87b")

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

static func passive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passive(child)
