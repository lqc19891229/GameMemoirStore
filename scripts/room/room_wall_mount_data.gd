class_name MemoirRoomWallMountData
extends RefCounted
## Inventory-owned, validated exterior wall mounts. No change to legacy floor poses.
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
const BlueprintData = preload("res://scripts/room/room_blueprint_data.gd")
const MAX_ENTRIES := 96
const MOUNT_ROLE := "poster_floor_frame"
const MIN_HEIGHT := 0.4
const MAX_HEIGHT := 2.8
const EDGE_GAP := 0.12

static func clean_entry(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var wall: String = str(raw.get("wall",""))
	if wall not in ["north","south","west","east"]: return {}
	for key in ["along","height"]:
		var value: Variant = raw.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return {}
	var along: float = float(raw["along"])
	var height: float = float(raw["height"])
	if absf(along) > 12.0 or height < MIN_HEIGHT or height > MAX_HEIGHT: return {}
	var original: Variant = raw.get("floor_pose")
	if not original is Dictionary: return {}
	for key in ["x","z","yaw"]:
		var value: Variant = original.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return {}
	return {"wall":wall,"along":along,"height":height,
		"floor_pose":{"x":clampf(float(original.x),-12,12),
			"z":clampf(float(original.z),-12,12),
			"yaw":wrapf(float(original.yaw),-PI,PI)}}

static func fits(mount: Dictionary, blueprint: Dictionary, frame_width: float, frame_height: float) -> bool:
	if mount.is_empty() or not is_finite(frame_width) or not is_finite(frame_height): return false
	if frame_width <= 0.0 or frame_height <= 0.0: return false
	var wall: String = str(mount.wall)
	var half: Vector2 = BlueprintData.half_size(blueprint)
	var room_height := 3.0
	var along: float = float(mount.along)
	var height: float = float(mount.height)
	var limit: float = half.x if wall in ["north","south"] else half.y
	if absf(along)+frame_width*.5+EDGE_GAP >= limit: return false
	if height < 0.4 or height+frame_height > room_height-.15: return false
	# Existing external openings: a door on the south wall, a window on the west.
	# Keep clearance around the entire visible decoration, not just its centre.
	if wall == "south" and absf(along-float(blueprint.door_x)) < (frame_width+1.2)*.5+.15 and height < 2.35:
		return false
	if wall == "west" and absf(along-float(blueprint.window_z)) < (frame_width+2.36)*.5+.12:
		return false
	return true

static func clean(raw: Variant, placements: Dictionary, blueprint: Dictionary) -> Dictionary:
	var result := {}
	if not raw is Dictionary: return result
	for key: Variant in raw:
		if result.size() >= MAX_ENTRIES: break
		if not key is String: continue
		var role: String = key
		if not LayoutData.valid_role(role) or LayoutData.base_role(role) != MOUNT_ROLE: continue
		if not placements.has(role): continue
		var mount: Dictionary = clean_entry(raw[role])
		if not mount.is_empty() and fits(mount,blueprint,.77,1.2):
			result[role] = mount
	return result
