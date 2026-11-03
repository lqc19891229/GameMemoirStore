extends Node
signal changed
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
const ItemCatalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const BlueprintData = preload("res://scripts/room/room_blueprint_data.gd")
const Finishes = preload("res://scripts/items/furniture_finishes.gd")
const FURNITURE_COLOR_LABELS = Finishes.LABELS
const FURNITURE_COLOR_HEX = Finishes.HEX
const NAMES := {"desk":"桌子（整套）", "monitor":"显示器", "computer":"机箱", "keyboard":"键盘", "mouse":"鼠标", "chair":"椅子", "bookcase":"书架", "lamp":"落地灯", "rug":"地毯", "plant":"盆栽", "sofa":"双人沙发", "stool":"软垫矮凳"}
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
# Editor-only multi-selection; persisted poses and inventory contracts stay unchanged.
var group_selection: Array[String] = []
var group_markers: Dictionary = {}
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
var aperture_drag_before: Dictionary = {}
var edge_drag_before: Dictionary = {}
var edge_drag_source: Dictionary = {}
var wall_stroke_before: Dictionary = {}
var wall_snap := false
var inner_wall_snap := false
# Ephemeral editing affordance: a wall magnet during direct dragging and
# first placement. Explicit wall snap toggles retain their previous behavior.
var smart_snap := true
var snap_bypass := false
var wall_magnet_active := false
const WALL_SNAP_RADIUS := .32
const ALIGN_RADIUS := .65
const WALL_SAFE_GAP := .045
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
	for item in ItemCatalog.items:
		if item.category == "furniture" and item.furniture_scene != null and not item.retired:
			if not templates.has(item.subcategory): templates[item.subcategory] = item.furniture_scene
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
	var base: String = Data.base_role(role)
	var item: MemoirItemDefinition = ItemCatalog.item_for_placement_role(base)
	var label: String = NAMES.get(base,item.name if item != null else base)
	return label + (" · " + role.substr(role.rfind("_")+1) if Data.is_copy(role) else "")

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
	if not active or not InventoryData.is_room_furniture_role(Data.base_role(selected)): return
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
	var overlay: StandardMaterial3D = StandardMaterial3D.new() if preview else Finishes.overlay(index)
	if preview:
		var color := Color("76dbb1") if valid else Color("ec786f")
		color.a = 0.38
		overlay.albedo_color = color
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint_materials[key] = overlay
	return overlay

func _apply_furniture_appearance() -> void:
	for role: String in nodes:
		if not InventoryData.is_room_furniture_role(Data.base_role(role)): continue
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

func _next_furniture_role(base_role: String, uid: String) -> String:
	# Replacing the original free starter piece keeps legacy room keys stable.
	# All newly purchased pieces use their inventory UID as an unlimited key.
	if authored.has(base_role) and not placed_instances.has(base_role):
		if InventoryData.initial_placements().get(base_role, "") == uid:
			return base_role
	return Data.instance_role(base_role, uid)

func start_place(item_id: String, uid: String) -> bool:
	if not active or not placing_role.is_empty(): return false
	var item: MemoirItemDefinition = ItemCatalog.lookup(item_id)
	if item == null or item.category != "furniture" or item.placement_surface != "floor": return false
	var base_role := item.subcategory
	if ItemCatalog.item_for_placement_role(base_role) != item: return false
	if placed_instances.values().has(uid): return false
	var owned := false
	for entry: Dictionary in available_inventory:
		if entry.uid == uid and entry.item_id == item_id: owned = true
	if not owned: return false
	var role := _next_furniture_role(base_role, uid)
	if role.is_empty(): return false
	end_drag()
	group_selection.clear()
	placing_before = _draft()
	if not nodes.has(role): _create_copy(role)
	placed_instances[role] = uid
	selected = role
	placing_role = role
	nodes[role].transform = authored.get(base_role, Transform3D.IDENTITY)
	update()
	return true

func preview_placement(position_xz: Vector2) -> void:
	if not active or placing_role.is_empty(): return
	var position := position_xz.snapped(Vector2.ONE * grid_step) if snapping else position_xz
	position = _wall_snap_point(placing_role,position)
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
	wall_magnet_active = false
	snap_bypass = false
	placing_role = ""
	placing_before = {}
	_apply_furniture_appearance()
	_remember(before)
	update()
	return true

func cancel_placement() -> void:
	if placing_role.is_empty(): return
	wall_magnet_active = false
	snap_bypass = false
	placing_role = ""
	_restore_draft(placing_before)
	placing_before = {}
	update()

func _create_copy(role: String) -> void:
	if nodes.has(role) or not Data.valid_role(role) or not templates.has(Data.base_role(role)): return
	var item: Node3D = templates[Data.base_role(role)].instantiate()
	item.role = role
	item.name = role
	world.get_node("Room/Furniture").add_child(item)
	nodes[role] = item
	world.get_node("Room").apply_style(world.get_node("Room").style)

func restore(poses: Dictionary) -> void:
	for role: String in nodes.keys():
		if not authored.has(role) and not poses.has(role):
			nodes[role].free()
			nodes.erase(role)
	for role: String in poses:
		_create_copy(role)
		nodes[role].transform = poses[role]
	if not nodes.has(selected): selected = "desk"
	_apply_furniture_appearance()

func duplicate_selected() -> void:
	if not active or not placing_role.is_empty() or group_selection.size() > 1 or not templates.has(Data.base_role(selected)): return
	var furniture_id: String = InventoryData.furniture_item_id(Data.base_role(selected))
	var instance_uid := InventoryData.unused_uid(available_inventory, placed_instances, furniture_id)
	if instance_uid.is_empty():
		message = "没有可用的家具，请先在商店购买"
		changed.emit()
		return
	end_drag()
	var before := _draft()
	var source: Node3D = nodes[selected]
	var role := _next_furniture_role(Data.base_role(selected), instance_uid)
	if role.is_empty() or nodes.has(role):
		message = "这件家具的库存实例标识无效"
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
	group_selection = [role]
	_remember(before)
	update()

func delete_selected() -> void:
	store_selected()

func store_selected() -> void:
	if not active or group_selection.size() > 1 or not InventoryData.is_room_furniture_role(Data.base_role(selected)): return
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
	group_selection.clear()
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
	if not active or shape not in ["rectangle", "l", "custom"]: return false
	end_drag()
	var next := blueprint.duplicate(true)
	next.shape = shape
	next.removed_cells = []
	# Existing L-shaped edits convert losslessly to removed grid cells.
	if shape == "custom" and blueprint.shape == "l":
		var size := BlueprintData.cell_count(next)
		for iz in range(size.y):
			for ix in range(size.x):
				if float(ix) * BlueprintData.FLOOR_GRID >= float(next.width) - float(next.notch_width) and float(iz) * BlueprintData.FLOOR_GRID >= float(next.depth) - float(next.notch_depth):
					next.removed_cells.append({"ix":ix,"iz":iz})
	return _apply_blueprint_change(BlueprintData.clean(next))

func _apply_blueprint_change(next: Dictionary, remember: bool = true) -> bool:
	if next == blueprint: return false
	# Do not drop internal walls when altering the outer boundary.
	if (next.partitions.size() != blueprint.partitions.size()
		or (next.shape == "custom" and blueprint.shape == "custom" and next.removed_cells.size() != blueprint.removed_cells.size())
		or next.floor_finishes.size() != blueprint.floor_finishes.size()
		or next.edge_finishes.size() != blueprint.edge_finishes.size()
		or next.zone_cells.size() != blueprint.zone_cells.size()
		or next.saved_schemes != blueprint.saved_schemes):
		message = "调整失败：外轮廓将移除已有内墙或地板单元，请先调整结构"
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
	if remember: _remember(before)
	update()
	return true

func begin_aperture_drag() -> void:
	if not active: return
	if not aperture_drag_before.is_empty(): return
	end_drag()
	aperture_drag_before = _draft()

func drag_aperture(key: String, value: float) -> bool:
	if not active or aperture_drag_before.is_empty(): return false
	if key not in ["door_x","window_z"] or not is_finite(value): return false
	var next := blueprint.duplicate(true)
	next[key] = snappedf(value,.05)
	return _apply_blueprint_change(BlueprintData.clean(next), false)

func end_aperture_drag(cancel: bool = false) -> void:
	if aperture_drag_before.is_empty(): return
	var before: Dictionary = aperture_drag_before
	aperture_drag_before = {}
	if cancel:
		_restore_draft(before)
	else:
		_remember(before)
	update()

func begin_custom_edge_drag(at: Vector2) -> bool:
	if not active or blueprint.shape != "custom" or not edge_drag_before.is_empty(): return false
	var source: Dictionary = BlueprintData.nearest_edge(blueprint,at,.28)
	if source.is_empty(): return false
	var record: Dictionary = BlueprintData.edge_edit(blueprint,source)
	if str(record.kind) not in ["door","window"]: return false
	end_drag()
	edge_drag_before = _draft()
	edge_drag_source = source.duplicate()
	return true

func edge_drag_blocker(at: Vector2) -> String:
	if edge_drag_before.is_empty() or edge_drag_source.is_empty(): return "请先选中已有门洞或窗户"
	var base: Dictionary = edge_drag_before.blueprint
	var target: Dictionary = BlueprintData.nearest_edge(base,at,.36)
	if target.is_empty(): return "目标不在可用外墙段"
	if not BlueprintData.same_edge(target,edge_drag_source):
		for entry: Dictionary in base.edge_finishes:
			if BlueprintData.same_edge(entry,target):
				return "目标外墙已设置门窗或独立颜色"
	return ""

func drag_custom_edge_to(at: Vector2) -> bool:
	var reason := edge_drag_blocker(at)
	if not reason.is_empty():
		message = "移动失败：" + reason
		changed.emit()
		return false
	var base: Dictionary = edge_drag_before.blueprint
	var target: Dictionary = BlueprintData.nearest_edge(base,at,.36)
	var original: Dictionary = BlueprintData.edge_edit(base,edge_drag_source)
	if BlueprintData.same_edge(edge_drag_source,target) and blueprint == base: return false
	var next: Dictionary = base.duplicate(true)
	var kept: Array = []
	for entry: Dictionary in base.edge_finishes:
		if not BlueprintData.same_edge(entry,edge_drag_source): kept.append(entry.duplicate(true))
	if not BlueprintData.same_edge(target,edge_drag_source):
		kept.append({"ix":target.ix,"iz":target.iz,"dx":target.dx,"dz":target.dz,
			"kind":original.kind,"finish":original.finish})
	else:
		kept.append(original.duplicate(true))
	next.edge_finishes = kept
	next = BlueprintData.clean(next)
	if next.edge_finishes.size() != base.edge_finishes.size(): return false
	blueprint = next
	world.get_node("Room").apply_blueprint(blueprint)
	update()
	return true

func end_custom_edge_drag(cancel: bool = false) -> void:
	if edge_drag_before.is_empty(): return
	var before: Dictionary = edge_drag_before
	edge_drag_before = {}
	edge_drag_source = {}
	if cancel: _restore_draft(before)
	else: _remember(before)
	update()

func floor_cell_blocker(cell: Dictionary, removing: bool = true) -> String:
	if not active or blueprint.shape != "custom": return "请先选择自定义户型"
	if not BlueprintData.valid_cell(blueprint, cell): return "超出房间范围"
	if removing:
		if BlueprintData.has_cell(blueprint, cell): return "此处已经移除地板"
		if BlueprintData.floor_finish(blueprint, cell) != 0: return "请先将此地板恢复默认材质"
		if BlueprintData.zone_at(blueprint, cell) != 0: return "请先清除此地板的功能分区"
		for scheme: Dictionary in blueprint.saved_schemes:
			for stored: Dictionary in scheme.zone_cells:
				if stored.ix == cell.ix and stored.iz == cell.iz:
					return "此格已用于保存的装修方案，请先覆盖或删除相应方案"
		if not BlueprintData.editable_cell(blueprint, cell): return "门窗所在的后墙和左墙必须保留地板"
		if blueprint.removed_cells.size() >= BlueprintData.MAX_REMOVED: return "可移除地板已达到上限"
		var shape := BlueprintData.cell_polygon(blueprint, cell, collision_margin)
		for role: String in nodes:
			if not is_floor(role): continue
			if InventoryData.is_room_furniture_role(Data.base_role(role)) and not placed_instances.has(role): continue
			if Data.overlap(shape, footprint(role, collision_margin)):
				return "该地板上已有" + name_for(role)
		for part: Dictionary in blueprint.partitions:
			if Data.overlap(shape, BlueprintData.polygon(part, collision_margin)):
				return "该地板上已有内墙"
		var trial := blueprint.duplicate(true)
		trial.removed_cells.append(cell)
		if not BlueprintData.floor_connected(trial): return "不能将房间分成不相连的地板区域"
	elif not BlueprintData.has_cell(blueprint, cell):
		return "此处已有地板"
	return ""

func paint_floor_cell(at: Vector2, removing: bool = true) -> bool:
	if not active or not placing_role.is_empty(): return false
	var cell: Dictionary = BlueprintData.cell_at(blueprint, at)
	var reason := floor_cell_blocker(cell, removing)
	if not reason.is_empty():
		message = "绘制失败：" + reason
		changed.emit()
		return false
	end_drag()
	var before := _draft()
	var next := blueprint.duplicate(true)
	if removing: next.removed_cells.append(cell)
	else: next.removed_cells.erase(cell)
	next = BlueprintData.clean(next)
	if next.edge_finishes.size() != blueprint.edge_finishes.size() or next.zone_cells.size() != blueprint.zone_cells.size() or next.saved_schemes != blueprint.saved_schemes:
		message = "绘制失败：此操作会移除已有外墙装修或功能分区，请先恢复相关配置"
		changed.emit()
		return false
	blueprint = next
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func fill_room_region(at: Vector2, zone: int) -> int:
	if not active or blueprint.shape != "custom" or not placing_role.is_empty(): return 0
	if zone < 0 or zone > BlueprintData.ZONE_PRESETS.size(): return 0
	var region: Array = BlueprintData.room_region_at(blueprint, at)
	if region.is_empty(): return 0
	var existing: Dictionary = {}
	for entry: Dictionary in blueprint.zone_cells:
		existing[Vector2i(int(entry.ix),int(entry.iz))] = entry
	var changed_cells := 0
	for cell: Dictionary in region:
		if BlueprintData.zone_at(blueprint,cell) != zone: changed_cells += 1
	if changed_cells == 0: return 0
	var before := _draft()
	for cell: Dictionary in region:
		var key := Vector2i(int(cell.ix),int(cell.iz))
		existing.erase(key)
		if zone > 0:
			existing[key] = {"ix":cell.ix,"iz":cell.iz,"zone":zone}
	var next := blueprint.duplicate(true)
	next.zone_cells = existing.values()
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return changed_cells

func save_decor_scheme(slot: int) -> bool:
	if not active or blueprint.shape != "custom" or slot < 0 or slot >= BlueprintData.MAX_SCHEMES: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var saved_schemes := []
	for entry: Dictionary in next.saved_schemes:
		if int(entry.slot) != slot: saved_schemes.append(entry)
	saved_schemes.append({"slot":slot,
		"zone_cells":next.zone_cells.duplicate(true),
		"zone_styles":next.zone_styles.duplicate(true),
		"floor_finishes":next.floor_finishes.duplicate(true)})
	next.saved_schemes = saved_schemes
	blueprint = BlueprintData.clean(next)
	if before.blueprint == blueprint: return false
	_remember(before)
	update()
	return true

func load_decor_scheme(slot: int) -> bool:
	if not active or blueprint.shape != "custom": return false
	var scheme: Dictionary = BlueprintData.scheme_for_slot(blueprint,slot)
	if scheme.is_empty(): return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	next.zone_cells = scheme.zone_cells.duplicate(true)
	next.zone_styles = scheme.zone_styles.duplicate(true)
	next.floor_finishes = scheme.floor_finishes.duplicate(true)
	blueprint = BlueprintData.clean(next)
	if before.blueprint == blueprint: return false
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func clear_decor_scheme(slot: int) -> bool:
	if not active or slot < 0 or slot >= BlueprintData.MAX_SCHEMES: return false
	if BlueprintData.scheme_for_slot(blueprint,slot).is_empty(): return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var keep := []
	for entry: Dictionary in next.saved_schemes:
		if int(entry.slot) != slot: keep.append(entry)
	next.saved_schemes = keep
	blueprint = BlueprintData.clean(next)
	_remember(before)
	update()
	return true

func paint_zone_cell(at: Vector2, zone: int) -> bool:
	if not active or blueprint.shape != "custom" or not placing_role.is_empty(): return false
	if zone < 0 or zone > BlueprintData.ZONE_PRESETS.size(): return false
	var cell: Dictionary = BlueprintData.cell_at(blueprint, at)
	if not BlueprintData.valid_cell(blueprint, cell) or BlueprintData.has_cell(blueprint, cell): return false
	if BlueprintData.zone_at(blueprint, cell) == zone: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var entries := []
	for entry: Dictionary in next.zone_cells:
		if entry.ix != cell.ix or entry.iz != cell.iz: entries.append(entry)
	if zone > 0:
		entries.append({"ix":cell.ix,"iz":cell.iz,"zone":zone})
	next.zone_cells = entries
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func set_zone_style(zone: int, key: String, value: int) -> bool:
	if not active or zone < 1 or zone > BlueprintData.ZONE_PRESETS.size(): return false
	if key not in ["floor","wall","light"]: return false
	if value < 0 or value >= (3 if key == "light" else BlueprintData.FINISH_COUNT): return false
	var old: Dictionary = BlueprintData.zone_style(blueprint, zone)
	if int(old[key]) == value: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var config: Dictionary = next.zone_styles[zone-1]
	config[key] = value
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func apply_zone_preset(zone: int, preset: int) -> bool:
	if not active or zone < 1 or zone > BlueprintData.ZONE_PRESETS.size(): return false
	if preset < 0 or preset >= BlueprintData.ZONE_PRESETS.size(): return false
	var target: Dictionary = BlueprintData.ZONE_PRESETS[preset]
	if BlueprintData.zone_style(blueprint, zone) == target: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	next.zone_styles[zone-1] = target.duplicate()
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func paint_floor_finish(at: Vector2, finish: int) -> bool:
	if not active or blueprint.shape != "custom": return false
	if finish < 0 or finish >= BlueprintData.FINISH_COUNT: return false
	var cell: Dictionary = BlueprintData.cell_at(blueprint, at)
	if not BlueprintData.valid_cell(blueprint, cell) or BlueprintData.has_cell(blueprint, cell): return false
	if BlueprintData.floor_finish(blueprint, cell) == finish: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var retained := []
	for entry: Dictionary in next.floor_finishes:
		if entry.ix != cell.ix or entry.iz != cell.iz:
			retained.append(entry)
	if finish > 0:
		retained.append({"ix":cell.ix, "iz":cell.iz, "finish":finish})
	next.floor_finishes = retained
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func exterior_span_blocker(at: Vector2, count: int, kind: String, finish: int) -> String:
	if not active or blueprint.shape != "custom": return "需要自定义房间"
	if kind not in ["wall","door","window"] or finish < 0 or finish >= BlueprintData.FINISH_COUNT: return "门窗类型或材质无效"
	var edge: Dictionary = BlueprintData.nearest_edge(blueprint,at)
	if edge.is_empty(): return "未选择外墙段"
	var span: Array = BlueprintData.edge_span(blueprint,edge,count)
	if span.size() != count: return "外墙不足 %.1f 米连续长度" % (float(count)*BlueprintData.FLOOR_GRID)
	for item: Dictionary in span:
		var previous: Dictionary = BlueprintData.edge_edit(blueprint,item)
		if int(previous.finish) > 0 or str(previous.kind) != "wall":
			if str(previous.kind) != kind or int(previous.finish) != finish:
				return "目标墙段已有独立门窗或配色"
	return ""

func paint_exterior_span(at: Vector2, count: int, kind: String, finish: int) -> bool:
	var reason := exterior_span_blocker(at,count,kind,finish)
	if not reason.is_empty():
		message = "绘制失败：" + reason
		changed.emit()
		return false
	var edge: Dictionary = BlueprintData.nearest_edge(blueprint,at)
	var span: Array = BlueprintData.edge_span(blueprint,edge,count)
	var next := blueprint.duplicate(true)
	var changes := 0
	for item: Dictionary in span:
		var previous: Dictionary = BlueprintData.edge_edit(blueprint,item)
		if previous.kind == kind and int(previous.finish) == finish: continue
		changes += 1
		if kind != "wall" or finish > 0:
			next.edge_finishes.append({"ix":item.ix,"iz":item.iz,"dx":item.dx,"dz":item.dz,
				"kind":kind,"finish":finish})
	if changes == 0: return false
	var before := _draft()
	next = BlueprintData.clean(next)
	if next.edge_finishes.size() != blueprint.edge_finishes.size()+changes:
		return false
	blueprint = next
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func paint_exterior_edge(at: Vector2, kind: String, finish: int) -> bool:
	if not active or blueprint.shape != "custom": return false
	if kind not in ["wall", "window", "door"] or finish < 0 or finish >= BlueprintData.FINISH_COUNT: return false
	var edge: Dictionary = BlueprintData.nearest_edge(blueprint, at)
	if edge.is_empty(): return false
	var existing: Dictionary = BlueprintData.edge_edit(blueprint, edge)
	if existing.kind == kind and int(existing.finish) == finish: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var retained := []
	for entry: Dictionary in next.edge_finishes:
		if not BlueprintData.same_edge(entry, edge): retained.append(entry)
	if kind != "wall" or finish > 0:
		retained.append({"ix":edge.ix, "iz":edge.iz, "dx":edge.dx, "dz":edge.dz,
			"kind":kind, "finish":finish})
	next.edge_finishes = retained
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func paint_partition_finish(at: Vector2, finish: int) -> bool:
	if not active or finish < 0 or finish >= BlueprintData.FINISH_COUNT: return false
	var nearest := -1
	var distance := .36
	for index in range(blueprint.partitions.size()):
		var part: Dictionary = blueprint.partitions[index]
		var metric := Vector2(float(part.x), float(part.z)).distance_to(at)
		if metric < distance:
			distance = metric
			nearest = index
	if nearest < 0: return false
	if int(blueprint.partitions[nearest].get("finish", 0)) == finish: return false
	var before := _draft()
	var next := blueprint.duplicate(true)
	var part: Dictionary = next.partitions[nearest]
	if finish == 0: part.erase("finish")
	else: part["finish"] = finish
	blueprint = BlueprintData.clean(next)
	world.get_node("Room").apply_blueprint(blueprint)
	_remember(before)
	update()
	return true

func begin_wall_stroke() -> void:
	if not active or not wall_stroke_before.is_empty(): return
	end_drag()
	wall_stroke_before = _draft()

func end_wall_stroke(cancel: bool = false) -> void:
	if wall_stroke_before.is_empty(): return
	var before: Dictionary = wall_stroke_before
	wall_stroke_before = {}
	if cancel: _restore_draft(before)
	else: _remember(before)
	update()

func set_wall_snap(enabled: bool) -> void:
	wall_snap = enabled
	update()

func set_inner_wall_snap(enabled: bool) -> void:
	inner_wall_snap = enabled
	update()

func inner_wall_clearance(role: String = "") -> float:
	if role.is_empty(): role = selected
	if not nodes.has(role) or not is_floor(role): return -1.0
	var shape: PackedVector2Array = footprint(role)
	var mins := Vector2(INF,INF)
	var maxs := Vector2(-INF,-INF)
	for point: Vector2 in shape:
		mins = mins.min(point)
		maxs = maxs.max(point)
	var closest := INF
	for part: Dictionary in blueprint.partitions:
		if str(part.kind) == "door": continue
		var e: Vector2 = BlueprintData.extents(part)
		if part.axis == "x":
			if maxs.x < float(part.x)-e.x or mins.x > float(part.x)+e.x: continue
			closest = minf(closest,maxf(0.0,maxf(float(part.z)-e.y-maxs.y,mins.y-float(part.z)-e.y)))
		else:
			if maxs.y < float(part.z)-e.y or mins.y > float(part.z)+e.y: continue
			closest = minf(closest,maxf(0.0,maxf(float(part.x)-e.x-maxs.x,mins.x-float(part.x)-e.x)))
	return closest if is_finite(closest) else -1.0

func wall_clearance(role: String = "") -> float:
	if role.is_empty(): role = selected
	if not nodes.has(role) or not is_floor(role): return -1.0
	var footprint2: PackedVector2Array = footprint(role)
	var left := INF
	var right := -INF
	var back := INF
	var front := -INF
	for point: Vector2 in footprint2:
		left = minf(left,point.x)
		right = maxf(right,point.x)
		back = minf(back,point.y)
		front = maxf(front,point.y)
	var limits: Vector2 = BlueprintData.half_size(blueprint)
	return maxf(0.0,minf(minf(left+limits.x,limits.x-right),minf(back+limits.y,limits.y-front)))

func _wall_snap_point(role: String, target: Vector2) -> Vector2:
	wall_magnet_active = false
	if not is_floor(role): return target
	var temporary_magnet := smart_snap and not snap_bypass and (role == placing_role or (role == selected and gesture == "move"))
	var snap_exterior := not snap_bypass and (wall_snap or temporary_magnet)
	var snap_interior := not snap_bypass and (inner_wall_snap or temporary_magnet)
	if not snap_exterior and not snap_interior: return target
	var node: Node3D = nodes[role]
	var pose: Transform3D = node.transform
	pose.origin.x = target.x
	pose.origin.z = target.y
	var shape: PackedVector2Array = _footprint_at(role,pose,0.0)
	var mins := Vector2(INF,INF)
	var maxs := Vector2(-INF,-INF)
	for point: Vector2 in shape:
		mins = mins.min(point)
		maxs = maxs.max(point)
	var candidates: Array[Vector2] = []
	if snap_exterior:
		var half: Vector2 = BlueprintData.half_size(blueprint)
		for axis_id in range(2):
			for direction in [-1.0,1.0]:
				var delta: float
				if axis_id == 0:
					delta = (-half.x + edge_margin + collision_margin + .015 - mins.x) if direction < 0 else half.x - edge_margin - collision_margin - .015 - maxs.x
				else:
					delta = (-half.y + edge_margin + collision_margin + .015 - mins.y) if direction < 0 else half.y - edge_margin - collision_margin - .015 - maxs.y
				if absf(delta) <= WALL_SNAP_RADIUS:
					candidates.append(target + (Vector2(delta,0) if axis_id == 0 else Vector2(0,delta)))
	if snap_interior:
		for part: Dictionary in blueprint.partitions:
			if str(part.kind) == "door": continue
			var extents: Vector2 = BlueprintData.extents(part)
			for direction in [-1.0,1.0]:
				var displacement: float
				var candidate: Vector2
				if part.axis == "x":
					if maxs.x < float(part.x)-extents.x or mins.x > float(part.x)+extents.x: continue
					displacement = (float(part.z)-extents.y-WALL_SAFE_GAP-maxs.y) if direction < 0 else (float(part.z)+extents.y+WALL_SAFE_GAP-mins.y)
					candidate = target + Vector2(0,displacement)
				else:
					if maxs.y < float(part.z)-extents.y or mins.y > float(part.z)+extents.y: continue
					displacement = (float(part.x)-extents.x-WALL_SAFE_GAP-maxs.x) if direction < 0 else (float(part.x)+extents.x+WALL_SAFE_GAP-mins.x)
					candidate = target + Vector2(displacement,0)
				if absf(displacement) <= WALL_SNAP_RADIUS: candidates.append(candidate)
	if candidates.is_empty(): return target
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_to(target) < b.distance_to(target))
	for candidate: Vector2 in candidates:
		pose.origin.x = candidate.x
		pose.origin.z = candidate.y
		if _blocker(role,_footprint_at(role,pose,collision_margin)).is_empty():
			wall_magnet_active = true
			return candidate
	return target

func _matching_furniture(role: String) -> Array[String]:
	var peers: Array[String] = []
	if not nodes.has(role) or not is_floor(role) or not placed_instances.has(role): return peers
	var category: String = Data.base_role(role)
	for other: String in nodes:
		if is_floor(other) and placed_instances.has(other) and Data.base_role(other) == category:
			peers.append(other)
	return peers

func furniture_spacing_summary(role: String = "") -> String:
	if role.is_empty(): role = selected
	var peers: Array[String] = _matching_furniture(role)
	if peers.size() < 2: return "同类家具不足 2 件，无法计算等距参考"
	var details: Array[String] = []
	for dimension in ["x","z"]:
		var values: Array[float] = []
		for peer: String in peers:
			values.append(float(nodes[peer].position.x if dimension == "x" else nodes[peer].position.z))
		values.sort()
		var minimum := INF
		var maximum := 0.0
		for index in range(1,values.size()):
			var gap: float = values[index] - values[index-1]
			minimum = minf(minimum,gap)
			maximum = maxf(maximum,gap)
		details.append("%s 中心距 %.2f–%.2f 米" % [dimension.to_upper(),minimum,maximum])
	return "%d 件同类家具 · %s" % [peers.size()," · ".join(details)]

func nearest_alignment(role: String, dimension: String) -> Dictionary:
	if dimension not in ["x","z"] or not nodes.has(role) or not is_floor(role): return {}
	var node: Node3D = nodes[role]
	var current := Vector2(node.position.x,node.position.z)
	var best := {}
	var nearest := ALIGN_RADIUS
	for other: String in nodes:
		if other == role or not is_floor(other): continue
		if InventoryData.is_room_furniture_role(Data.base_role(other)) and not placed_instances.has(other): continue
		var peer: Node3D = nodes[other]
		var shift: float = peer.position.x-current.x if dimension == "x" else peer.position.z-current.y
		if absf(shift) < .002 or absf(shift) >= nearest: continue
		var candidate := current + (Vector2(shift,0) if dimension == "x" else Vector2(0,shift))
		var pose: Transform3D = node.transform
		pose.origin.x = candidate.x
		pose.origin.z = candidate.y
		if not _blocker(role,_footprint_at(role,pose,collision_margin)).is_empty(): continue
		if not _sweep_blocker(role,node.transform,pose).is_empty(): continue
		best = {"target":candidate,"peer":other,"axis":dimension,"delta":absf(shift)}
		nearest = absf(shift)
	return best

func align_selected(dimension: String) -> bool:
	if not active or not placing_role.is_empty(): return false
	var guide: Dictionary = nearest_alignment(selected,dimension)
	if guide.is_empty():
		message = "附近没有可安全对齐的家具"
		changed.emit()
		return false
	var before: Dictionary = _draft()
	var node: Node3D = nodes[selected]
	var target: Vector2 = guide.target
	node.position.x = target.x
	node.position.z = target.y
	_remember(before)
	update()
	return true

func distribute_matching_furniture(dimension: String) -> bool:
	if not active or not placing_role.is_empty() or dimension not in ["x","z"]: return false
	var roles: Array[String] = _matching_furniture(selected)
	if roles.size() < 3:
		message = "至少需要 3 件已摆放的同类家具"
		changed.emit()
		return false
	roles.sort_custom(func(a: String,b: String) -> bool:
		return float(nodes[a].position.x if dimension == "x" else nodes[a].position.z) < float(nodes[b].position.x if dimension == "x" else nodes[b].position.z))
	var start_value: float = nodes[roles[0]].position.x if dimension == "x" else nodes[roles[0]].position.z
	var end_value: float = nodes[roles[-1]].position.x if dimension == "x" else nodes[roles[-1]].position.z
	if end_value-start_value < .05: return false
	var before: Dictionary = _draft()
	var changes := 0
	for index in range(1,roles.size()-1):
		var role: String = roles[index]
		var node: Node3D = nodes[role]
		var goal: float = lerpf(start_value,end_value,float(index)/float(roles.size()-1))
		var target_pose: Transform3D = node.transform
		if dimension == "x": target_pose.origin.x = goal
		else: target_pose.origin.z = goal
		if target_pose.origin.distance_to(node.position) <= .002: continue
		if not _sweep_blocker(role,node.transform,target_pose).is_empty():
			_restore_draft(before)
			update()
			message = "等距排列被墙体或其他家具阻挡"
			changed.emit()
			return false
		node.transform = target_pose
		changes += 1
	if changes == 0: return false
	var collision: String = _layout_blocker()
	if not collision.is_empty():
		_restore_draft(before)
		update()
		message = "等距排列失败：" + collision
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
	if wall_stroke_before.is_empty(): _remember(before)
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
		if InventoryData.is_room_furniture_role(Data.base_role(role)) and not placed_instances.has(role): continue
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
	if wall_stroke_before.is_empty(): _remember(before)
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
	end_wall_stroke()
	end_aperture_drag()
	end_custom_edge_drag()
	end_drag()
	if undo_stack.is_empty(): return
	redo_stack.append(_draft())
	_restore_draft(undo_stack.pop_back())
	update()

func redo() -> void:
	if not active: return
	end_wall_stroke()
	end_aperture_drag()
	end_custom_edge_drag()
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
	group_selection.clear()
	_clear_group_markers()
	gesture = ""
	restore(committed)
	placed_instances = committed_placements.duplicate()
	furniture_colors = committed_colors.duplicate()
	_apply_furniture_appearance()
	update()

func finish(apply: bool) -> bool:
	if not active: return false
	end_wall_stroke(not apply)
	end_aperture_drag(not apply)
	end_custom_edge_drag(not apply)
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
	group_selection.clear()
	_clear_group_markers()
	gizmo.hide()
	return true

func _group_eligible(role: String) -> bool:
	return nodes.has(role) and placed_instances.has(role) and is_floor(role) and InventoryData.is_room_furniture_role(Data.base_role(role))

func select(role: String, preserve_group: bool = false) -> void:
	if not nodes.has(role) or not placing_role.is_empty(): return
	if InventoryData.is_room_furniture_role(Data.base_role(role)) and not placed_instances.has(role): return
	end_drag()
	if not preserve_group or not group_selection.has(role):
		group_selection = [role] if _group_eligible(role) else []
	selected = role
	update()

func toggle_group_member(role: String) -> bool:
	if not active or not placing_role.is_empty() or not gesture.is_empty() or not _group_eligible(role): return false
	if group_selection.is_empty() and _group_eligible(selected): group_selection.append(selected)
	if group_selection.has(role):
		# Keep one primary piece selected; Ctrl+click removes extra members.
		if group_selection.size() <= 1: return false
		group_selection.erase(role)
		if selected == role: selected = group_selection.back()
	else:
		group_selection.append(role)
		selected = role
	update()
	return true

func clear_group_selection() -> void:
	if group_selection.size() <= 1: return
	end_drag()
	group_selection = [selected] if _group_eligible(selected) else []
	update()

func _clear_group_markers() -> void:
	for marker: MeshInstance3D in group_markers.values():
		if is_instance_valid(marker): marker.queue_free()
	group_markers.clear()

func _sync_group_markers() -> void:
	if not active or group_selection.size() <= 1:
		_clear_group_markers()
		return
	# The primary furniture uses the original gizmo. Other selected furniture
	# receive a screen-independent cyan footprint; these meshes have no collider.
	for role: String in group_markers.keys():
		if role == selected or not group_selection.has(role) or not _group_eligible(role):
			group_markers[role].queue_free()
			group_markers.erase(role)
	for role: String in group_selection:
		if role == selected or not _group_eligible(role): continue
		if not group_markers.has(role):
			var size: Vector3 = bounds_for(role)
			var mesh := ImmediateMesh.new()
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color("61d9ff")
			material.no_depth_test = true
			mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
			var corners := [
				Vector3(-size.x*.5,0.065,-size.z*.5),
				Vector3(size.x*.5,0.065,-size.z*.5),
				Vector3(size.x*.5,0.065,size.z*.5),
				Vector3(-size.x*.5,0.065,size.z*.5)
			]
			for i in range(4):
				mesh.surface_add_vertex(corners[i])
				mesh.surface_add_vertex(corners[(i+1)%4])
			mesh.surface_end()
			var marker := MeshInstance3D.new()
			marker.name = "GroupSelection_" + role
			marker.mesh = mesh
			world.add_child(marker)
			group_markers[role] = marker
		(group_markers[role] as MeshInstance3D).global_transform = nodes[role].global_transform

func set_tool(value: String) -> void:
	tool = value
	end_drag()
	update()

func reset_layout() -> void:
	if not active: return
	end_drag()
	group_selection.clear()
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
	if group_selection.size() > 1:
		var before_group := _draft()
		var target := position_xz.snapped(Vector2.ONE*grid_step) if snapping else position_xz
		var anchor: Vector3 = nodes[selected].position
		_transform_group(target-Vector2(anchor.x,anchor.z),0.0)
		if gesture.is_empty(): _remember(before_group)
		return
	var undo_before := _draft()
	var before: Transform3D = nodes[selected].transform
	var point := position_xz
	if snapping: point = point.snapped(Vector2.ONE * grid_step)
	point = _wall_snap_point(selected,point)
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
	if group_selection.size() > 1:
		var before_group := _draft()
		var target_yaw := snappedf(yaw,deg_to_rad(angle_step)) if snapping else yaw
		_transform_group(Vector2.ZERO,angle_difference(nodes[selected].rotation.y,target_yaw))
		if gesture.is_empty(): _remember(before_group)
		return
	var undo_before := _draft()
	var before: Transform3D = nodes[selected].transform
	if snapping: yaw = snappedf(yaw, deg_to_rad(angle_step))
	nodes[selected].rotation.y = wrapf(yaw, -PI, PI)
	clamp_pose(selected)
	_constrain_motion(before, nodes[selected].transform)
	if gesture.is_empty(): _remember(undo_before)

func _blocker(role: String, polygon: PackedVector2Array, ignored: Array[String] = []) -> String:
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
		if other == role or ignored.has(other) or is_floor(other) != floor_item or not is_blocking(other): continue
		if InventoryData.is_room_furniture_role(Data.base_role(other)) and not placed_instances.has(other): continue
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
		if InventoryData.is_room_furniture_role(Data.base_role(role)) and not placed_instances.has(role): continue
		var blocker := _blocker(role, footprint(role, collision_margin))
		if not blocker.is_empty(): return blocker
	return ""

func _sweep_blocker(role: String, before: Transform3D, after: Transform3D, ignored: Array[String] = []) -> String:
	var points := _footprint_at(role, before, collision_margin)
	points.append_array(_footprint_at(role, after, collision_margin))
	var hull := Geometry2D.convex_hull(points)
	# Geometry2D closes its hull; SAT expects each corner once.
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]): hull.resize(hull.size() - 1)
	return _blocker(role,hull,ignored)

func _group_pose_targets(start: Dictionary, delta: Vector2, yaw: float, ratio: float, pivot: Vector2) -> Dictionary:
	var targets := {}
	var angle := yaw*ratio
	for role: String in group_selection:
		var pose: Transform3D = start[role]
		var planar := Vector2(pose.origin.x,pose.origin.z)
		var next := (planar-pivot).rotated(-angle)+pivot+delta*ratio
		pose.origin.x = next.x
		pose.origin.z = next.y
		pose.basis = Basis(Vector3.UP,angle)*pose.basis
		targets[role] = pose
	return targets

func _group_swept_contact(previous: Dictionary, target: Dictionary) -> String:
	for role: String in group_selection:
		var reason := _sweep_blocker(role,previous[role],target[role],group_selection)
		if not reason.is_empty(): return reason
	return ""

func _transform_group(delta: Vector2, yaw: float) -> void:
	if group_selection.size() <= 1 or not _group_eligible(selected): return
	var initial := {}
	var pivot := Vector2.ZERO
	for role: String in group_selection:
		if not _group_eligible(role): return
		var pose: Transform3D = nodes[role].transform
		initial[role] = pose
		pivot += Vector2(pose.origin.x,pose.origin.z)
	pivot /= float(group_selection.size())
	# Evaluate rigid group poses from a shared starting state. Swept collision
	# tests ignore members of the group but retain walls and all other objects.
	# Rotate in 1-degree segments to prevent a member from cutting corners.
	var steps := maxi(1,ceili(absf(yaw)/deg_to_rad(1.0)))
	var previous := initial
	var blocker := ""
	for step in range(1,steps+1):
		var ratio := float(step)/float(steps)
		var target := _group_pose_targets(initial,delta,yaw,ratio,pivot)
		blocker = _group_swept_contact(previous,target)
		if blocker.is_empty():
			previous = target
			continue
		var low := float(step-1)/float(steps)
		var high := ratio
		for attempt in range(12):
			var mid := (low+high)*.5
			var candidate := _group_pose_targets(initial,delta,yaw,mid,pivot)
			if _group_swept_contact(previous,candidate).is_empty(): low = mid
			else: high = mid
		previous = _group_pose_targets(initial,delta,yaw,low,pivot)
		break
	for role: String in group_selection:
		nodes[role].transform = previous[role]
	wall_magnet_active = false
	update(blocker)

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
	if not blocker.is_empty(): wall_magnet_active = false
	update(blocker)

func set_snapping(enabled: bool) -> void:
	if not active or snapping == enabled: return
	snapping = enabled
	update()

func nudge_selected(direction: Vector2, fine: bool = false) -> bool:
	# Keyboard nudges share mouse placement constraints and normal undo records.
	# Fine adjustment temporarily skips grid rounding for a genuine 1 cm step.
	if not active or not gesture.is_empty() or not nodes.has(selected): return false
	if direction.is_zero_approx(): return false
	var previous: Transform3D = nodes[selected].transform
	var step: float = 0.01 if fine else grid_step
	var previous_snap: bool = snapping
	if fine: snapping = false
	move_to(Vector2(previous.origin.x,previous.origin.z) + direction.normalized() * step)
	snapping = previous_snap
	if fine: update()
	return not previous.is_equal_approx(nodes[selected].transform)

func rotate_step(direction: float, fine: bool = false) -> void:
	if not active or not nodes.has(selected): return
	# 1-degree rotation must not be rounded back to the normal 15-degree grid.
	var previous_snap: bool = snapping
	if fine: snapping = false
	rotate_to(nodes[selected].rotation.y + deg_to_rad(1.0 if fine else angle_step) * direction)
	snapping = previous_snap
	if fine: update()

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
	# Show the contextual gesture cue immediately on pointer-down, not only
	# after the first mouse motion event.
	update()

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
	var was_dragging := not gesture.is_empty()
	# Keep the last collision reason readable after mouse-up, as before P21.
	# Ordinary gesture cues and temporary magnets should disappear immediately.
	var blocked_contact := message.begins_with("已阻挡：")
	if was_dragging and not drag_before.is_empty(): _remember(drag_before)
	gesture = ""
	drag_before = {}
	snap_bypass = false
	wall_magnet_active = false
	if was_dragging and active and not blocked_contact: update()

func pick_handle(pixel: Vector2) -> String:
	var origin: Vector3 = world.camera.project_ray_origin(pixel)
	var query := PhysicsRayQueryParameters3D.create(origin,origin + world.camera.project_ray_normal(pixel)*40,2)
	query.collide_with_areas = true
	var result := world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(result.collider.get_meta("operation", "")) if not result.is_empty() else ""

func update(contact: String = "") -> void:
	# Undo, storage or preview cancellation may remove a member from the room.
	for role: String in group_selection.duplicate():
		if not _group_eligible(role): group_selection.erase(role)
	if not group_selection.has(selected) and _group_eligible(selected):
		group_selection = [selected]
	_sync_group_markers()
	var blocker := _layout_blocker()
	valid = blocker.is_empty()
	if not placing_role.is_empty(): _apply_furniture_appearance()
	message = "右键环绕 · 滚轮缩放 · 拖动物品布置房间"
	if not placing_role.is_empty():
		message = "鼠标移动预览 · 左键放置 · Q/E 旋转 · 右键取消"
	if not valid: message = blocker + "，请选择其他位置" if not placing_role.is_empty() else blocker + "，请调整位置或恢复默认布置"
	elif not contact.is_empty(): message = "已阻挡：" + contact
	elif wall_magnet_active: message = "已贴墙吸附 · 按住 Alt 暂时关闭吸附"
	elif gesture == "rotate": message = "正在旋转整组 · 松开鼠标完成" if group_selection.size() > 1 else "正在旋转 · 松开鼠标完成 · Q/E 微调"
	elif gesture == "move": message = "正在移动整组 · 松开鼠标完成" if group_selection.size() > 1 else "正在移动 · Shift＋拖动可旋转 · Alt 关闭吸附"
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
	outline.material_override.set_shader_parameter("line_color",Color("ff756a") if not valid else Color("ffc563") if contact else Color("82c6a3") if wall_magnet_active else Color("61d9ff"))
	var handle_height := 0.0 if selected == "desk" else size.y + .08
	gizmo.get_node("MoveHandles").position.y = handle_height
	gizmo.get_node("RotateHandles").position.y = handle_height
	gizmo.get_node("MoveHandles").visible = tool == "move"
	gizmo.get_node("RotateHandles").visible = tool == "rotate"
	# Hidden tools must not intercept picking.
	for handle in gizmo.find_children("*","CollisionShape3D",true,false):
		handle.disabled = (handle.get_parent().get_parent().name == "MoveHandles") != (tool == "move")
