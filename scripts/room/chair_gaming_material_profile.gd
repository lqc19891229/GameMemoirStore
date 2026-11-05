@tool
extends Node
## Visual baseline for the imported gaming chair. The GLB keeps its mesh nodes
## and geometry; all materials are independent instances of shared PBR presets.
## Runtime inventory UID overrides from FurnitureMaterialSlots always win.
const Slots = preload("res://scripts/items/furniture_material_slots.gd")

const PARTS := {
	"graphite": {"preset": "plastic/plastic_black", "color": "30343a"},
	"gunmetal": {"preset": "metal/metal_black_matte", "color": "61676d"},
	"rubber": {"preset": "rubber/rubber_black", "color": "24282c"},
	"wheel_hub": {"preset": "metal/metal_brushed_steel", "color": "656b70"},
	"steel": {"preset": "metal/metal_brushed_steel", "color": "9da2a6"},
	"dark_shell": {"preset": "plastic/plastic_black", "color": "222a30"},
	"grey_inset": {"preset": "fabric/fabric_gray", "color": "888b8d"},
	"leather_pearl": {"preset": "leather/leather_white", "color": "d4cec4"},
	"leather_cream": {"preset": "leather/leather_white", "color": "e2dcd3"},
	"stitch": {"preset": "fabric/fabric_beige", "color": "b5aaa0"},
	"edge_welt": {"preset": "leather/leather_black", "color": "77797b"},
	"leather_shadow": {"preset": "leather/leather_white", "color": "bbb6b0"}
}

func _ready() -> void:
	apply_profile()


func apply_profile() -> void:
	var furniture := get_parent() as Node3D
	if furniture == null:
		return
	var model := furniture.get_node_or_null("Model") as Node3D
	if model == null:
		return
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not PARTS.has(str(part.name)):
			continue
		var config: Dictionary = PARTS[str(part.name)]
		var material := Slots.build_material(str(config["preset"]), str(config["color"]))
		if material == null:
			push_warning("Gaming chair material missing: " + str(config["preset"]))
			continue
		for surface in range(part.mesh.get_surface_count()):
			part.set_surface_override_material(surface, material)
