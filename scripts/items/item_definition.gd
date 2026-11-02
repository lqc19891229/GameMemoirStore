@tool
class_name MemoirItemDefinition
extends Resource
## A single source of truth for shop, inventory and placement metadata.
@export var item_id := ""
@export var name := ""
@export_enum("furniture", "device", "component", "decoration") var category := "device"
@export var subcategory := ""
@export var slot := ""
@export var price := 0
@export_multiline var description := ""
@export_enum("floor", "desk", "pc_case", "room_style", "none") var placement_surface := "none"
@export var visual_id := ""
@export var speed := 1.0
@export var income := 0
@export var capacity := 0
@export var retired := false
@export var furniture_scene: PackedScene
