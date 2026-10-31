class_name MemoirWorkstationLayoutData
extends RefCounted
## Only horizontal poses are persisted; height and scale remain authored in scenes.
const MAX_POSITION := 20.0
const ROLES := ["desk", "monitor", "computer", "keyboard", "mouse", "chair", "bookcase", "lamp", "rug", "plant"]
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

static func base_role(role: String) -> String:
	return role.get_slice("_", 0)

static func is_copy(role: String) -> bool:
	var parts := role.split("_")
	return parts.size() == 2 and parts[0] in ["chair","bookcase","lamp","rug","plant"] and parts[1] in ["1","2","3","4","5","6","7","8"]

static func valid_role(role: String) -> bool:
	return role in ROLES or is_copy(role)

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
