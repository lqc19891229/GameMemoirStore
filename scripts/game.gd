class_name GameDefinition
extends Resource
## 单款游戏资源的唯一字段定义；每份 .tres 保存一款游戏的具体值。
## enabled 仅用于 Excel 导出控制，不属于运行时游戏资料。

@export_group("基本资料")
@export var game_id: StringName = &""
@export var title: String = ""
@export var developer: String = ""
@export var genres: PackedStringArray = []
@export var series_id: StringName = &""
@export_multiline var description: String = ""
@export var capsule: Texture2D
## 按 01～04 顺序保存独立展示图；由 Excel 素材文件夹自动解析。
@export var screenshots: Array[Texture2D] = []

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
