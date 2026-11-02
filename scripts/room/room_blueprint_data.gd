class_name MemoirRoomBlueprintData
extends RefCounted
## Rectangular or L-shaped rooms; interior walls are grid-aligned one-metre segments.
const DEFAULT := {"width": 8.0, "depth": 6.0, "door_x": -2.75, "window_z": -0.8, "partitions": [], "shape":"rectangle", "notch_width":1.5, "notch_depth":1.5}
const MIN_WIDTH := 6.0
const MAX_WIDTH := 12.0
const MIN_DEPTH := 5.0
const MAX_DEPTH := 10.0
const WALL_LENGTH := 1.0
const WALL_THICKNESS := 0.14
const WALL_GRID := 0.5
const MAX_PARTITIONS := 96

static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	if not raw is Dictionary: return result
	for key: String in ["width", "depth", "door_x", "window_z", "notch_width", "notch_depth"]:
		var number: Variant = raw.get(key)
		if (number is int or number is float) and is_finite(float(number)):
			result[key] = float(number)
	result.width = snappedf(clampf(result.width, MIN_WIDTH, MAX_WIDTH), 0.5)
	result.depth = snappedf(clampf(result.depth, MIN_DEPTH, MAX_DEPTH), 0.5)
	result.shape = "l" if raw.get("shape", "rectangle") == "l" else "rectangle"
	result.notch_width = snappedf(clampf(result.notch_width, 1.0, minf(4.0, result.width - 3.0)), 0.5)
	result.notch_depth = snappedf(clampf(result.notch_depth, 1.0, minf(4.0, result.depth - 2.5)), 0.5)
	# A door needs 1 m and a window needs 2.36 m of uninterrupted wall.
	result.door_x = snappedf(clampf(result.door_x, -result.width / 2.0 + 0.7, result.width / 2.0 - 0.7), 0.05)
	result.window_z = snappedf(clampf(result.window_z, -result.depth / 2.0 + 1.35, result.depth / 2.0 - 1.35), 0.05)
	var entries: Variant = raw.get("partitions", [])
	if entries is Array:
		for raw_part: Variant in entries:
			if result.partitions.size() >= MAX_PARTITIONS: break
			var part: Dictionary = clean_partition(raw_part)
			if part.is_empty() or not inside(result, part): continue
			var duplicate_or_overlap := false
			for existing: Dictionary in result.partitions:
				if intersects(existing, part):
					duplicate_or_overlap = true
					break
			if not duplicate_or_overlap: result.partitions.append(part)
	return result

static func clean_partition(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var axis: String = str(raw.get("axis", ""))
	var kind: String = str(raw.get("kind", "wall"))
	if axis not in ["x", "z"] or kind not in ["wall", "door"]: return {}
	var x: Variant = raw.get("x", null)
	var z: Variant = raw.get("z", null)
	if not (x is int or x is float) or not (z is int or z is float): return {}
	if not is_finite(float(x)) or not is_finite(float(z)): return {}
	# Refuse off-grid inputs rather than silently relocating old saved walls.
	var at_x := snappedf(float(x), WALL_GRID)
	var at_z := snappedf(float(z), WALL_GRID)
	if absf(float(x) - at_x) > .001 or absf(float(z) - at_z) > .001: return {}
	return {"x": at_x, "z": at_z, "axis": axis, "kind": kind}

static func half_size(value: Dictionary) -> Vector2:
	return Vector2(float(value.width) * .5, float(value.depth) * .5)

static func extents(part: Dictionary) -> Vector2:
	return Vector2(.5, WALL_THICKNESS * .5) if part.axis == "x" else Vector2(WALL_THICKNESS * .5, .5)

static func inside(blueprint: Dictionary, part: Dictionary) -> bool:
	var e := extents(part)
	if absf(part.x) + e.x >= float(blueprint.width) * .5 - .10 or absf(part.z) + e.y >= float(blueprint.depth) * .5 - .10: return false
	return not cutout_overlap(blueprint, polygon(part, .02))

static func intersects(a: Dictionary, b: Dictionary) -> bool:
	var ea := extents(a)
	var eb := extents(b)
	var dx := absf(float(a.x) - float(b.x))
	var dz := absf(float(a.z) - float(b.z))
	# Permit perpendicular segments to join at grid-corner endpoints.
	if a.axis != b.axis and dx >= .5 - .001 and dz >= .5 - .001: return false
	return dx < ea.x + eb.x - .001 and dz < ea.y + eb.y - .001

static func polygon(part: Dictionary, margin: float = 0.0) -> PackedVector2Array:
	var e := extents(part) + Vector2.ONE * margin
	return PackedVector2Array([
		Vector2(part.x-e.x, part.z-e.y), Vector2(part.x+e.x, part.z-e.y),
		Vector2(part.x+e.x, part.z+e.y), Vector2(part.x-e.x, part.z+e.y)
	])
 
static func cutout_polygon(value: Dictionary, clearance: float = 0.0) -> PackedVector2Array:
	if value.shape != "l": return PackedVector2Array()
	var x: float = float(value.width) * .5 - float(value.notch_width) - clearance
	var z: float = float(value.depth) * .5 - float(value.notch_depth) - clearance
	var max_x: float = float(value.width) * .5 + .25
	var max_z: float = float(value.depth) * .5 + .25
	return PackedVector2Array([Vector2(x,z), Vector2(max_x,z), Vector2(max_x,max_z), Vector2(x,max_z)])

static func cutout_overlap(value: Dictionary, footprint: PackedVector2Array, clearance: float = 0.0) -> bool:
	var polygon_out := cutout_polygon(value, clearance)
	return not polygon_out.is_empty() and MemoirWorkstationLayoutData.overlap(footprint, polygon_out)

static func footprint_inside(value: Dictionary, footprint: PackedVector2Array, margin: float = 0.0) -> bool:
	var limits := half_size(value)
	for corner: Vector2 in footprint:
		if absf(corner.x) > limits.x - margin + .002 or absf(corner.y) > limits.y - margin + .002: return false
	return not cutout_overlap(value, footprint, margin)
