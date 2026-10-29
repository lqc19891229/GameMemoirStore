class_name GameDefinition
extends Resource
## Matches the 13 game fields in the current Excel sheet.
## enabled is an authoring flag and is intentionally not stored here.

@export_group("基本资料")
@export var game_id: StringName = &""
@export var title: String = ""
@export var developer: String = ""
@export var genres: PackedStringArray = []
@export var series_id: StringName = &""
@export_multiline var description: String = ""
@export var capsule: Texture2D

@export_group("时间线")
@export var announce_ym: int = 0
@export var store_release_ym: int = 200309
@export var delist_ym: int = 0

@export_group("价格")
@export var base_price: int = 0

@export_group("硬件配置")
@export var cpu: String = ""
@export var gpu: String = ""

func state_at(ym: int) -> StringName:
	if ym < store_release_ym:
		if announce_ym > 0 and ym >= announce_ym:
			return &"coming_soon"
		return &"hidden"
	if delist_ym > 0 and ym >= delist_ym:
		return &"delisted"
	return &"available"

func is_available(ym: int) -> bool:
	return state_at(ym) == &"available"
