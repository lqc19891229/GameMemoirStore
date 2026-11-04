class_name MemoirFurnitureFinishes
extends RefCounted
## Stable finish indices for shop preview and room instances. Never reorder existing entries.
const LABELS := ["原色", "奶油白", "鼠尾草绿", "雾蓝", "暖粉", "浅橡木", "深胡桃木", "石墨黑", "陶土橙", "樱桃木", "浅灰", "海军蓝", "森林绿", "薰衣草紫", "黄铜金", "珊瑚红"]
const HEX := ["", "eae1d4", "a4bdac", "9fbed3", "d9b3b5", "d6b184", "76604e", "454a51", "bc8569", "a36d51", "bbc2c4", "455b80", "52765a", "ad9cc3", "c7a765", "d77b6b"]
const ALPHA := [0.0, .32, .32, .32, .32, .32, .40, .43, .34, .37, .30, .38, .34, .32, .40, .32]
const ROUGHNESS := [.8, .93, .91, .88, .90, .70, .62, .48, .82, .70, .85, .80, .88, .87, .42, .84]
const METALLIC := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, .03, .22, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, .52, 0.0]

static func valid(index: int) -> bool:
	return index >= 0 and index < LABELS.size()

static func overlay(index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if index <= 0 or not valid(index):
		return material
	var color := Color(HEX[index])
	color.a = ALPHA[index]
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = ROUGHNESS[index]
	material.metallic = METALLIC[index]
	return material

static func apply_preview(furniture: Node3D, index: int) -> void:
	if index == 0 or not valid(index):
		return
	var finish := overlay(index)
	for mesh: MeshInstance3D in furniture.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = finish
