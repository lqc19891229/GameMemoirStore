class_name MemoirWorkstationLayoutData
extends RefCounted
## Only horizontal poses are persisted; height and scale remain authored in scenes.
const MAX_POSITION := 20.0
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const ROLES := ["desk", "monitor", "computer", "keyboard", "mouse"]
static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary: return result
	for raw_role: Variant in raw:
		if not raw_role is String or not valid_role(raw_role): continue
		var role: String = raw_role
		var pose: Variant = raw.get(role)
		if not pose is Dictionary: continue
		var valid := true
		for key in ["x", "z", "yaw"]:
			var value: Variant = pose.get(key)
			if not (value is int or value is float) or not is_finite(float(value)): valid = false
		if not valid: continue
		result[role] = {"x": clampf(float(pose.x), -MAX_POSITION, MAX_POSITION), "z": clampf(float(pose.z), -MAX_POSITION, MAX_POSITION), "yaw": wrapf(float(pose.yaw), -PI, PI)}
	return result

## Existing "chair_1"…"_8" names are accepted unchanged on load.
## Newly placed instances use one immutable role per inventory UID, with no slot limit.
const INSTANCE_SEPARATOR := "__instance__"

static func instance_role(furniture_role: String, uid: String) -> String:
	if Catalog.item_for_placement_role(furniture_role) == null: return ""
	if not uid.begins_with("item_") or uid.length() > 80: return ""
	var index := uid.substr(5)
	if not index.is_valid_int() or int(index) < 1 or str(int(index)) != index: return ""
	return furniture_role + INSTANCE_SEPARATOR + uid

static func is_instance_role(role: String) -> bool:
	var separator := role.find(INSTANCE_SEPARATOR)
	if separator < 1: return false
	var furniture_role := role.substr(0,separator)
	var uid := role.substr(separator+INSTANCE_SEPARATOR.length())
	return instance_role(furniture_role,uid) == role

static func instance_uid(role: String) -> String:
	if not is_instance_role(role): return ""
	return role.substr(role.find(INSTANCE_SEPARATOR)+INSTANCE_SEPARATOR.length())

static func base_role(role: String) -> String:
	if is_instance_role(role):
		return role.substr(0,role.find(INSTANCE_SEPARATOR))
	if is_legacy_copy(role):
		return role.substr(0,role.rfind("_"))
	return role

static func is_legacy_copy(role: String) -> bool:
	var index := role.rfind("_")
	if index < 1: return false
	var suffix := role.substr(index+1)
	if not suffix.is_valid_int() or int(suffix) < 1 or int(suffix) > 8: return false
	return Catalog.item_for_placement_role(role.substr(0,index)) != null

static func is_copy(role: String) -> bool:
	return is_instance_role(role) or is_legacy_copy(role)

static func valid_role(role: String) -> bool:
	return role in ROLES or Catalog.item_for_placement_role(role) != null or is_copy(role)

static func overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	# Separating axes for convex footprints; a tiny tolerance permits touching edges.
	for polygon: PackedVector2Array in [a, b]:
		for i in range(polygon.size()):
			var edge := polygon[(i + 1) % polygon.size()] - polygon[i]
			if edge.is_zero_approx(): continue
			var axis := edge.orthogonal().normalized()
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for point in a:
				amin = minf(amin, point.dot(axis))
				amax = maxf(amax, point.dot(axis))
			for point in b:
				bmin = minf(bmin, point.dot(axis))
				bmax = maxf(bmax, point.dot(axis))
			if amax <= bmin + 0.002 or bmax <= amin + 0.002: return false
	return true
