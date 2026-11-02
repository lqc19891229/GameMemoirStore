@tool
class_name MemoirItemCatalog
extends Resource
## Authoritative item membership and metadata, distinct from game sales catalog.
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
