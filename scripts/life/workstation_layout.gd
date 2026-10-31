extends Node
signal changed
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const NAMES := {"desk":"桌子（整套）", "monitor":"显示器", "computer":"机箱", "keyboard":"键盘", "mouse":"鼠标"}
@export var tabletop_half_size := Vector2(2.4, 1.15)
@export var tabletop_height := 0.78
@export var edge_margin := 0.025
@export var desk_move_limit := 1.5
@export var grid_step := 0.05
@export var angle_step := 15.0
@export_range(0.005, 0.1, 0.005) var collision_margin := 0.01
var world: Node3D
var group: Node3D
var gizmo: Node3D
var nodes: Dictionary = {}
var authored: Dictionary = {}
var committed: Dictionary = {}
var saved: Dictionary = {}
var active := false
var selected := "desk"
var tool := "move"
var snapping := true
var valid := true
var message := ""
var gesture := ""
var axis := "plane"
var start_hit := Vector3.ZERO
var start_position := Vector3.ZERO
var start_yaw := 0.0
var start_angle := 0.0
var start_axis := Vector3.ZERO
var drag_height := 0.78

func setup(owner_world: Node3D) -> void:
	world = owner_world
	group = world.get_node("%TableGroup")
	gizmo = world.get_node("%LayoutGizmo")
	nodes = {"desk":group}
	nodes.merge(world.devices)
	authored = snapshot()
	committed = authored.duplicate()

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for role: String in nodes: result[role] = nodes[role].transform
	return result

func restore(poses: Dictionary) -> void:
	for role: String in nodes: nodes[role].transform = poses[role]

func load_saved(raw: Variant) -> void:
	if active: return
	var cleaned := Data.clean(raw)
	if cleaned == saved and _layout_blocker().is_empty(): return
	restore(authored)
	for role: String in cleaned:
		nodes[role].position.x = cleaned[role].x
		nodes[role].position.z = cleaned[role].z
		nodes[role].rotation.y = cleaned[role].yaw
		clamp_pose(role)
	# Older layouts may touch or overlap after a model/bounds change. Keep the
	# table pose, but recover a usable equipment arrangement rather than loading penetration.
	if not _layout_blocker().is_empty():
		for role: String in world.devices: nodes[role].transform = authored[role]
	saved = cleaned
	committed = snapshot()

func export_layout() -> Dictionary:
	var result: Dictionary = {}
	for role: String in nodes:
		var pose: Transform3D = committed[role]
		result[role] = {"x":pose.origin.x, "z":pose.origin.z, "yaw":pose.basis.get_euler().y}
	return result

func begin() -> void:
	active = true
	selected = "desk"
	gesture = ""
	restore(committed)
	update()

func finish(apply: bool) -> bool:
	if not active: return false
	if apply: update()
	if apply and not valid: return false
	end_drag()
	if apply:
		committed = snapshot()
		saved = export_layout()
	else: restore(committed)
	active = false
	gizmo.hide()
	return true

func select(role: String) -> void:
	if not nodes.has(role): return
	selected = role
	end_drag()
	update()

func set_tool(value: String) -> void:
	tool = value
	end_drag()
	update()

func reset_layout() -> void:
	if not active: return
	end_drag()
	restore(authored)
	update()

func footprint(role: String, padding: float = 0.0) -> PackedVector2Array:
	return _footprint_at(role, nodes[role].transform, padding)

func _footprint_at(role: String, pose: Transform3D, padding: float) -> PackedVector2Array:
	var size: Vector3 = nodes[role].appearance.bounds + Vector3(padding * 2, 0, padding * 2)
	var result := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var point: Vector3 = pose * Vector3(corner.x * size.x/2, 0, corner.y * size.z/2)
		result.append(Vector2(point.x, point.z))
	return result

func clamp_pose(role: String) -> void:
	var node: Node3D = nodes[role]
	if role == "desk":
		node.position.x = clampf(node.position.x, -desk_move_limit, desk_move_limit)
		node.position.z = clampf(node.position.z, -desk_move_limit, desk_move_limit)
		node.position.y = (authored[role] as Transform3D).origin.y
		return
	node.position.y = tabletop_height
	var corners := footprint(role, collision_margin)
	var extent := Vector2.ZERO
	for point in corners: extent = extent.max((point - Vector2(node.position.x,node.position.z)).abs())
	var allowance := (tabletop_half_size - extent - Vector2.ONE * edge_margin).max(Vector2.ZERO)
	node.position.x = clampf(node.position.x, -allowance.x, allowance.x)
	node.position.z = clampf(node.position.z, -allowance.y, allowance.y)

func move_to(position_xz: Vector2) -> void:
	if not active: return
	var before: Transform3D = nodes[selected].transform
	var point := position_xz
	if snapping: point = point.snapped(Vector2.ONE * grid_step)
	nodes[selected].position.x = point.x
	nodes[selected].position.z = point.y
	clamp_pose(selected)
	_constrain_motion(before, nodes[selected].transform)

func rotate_to(yaw: float) -> void:
	if not active: return
	var before: Transform3D = nodes[selected].transform
	if snapping: yaw = snappedf(yaw, deg_to_rad(angle_step))
	nodes[selected].rotation.y = wrapf(yaw, -PI, PI)
	clamp_pose(selected)
	_constrain_motion(before, nodes[selected].transform)

func _blocker(role: String, polygon: PackedVector2Array) -> String:
	for point in polygon:
		if absf(point.x) > tabletop_half_size.x - edge_margin + 0.002 or absf(point.y) > tabletop_half_size.y - edge_margin + 0.002:
			return NAMES[role] + "到达桌沿"
	for other: String in world.devices:
		if other != role and Data.overlap(polygon, footprint(other, collision_margin)):
			return NAMES[role] + "碰到" + NAMES[other]
	return ""

func _layout_blocker() -> String:
	for role: String in world.devices:
		var blocker := _blocker(role, footprint(role, collision_margin))
		if not blocker.is_empty(): return blocker
	return ""

func _sweep_blocker(role: String, before: Transform3D, after: Transform3D) -> String:
	var points := _footprint_at(role, before, collision_margin)
	points.append_array(_footprint_at(role, after, collision_margin))
	var hull := Geometry2D.convex_hull(points)
	# Geometry2D closes its hull; SAT expects each corner once.
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]): hull.resize(hull.size() - 1)
	return _blocker(role, hull)

func _constrain_motion(before: Transform3D, target: Transform3D) -> void:
	if selected == "desk":
		update()
		return
	var node: Node3D = nodes[selected]
	node.transform = before
	var angle := absf(angle_difference(before.basis.get_euler().y, target.basis.get_euler().y))
	# Translation uses an exact convex swept footprint. Rotation is split into
	# <=1-degree sweeps; padded bounds cover the small curved arc between samples.
	var steps := maxi(1, ceili(angle / deg_to_rad(1.0)))
	var blocker := ""
	for i in range(1, steps + 1):
		var next := before.interpolate_with(target, float(i) / steps)
		var previous := node.transform
		blocker = _sweep_blocker(selected, previous, next)
		if blocker.is_empty():
			node.transform = next
			continue
		# Find the last free pose, rather than jumping through a blocker or
		# discarding all movement when the pointer is beyond the contact edge.
		var low := 0.0
		var high := 1.0
		for iteration in range(12):
			var middle := (low + high) * 0.5
			if _sweep_blocker(selected, previous, previous.interpolate_with(next, middle)).is_empty(): low = middle
			else: high = middle
		node.transform = previous.interpolate_with(next, low)
		break
	update(blocker)

func rotate_step(direction: float) -> void:
	rotate_to(nodes[selected].rotation.y + deg_to_rad(angle_step) * direction)

func _plane_point(pixel: Vector2) -> Variant:
	var frame: Node3D = world if selected == "desk" else group
	var height := drag_height
	var plane := Plane(frame.global_basis.y.normalized(), frame.to_global(Vector3(0,height,0)))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	return frame.to_local(hit) if hit != null else null

func begin_drag(pixel: Vector2, operation: String = "move", direction: String = "plane", from_handle: bool = false) -> void:
	if not active: return
	var node: Node3D = nodes[selected]
	drag_height = node.position.y + (tabletop_height if selected == "desk" else node.appearance.bounds.y * .5)
	if from_handle:
		var handles: Node3D = gizmo.get_node("MoveHandles" if operation == "move" else "RotateHandles")
		var frame: Node3D = world if selected == "desk" else group
		drag_height = frame.to_local(handles.to_global(Vector3(0,.05,0))).y
	var hit: Variant = _plane_point(pixel)
	if hit == null: return
	gesture = operation
	axis = direction
	start_hit = hit
	start_position = nodes[selected].position
	start_yaw = nodes[selected].rotation.y
	start_axis = (nodes[selected].basis.x if axis == "x" else nodes[selected].basis.z).normalized()
	start_angle = atan2(hit.z - start_position.z, hit.x - start_position.x)

func drag_to(pixel: Vector2) -> void:
	if gesture.is_empty(): return
	var hit: Variant = _plane_point(pixel)
	if hit == null: return
	if gesture == "move":
		var delta: Vector3 = hit - start_hit
		if axis in ["x", "z"]: delta = start_axis * delta.dot(start_axis)
		move_to(Vector2(start_position.x + delta.x, start_position.z + delta.z))
	else:
		var current := atan2(hit.z - start_position.z, hit.x - start_position.x)
		rotate_to(start_yaw - angle_difference(start_angle,current))

func end_drag() -> void:
	gesture = ""

func pick_handle(pixel: Vector2) -> String:
	var origin: Vector3 = world.camera.project_ray_origin(pixel)
	var query := PhysicsRayQueryParameters3D.create(origin,origin + world.camera.project_ray_normal(pixel)*40,2)
	query.collide_with_areas = true
	var result := world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(result.collider.get_meta("operation", "")) if not result.is_empty() else ""

func update(contact: String = "") -> void:
	var blocker := _layout_blocker()
	valid = blocker.is_empty()
	message = "右键环绕 · 滚轮缩放 · 拖动物品或手柄调整"
	if not valid: message = blocker + "，请恢复默认布置或调整设备"
	elif not contact.is_empty(): message = "已阻挡：" + contact
	_update_gizmo(not contact.is_empty())
	changed.emit()

func _update_gizmo(contact: bool = false) -> void:
	if not active or not gizmo.is_inside_tree(): return
	gizmo.show()
	var node: Node3D = nodes[selected]
	var size: Vector3 = Vector3(tabletop_half_size.x*2,tabletop_height,tabletop_half_size.y*2) if selected == "desk" else node.appearance.bounds * node.scale.abs()
	var center: Vector3 = node.to_global(Vector3(0,tabletop_height,0)) if selected == "desk" else node.to_global(Vector3(0,.02,0))
	gizmo.global_position = center
	gizmo.global_rotation.y = node.global_rotation.y
	var outline: MeshInstance3D = gizmo.get_node("Outline")
	outline.scale = Vector3(size.x + .06,size.z + .06,1)
	outline.material_override.set_shader_parameter("line_color",Color("ff756a") if not valid else (Color("ffc563") if contact else Color("61d9ff")))
	var handle_height := 0.0 if selected == "desk" else size.y + .08
	gizmo.get_node("MoveHandles").position.y = handle_height
	gizmo.get_node("RotateHandles").position.y = handle_height
	gizmo.get_node("MoveHandles").visible = tool == "move"
	gizmo.get_node("RotateHandles").visible = tool == "rotate"
	# Hidden tools must not intercept picking.
	for handle in gizmo.find_children("*","CollisionShape3D",true,false):
		handle.disabled = (handle.get_parent().get_parent().name == "MoveHandles") != (tool == "move")
