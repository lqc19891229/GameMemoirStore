class_name MemoirRoomBlueprintData
extends RefCounted
## Rectangular room blueprint. All distances are metres.
const DEFAULT := {"width": 8.0, "depth": 6.0, "door_x": -2.75, "window_z": -0.8}
const MIN_WIDTH := 6.0
const MAX_WIDTH := 12.0
const MIN_DEPTH := 5.0
const MAX_DEPTH := 10.0

static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate()
	if not raw is Dictionary: return result
	for key: String in result:
		var number: Variant = raw.get(key)
		if (number is int or number is float) and is_finite(float(number)):
			result[key] = float(number)
	result.width = snappedf(clampf(result.width, MIN_WIDTH, MAX_WIDTH), 0.5)
	result.depth = snappedf(clampf(result.depth, MIN_DEPTH, MAX_DEPTH), 0.5)
	# A door needs 1 m and a window needs 2.36 m of uninterrupted wall.
	result.door_x = snappedf(clampf(result.door_x, -result.width / 2.0 + 0.7, result.width / 2.0 - 0.7), 0.05)
	result.window_z = snappedf(clampf(result.window_z, -result.depth / 2.0 + 1.35, result.depth / 2.0 - 1.35), 0.05)
	return result

static func half_size(value: Dictionary) -> Vector2:
	return Vector2(float(value.width) * 0.5, float(value.depth) * 0.5)
