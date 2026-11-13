class_name MemoirItemTaxonomy
extends RefCounted
## Shared navigation for the shop and the room editor. Technical placement
## roles and stable item IDs are deliberately separate from UI categories.
const GROUPS := [
	{"id":"tables","name":"桌类"},
	{"id":"seating","name":"座椅类"},
	{"id":"storage","name":"储物类"},
	{"id":"lighting","name":"灯具类"},
	{"id":"decor","name":"装饰类"},
	{"id":"hardware","name":"电子设备"},
]
const TYPES := {
	"computer_desk":"电脑桌", "side_table":"边桌", "coffee_table":"茶几", "writing_desk":"写字桌", "lounge_chair":"休闲椅", "bench":"长凳",
	"office_chair":"电脑椅", "sofa":"沙发", "stool":"矮凳", "cushion":"坐垫",
	"bookcase":"书架", "shelf":"置物架", "cabinet":"展示柜",
	"floor_lamp":"落地灯", "desk_lamp":"台灯", "ambient_light":"氛围灯",
	"rug":"地毯", "plant":"绿植", "poster":"海报", "ornament":"摆件",
	"monitor":"显示器", "computer":"机箱", "keyboard":"键盘",
	"mouse":"鼠标", "microphone":"麦克风", "audio":"音频设备",
	"misc":"其他"
}
const GROUP_TYPES := {
	"tables": ["computer_desk", "side_table", "coffee_table", "writing_desk", "misc"],
	"seating": ["office_chair", "lounge_chair", "bench", "sofa", "stool", "cushion", "misc"],
	"storage": ["bookcase", "shelf", "cabinet", "misc"],
	"lighting": ["floor_lamp", "desk_lamp", "ambient_light", "misc"],
	"decor": ["rug", "plant", "poster", "ornament", "misc"],
	"hardware": ["monitor", "computer", "keyboard", "mouse", "microphone", "audio", "misc"],
}

static func types_for_group(group: String) -> Array:
	return GROUP_TYPES.get(group, []).duplicate()

static func valid_group_type(group: String, kind: String) -> bool:
	return GROUP_TYPES.has(group) and kind in GROUP_TYPES[group]

const ROLE_GROUPS := {
	"chair":"seating","bookcase":"storage","lamp":"lighting",
	"rug":"decor","plant":"decor","sofa":"seating","stool":"seating"
}
const ROLE_TYPES := {
	"chair":"office_chair","bookcase":"bookcase","lamp":"floor_lamp",
	"rug":"rug","plant":"plant","sofa":"sofa","stool":"stool"
}

static func valid_group(group: String) -> bool:
	if group.is_empty(): return true
	for entry: Dictionary in GROUPS:
		if entry.id == group: return true
	return false

static func group_for(item: Variant) -> String:
	if item == null: return ""
	var value: String = str(item.catalog_group)
	if not value.is_empty() and valid_group(value): return value
	if item.category == "device": return "hardware"
	if item.category == "furniture": return str(ROLE_GROUPS.get(item.subcategory,"decor"))
	return ""

static func type_for(item: Variant) -> String:
	if item == null: return ""
	if TYPES.has(item.catalog_type): return str(item.catalog_type)
	if item.category == "device":
		if item.slot in ["monitor","computer","keyboard","mouse"]: return item.slot
		if item.slot == "peripheral": return "keyboard"
		if item.slot == "audio": return "microphone"
	if item.category == "furniture": return str(ROLE_TYPES.get(item.subcategory,"misc"))
	return "misc"

static func group_name(group: String) -> String:
	for entry: Dictionary in GROUPS:
		if entry.id == group: return str(entry.name)
	return "全部"

static func type_name(kind: String) -> String:
	return str(TYPES.get(kind, "其他"))
