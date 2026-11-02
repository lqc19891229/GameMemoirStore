class_name MemoirInventoryData
extends RefCounted
## Stable per-object IDs allow multiple identical pieces of furniture.
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const STARTER_IDS := ["starter_pc", "starter_monitor", "starter_mouse", "starter_desk", "starter_cabinet"]
const ROOM_DEFAULTS := {"chair": "room_chair", "bookcase": "room_bookcase", "lamp": "room_lamp", "rug": "room_rug", "plant": "room_plant"}

static func initial() -> Array:
	var result: Array = []
	for id: String in STARTER_IDS:
		result.append({"uid": "legacy_" + id, "item_id": id})
	for role: String in ROOM_DEFAULTS:
		result.append({"uid": "starter_" + role, "item_id": ROOM_DEFAULTS[role]})
	return result

static func initial_placements() -> Dictionary:
	var result: Dictionary = {}
	for role: String in ROOM_DEFAULTS:
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
		if not _is_furniture_copy(role): continue
		if raw_placements is Dictionary and raw_placements.has(role): continue
		var uid := "legacy_" + role
		if seen.has(uid): continue
		result.append({"uid": uid, "item_id": ROOM_DEFAULTS[role.get_slice("_", 0)]})
		seen[uid] = true
	return result

static func _is_furniture_copy(role: String) -> bool:
	var parts := role.split("_")
	return parts.size() == 2 and ROOM_DEFAULTS.has(parts[0]) and parts[1].is_valid_int() and int(parts[1]) >= 1 and int(parts[1]) <= 8

static func clean_placements(raw: Variant, inventory: Array, layout: Dictionary) -> Dictionary:
	var result := initial_placements()
	var used: Dictionary = {}
	for uid: String in result.values(): used[uid] = true
	if raw is Dictionary:
		for role: String in raw:
			if not ROOM_DEFAULTS.has(role) and not _is_furniture_copy(role): continue
			if role != role.get_slice("_", 0) and not layout.has(role): continue
			var uid := str(raw[role])
			if used.has(uid): continue
			for entry: Dictionary in inventory:
				if entry.uid == uid and entry.item_id == ROOM_DEFAULTS[role.get_slice("_", 0)]:
					result[role] = uid
					used[uid] = true
					break
	for role: String in layout:
		if _is_furniture_copy(role) and not result.has(role):
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
