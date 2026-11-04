class_name MemoirRoomWallMountData
extends RefCounted
## Inventory-owned, validated exterior wall mounts. No change to legacy floor poses.
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
const BlueprintData = preload("res://scripts/room/room_blueprint_data.gd")
const MAX_ENTRIES := 96
const MOUNT_ROLE := "poster_floor_frame"
const LAMP_ROLE := "wall_sconce"
const LAMP_ENERGY := [0.24,0.50,0.84]
# Approximate correlated color temperatures: warm / neutral / cool.
const LAMP_TEMPERATURES := [2700,4000,6500]
const LAMP_COLORS := [Color(1.0,0.69,0.42),Color(1.0,0.87,0.73),Color(0.80,0.88,1.0)]

static func is_mountable(role: String) -> bool:
	return role in [MOUNT_ROLE,LAMP_ROLE]

static func dimensions(role: String) -> Vector2:
	return Vector2(.40,.60) if role == LAMP_ROLE else Vector2(.77,1.20)
const MIN_HEIGHT := 0.4
const MAX_HEIGHT := 2.8
const EDGE_GAP := 0.12

static func clean_entry(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var wall: String = str(raw.get("wall",""))
	if wall not in ["north","south","west","east","partition"]: return {}
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
	var entry := {"wall":wall,"along":along,"height":height,
		"floor_pose":{"x":clampf(float(original.x),-12,12),
			"z":clampf(float(original.z),-12,12),
			"yaw":wrapf(float(original.yaw),-PI,PI)}}
	if wall == "partition":
		var part: Dictionary = BlueprintData.clean_partition(raw.get("part",{}))
		if part.is_empty() or str(part.kind) != "wall": return {}
		var raw_side: Variant = raw.get("side")
		if not (raw_side is int or raw_side is float): return {}
		if not is_finite(float(raw_side)) or float(raw_side) not in [-1.0,1.0]: return {}
		entry["part"] = {"x":float(part.x),"z":float(part.z),"axis":str(part.axis)}
		entry["side"] = int(raw_side)
	var raw_on: Variant = raw.get("on",true)
	if not raw_on is bool: return {}
	var raw_level: Variant = raw.get("level",2)
	if not (raw_level is int or raw_level is float) or not is_finite(float(raw_level)): return {}
	if int(raw_level) < 1 or int(raw_level) > 3 or float(raw_level) != float(int(raw_level)): return {}
	var raw_tone: Variant = raw.get("tone",1)
	if not (raw_tone is int or raw_tone is float) or not is_finite(float(raw_tone)): return {}
	if int(raw_tone) < 1 or int(raw_tone) > 3 or float(raw_tone) != float(int(raw_tone)): return {}
	entry["on"] = raw_on
	entry["level"] = int(raw_level)
	entry["tone"] = int(raw_tone)
	return entry

static func fits(mount: Dictionary, blueprint: Dictionary, frame_width: float, frame_height: float) -> bool:
	if mount.is_empty() or not is_finite(frame_width) or not is_finite(frame_height): return false
	if frame_width <= 0.0 or frame_height <= 0.0: return false
	var wall: String = str(mount.wall)
	var half: Vector2 = BlueprintData.half_size(blueprint)
	var room_height := 3.0
	var along: float = float(mount.along)
	var height: float = float(mount.height)
	if wall == "partition":
		if not mount.has("part") or not mount.has("side"): return false
		var part: Dictionary = mount.part
		if int(mount.side) not in [-1,1]: return false
		var supported := false
		for candidate: Dictionary in blueprint.partitions:
			if str(candidate.kind) == "wall" and str(candidate.axis) == str(part.get("axis","")) and is_equal_approx(float(candidate.x),float(part.get("x",INF))) and is_equal_approx(float(candidate.z),float(part.get("z",INF))):
				supported = true
				break
		if not supported: return false
		# One partition spans one metre; a frame may not overhang its ends.
		if absf(along)+frame_width*.5+.025 > BlueprintData.WALL_LENGTH*.5: return false
	else:
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
		if not LayoutData.valid_role(role) or not is_mountable(LayoutData.base_role(role)): continue
		if not placements.has(role): continue
		var mount: Dictionary = clean_entry(raw[role])
		var size: Vector2 = dimensions(LayoutData.base_role(role))
		if not mount.is_empty() and fits(mount,blueprint,size.x,size.y):
			result[role] = mount
	return result
