class_name MemoirInventoryData
extends RefCounted
## Stable per-object IDs allow multiple identical pieces of furniture.
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
const STARTER_IDS := ["starter_pc", "starter_monitor", "starter_mouse", "starter_desk", "starter_cabinet"]
const ROOM_DEFAULTS := {"chair": "room_chair", "bookcase": "room_bookcase", "lamp": "room_lamp", "rug": "room_rug", "plant": "room_plant", "sofa":"room_sofa", "stool":"room_stool"}
const STARTER_FURNITURE_ROLES := ["chair","bookcase","lamp","rug","plant"]

## ROOM_DEFAULTS is a migration map for authored furniture, not the live catalog.
## New SKUs register a distinct stable subcategory/placement role in the item catalog.
static func furniture_item_id(role: String) -> String:
	var item: MemoirItemDefinition = Catalog.item_for_placement_role(role)
	return item.item_id if item != null else ""

static func is_room_furniture_role(role: String) -> bool:
	return Catalog.item_for_placement_role(role) != null

static func initial() -> Array:
	var result: Array = []
	for id: String in STARTER_IDS:
		result.append({"uid": "legacy_" + id, "item_id": id})
	for role: String in STARTER_FURNITURE_ROLES:
		result.append({"uid": "starter_" + role, "item_id": ROOM_DEFAULTS[role]})
	return result

static func initial_placements() -> Dictionary:
	var result: Dictionary = {}
	for role: String in STARTER_FURNITURE_ROLES:
		result[role] = "starter_" + role
	return result

static func owns(inventory: Array, item_id: String) -> bool:
	for entry: Variant in inventory:
		if entry is Dictionary and entry.get("item_id", "") == item_id: return true
	return false

static func count(inventory: Array, item_id: String) -> int:
	var total := 0
	for entry: Variant in inventory:
		if entry is Dictionary and entry.get("item_id", "") == item_id: total += 1
	return total

## One stock summary shared by shop, inventory and 3D room cards.
## Ignores non-matching IDs and counts each persisted UID only once.
static func stock_summary(inventory: Array, placements: Dictionary, item_id: String) -> Dictionary:
	var owned := 0
	var placed := 0
	var seen: Dictionary = {}
	var placed_uids: Dictionary = {}
	for role: String in placements:
		placed_uids[str(placements[role])] = true
	for entry: Variant in inventory:
		if not entry is Dictionary or str(entry.get("item_id","")) != item_id: continue
		var uid: String = str(entry.get("uid",""))
		if uid.is_empty() or seen.has(uid): continue
		seen[uid] = true
		owned += 1
		if placed_uids.has(uid): placed += 1
	return {"owned":owned,"available":owned-placed,"placed":placed}

static func next_uid(inventory: Array) -> String:
	var used: Dictionary = {}
	for entry: Variant in inventory:
		if entry is Dictionary: used[str(entry.get("uid", ""))] = true
	var number := 1
	while used.has("item_" + str(number)): number += 1
	return "item_" + str(number)

static func clean(raw: Variant, legacy_owned: Array, legacy_layout: Dictionary, raw_placements: Variant = {}) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary: continue
			var uid := str(entry.get("uid", ""))
			var item_id := str(entry.get("item_id", ""))
			if uid.is_empty() or uid.length() > 80 or seen.has(uid) or Catalog.lookup(item_id) == null: continue
			seen[uid] = true
			result.append({"uid": uid, "item_id": item_id})
	for entry: Dictionary in initial():
		if not seen.has(entry.uid) and not owns(result, entry.item_id):
			result.append(entry.duplicate())
			seen[entry.uid] = true
	for raw_id: Variant in legacy_owned:
		var id := str(raw_id)
		if Catalog.lookup(id) == null or owns(result, id): continue
		var uid := "legacy_" + id
		if not seen.has(uid):
			result.append({"uid": uid, "item_id": id})
			seen[uid] = true
	# Pre-v4 saves contain free room copies. Preserve their identities and ownership.
	for role: String in legacy_layout:
		if not LayoutData.is_legacy_copy(role): continue
		if raw_placements is Dictionary and raw_placements.has(role): continue
		var uid := "legacy_" + role
		if seen.has(uid): continue
		result.append({"uid": uid, "item_id": furniture_item_id(LayoutData.base_role(role))})
		seen[uid] = true
	return result

static func _is_furniture_copy(role: String) -> bool:
	return LayoutData.is_copy(role)

static func clean_placements(raw: Variant, inventory: Array, layout: Dictionary) -> Dictionary:
	# Missing field means a pre-v4 save with authored furniture.
	# An explicit empty Dictionary means the player stored every original piece.
	var result: Dictionary = initial_placements() if not raw is Dictionary else {}
	var used: Dictionary = {}
	for uid: String in result.values(): used[uid] = true
	if raw is Dictionary:
		for role: String in raw:
			if not is_room_furniture_role(role) and not _is_furniture_copy(role): continue
			# Every dynamic instance must have a corresponding saved transform.
			if _is_furniture_copy(role) and not layout.has(role): continue
			var uid := str(raw[role])
			if used.has(uid): continue
			if LayoutData.is_instance_role(role) and LayoutData.instance_uid(role) != uid: continue
			for entry: Dictionary in inventory:
				if entry.uid == uid and entry.item_id == furniture_item_id(LayoutData.base_role(role)):
					result[role] = uid
					used[uid] = true
					break
	for role: String in layout:
		# Only old pre-v4 numbered copies can be recovered without a UID map.
		if LayoutData.is_legacy_copy(role) and not result.has(role):
			var uid := "legacy_" + role
			for entry: Dictionary in inventory:
				if entry.uid == uid:
					result[role] = uid
					break
	return result

static func unused_uid(inventory: Array, placements: Dictionary, item_id: String) -> String:
	for entry: Dictionary in inventory:
		if entry.item_id == item_id and not placements.values().has(entry.uid): return entry.uid
	return ""
