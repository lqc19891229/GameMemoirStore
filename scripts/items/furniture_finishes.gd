class_name MemoirFurnitureFinishes
extends RefCounted
## Stable finish indices for shop preview and room instances. Never reorder existing entries.
const LABELS := ["原色", "奶油白", "鼠尾草绿", "雾蓝", "暖粉", "浅橡木", "深胡桃木", "石墨黑", "陶土橙", "樱桃木", "浅灰", "海军蓝", "森林绿", "薰衣草紫", "黄铜金", "珊瑚红"]
const HEX := ["", "eae1d4", "a4bdac", "9fbed3", "d9b3b5", "d6b184", "76604e", "454a51", "bc8569", "a36d51", "bbc2c4", "455b80", "52765a", "ad9cc3", "c7a765", "d77b6b"]
const ALPHA := [0.0, .32, .32, .32, .32, .32, .40, .43, .34, .37, .30, .38, .34, .32, .40, .32]
const ROUGHNESS := [.8, .93, .91, .88, .90, .70, .62, .48, .82, .70, .85, .80, .88, .87, .42, .84]
const METALLIC := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, .03, .22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, .52, 0.0]

# Values 1..15 are original indexed finishes. 0x1000000..0x1FFFFFF
# represent RGB colours without changing the legacy integer save field.
const CUSTOM_COLOR_FLAG := 0x1000000
const CUSTOM_RGB_MAX := 0xFFFFFF

static func from_color(color: Color) -> int:
	return CUSTOM_COLOR_FLAG | (color.to_rgba32() >> 8)

static func is_custom(index: int) -> bool:
	return index >= CUSTOM_COLOR_FLAG and index <= CUSTOM_COLOR_FLAG + CUSTOM_RGB_MAX

static func is_saved_finish(index: int) -> bool:
	return valid(index) or is_custom(index)

static func color_for(index: int) -> Color:
	if is_custom(index):
		return Color.html("#%06x" % (index & CUSTOM_RGB_MAX))
	if valid(index) and index > 0:
		return Color(HEX[index])
	return Color.WHITE

static func valid(index: int) -> bool:
	return index >= 0 and index < LABELS.size()

static func overlay(index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if index <= 0 or not is_saved_finish(index):
		return material
	var color := color_for(index)
	color.a = 0.52 if is_custom(index) else ALPHA[index]
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Packed RGB values are not palette indices; they use neutral material defaults.
	material.roughness = 0.83 if is_custom(index) else ROUGHNESS[index]
	material.metallic = 0.0 if is_custom(index) else METALLIC[index]
	return material

static func apply_preview(furniture: Node3D, index: int) -> void:
	if index == 0 or not valid(index):
		return
	var finish := overlay(index)
	for mesh: MeshInstance3D in furniture.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = finish
