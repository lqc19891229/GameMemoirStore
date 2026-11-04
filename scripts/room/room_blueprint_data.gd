class_name MemoirRoomBlueprintData
extends RefCounted
## Rectangular, L and grid-painted orthogonal footprints with validated interior walls.
const DEFAULT := {"width": 8.0, "depth": 6.0, "door_x": -2.75, "window_z": -0.8, "partitions": [], "shape":"rectangle", "notch_width":1.5, "notch_depth":1.5, "removed_cells":[], "floor_finishes":[], "edge_finishes":[]}
const MIN_WIDTH := 6.0
const MAX_WIDTH := 12.0
const MIN_DEPTH := 5.0
const MAX_DEPTH := 10.0
const WALL_LENGTH := 1.0
const WALL_THICKNESS := 0.14
const WALL_GRID := 0.5
const MAX_PARTITIONS := 96
const FLOOR_GRID := 0.5
const MAX_REMOVED := 128
const FINISH_COUNT := 4
const MAX_EDGE_EDITS := 256

static func clean(raw: Variant) -> Dictionary:
	var result: Dictionary = DEFAULT.duplicate(true)
	if not raw is Dictionary: return result
	for key: String in ["width", "depth", "door_x", "window_z", "notch_width", "notch_depth"]:
		var number: Variant = raw.get(key)
		if (number is int or number is float) and is_finite(float(number)):
			result[key] = float(number)
	result.width = snappedf(clampf(result.width, MIN_WIDTH, MAX_WIDTH), 0.5)
	result.depth = snappedf(clampf(result.depth, MIN_DEPTH, MAX_DEPTH), 0.5)
	var requested_shape: String = str(raw.get("shape", "rectangle"))
	result.shape = requested_shape if requested_shape in ["rectangle", "l", "custom"] else "rectangle"
	result.notch_width = snappedf(clampf(result.notch_width, 1.0, minf(4.0, result.width - 3.0)), 0.5)
	result.notch_depth = snappedf(clampf(result.notch_depth, 1.0, minf(4.0, result.depth - 2.5)), 0.5)
	# A door needs 1 m and a window needs 2.36 m of uninterrupted wall.
	result.door_x = snappedf(clampf(result.door_x, -result.width / 2.0 + 0.7, result.width / 2.0 - 0.7), 0.05)
	result.window_z = snappedf(clampf(result.window_z, -result.depth / 2.0 + 1.35, result.depth / 2.0 - 1.35), 0.05)
	if result.shape == "custom":
		var cutouts: Variant = raw.get("removed_cells", [])
		if cutouts is Array:
			for raw_cell: Variant in cutouts:
				if result.removed_cells.size() >= MAX_REMOVED: break
				var cell: Dictionary = clean_cell(raw_cell)
				if cell.is_empty() or not editable_cell(result, cell): continue
				if has_cell(result, cell): continue
				result.removed_cells.append(cell)
				if not floor_connected(result):
					result.removed_cells.pop_back()
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
	if result.shape == "custom":
		var floor_entries: Variant = raw.get("floor_finishes", [])
		if floor_entries is Array:
			for raw_entry: Variant in floor_entries:
				var finish: Dictionary = clean_floor_finish(raw_entry)
				if finish.is_empty() or not valid_cell(result, finish) or has_cell(result, finish): continue
				if floor_finish(result, finish) != 0: continue
				result.floor_finishes.append(finish)
		var edge_entries: Variant = raw.get("edge_finishes", [])
		if edge_entries is Array:
			for raw_entry: Variant in edge_entries:
				if result.edge_finishes.size() >= MAX_EDGE_EDITS: break
				var edge: Dictionary = clean_edge_finish(raw_entry)
				if edge.is_empty() or not edge_exposed(result, edge): continue
				var present := false
				for old_edge: Dictionary in result.edge_finishes:
					if same_edge(old_edge, edge):
						present = true
						break
				if not present: result.edge_finishes.append(edge)

	# Backward-compatible one-time migration: preserve legacy zone floor colors
	# as ordinary tile finishes. No functional labels, preset slots or zone
	# lights survive into the new free-decoration blueprint schema.
	if result.shape == "custom":
		var legacy_zones: Variant = raw.get("zone_cells",[])
		var legacy_styles: Variant = raw.get("zone_styles",[])
		if legacy_zones is Array:
			var seen: Dictionary = {}
			for old: Variant in legacy_zones:
				if not old is Dictionary: continue
				var cell: Dictionary = clean_cell(old)
				if cell.is_empty() or not valid_cell(result,cell) or has_cell(result,cell): continue
				var key := Vector2i(int(cell.ix),int(cell.iz))
				if seen.has(key): continue
				seen[key] = true
				var raw_zone: Variant = old.get("zone",0)
				if not (raw_zone is int or raw_zone is float) or not is_finite(float(raw_zone)): continue
				if float(raw_zone) != floorf(float(raw_zone)) or int(raw_zone) < 1 or int(raw_zone) > 3: continue
				if floor_finish(result,cell) != 0: continue
				var defaults := [2,1,3]
				var color_id: int = defaults[int(raw_zone)-1]
				if legacy_styles is Array and legacy_styles.size() >= int(raw_zone) and legacy_styles[int(raw_zone)-1] is Dictionary:
					color_id = finish_id(legacy_styles[int(raw_zone)-1].get("floor",color_id))
				if color_id > 0:
					result.floor_finishes.append({"ix":cell.ix,"iz":cell.iz,"finish":color_id})
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
	var part := {"x": at_x, "z": at_z, "axis": axis, "kind": kind}
	var finish: int = finish_id(raw.get("finish", 0))
	if finish != 0: part["finish"] = finish
	return part

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
	if value.shape == "custom":
		for removed: Dictionary in value.removed_cells:
			if MemoirWorkstationLayoutData.overlap(footprint, cell_polygon(value, removed, clearance)):
				return true
		return false
	var polygon_out := cutout_polygon(value, clearance)
	return not polygon_out.is_empty() and MemoirWorkstationLayoutData.overlap(footprint, polygon_out)

static func footprint_inside(value: Dictionary, footprint: PackedVector2Array, margin: float = 0.0) -> bool:
	var limits := half_size(value)
	for corner: Vector2 in footprint:
		if absf(corner.x) > limits.x - margin + .002 or absf(corner.y) > limits.y - margin + .002: return false
	return not cutout_overlap(value, footprint, margin)

## Grid cells use lower-left-relative integer coordinates. Edits are serialized
## as simple dictionaries, safe for the existing JSON save pipeline.
static func cell_count(value: Dictionary) -> Vector2i:
	return Vector2i(roundi(float(value.width) / FLOOR_GRID), roundi(float(value.depth) / FLOOR_GRID))

static func clean_cell(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var ix: Variant = raw.get("ix")
	var iz: Variant = raw.get("iz")
	if not (ix is int or ix is float) or not (iz is int or iz is float): return {}
	if not is_finite(float(ix)) or not is_finite(float(iz)): return {}
	if float(ix) != floorf(float(ix)) or float(iz) != floorf(float(iz)): return {}
	return {"ix":int(ix), "iz":int(iz)}

static func valid_cell(value: Dictionary, cell: Dictionary) -> bool:
	if cell.is_empty(): return false
	var size := cell_count(value)
	return cell.ix >= 0 and cell.ix < size.x and cell.iz >= 0 and cell.iz < size.y

static func editable_cell(value: Dictionary, cell: Dictionary) -> bool:
	# Preserve uninterrupted back/left exterior walls with their original door/window.
	return valid_cell(value, cell) and cell.ix > 0 and cell.iz > 0

static func has_cell(value: Dictionary, cell: Dictionary) -> bool:
	if cell.is_empty(): return false
	for removed: Dictionary in value.removed_cells:
		if removed.ix == cell.ix and removed.iz == cell.iz: return true
	return false

static func cell_at(value: Dictionary, at: Vector2) -> Dictionary:
	return {"ix":floori((at.x + float(value.width) * .5) / FLOOR_GRID),
		"iz":floori((at.y + float(value.depth) * .5) / FLOOR_GRID)}

static func cell_center(value: Dictionary, cell: Dictionary) -> Vector2:
	return Vector2(-float(value.width) * .5 + (float(cell.ix) + .5) * FLOOR_GRID,
		-float(value.depth) * .5 + (float(cell.iz) + .5) * FLOOR_GRID)

static func cell_polygon(value: Dictionary, cell: Dictionary, clearance: float = 0.0) -> PackedVector2Array:
	var center := cell_center(value, cell)
	var e := FLOOR_GRID * .5 + clearance
	return PackedVector2Array([center + Vector2(-e,-e), center + Vector2(e,-e),
		center + Vector2(e,e), center + Vector2(-e,e)])

static func floor_connected(value: Dictionary) -> bool:
	# Any island produced by floor removal is rejected before saving.
	var size := cell_count(value)
	var removed: Dictionary = {}
	for cell: Dictionary in value.removed_cells:
		if not valid_cell(value, cell): return false
		removed[Vector2i(cell.ix, cell.iz)] = true
	var total := size.x * size.y - removed.size()
	if total <= 0: return false
	var seed := Vector2i(-1,-1)
	for z in range(size.y):
		for x in range(size.x):
			if not removed.has(Vector2i(x,z)):
				seed = Vector2i(x,z)
				break
		if seed.x >= 0: break
	if seed.x < 0: return false
	var pending: Array[Vector2i] = [seed]
	var visited: Dictionary = {seed:true}
	var cursor := 0
	while cursor < pending.size():
		var item := pending[cursor]
		cursor += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var other := item + step
			if other.x < 0 or other.y < 0 or other.x >= size.x or other.y >= size.y: continue
			if removed.has(other) or visited.has(other): continue
			visited[other] = true
			pending.append(other)
	return visited.size() == total

## Floor finishes and exterior wall edits only apply to custom rooms.
## They are keyed by stable grid coordinates, never by scene-tree indices.
static func finish_id(value: Variant) -> int:
	if not (value is int or value is float): return 0
	if not is_finite(float(value)) or float(value) != floorf(float(value)): return 0
	return int(value) if int(value) >= 0 and int(value) < FINISH_COUNT else 0

static func clean_floor_finish(value: Variant) -> Dictionary:
	var cell := clean_cell(value)
	if cell.is_empty(): return {}
	var finish: int = finish_id(value.get("finish", 0))
	if finish == 0: return {}
	cell["finish"] = finish
	return cell

static func floor_finish(value: Dictionary, cell: Dictionary) -> int:
	for entry: Dictionary in value.get("floor_finishes", []):
		if int(entry.ix) == int(cell.ix) and int(entry.iz) == int(cell.iz):
			return int(entry.finish)
	return 0

static func clean_edge_finish(value: Variant) -> Dictionary:
	var cell := clean_cell(value)
	if cell.is_empty(): return {}
	var dx: Variant = value.get("dx", null)
	var dz: Variant = value.get("dz", null)
	if not (dx is int or dx is float) or not (dz is int or dz is float): return {}
	if not is_finite(float(dx)) or not is_finite(float(dz)): return {}
	if absf(float(dx)) + absf(float(dz)) != 1.0: return {}
	var kind: String = str(value.get("kind", "wall"))
	if kind not in ["wall", "window", "door"]: return {}
	var finish: int = finish_id(value.get("finish", 0))
	cell["dx"] = int(dx)
	cell["dz"] = int(dz)
	cell["kind"] = kind
	cell["finish"] = finish
	return cell

static func same_edge(a: Dictionary, b: Dictionary) -> bool:
	return a.ix == b.ix and a.iz == b.iz and a.dx == b.dx and a.dz == b.dz

static func edge_exposed(value: Dictionary, edge: Dictionary) -> bool:
	if value.shape != "custom" or not valid_cell(value, edge): return false
	var removed_cell := {"ix":int(edge.ix), "iz":int(edge.iz)}
	if not has_cell(value, removed_cell): return false
	var next := {"ix":int(edge.ix)+int(edge.dx), "iz":int(edge.iz)+int(edge.dz)}
	return valid_cell(value, next) and not has_cell(value, next)

static func exposed_edges(value: Dictionary) -> Array:
	var edges := []
	if value.shape != "custom": return edges
	for cell: Dictionary in value.removed_cells:
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var edge := {"ix":int(cell.ix), "iz":int(cell.iz),
				"dx":delta.x, "dz":delta.y}
			if edge_exposed(value, edge): edges.append(edge)
	return edges

static func edge_center(value: Dictionary, edge: Dictionary) -> Vector2:
	return cell_center(value, edge) + Vector2(float(edge.dx), float(edge.dz)) * FLOOR_GRID * .5

static func nearest_edge(value: Dictionary, at: Vector2, radius: float = .36) -> Dictionary:
	var best := {}
	var dist := radius
	for edge: Dictionary in exposed_edges(value):
		var pos := edge_center(value, edge)
		var metric := pos.distance_to(at)
		if metric < dist:
			dist = metric
			best = edge
	return best

static func edge_neighbor(value: Dictionary, edge: Dictionary, step: int) -> Dictionary:
	var nx: int = int(edge.ix) + (step if int(edge.dx) == 0 else 0)
	var nz: int = int(edge.iz) + (step if int(edge.dz) == 0 else 0)
	var candidate := {"ix":nx,"iz":nz,"dx":int(edge.dx),"dz":int(edge.dz)}
	return candidate if edge_exposed(value,candidate) else {}

static func same_opening_neighbor(value: Dictionary, edge: Dictionary, step: int) -> bool:
	var adjacent: Dictionary = edge_neighbor(value,edge,step)
	if adjacent.is_empty(): return false
	var source: Dictionary = edge_edit(value,edge)
	var neighbor: Dictionary = edge_edit(value,adjacent)
	return source.kind == neighbor.kind and str(source.kind) in ["door","window"]

static func edge_span(value: Dictionary, edge: Dictionary, count: int) -> Array:
	if count < 1 or count > 4 or not edge_exposed(value,edge): return []
	for direction in [1,-1]:
		var result: Array = [edge]
		var complete := true
		for offset in range(1,count):
			var neighbor: Dictionary = edge_neighbor(value,edge,offset*direction)
			if neighbor.is_empty():
				complete = false
				break
			result.append(neighbor)
		if complete: return result
	return []

static func edge_edit(value: Dictionary, edge: Dictionary) -> Dictionary:
	for old: Dictionary in value.get("edge_finishes", []):
		if same_edge(old, edge): return old
	return {"ix":edge.ix, "iz":edge.iz, "dx":edge.dx, "dz":edge.dz, "kind":"wall", "finish":0}

## Painted room areas use the same grid coordinates as the floor brush.
## Finishes are direct user edits; no room-purpose designation influences them.
static func effective_floor_finish(value: Dictionary, cell: Dictionary) -> int:
	return floor_finish(value,cell)

static func effective_wall_finish(_value: Dictionary, _at: Vector2, manual: int) -> int:
	return manual

## Connected space detection: a solid 1m partition blocks crossings between
## 0.5m floor cells. Door segments keep the path open, so adjoining spaces
## with open doorways are intentionally classified as connected.
static func floor_cell_exists(value: Dictionary, cell: Dictionary) -> bool:
	if not valid_cell(value, cell): return false
	if value.shape == "custom": return not has_cell(value, cell)
	if value.shape == "l":
		return not cutout_overlap(value, cell_polygon(value, cell))
	return true

static func wall_between(value: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	var one := Vector2i(int(a.ix),int(a.iz))
	var two := Vector2i(int(b.ix),int(b.iz))
	var move := two - one
	if absi(move.x) + absi(move.y) != 1: return true
	var center_a: Vector2 = cell_center(value, a)
	var center_b: Vector2 = cell_center(value, b)
	var midpoint := (center_a + center_b) * .5
	var orientation := "z" if move.x != 0 else "x"
	for part: Dictionary in value.partitions:
		if part.kind == "door" or part.axis != orientation: continue
		if orientation == "z":
			if absf(float(part.x) - midpoint.x) < .001 and absf(float(part.z) - midpoint.y) < .499:
				return true
		elif absf(float(part.z) - midpoint.y) < .001 and absf(float(part.x) - midpoint.x) < .499:
			return true
	return false

static func room_region_at(value: Dictionary, at: Vector2) -> Array:
	var start: Dictionary = cell_at(value, at)
	if not floor_cell_exists(value, start): return []
	var size := cell_count(value)
	var pending: Array[Vector2i] = [Vector2i(int(start.ix),int(start.iz))]
	var seen := {pending[0]:true}
	var cursor := 0
	var result := []
	while cursor < pending.size():
		var current: Vector2i = pending[cursor]
		cursor += 1
		var a := {"ix":current.x,"iz":current.y}
		result.append(a)
		for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var adjacent := current + step
			if adjacent.x < 0 or adjacent.y < 0 or adjacent.x >= size.x or adjacent.y >= size.y: continue
			if seen.has(adjacent): continue
			var b := {"ix":adjacent.x,"iz":adjacent.y}
			if not floor_cell_exists(value,b) or wall_between(value,a,b): continue
			seen[adjacent] = true
			pending.append(adjacent)
	return result

static func room_regions(value: Dictionary) -> Array:
	var found := []
	var visited := {}
	var size := cell_count(value)
	for iz in range(size.y):
		for ix in range(size.x):
			var key := Vector2i(ix,iz)
			if visited.has(key): continue
			var cell := {"ix":ix,"iz":iz}
			if not floor_cell_exists(value,cell): continue
			var region: Array = room_region_at(value,cell_center(value,cell))
			if region.is_empty(): continue
			for member: Dictionary in region:
				visited[Vector2i(int(member.ix),int(member.iz))] = true
			found.append(region)
	return found

