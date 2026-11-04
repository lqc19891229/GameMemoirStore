@tool
extends RefCounted
## Pure geometry for editing one authored horizontal support rectangle.
## The opposite side stays fixed while resizing; minimum footprint is 2 cm.
const MIN_SIZE := 0.02


static func changed_anchor(original: Dictionary, handle: String, delta: Vector2) -> Dictionary:
	var result := original.duplicate(true)
	var center: Vector3 = original.center
	var size: Vector2 = original.size
	if handle == "move":
		center.x = snappedf(center.x + delta.x, 0.01)
		center.z = snappedf(center.z + delta.y, 0.01)
	elif handle == "left" or handle == "right":
		var sign_x := -1.0 if handle == "left" else 1.0
		var old_edge := center.x + sign_x * size.x * 0.5
		var other_edge := center.x - sign_x * size.x * 0.5
		var next_edge := snappedf(old_edge + delta.x, 0.01)
		next_edge = minf(next_edge, other_edge - MIN_SIZE) if sign_x < 0.0 else maxf(next_edge, other_edge + MIN_SIZE)
		center.x = snappedf((other_edge + next_edge) * 0.5, 0.005)
		size.x = absf(next_edge - other_edge)
	elif handle == "near" or handle == "far":
		var sign_z := -1.0 if handle == "near" else 1.0
		var old_edge := center.z + sign_z * size.y * 0.5
		var other_edge := center.z - sign_z * size.y * 0.5
		var next_edge := snappedf(old_edge + delta.y, 0.01)
		next_edge = minf(next_edge, other_edge - MIN_SIZE) if sign_z < 0.0 else maxf(next_edge, other_edge + MIN_SIZE)
		center.z = snappedf((other_edge + next_edge) * 0.5, 0.005)
		size.y = absf(next_edge - other_edge)
	result.center = center
	result.size = size
	return result
