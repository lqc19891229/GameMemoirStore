class_name MemoirFurnitureSupportSurfaces
extends RefCounted
## Geometric helpers for stacking small objects on furniture.
## This is a foundation API; the existing floor-only inventory workflow remains unchanged.
## Anchors are authored in the supporting furniture's LOCAL coordinates, in metres.

const MIN_MARGIN := 0.01
const MAX_ANCHORS := 32

static func clean_anchor(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var key := str(raw.get("id", ""))
	if key.is_empty() or key.length() > 64:
		return {}
	var position: Variant = raw.get("center")
	var size: Variant = raw.get("size")
	if not position is Vector3 or not size is Vector2:
		return {}
	if not _finite_vector(position) or not is_finite(size.x) or not is_finite(size.y):
		return {}
	if size.x <= 0.0 or size.y <= 0.0:
		return {}
	return {"id": key, "center": position, "size": size}

static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func from_bounds(bounds: Vector3, inset: float = 0.05) -> Dictionary:
	if not _finite_vector(bounds) or bounds.x <= 0.0 or bounds.y <= 0.0 or bounds.z <= 0.0:
		return {}
	var width := bounds.x - 2.0 * inset
	var depth := bounds.z - 2.0 * inset
	if width <= 0.0 or depth <= 0.0:
		return {}
	return {"id": "top", "center": Vector3(0.0, bounds.y, 0.0), "size": Vector2(width, depth)}

static func fits(anchor: Dictionary, local_point: Vector3, object_size: Vector2, margin: float = MIN_MARGIN) -> bool:
	var cleaned := clean_anchor(anchor)
	if cleaned.is_empty() or not _finite_vector(local_point):
		return false
	if not is_finite(object_size.x) or not is_finite(object_size.y):
		return false
	if object_size.x <= 0.0 or object_size.y <= 0.0 or not is_finite(margin) or margin < 0.0:
		return false
	var center: Vector3 = cleaned.center
	var size: Vector2 = cleaned.size
	# Object origin is at its bottom centre; allow tiny contact tolerance.
	if absf(local_point.y - center.y) > 0.025:
		return false
	return absf(local_point.x - center.x) + object_size.x * 0.5 + margin <= size.x * 0.5 and absf(local_point.z - center.z) + object_size.y * 0.5 + margin <= size.y * 0.5

static func world_position(support: Node3D, anchor: Dictionary, offset: Vector2) -> Vector3:
	var cleaned := clean_anchor(anchor)
	if support == null or cleaned.is_empty():
		return Vector3.ZERO
	return support.global_transform * (cleaned.center + Vector3(offset.x, 0.0, offset.y))

static func anchors_for(support: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if support == null:
		return result
	# Preferred explicit multi-shelf anchors. Never infer stackable surfaces
	# from a visual mesh's AABB (so chairs/lamps do not accidentally allow stacking).
	var authored: Variant = support.get_meta("support_surfaces", [])
	if not authored is Array:
		return result
	var ids := {}
	for raw: Variant in authored:
		if result.size() >= MAX_ANCHORS:
			break
		var anchor := clean_anchor(raw)
		if anchor.is_empty() or ids.has(anchor.id):
			continue
		ids[anchor.id] = true
		result.append(anchor)
	return result

static func find_fit(support: Node3D, local_point: Vector3, object_size: Vector2) -> Dictionary:
	for anchor in anchors_for(support):
		if fits(anchor, local_point, object_size):
			return anchor
	return {}
