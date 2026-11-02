extends Node
signal changed
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
const ItemCatalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const BlueprintData = preload("res://scripts/room/room_blueprint_data.gd")
const FURNITURE_COLOR_LABELS := ["原色", "奶油白", "鼠尾草绿", "雾蓝", "暖粉", "浅橡木"]
const FURNITURE_COLOR_HEX := ["", "eae1d4", "a4bdac", "9fbed3", "d9b3b5", "d6b184"]
const NAMES := {"desk":"桌子（整套）", "monitor":"显示器", "computer":"机箱", "keyboard":"键盘", "mouse":"鼠标", "chair":"椅子", "bookcase":"书架", "lamp":"落地灯", "rug":"地毯", "plant":"盆栽"}
@export var tabletop_half_size := Vector2(2.4, 1.15)
@export var tabletop_height := 0.78
@export var edge_margin := 0.025
@export var room_half_size := Vector2(4, 3)
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
var committed_style: Dictionary = {}
var blueprint: Dictionary = BlueprintData.DEFAULT.duplicate(true)
var committed_blueprint: Dictionary = BlueprintData.DEFAULT.duplicate(true)
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var drag_before: Dictionary = {}
var templates: Dictionary = {}
var available_inventory: Array = []
var placed_instances: Dictionary = {}
var committed_placements: Dictionary = {}
var furniture_colors: Dictionary = {}
var committed_colors: Dictionary = {}
var placing_role := ""
var placing_before: Dictionary = {}
var preview_original_materials: Dictionary = {}
var tint_materials: Dictionary = {}

func setup(owner_world: Node3D) -> void:
	world = owner_world
	group = world.get_node("%TableGroup")
	gizmo = world.get_node("%LayoutGizmo")
	nodes = {"desk":group}
	nodes.merge(world.devices)
	for item: Node3D in world.get_node("Room/Furniture").get_children():
		nodes[item.role] = item
		templates[item.role] = load(item.scene_file_path)
	committed_style = world.get_node("Room").style.duplicate()
	blueprint = world.get_node("Room").blueprint.duplicate()
	committed_blueprint = blueprint.duplicate(true)
	authored = snapshot()
	committed = authored.duplicate()
	available_inventory = InventoryData.initial()
	placed_instances = InventoryData.initial_placements()
	committed_placements = placed_instances.duplicate()
	furniture_colors = {}
	committed_colors = {}

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for role: String in nodes: result[role] = nodes[role].transform
	return result

func name_for(role: String) -> String:
	return NAMES.get(Data.base_role(role),role) + (" · " + role.get_slice("_",1) if Data.is_copy(role) else "")

func load_placements(raw: Dictionary, inventory: Array) -> void:
	if active: return
	available_inventory = inventory.duplicate(true)
	placed_instances = raw.duplicate()
	committed_placements = placed_instances.duplicate()
	_apply_furniture_appearance()

func load_colors(raw: Dictionary) -> void:
	if active: return
	furniture_colors.clear()
	for entry: Dictionary in available_inventory:
		var uid := str(entry.uid)
		var value: Variant = raw.get(uid, 0)
		if value is int and int(value) > 0 and int(value) < FURNITURE_COLOR_LABELS.size():
			furniture_colors[uid] = int(value)
	committed_colors = furniture_colors.duplicate()
	_apply_furniture_appearance()

func color_for(role: String) -> int:
	return int(furniture_colors.get(str(placed_instances.get(role, "")), 0))

func set_furniture_color(index: int) -> void:
	if not active or not InventoryData.ROOM_DEFAULTS.has(Data.base_role(selected)): return
	if not placed_instances.has(selected) or index < 0 or index >= FURNITURE_COLOR_LABELS.size(): return
	var before := _draft()
	var uid := str(placed_instances[selected])
	if index == 0: furniture_colors.erase(uid)
	else: furniture_colors[uid] = index
	_apply_furniture_appearance()
	_remember(before)
	update()

func _tint_material(index: int, preview: bool) -> StandardMaterial3D:
	var key := "ghost_valid" if preview and valid else "ghost_invalid" if preview else str(index)
	if tint_materials.has(key): return tint_materials[key]
	var overlay := StandardMaterial3D.new()
	var color := Color("76dbb1") if preview and valid else Color("ec786f") if preview else Color(FURNITURE_COLOR_HEX[index])
	color.a = 0.38 if preview else 0.32
	overlay.albedo_color = color
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint_materials[key] = overlay
	return overlay

func _apply_furniture_appearance() -> void:
	for role: String in nodes:
		if not InventoryData.ROOM_DEFAULTS.has(Data.base_role(role)): continue
		var furniture: Node3D = nodes[role]
		furniture.visible = placed_instances.has(role)
		# Hiding Node3D does not disable its Area3D ray picking volume.
		var pick_area := furniture.get_node_or_null("PickArea") as Area3D
		if pick_area != null: pick_area.collision_layer = 1 if furniture.visible else 0
		var preview := placing_role == role
		var index := color_for(role)
		var overlay: StandardMaterial3D = _tint_material(index, preview) if preview or index != 0 else null
		for mesh: MeshInstance3D in furniture.find_children("*", "MeshInstance3D", true, false):
			var mesh_id := mesh.get_instance_id()
			if preview:
				# GeometryInstance3D.transparency is not supported by Compatibility.
				# A transparent override makes previews genuinely translucent there.
				if not preview_original_materials.has(mesh_id):
					preview_original_materials[mesh_id] = mesh.material_override
				mesh.material_override = overlay
				mesh.material_overlay = null
				mesh.transparency = 0.35
			else:
				if preview_original_materials.has(mesh_id):
					mesh.material_override = preview_original_materials[mesh_id]
					preview_original_materials.erase(mesh_id)
				mesh.material_overlay = overlay
				mesh.transparency = 0.0
	if placing_role.is_empty(): preview_original_materials.clear()

func _next_furniture_role(base_role: String) -> String:
	if not placed_instances.has(base_role): return base_role
	for index in range(1, 9):
		var role := base_role + "_" + str(index)
		if not nodes.has(role): return role
	return ""

func start_place(item_id: String, uid: String) -> bool:
	if not active or not placing_role.is_empty(): return false
	var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
	if item == null or item.category != "furniture" or item.placement_surface != "floor": return false
	var base_role := item.subcategory
	if str(InventoryData.ROOM_DEFAULTS.get(base_role, "")) != item_id: return false
	if placed_instances.values().has(uid): return false
	var owned := false
	for entry: Dictionary in available_inventory:
		if entry.uid == uid and entry.item_id == item_id: owned = true
	if not owned: return false
	var role := _next_furniture_role(base_role)
	if role.is_empty(): return false
	end_drag()
	placing_before = _draft()
	if not nodes.has(role): _create_copy(role)
	placed_instances[role] = uid
	selected = role
	placing_role = role
	nodes[role].transform = authored[base_role]
	update()
	return true

func preview_placement(position_xz: Vector2) -> void:
	if not active or placing_role.is_empty(): return
	var position := position_xz.snapped(Vector2.ONE * grid_step) if snapping else position_xz
	nodes[placing_role].position.x = position.x
	nodes[placing_role].position.z = position.y
	update()

func preview_at(pixel: Vector2) -> void:
	if placing_role.is_empty(): return
	var plane := Plane(world.global_basis.y.normalized(), world.to_global(Vector3.ZERO))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	if hit != null:
		var local: Vector3 = world.to_local(hit)
		preview_placement(Vector2(local.x, local.z))

func confirm_placement() -> bool:
	if placing_role.is_empty() or not valid: return false
	var before := placing_before
	placing_role = ""
	placing_before = {}
	_apply_furniture_appearance()
	_remember(before)
	update()
	return true

func cancel_placement() -> void:
	if placing_role.is_empty(): return
	placing_role = ""
	_restore_draft(placing_before)
	placing_before = {}
	update()

func _create_copy(role: String) -> void:
	if nodes.has(role) or not Data.is_copy(role): return
	var item: Node3D = templates[Data.base_role(role)].instantiate()
	item.role = role
	item.name = role
	world.get_node("Room/Furniture").add_child(item)
	nodes[role] = item
	world.get_node("Room").apply_style(world.get_node("Room").style)

func restore(poses: Dictionary) -> void:
	for role: String in nodes.keys():
		if Data.is_copy(role) and not poses.has(role):
			nodes[role].free()
			nodes.erase(role)
	for role: String in poses:
		_create_copy(role)
		nodes[role].transform = poses[role]
	if not nodes.has(selected): selected = "desk"
	_apply_furniture_appearance()

func duplicate_selected() -> void:
	if not active or not placing_role.is_empty() or not templates.has(Data.base_role(selected)): return
	var furniture_id: String = str(InventoryData.ROOM_DEFAULTS.get(Data.base_role(selected), ""))
	var instance_uid := InventoryData.unused_uid(available_inventory, placed_instances, furniture_id)
	if instance_uid.is_empty():
		message = "没有可用的家具，请先在商店购买"
		changed.emit()
		return
	end_drag()
	var before := _draft()
	var source: Node3D = nodes[selected]
	var role := ""
	for index in range(1,9):
		var candidate := Data.base_role(selected) + "_" + str(index)
		if not nodes.has(candidate):
			role = candidate
			break
	if role.is_empty():
		message = "这类家具最多可复制 8 件"
		changed.emit()
		return
	_create_copy(role)
	var copy: Node3D = nodes[role]
	copy.transform = source.transform
	var found := false
	# Search nearby floor cells; never spawn a copy inside another object.
	for ring in range(1,17):
		for step in range(16):
			var angle := TAU * step / 16.0
			copy.position = source.position + Vector3(cos(angle),0,sin(angle)) * ring * .25
			if _blocker(role,footprint(role,collision_margin)).is_empty():
				found = true
				break
		if found: break
	if not found:
		copy.free()
		nodes.erase(role)
		message = "附近没有足够空间，请先腾出位置"
		changed.emit()
		return
	placed_instances[role] = instance_uid
	selected = role
	_remember(before)
	update()

func delete_selected() -> void:
	store_selected()

func store_selected() -> void:
	if not active or not InventoryData.ROOM_DEFAULTS.has(Data.base_role(selected)): return
	if not placing_role.is_empty() or not placed_instances.has(selected): return
	end_drag()
	var before := _draft()
	placed_instances.erase(selected)
	if Data.is_copy(selected):
		nodes[selected].free()
		nodes.erase(selected)
	else:
		nodes[selected].hide()
	selected = "desk"
	_apply_furniture_appearance()
	_remember(before)
	update()

func load_saved(raw: Variant) -> void:
	if active: return
	var cleaned := Data.clean(raw)
	if cleaned == saved and _layout_blocker().is_empty(): return
	restore(authored)
	for role: String in cleaned:
		_create_copy(role)
		nodes[role].position.x = cleaned[role].x
		nodes[role].position.z = cleaned[role].z
		nodes[role].rotation.y = cleaned[role].yaw
		clamp_pose(role)
	# Older layouts may touch or overlap after a model/bounds change. Keep the
	# table pose, but recover a usable equipment arrangement rather than loading penetration.
	if not _layout_blocker().is_empty():
		for role: String in world.devices: nodes[role].transform = authored[role]
	# Imported legacy table poses may intersect new room furniture or walls.
	# Recover the complete authored room rather than keeping a partially invalid save.
	if not _layout_blocker().is_empty(): restore(authored)
	saved = cleaned
	committed = snapshot()

func export_layout() -> Dictionary:
	var result: Dictionary = {}
	for role: String in nodes:
		var pose: Transform3D = committed[role]
		result[role] = {"x":pose.origin.x, "z":pose.origin.z, "yaw":pose.basis.get_euler().y}
	return result

func load_blueprint(raw: Variant) -> void:
	if active: return
	var next: Dictionary = BlueprintData.clean(raw)
	if next != blueprint:
		blueprint = next
		room_half_size = BlueprintData.half_size(blueprint)
		world.get_node("Room").apply_blueprint(blueprint)
	committed_blueprint = blueprint.duplicate()

func set_blueprint_value(key: String, value: float) -> bool:
	if not active or key not in ["width", "depth", "door_x", "window_z", "notch_width", "notch_depth"] or not is_finite(value): return false
	end_drag()
	var next := blueprint.duplicate(true)
	next[key] = value
	return _apply_blueprint_change(BlueprintData.clean(next))

func set_blueprint_shape(shape: String) -> bool:
	if not active or shape not in ["rectangle", "l"]: return false
	end_drag()
	var next := blueprint.duplicate(true)
	next.shape = shape
	return _apply_blueprint_change(BlueprintData.clean(next))

func _apply_blueprint_change(next: Dictionary) -> bool:
	if next == blueprint: return false
	# Do not drop internal walls when altering the outer boundary.
	if next.partitions.size() != blueprint.partitions.size():
		message = "调整失败：外轮廓将移除已有内墙，请先拆除相关墙段"
		changed.emit()
		return false
	var before := _draft()
	blueprint = next
	room_half_size = BlueprintData.half_size(blueprint)
	world.get_node("Room").apply_blueprint(blueprint)
	var collision := _layout_blocker()
	if collision.is_empty():
		for part: Dictionary in blueprint.partitions:
			if not BlueprintData.inside(blueprint, part):
				collision = "外墙与已有内墙重叠"
				break
	if not collision.is_empty():
		blueprint = before.blueprint.duplicate(true)
		room_half_size = BlueprintData.half_size(blueprint)
		world.get_node("Room").apply_blueprint(blueprint)
		update()
		message = "调整失败：" + collision + "，请先移动、拆除或收回相关物品"
		changed.emit()
		return false
	_remember(before)
	update()
	return true

func add_partition(at: Vector2, axis: String, kind: String = "wall") -> bool:
	if not active or not placing_role.is_empty(): return false
	var part: Dictionary = BlueprintData.clean_partition({
		"x": snappedf(at.x, BlueprintData.WALL_GRID),
		"z": snappedf(at.y, BlueprintData.WALL_GRID),
		"axis": axis, "kind": kind
	})
	var blocker := partition_blocker(part)
	if not blocker.is_empty():
		message = "建造失败：" + blocker
		changed.emit()
		return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	next.partitions.append(part)
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func partition_blocker(part: Dictionary) -> String:
	if part.is_empty(): return "无效墙段"
	if blueprint.partitions.size() >= BlueprintData.MAX_PARTITIONS: return "墙段已达上限"
	if not BlueprintData.inside(blueprint, part): return "墙段超出房间范围"
	for existing: Dictionary in blueprint.partitions:
		if BlueprintData.intersects(existing, part): return "此处已有墙体"
	var shape := BlueprintData.polygon(part, collision_margin)
	for role: String in nodes:
		if not is_floor(role): continue
		if InventoryData.ROOM_DEFAULTS.has(Data.base_role(role)) and not placed_instances.has(role): continue
		# Rugs cannot pass through structural walls either.
		if Data.overlap(shape, footprint(role, collision_margin)):
			return "墙体会穿过" + name_for(role)
	return ""

func remove_partition(at: Vector2) -> bool:
	if not active or blueprint.partitions.is_empty(): return false
	var nearest := -1
	var distance := .34
	for index in range(blueprint.partitions.size()):
		var part: Dictionary = blueprint.partitions[index]
		var extents := BlueprintData.extents(part)
		var delta := Vector2(absf(float(part.x) - at.x), absf(float(part.z) - at.y)) - extents
		var metric := Vector2(maxf(delta.x, 0.0), maxf(delta.y, 0.0)).length()
		if metric < distance:
			nearest = index
			distance = metric
	if nearest == -1: return false
	var before := _draft()
	blueprint.partitions.remove_at(nearest)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func load_style(raw: Variant) -> void:
	if active: return
	world.get_node("Room").apply_style(raw)
	committed_style = world.get_node("Room").style.duplicate()

func _draft() -> Dictionary:
	return {"poses":snapshot(), "style":world.get_node("Room").style.duplicate(), "placements":placed_instances.duplicate(), "colors":furniture_colors.duplicate(), "blueprint":blueprint.duplicate(true)}

func _restore_draft(draft: Dictionary) -> void:
	blueprint = draft.blueprint.duplicate(true)
	room_half_size = BlueprintData.half_size(blueprint)
	world.get_node("Room").apply_blueprint(blueprint)
	restore(draft.poses)
	placed_instances = draft.placements.duplicate()
	furniture_colors = draft.colors.duplicate()
	_apply_furniture_appearance()
	world.get_node("Room").apply_style(draft.style)

func _remember(before: Dictionary) -> void:
	if before == _draft(): return
	undo_stack.append(before)
	if undo_stack.size() > 80: undo_stack.pop_front()
	redo_stack.clear()
	changed.emit()

func undo() -> void:
	if not active: return
	end_drag()
	if undo_stack.is_empty(): return
	redo_stack.append(_draft())
	_restore_draft(undo_stack.pop_back())
	update()

func redo() -> void:
	if not active: return
	end_drag()
	if redo_stack.is_empty(): return
	undo_stack.append(_draft())
	_restore_draft(redo_stack.pop_back())
	update()

func set_style(key: String, value: int) -> void:
	if not active or not committed_style.has(key): return
	var before := _draft()
	var next: Dictionary = world.get_node("Room").style.duplicate()
	next[key] = value
	world.get_node("Room").apply_style(next)
	_remember(before)
	update()

func begin() -> void:
	active = true
	blueprint = committed_blueprint.duplicate(true)
	room_half_size = BlueprintData.half_size(blueprint)
	world.get_node("Room").apply_blueprint(blueprint)
	placing_role = ""
	placing_before = {}
	undo_stack.clear()
	redo_stack.clear()
	selected = "desk"
	gesture = ""
	restore(committed)
	placed_instances = committed_placements.duplicate()
	furniture_colors = committed_colors.duplicate()
	_apply_furniture_appearance()
	update()

func finish(apply: bool) -> bool:
	if not active: return false
	if apply: update()
	if apply and (not valid or not placing_role.is_empty()): return false
	if not placing_role.is_empty(): cancel_placement()
	end_drag()
	if apply:
		committed = snapshot()
		committed_placements = placed_instances.duplicate()
		committed_colors = furniture_colors.duplicate()
		committed_style = world.get_node("Room").style.duplicate()
		committed_blueprint = blueprint.duplicate(true)
		saved = export_layout()
	else:
		restore(committed)
		placed_instances = committed_placements.duplicate()
		furniture_colors = committed_colors.duplicate()
		_apply_furniture_appearance()
		world.get_node("Room").apply_style(committed_style)
		blueprint = committed_blueprint.duplicate(true)
		room_half_size = BlueprintData.half_size(blueprint)
		world.get_node("Room").apply_blueprint(blueprint)
	active = false
	gizmo.hide()
	return true

func select(role: String) -> void:
	if not nodes.has(role) or not placing_role.is_empty(): return
	if InventoryData.ROOM_DEFAULTS.has(Data.base_role(role)) and not placed_instances.has(role): return
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
	var before := _draft()
	restore(authored)
	blueprint = BlueprintData.DEFAULT.duplicate(true)
	room_half_size = BlueprintData.half_size(blueprint)
	world.get_node("Room").apply_blueprint(blueprint)
	placed_instances = InventoryData.initial_placements()
	furniture_colors.clear()
	_apply_furniture_appearance()
	world.get_node("Room").apply_style({})
	_remember(before)
	update()

func footprint(role: String, padding: float = 0.0) -> PackedVector2Array:
	return _footprint_at(role, nodes[role].transform, padding)

func _footprint_at(role: String, pose: Transform3D, padding: float) -> PackedVector2Array:
	var size: Vector3 = bounds_for(role) + Vector3(padding * 2, 0, padding * 2)
	var result := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var point: Vector3 = pose * Vector3(corner.x * size.x/2, 0, corner.y * size.z/2)
		result.append(Vector2(point.x, point.z))
	return result

func surface_for(role: String) -> String:
	return "desk" if world.devices.has(role) else "floor"

func is_floor(role: String) -> bool:
	return surface_for(role) == "floor"

func bounds_for(role: String) -> Vector3:
	if role == "desk": return Vector3(tabletop_half_size.x*2, tabletop_height, tabletop_half_size.y*2)
	if world.devices.has(role): return nodes[role].appearance.bounds
	return nodes[role].bounds

func is_blocking(role: String) -> bool:
	return role == "desk" or world.devices.has(role) or nodes[role].blocking

func clamp_pose(role: String) -> void:
	var node: Node3D = nodes[role]
	node.position.y = (authored.get(Data.base_role(role), Transform3D.IDENTITY) as Transform3D).origin.y if is_floor(role) else tabletop_height
	var corners := footprint(role, collision_margin)
	var extent := Vector2.ZERO
	for point in corners: extent = extent.max((point - Vector2(node.position.x,node.position.z)).abs())
	var limits := room_half_size if is_floor(role) else tabletop_half_size
	var allowance := (limits - extent - Vector2.ONE * edge_margin).max(Vector2.ZERO)
	node.position.x = clampf(node.position.x, -allowance.x, allowance.x)
	node.position.z = clampf(node.position.z, -allowance.y, allowance.y)

func move_to(position_xz: Vector2) -> void:
	if not active: return
	if not placing_role.is_empty():
		preview_placement(position_xz)
		return
	var undo_before := _draft()
	var before: Transform3D = nodes[selected].transform
	var point := position_xz
	if snapping: point = point.snapped(Vector2.ONE * grid_step)
	nodes[selected].position.x = point.x
	nodes[selected].position.z = point.y
	clamp_pose(selected)
	_constrain_motion(before, nodes[selected].transform)
	if gesture.is_empty(): _remember(undo_before)

func rotate_to(yaw: float) -> void:
	if not active: return
	if not placing_role.is_empty():
		nodes[placing_role].rotation.y = wrapf(snappedf(yaw, deg_to_rad(angle_step)) if snapping else yaw, -PI, PI)
		update()
		return
	var undo_before := _draft()
	var before: Transform3D = nodes[selected].transform
	if snapping: yaw = snappedf(yaw, deg_to_rad(angle_step))
	nodes[selected].rotation.y = wrapf(yaw, -PI, PI)
	clamp_pose(selected)
	_constrain_motion(before, nodes[selected].transform)
	if gesture.is_empty(): _remember(undo_before)

func _blocker(role: String, polygon: PackedVector2Array) -> String:
	var floor_item := is_floor(role)
	if floor_item:
		if not BlueprintData.footprint_inside(blueprint, polygon, edge_margin):
			return name_for(role) + "到达房间边界"
	else:
		for point in polygon:
			if absf(point.x) > tabletop_half_size.x - edge_margin + .002 or absf(point.y) > tabletop_half_size.y - edge_margin + .002:
				return name_for(role) + "到达桌沿"
	if not is_blocking(role): return ""
	if floor_item:
		for part: Dictionary in blueprint.partitions:
			if Data.overlap(polygon, BlueprintData.polygon(part, collision_margin)):
				return name_for(role) + "碰到内墙"
	for other: String in nodes:
		if other == role or is_floor(other) != floor_item or not is_blocking(other): continue
		if InventoryData.ROOM_DEFAULTS.has(Data.base_role(other)) and not placed_instances.has(other): continue
		if Data.overlap(polygon, footprint(other, collision_margin)):
			return name_for(role) + "碰到" + name_for(other)
	return ""

func _layout_blocker() -> String:
	# Desktop hardware must stay under the table's Equipment node. It is
	# never a free floor item, even when a save or caller bypasses the UI.
	for role: String in world.devices:
		if nodes[role].get_parent() != world.get_node("%Equipment"):
			return name_for(role) + "必须放在电脑桌上"
	for role: String in nodes:
		if InventoryData.ROOM_DEFAULTS.has(Data.base_role(role)) and not placed_instances.has(role): continue
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
	var frame: Node3D = world if is_floor(selected) else group
	var height := drag_height
	var plane := Plane(frame.global_basis.y.normalized(), frame.to_global(Vector3(0,height,0)))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	return frame.to_local(hit) if hit != null else null

func begin_drag(pixel: Vector2, operation: String = "move", direction: String = "plane", from_handle: bool = false) -> void:
	if not active: return
	var node: Node3D = nodes[selected]
	drag_height = node.position.y + bounds_for(selected).y * .5
	if from_handle:
		var handles: Node3D = gizmo.get_node("MoveHandles" if operation == "move" else "RotateHandles")
		var frame: Node3D = world if is_floor(selected) else group
		drag_height = frame.to_local(handles.to_global(Vector3(0,.05,0))).y
	var hit: Variant = _plane_point(pixel)
	if hit == null: return
	drag_before = _draft()
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
	if not gesture.is_empty() and not drag_before.is_empty(): _remember(drag_before)
	gesture = ""
	drag_before = {}

func pick_handle(pixel: Vector2) -> String:
	var origin: Vector3 = world.camera.project_ray_origin(pixel)
	var query := PhysicsRayQueryParameters3D.create(origin,origin + world.camera.project_ray_normal(pixel)*40,2)
	query.collide_with_areas = true
	var result := world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(result.collider.get_meta("operation", "")) if not result.is_empty() else ""

func update(contact: String = "") -> void:
	var blocker := _layout_blocker()
	valid = blocker.is_empty()
	if not placing_role.is_empty(): _apply_furniture_appearance()
	message = "右键环绕 · 滚轮缩放 · 拖动物品布置房间"
	if not placing_role.is_empty():
		message = "鼠标移动预览 · 左键放置 · 右键/Esc 取消"
	if not valid: message = blocker + "，请选择其他位置" if not placing_role.is_empty() else blocker + "，请调整位置或恢复默认布置"
	elif not contact.is_empty(): message = "已阻挡：" + contact
	_update_gizmo(not contact.is_empty())
	changed.emit()

func _update_gizmo(contact: bool = false) -> void:
	if not active or not gizmo.is_inside_tree(): return
	gizmo.show()
	var node: Node3D = nodes[selected]
	var size := bounds_for(selected) * node.scale.abs()
	# Raise floor outlines above rugs so selected furniture remains readable.
	var base_height := .06 if is_floor(selected) else .02
	var center: Vector3 = node.to_global(Vector3(0,tabletop_height,0)) if selected == "desk" else node.to_global(Vector3(0,base_height,0))
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
