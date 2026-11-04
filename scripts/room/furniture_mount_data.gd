class_name MemoirFurnitureMountData
extends RefCounted
## Validated, inventory-aware surface attachments. Keys are stable furniture roles.
## A mount preserves the original floor pose, so detaching never loses it.
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
const LIMIT := 256

static func clean_entry(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var support := str(value.get("support", ""))
	var anchor := str(value.get("anchor", ""))
	if not LayoutData.valid_role(support) or anchor.is_empty() or anchor.length() > 64: return {}
	var x: Variant = value.get("x")
	var z: Variant = value.get("z")
	var yaw: Variant = value.get("yaw")
	var original: Variant = value.get("floor_pose")
	if not _number(x) or not _number(z) or not _number(yaw) or not original is Dictionary: return {}
	for key in ["x", "z", "yaw"]:
		if not _number(original.get(key)): return {}
	if absf(float(x)) > 20.0 or absf(float(z)) > 20.0: return {}
	return {"support":support,"anchor":anchor,"x":float(x),"z":float(z),"yaw":wrapf(float(yaw),-PI,PI),
		"floor_pose":{"x":clampf(float(original.x),-20.0,20.0),"z":clampf(float(original.z),-20.0,20.0),
		"yaw":wrapf(float(original.yaw),-PI,PI)}}

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func clean(raw: Variant, placements: Dictionary) -> Dictionary:
	var result := {}
	if not raw is Dictionary: return result
	for raw_role: Variant in raw:
		if result.size() >= LIMIT: break
		if not raw_role is String: continue
		var role: String = raw_role
		if not LayoutData.valid_role(role) or not placements.has(role): continue
		var entry := clean_entry(raw[role])
		if entry.is_empty() or entry.support == role or not placements.has(entry.support): continue
		# Only one level of attachments: no cycles and predictable movement.
		if raw.has(entry.support): continue
		result[role] = entry
	return result
