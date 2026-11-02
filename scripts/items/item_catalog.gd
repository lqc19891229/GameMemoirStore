@tool
class_name MemoirItemCatalog
extends Resource
## Authoritative item membership and metadata, distinct from game sales catalog.
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
@export var items: Array[MemoirItemDefinition] = []

func lookup(item_id: String) -> MemoirItemDefinition:
	for item: MemoirItemDefinition in items:
		if item.item_id == item_id: return item
	return null

func for_sale() -> Array[MemoirItemDefinition]:
	var result: Array[MemoirItemDefinition] = []
	for item: MemoirItemDefinition in items:
		if item.price > 0 and not item.retired: result.append(item)
	return result

func room_furniture() -> Array[MemoirItemDefinition]:
	var result: Array[MemoirItemDefinition] = []
	for item in items:
		if item.category == "furniture" and item.placement_surface == "floor" and item.furniture_scene != null and not item.retired:
			result.append(item)
	return result

func item_for_placement_role(role: String) -> MemoirItemDefinition:
	for item in room_furniture():
		if item.subcategory == role: return item
	return null

func matches_filters(item: MemoirItemDefinition, group: String = "", kind: String = "", query: String = "") -> bool:
	if not group.is_empty() and Taxonomy.group_for(item) != group: return false
	if not kind.is_empty() and Taxonomy.type_for(item) != kind: return false
	var text_value := query.strip_edges().to_lower()
	return text_value.is_empty() or item.name.to_lower().contains(text_value) or item.item_id.to_lower().contains(text_value) or item.description.to_lower().contains(text_value)

func filtered_items(source: Array[MemoirItemDefinition], group: String = "", kind: String = "", query: String = "") -> Array[MemoirItemDefinition]:
	var result: Array[MemoirItemDefinition] = []
	for item in source:
		if matches_filters(item,group,kind,query): result.append(item)
	return result
