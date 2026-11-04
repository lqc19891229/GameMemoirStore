extends Node
signal changed
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const InventoryData = preload("res://scripts/items/inventory_data.gd")
const ItemCatalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const BlueprintData = preload("res://scripts/room/room_blueprint_data.gd")
const Finishes = preload("res://scripts/items/furniture_finishes.gd")
const MountData = preload("res://scripts/room/furniture_mount_data.gd")
const WallMountData = preload("res://scripts/room/room_wall_mount_data.gd")
const SupportSurfaces = preload("res://scripts/room/furniture_support_surfaces.gd")
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
# Three session-only selection presets. Each UID prevents accidental reuse
# when a furniture instance has been stored, replaced or undone.
const QUICK_GROUP_SLOTS := 3
var quick_groups: Dictionary = {}
var group_markers: Dictionary = {}
var group_bounds_marker: MeshInstance3D
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
var start_group_pivot := Vector2.ZERO
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
var surface_mounts: Dictionary = {}
var committed_mounts: Dictionary = {}
var wall_mounts: Dictionary = {}
var committed_wall_mounts: Dictionary = {}
var placing_role := ""
var placing_before: Dictionary = {}
# P39 preview is transient visual state: never enters nodes, inventory or undo.
var group_copy_preview_active := false
var group_copy_preview_valid := false
var group_copy_preview_offset := Vector2.ZERO
var group_copy_preview_yaw := 0.0
var group_copy_preview_plan: Dictionary = {}
var group_copy_repeat := false
var group_copy_preview_placed_count := 0
var group_copy_preview_end_reason := ""
var group_copy_last_roles: Array[String] = []
var group_copy_last_primary := ""
var group_copy_preview_error := ""
var group_copy_preview_nodes: Dictionary = {}
var group_copy_preview_sources: Array[String] = []
var group_copy_preview_good: StandardMaterial3D
var group_copy_preview_bad: StandardMaterial3D
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
	surface_mounts.clear()
	committed_mounts.clear()
	wall_mounts.clear()
	committed_wall_mounts.clear()
	placed_instances = raw.duplicate()
	committed_placements = placed_instances.duplicate()
	_apply_furniture_appearance()

func load_colors(raw: Dictionary) -> void:
	if active: return
	furniture_colors.clear()
	for entry: Dictionary in available_inventory:
		var uid := str(entry.uid)
		var value: Variant = raw.get(uid, 0)
		if value is int and int(value) > 0 and Finishes.is_saved_finish(int(value)):
			furniture_colors[uid] = int(value)
	committed_colors = furniture_colors.duplicate()
	_apply_furniture_appearance()

func load_mounts(raw: Variant) -> void:
	if active: return
	surface_mounts = MountData.clean(raw,placed_instances)
	# Validate scene-authored anchors as well as the saved role/UID references.
	for role: String in surface_mounts.keys():
		if not _mount_valid(role,surface_mounts[role]):
			surface_mounts.erase(role)
	committed_mounts = surface_mounts.duplicate(true)
	_sync_mount_poses()
	committed = snapshot()

func export_mounts() -> Dictionary:
	return committed_mounts.duplicate(true)

func export_wall_mounts() -> Dictionary:
	return committed_wall_mounts.duplicate(true)

func _sync_wall_mount_poses() -> void:
	for role: String in wall_mounts:
		if not nodes.has(role) or not placed_instances.has(role): continue
		var data: Dictionary = wall_mounts[role]
		var half: Vector2 = BlueprintData.half_size(blueprint)
		var node: Node3D = nodes[role]
		var position := Vector3.ZERO
		var yaw := 0.0
		match str(data.wall):
			"north":
				position = Vector3(float(data.along),float(data.height),-half.y+.075)
				yaw = 0.0
			"south":
				position = Vector3(float(data.along),float(data.height),half.y-.075)
				yaw = PI
			"west":
				position = Vector3(-half.x+.075,float(data.height),float(data.along))
				yaw = PI*.5
			"east":
				position = Vector3(half.x-.075,float(data.height),float(data.along))
				yaw = -PI*.5
		node.position = position
		node.rotation.y = yaw

func _wall_mount_blocker(role: String, entry: Dictionary) -> String:
	var dimensions: Vector3 = bounds_for(role)
	if not WallMountData.fits(entry,blueprint,dimensions.x,dimensions.y):
		return "画框碰到墙边、门窗或天花板"
	for other: String in wall_mounts:
		if other == role: continue
		var mounted: Dictionary = wall_mounts[other]
		if entry.wall != mounted.wall: continue
		var other_dimensions: Vector3 = bounds_for(other)
		var x_hit: bool = absf(float(entry.along)-float(mounted.along)) < (dimensions.x+other_dimensions.x)*.5+collision_margin
		var y_hit: bool = float(entry.height)<float(mounted.height)+other_dimensions.y+collision_margin and float(mounted.height)<float(entry.height)+dimensions.y+collision_margin
		if x_hit and y_hit: return "画框与另一件墙面装饰重叠"
	return ""

func hang_selected_on_wall() -> bool:
	if not active or not gesture.is_empty() or not placing_role.is_empty() or group_selection.size()>1: return false
	if Data.base_role(selected) != WallMountData.MOUNT_ROLE or not placed_instances.has(selected): return false
	if wall_mounts.has(selected) or surface_mounts.has(selected): return false
	var role: String = selected
	var origin: Vector3 = nodes[role].position
	var half: Vector2 = BlueprintData.half_size(blueprint)
	var candidates: Array[Dictionary] = [
		{"wall":"north","along":origin.x,"distance":absf(origin.z+half.y)},
		{"wall":"south","along":origin.x,"distance":absf(origin.z-half.y)},
		{"wall":"west","along":origin.z,"distance":absf(origin.x+half.x)},
		{"wall":"east","along":origin.z,"distance":absf(origin.x-half.x)}
	]
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	for candidate: Dictionary in candidates:
		var pose: Dictionary = {"x":origin.x,"z":origin.z,"yaw":nodes[role].rotation.y}
		var entry: Dictionary = {"wall":candidate.wall,"along":snappedf(float(candidate.along),grid_step),
			"height":1.20,"floor_pose":pose}
		if not _wall_mount_blocker(role,entry).is_empty(): continue
		var before := _draft()
		wall_mounts[role] = entry
		_sync_wall_mount_poses()
		_remember(before)
		update()
		return true
	message = "附近外墙没有足够的挂画空间"
	changed.emit()
	return false

func take_down_selected_wall_mount() -> bool:
	if not active or not wall_mounts.has(selected) or not gesture.is_empty(): return false
	var role: String = selected
	var previous: Dictionary = wall_mounts[role]
	var before := _draft()
	wall_mounts.erase(role)
	nodes[role].position = Vector3(float(previous.floor_pose.x),0,float(previous.floor_pose.z))
	nodes[role].rotation.y = float(previous.floor_pose.yaw)
	clamp_pose(role)
	if not _layout_blocker().is_empty():
		_restore_draft(before)
		message = "原来的地面位置已被占用，请调整家具后再取下"
		changed.emit()
		return false
	_remember(before)
	update()
	return true

func move_wall_mount(direction: Vector2) -> bool:
	if not active or not wall_mounts.has(selected) or not gesture.is_empty() or group_selection.size()>1: return false
	if not is_finite(direction.x) or not is_finite(direction.y): return false
	var before := _draft()
	var entry: Dictionary = wall_mounts[selected].duplicate(true)
	entry["along"] = snappedf(float(entry.along)+direction.x,grid_step) if snapping else float(entry.along)+direction.x
	entry["height"] = snappedf(float(entry.height)+direction.y,grid_step) if snapping else float(entry.height)+direction.y
	var blocker: String = _wall_mount_blocker(selected,entry)
	if not blocker.is_empty():
		message = "已阻挡：" + blocker
		changed.emit()
		return false
	wall_mounts[selected] = entry
	_sync_wall_mount_poses()
	_remember(before)
	update()
	return true

func _mount_footprint(role: String, mount: Dictionary) -> PackedVector2Array:
	var width: Vector3 = bounds_for(role)
	var position := Vector2(float(mount.get("x",0.0)),float(mount.get("z",0.0)))
	var yaw := float(mount.get("yaw",0.0))
	var footprint := PackedVector2Array()
	for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		var offset := Vector2(corner.x * width.x * .5,corner.y * width.z * .5)
		footprint.append(position + offset.rotated(-yaw))
	return footprint

func _mount_valid(role: String, mount: Dictionary) -> bool:
	if not nodes.has(role) or not placed_instances.has(role): return false
	var support: String = str(mount.get("support",""))
	if not nodes.has(support) or not placed_instances.has(support) or support == role: return false
	for anchor: Dictionary in SupportSurfaces.anchors_for(nodes[support]):
		if anchor.id != str(mount.get("anchor","")): continue
		var center: Vector3 = anchor.center
		var surface_size: Vector2 = anchor.size
		for corner: Vector2 in _mount_footprint(role,mount):
			if absf(corner.x-center.x) + collision_margin > surface_size.x * .5: return false
			if absf(corner.y-center.z) + collision_margin > surface_size.y * .5: return false
		return true
	return false

func _sync_mount_poses() -> void:
	for role: String in surface_mounts:
		if not _mount_valid(role,surface_mounts[role]): continue
		var mount: Dictionary = surface_mounts[role]
		var support: Node3D = nodes[mount.support]
		var anchor: Dictionary = {}
		for candidate: Dictionary in SupportSurfaces.anchors_for(support):
			if candidate.id == mount.anchor:
				anchor = candidate
				break
		if anchor.is_empty(): continue
		var node: Node3D = nodes[role]
		node.global_position = support.to_global(anchor.center + Vector3(float(mount.x),0,float(mount.z)))
		node.global_rotation.y = support.global_rotation.y + float(mount.yaw)

func _mount_collision(role: String, mount: Dictionary) -> String:
	if not _mount_valid(role,mount): return "家具超出陈列表面或支撑物已收纳"
	var polygon := _mount_footprint(role,mount)
	for other: String in surface_mounts:
		if other == role: continue
		var entry: Dictionary = surface_mounts[other]
		if entry.support != mount.support or entry.anchor != mount.anchor: continue
		if Data.overlap(polygon,_mount_footprint(other,entry)):
			return "陈列物品与" + name_for(other) + "重叠"
	return ""

func edit_selected_mount(offset: Vector2, yaw: float) -> bool:
	if not active or not surface_mounts.has(selected) or group_selection.size() > 1 or not gesture.is_empty() and gesture not in ["move","rotate"]:
		return false
	if not is_finite(offset.x) or not is_finite(offset.y) or not is_finite(yaw): return false
	var before := _draft()
	var entry: Dictionary = surface_mounts[selected].duplicate(true)
	entry["x"] = offset.x
	entry["z"] = offset.y
	entry["yaw"] = wrapf(snappedf(yaw,deg_to_rad(angle_step)) if snapping else yaw,-PI,PI)
	var blocker := _mount_collision(selected,entry)
	if not blocker.is_empty():
		message = "已阻挡：" + blocker
		changed.emit()
		return false
	surface_mounts[selected] = entry
	_sync_mount_poses()
	if gesture.is_empty(): _remember(before)
	update()
	return true

func _mounted_hit(pixel: Vector2) -> Variant:
	if not surface_mounts.has(selected): return null
	var entry: Dictionary = surface_mounts[selected]
	var support: Node3D = nodes.get(str(entry.support)) as Node3D
	if support == null: return null
	var anchor: Dictionary = {}
	for candidate: Dictionary in SupportSurfaces.anchors_for(support):
		if candidate.id == entry.anchor:
			anchor = candidate
			break
	if anchor.is_empty(): return null
	var plane := Plane(support.global_basis.y.normalized(),support.to_global(anchor.center))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel),world.camera.project_ray_normal(pixel))
	if hit == null: return null
	return support.to_local(hit)

func mount_selected_on_nearest_surface() -> bool:
	if not active or not placing_role.is_empty() or not gesture.is_empty() or group_selection.size() > 1: return false
	if not placed_instances.has(selected) or surface_mounts.has(selected): return false
	var role := selected
	var original: Transform3D = nodes[role].transform
	var original_pose := {"x":original.origin.x,"z":original.origin.z,"yaw":original.basis.get_euler().y}
	var best := {}
	var nearest := INF
	for support: String in placed_instances:
		if support == role or surface_mounts.has(support) or not nodes.has(support): continue
		for anchor: Dictionary in SupportSurfaces.anchors_for(nodes[support]):
			var location: Vector3 = nodes[support].to_global(anchor.center)
			var distance := location.distance_to(nodes[role].global_position)
			# Begin with a reliable centre placement; smaller offset adjustments can follow.
			var entry := {"support":support,"anchor":anchor.id,"x":0.0,"z":0.0,"yaw":0.0,"floor_pose":original_pose}
			if distance >= nearest or not _mount_valid(role,entry): continue
			if not _mount_collision(role,entry).is_empty(): continue
			best = entry
			nearest = distance
	if best.is_empty():
		message = "找不到可容纳此家具的空闲桌面或搁板"
		changed.emit()
		return false
	var before := _draft()
	surface_mounts[role] = best
	_sync_mount_poses()
	_remember(before)
	update()
	return true

func unmount_selected() -> bool:
	if not active or not surface_mounts.has(selected) or not gesture.is_empty(): return false
	var role: String = selected
	var entry: Dictionary = surface_mounts[role]
	var before := _draft()
	surface_mounts.erase(role)
	var floor_pose: Dictionary = entry.floor_pose
	nodes[role].position = Vector3(float(floor_pose.x),0.0,float(floor_pose.z))
	nodes[role].rotation.y = float(floor_pose.yaw)
	clamp_pose(role)
	if not _layout_blocker().is_empty():
		_restore_draft(before)
		message = "原来的地面位置已被占用，无法取下"
		changed.emit()
		return false
	_remember(before)
	update()
	return true

func load_wall_mounts(raw: Variant) -> void:
	if active: return
	wall_mounts = WallMountData.clean(raw,placed_instances,blueprint)
	for role: String in wall_mounts.keys():
		if not nodes.has(role) or not _wall_mount_blocker(role,wall_mounts[role]).is_empty():
			wall_mounts.erase(role)
	committed_wall_mounts = wall_mounts.duplicate(true)
	_sync_wall_mount_poses()
	committed = snapshot()

func color_for(role: String) -> int:
	return int(furniture_colors.get(str(placed_instances.get(role, "")), 0))

func set_furniture_color(index: int) -> void:
	if not active or not InventoryData.is_room_furniture_role(Data.base_role(selected)): return
	if not placed_instances.has(selected) or not Finishes.is_saved_finish(index): return
	var before := _draft()
	var uid := str(placed_instances[selected])
	if index == 0: furniture_colors.erase(uid)
	else: furniture_colors[uid] = index
	_apply_furniture_appearance()
	_remember(before)
	update()

func group_color_index() -> int:
	# -1 means that selected items have mixed finishes.
	if group_selection.size() < 2: return color_for(selected)
	var common := -1
	for role: String in group_selection:
		if not _group_eligible(role): return -1
		var index: int = color_for(role)
		if common < 0: common = index
		elif common != index: return -1
	return common

func set_group_furniture_color(index: int) -> bool:
	if not active or not gesture.is_empty() or not placing_role.is_empty() or group_selection.size() < 2: return false
	if not Finishes.is_saved_finish(index): return false
	for role: String in group_selection:
		if not _group_eligible(role): return false
	var before := _draft()
	for role: String in group_selection:
		var uid: String = str(placed_instances[role])
		if index == 0: furniture_colors.erase(uid)
		else: furniture_colors[uid] = index
	if before == _draft(): return false
	_apply_furniture_appearance()
	_remember(before)
	update()
	return true

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
	if not active or not placing_role.is_empty() or group_copy_preview_active: return false
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
	# Floor remains a valid fallback when no usable display surface is under the cursor.
	# Never keep an earlier surface attachment while switching back to floor preview.
	if surface_mounts.has(placing_role):
		surface_mounts.erase(placing_role)
		nodes[placing_role].position.y = 0.0
	var position := position_xz.snapped(Vector2.ONE * grid_step) if snapping else position_xz
	position = _wall_snap_point(placing_role,position)
	nodes[placing_role].position.x = position.x
	nodes[placing_role].position.z = position.y
	update()

func _surface_preview_at(pixel: Vector2) -> bool:
	if placing_role.is_empty(): return false
	# Only compact collectibles use automatic contact placement; ordinary sofas,
	# cabinets and floor furniture must never jump onto shelf surfaces.
	if Data.base_role(placing_role) not in ["desk_memento","mini_book_stack"]: return false
	var origin: Vector3 = world.camera.project_ray_origin(pixel)
	var direction: Vector3 = world.camera.project_ray_normal(pixel)
	var nearest: float = INF
	var best: Dictionary = {}
	for support: String in placed_instances:
		if support == placing_role or surface_mounts.has(support) or not nodes.has(support): continue
		var furniture: Node3D = nodes[support]
		for anchor: Dictionary in SupportSurfaces.anchors_for(furniture):
			var plane := Plane(furniture.global_basis.y.normalized(),furniture.to_global(anchor.center))
			var hit: Variant = plane.intersects_ray(origin,direction)
			if hit == null: continue
			var distance: float = origin.distance_to(hit)
			if distance >= nearest or direction.dot(hit-origin) <= 0.0: continue
			var local: Vector3 = furniture.to_local(hit)
			var offset := Vector2(local.x-anchor.center.x,local.z-anchor.center.z)
			if snapping: offset = offset.snapped(Vector2.ONE * grid_step)
			var placement := {"support":support,"anchor":anchor.id,"x":offset.x,"z":offset.y,
				"yaw":nodes[placing_role].rotation.y-furniture.global_rotation.y,
				"floor_pose":{"x":nodes[placing_role].position.x,"z":nodes[placing_role].position.z,"yaw":nodes[placing_role].rotation.y}}
			# A cursor outside the usable surface should continue to floor preview.
			# An occupied point within the surface stays red and cannot be confirmed.
			if not _mount_valid(placing_role,placement): continue
			best = placement
			nearest = distance
	if best.is_empty(): return false
	surface_mounts[placing_role] = best
	_sync_mount_poses()
	update()
	return true

func preview_at(pixel: Vector2) -> void:
	if placing_role.is_empty(): return
	if _surface_preview_at(pixel): return
	var plane := Plane(world.global_basis.y.normalized(), world.to_global(Vector3.ZERO))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	if hit != null:
		var local: Vector3 = world.to_local(hit)
		preview_placement(Vector2(local.x, local.z))

func confirm_placement() -> bool:
	if placing_role.is_empty() or not valid: return false
	# A new surface item has no prior safe floor position. Find a removable
	# staging point now, so taking it off a shelf later remains possible.
	if surface_mounts.has(placing_role):
		var attached_role: String = placing_role
		var attached: Dictionary = surface_mounts[attached_role].duplicate(true)
		var raised_pose: Transform3D = nodes[attached_role].transform
		var support_position: Vector3 = nodes[attached.support].position
		surface_mounts.erase(attached_role)
		var found_floor := false
		for ring in range(24):
			if found_floor: break
			for sector in range(16):
				var angle := TAU * float(sector) / 16.0
				var radius := float(ring) * .3
				var target := Vector2(support_position.x+cos(angle)*radius,
					support_position.z+sin(angle)*radius)
				nodes[attached_role].position = Vector3(target.x,0.0,target.y)
				nodes[attached_role].rotation.y = float(attached.floor_pose.yaw)
				clamp_pose(attached_role)
				if _blocker(attached_role,footprint(attached_role,collision_margin)).is_empty():
					var local: Vector3 = nodes[attached_role].position
					attached["floor_pose"] = {"x":local.x,"z":local.z,
						"yaw":nodes[attached_role].rotation.y}
					found_floor = true
					break
		surface_mounts[attached_role] = attached
		nodes[attached_role].transform = raised_pose
		_sync_mount_poses()
		if not found_floor:
			message = "附近没有可供取下时使用的安全地面位置"
			changed.emit()
			return false
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
	group_selection.clear()
	group_selection.append(role)
	_remember(before)
	update()

func group_duplicate_plan() -> Dictionary:
	if not active or group_selection.size() < 2 or not gesture.is_empty() or not placing_role.is_empty():
		return {"error":"请先选择至少 2 件已摆放家具"}
	var reserved: Dictionary = {}
	var reserved_roles: Dictionary = {}
	var copies: Dictionary = {}
	for source: String in group_selection:
		if not _group_eligible(source) or not templates.has(Data.base_role(source)):
			return {"error":"选择中包含不可复制的家具"}
		var furniture_id: String = InventoryData.furniture_item_id(Data.base_role(source))
		var available := {}
		for entry: Dictionary in available_inventory:
			var uid: String = str(entry.get("uid",""))
			if str(entry.get("item_id","")) != furniture_id or uid.is_empty(): continue
			if placed_instances.values().has(uid) or reserved.has(uid): continue
			var target: String = _next_furniture_role(Data.base_role(source),uid)
			if target.is_empty() or reserved_roles.has(target) or (nodes.has(target) and placed_instances.has(target)): continue
			available = {"uid":uid,"role":target}
			break
		if available.is_empty():
			return {"error":"%s 的空闲库存不足，请先购买" % name_for(source)}
		reserved[str(available.uid)] = true
		reserved_roles[str(available.role)] = true
		copies[source] = available
	return {"copies":copies}

func _group_copy_pose(source: String, displacement: Vector2, yaw: float, pivot: Vector2) -> Transform3D:
	var target: Transform3D = nodes[source].transform
	var initial := Vector2(target.origin.x,target.origin.z)
	var rotated: Vector2 = (initial-pivot).rotated(-yaw)+pivot+displacement
	target.origin.x = rotated.x
	target.origin.z = rotated.y
	target.basis = Basis(Vector3.UP,yaw)*target.basis
	return target

func _group_duplicate_targets(displacement: Vector2, yaw: float = 0.0) -> Dictionary:
	var targets := {}
	var pivot: Vector2 = group_pivot()
	for source: String in group_selection:
		var target: Transform3D = _group_copy_pose(source,displacement,yaw,pivot)
		var polygon: PackedVector2Array = _footprint_at(source,target,collision_margin)
		if not _blocker(source,polygon).is_empty(): return {}
		if is_blocking(source):
			# _blocker deliberately ignores its own role; a duplicate must not
			# occupy its source, any other source or another proposed copy.
			for original: String in group_selection:
				if is_blocking(original) and Data.overlap(polygon,footprint(original,collision_margin)): return {}
			for other: String in targets:
				if is_blocking(other) and Data.overlap(polygon,_footprint_at(other,targets[other],collision_margin)): return {}
		targets[source] = target
	return targets

func duplicate_group(displacement: Variant = null, yaw: float = 0.0) -> bool:
	var plan: Dictionary = group_duplicate_plan()
	if plan.has("error"):
		message = str(plan.error)
		changed.emit()
		return false
	var chosen: Dictionary = plan.copies
	var targets := {}
	# Every member receives the exact same offset, retaining all their
	# relative X/Z positions and orientations. No nodes or UIDs are reserved
	# until the whole constellation passes the placement test.
	if displacement is Vector2:
		targets = _group_duplicate_targets(displacement,yaw)
	else:
		for ring in range(1,21):
			for step in range(24):
				var angle: float = TAU*float(step)/24.0
				var offset := Vector2(cos(angle),sin(angle))*float(ring)*.25
				if snapping: offset = offset.snapped(Vector2.ONE*grid_step)
				targets = _group_duplicate_targets(offset)
				if not targets.is_empty(): break
			if not targets.is_empty(): break
	if targets.is_empty():
		message = "附近没有能容纳整组家具的空闲位置"
		changed.emit()
		return false
	var before: Dictionary = _draft()
	var old_selection: Array[String] = group_selection.duplicate()
	var old_primary: String = selected
	var copied_roles: Array[String] = []
	for source: String in old_selection:
		var spec: Dictionary = chosen[source]
		var target_role: String = str(spec.role)
		var uid: String = str(spec.uid)
		_create_copy(target_role)
		if not nodes.has(target_role):
			_restore_draft(before)
			group_selection = old_selection
			selected = old_primary
			update()
			message = "整组复制失败：无法创建家具实例"
			changed.emit()
			return false
		nodes[target_role].transform = targets[source]
		placed_instances[target_role] = uid
		var finish: int = color_for(source)
		if finish == 0: furniture_colors.erase(uid)
		else: furniture_colors[uid] = finish
		copied_roles.append(target_role)
	_apply_furniture_appearance()
	var contact: String = _layout_blocker()
	if not contact.is_empty():
		_restore_draft(before)
		group_selection = old_selection
		selected = old_primary
		update()
		message = "整组复制受阻：" + contact
		changed.emit()
		return false
	group_selection = copied_roles
	selected = str(chosen[old_primary].role)
	_remember(before)
	update()
	return true

func _copy_preview_material(good: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("54d5a0",.43) if good else Color("ff7770",.43)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _find_group_copy_offset(near: Vector2, yaw: float) -> Dictionary:
	# Pure search: does not instantiate copies or touch owned inventory.
	for ring in range(1,21):
		for step in range(24):
			var angle: float = TAU*float(step)/24.0
			var candidate: Vector2 = near+Vector2(cos(angle),sin(angle))*float(ring)*.25
			if snapping and not snap_bypass: candidate = candidate.snapped(Vector2.ONE*grid_step)
			if not _group_duplicate_targets(candidate,yaw).is_empty():
				return {"offset":candidate}
	return {}

func begin_group_copy_preview() -> bool:
	if group_copy_preview_active: return false
	var plan: Dictionary = group_duplicate_plan()
	if plan.has("error"):
		message = str(plan.error)
		changed.emit()
		return false
	var offset := Vector2(.75,.75)
	var suggested: Dictionary = _find_group_copy_offset(Vector2.ZERO,0.0)
	if suggested.has("offset"): offset = suggested.offset
	group_copy_preview_plan = plan.copies.duplicate(true)
	group_copy_repeat = false
	group_copy_preview_placed_count = 0
	group_copy_preview_end_reason = ""
	group_copy_last_roles.clear()
	group_copy_last_primary = ""
	group_copy_preview_yaw = 0.0
	group_copy_preview_good = _copy_preview_material(true)
	group_copy_preview_bad = _copy_preview_material(false)
	group_copy_preview_sources = group_selection.duplicate()
	for source: String in group_copy_preview_sources:
		var ghost: Node3D = templates[Data.base_role(source)].instantiate()
		ghost.name = "GroupCopyPreview_" + source
		world.get_node("Room/Furniture").add_child(ghost)
		# These copies must not enter layout.nodes and must not intercept
		# the room's pick ray or any collision/drag gesture.
		for collider: CollisionObject3D in ghost.find_children("*","CollisionObject3D",true,false):
			collider.collision_layer = 0
			collider.collision_mask = 0
			collider.input_ray_pickable = false
		for mesh: MeshInstance3D in ghost.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group_copy_preview_nodes[source] = ghost
	group_copy_preview_active = true
	set_group_copy_preview_offset(offset)
	return true

func set_group_copy_repeat(enabled: bool) -> bool:
	if not group_copy_preview_active or group_copy_repeat == enabled: return false
	group_copy_repeat = enabled
	changed.emit()
	return true

func set_group_copy_preview_offset(offset: Vector2, fine: bool = false) -> bool:
	if not group_copy_preview_active: return false
	group_copy_preview_offset = offset.snapped(Vector2.ONE*grid_step) if snapping and not snap_bypass and not fine else offset
	var plan: Dictionary = group_duplicate_plan()
	var inventory_good: bool = plan.has("copies") and plan.copies == group_copy_preview_plan
	var targets: Dictionary = _group_duplicate_targets(group_copy_preview_offset,group_copy_preview_yaw) if inventory_good else {}
	group_copy_preview_valid = targets.size() == group_copy_preview_sources.size()
	group_copy_preview_error = "" if group_copy_preview_valid else "预留库存发生变化 · 请取消并重试" if not inventory_good else "此处空间不足或家具重叠 · 请移动至空地"
	var pivot: Vector2 = group_pivot()
	for source: String in group_copy_preview_sources:
		var ghost: Node3D = group_copy_preview_nodes[source]
		ghost.transform = _group_copy_pose(source,group_copy_preview_offset,group_copy_preview_yaw,pivot)
		for mesh: MeshInstance3D in ghost.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = group_copy_preview_good if group_copy_preview_valid else group_copy_preview_bad
	changed.emit()
	return group_copy_preview_valid

func nudge_group_copy_preview(direction: Vector2, fine: bool = false) -> bool:
	if not group_copy_preview_active or direction == Vector2.ZERO: return false
	var unit := .01 if fine else grid_step
	return set_group_copy_preview_offset(group_copy_preview_offset+direction*unit,fine)

func rotate_group_copy_preview_step(direction: float, fine: bool = false) -> bool:
	if not group_copy_preview_active or is_zero_approx(direction): return false
	group_copy_preview_yaw = wrapf(group_copy_preview_yaw+deg_to_rad(1.0 if fine else angle_step)*signf(direction),-PI,PI)
	# Rotate around the same centroid as P35; preserve fine translation.
	return set_group_copy_preview_offset(group_copy_preview_offset,true)

func find_group_copy_preview_space() -> bool:
	if not group_copy_preview_active: return false
	var plan: Dictionary = group_duplicate_plan()
	if not plan.has("copies") or plan.copies != group_copy_preview_plan:
		set_group_copy_preview_offset(group_copy_preview_offset,true)
		return false
	var candidate: Dictionary = _find_group_copy_offset(group_copy_preview_offset,group_copy_preview_yaw)
	if candidate.is_empty():
		candidate = _find_group_copy_offset(Vector2.ZERO,group_copy_preview_yaw)
	if candidate.has("offset"):
		return set_group_copy_preview_offset(candidate.offset,true)
	group_copy_preview_valid = false
	group_copy_preview_error = "未找到可容纳当前朝向整组家具的空位"
	changed.emit()
	return false

func group_copy_preview_at(pixel: Vector2) -> void:
	if not group_copy_preview_active: return
	var plane := Plane(world.global_basis.y.normalized(),world.to_global(Vector3.ZERO))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel),world.camera.project_ray_normal(pixel))
	if hit == null: return
	var local: Vector3 = world.to_local(hit)
	var origin: Vector3 = nodes[selected].position
	var destination := Vector2(local.x,local.z)
	if snapping and not snap_bypass: destination = destination.snapped(Vector2.ONE*grid_step)
	set_group_copy_preview_offset(destination-Vector2(origin.x,origin.z))

func confirm_group_copy_preview() -> bool:
	if not group_copy_preview_active or not group_copy_preview_valid: return false
	var plan: Dictionary = group_duplicate_plan()
	# Each placement independently rechecks the exact pre-reserved stock IDs.
	if not plan.has("copies") or plan.copies != group_copy_preview_plan:
		set_group_copy_preview_offset(group_copy_preview_offset,true)
		return false
	var original_roles: Array[String] = group_copy_preview_sources.duplicate()
	var original_primary: String = selected
	var result: bool = duplicate_group(group_copy_preview_offset,group_copy_preview_yaw)
	if not result:
		group_copy_preview_valid = false
		group_copy_preview_error = "落点已失效 · 请重新选择空地"
		changed.emit()
		return false
	group_copy_preview_placed_count += 1
	group_copy_last_roles = group_selection.duplicate()
	group_copy_last_primary = selected
	if not group_copy_repeat:
		cancel_group_copy_preview()
		return true
	# Keep copying the *original source group*, not the newly placed copies.
	# The source selection and its UID/color mapping stay unchanged; each
	# successful batch has already made its own independent undo record.
	group_selection = original_roles
	selected = original_primary
	var next_plan: Dictionary = group_duplicate_plan()
	if next_plan.has("error"):
		cancel_group_copy_preview()
		group_copy_preview_end_reason = str(next_plan.error)
		return true
	group_copy_preview_plan = next_plan.copies.duplicate(true)
	# The just-placed batch now occupies the old ghost location. Automatically
	# search from there for a free spot, retaining the player's chosen yaw.
	var next_spot: Dictionary = _find_group_copy_offset(group_copy_preview_offset,group_copy_preview_yaw)
	if next_spot.is_empty(): next_spot = _find_group_copy_offset(Vector2.ZERO,group_copy_preview_yaw)
	if next_spot.has("offset"):
		set_group_copy_preview_offset(next_spot.offset,true)
	else:
		set_group_copy_preview_offset(group_copy_preview_offset,true)
		group_copy_preview_valid = false
		group_copy_preview_error = "暂无可用空位 · 移动预览或 Esc 结束连续复制"
		changed.emit()
	return true

func cancel_group_copy_preview() -> void:
	if not group_copy_preview_active and group_copy_preview_nodes.is_empty(): return
	group_copy_preview_active = false
	group_copy_preview_valid = false
	group_copy_preview_error = ""
	group_copy_preview_yaw = 0.0
	group_copy_repeat = false
	group_copy_preview_plan.clear()
	for ghost: Node3D in group_copy_preview_nodes.values():
		if is_instance_valid(ghost): ghost.queue_free()
	group_copy_preview_nodes.clear()
	group_copy_preview_sources.clear()
	group_copy_preview_good = null
	group_copy_preview_bad = null
	# When the user finishes a continuous placement session, focus their
	# latest copies. Before the first commit, cancel preserves the sources.
	if active and group_copy_last_roles.size() > 1:
		var placed_roles: Array[String] = []
		for role: String in group_copy_last_roles:
			if _group_eligible(role): placed_roles.append(role)
		if placed_roles.size() > 1:
			group_selection = placed_roles
			selected = group_copy_last_primary if placed_roles.has(group_copy_last_primary) else placed_roles.back()
			update()
	group_copy_last_roles.clear()
	group_copy_last_primary = ""
	changed.emit()

func store_group() -> bool:
	for role: String in group_selection:
		if _has_mounted_children(role): 
			message = "请先取下陈列物品，再收纳支撑家具"
			changed.emit()
			return false
	if not active or group_selection.size() < 2 or not gesture.is_empty() or not placing_role.is_empty(): return false
	for role: String in group_selection:
		if not _group_eligible(role): return false
	var before: Dictionary = _draft()
	var to_store: Array[String] = group_selection.duplicate()
	selected = "desk"
	group_selection.clear()
	_clear_group_markers()
	for role: String in to_store:
		placed_instances.erase(role)
		if Data.is_copy(role):
			nodes[role].free()
			nodes.erase(role)
		else:
			nodes[role].hide()
	_apply_furniture_appearance()
	_remember(before)
	update()
	return true

func delete_selected() -> void:
	store_selected()

func _has_mounted_children(support: String) -> bool:
	for mount: Dictionary in surface_mounts.values():
		if str(mount.get("support","")) == support: return true
	return false

func store_selected() -> void:
	if _has_mounted_children(selected):
		message = "请先取下陈列物品，再收纳支撑家具"
		changed.emit()
		return
	if not active or group_selection.size() > 1 or not InventoryData.is_room_furniture_role(Data.base_role(selected)): return
	if not placing_role.is_empty() or not placed_instances.has(selected): return
	end_drag()
	var before := _draft()
	surface_mounts.erase(selected)
	wall_mounts.erase(selected)
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

func load_saved(raw: Variant, raw_mounts: Variant = {}, raw_walls: Variant = {}) -> void:
	if active: return
	var cleaned := Data.clean(raw)
	var sanitized_mounts: Dictionary = MountData.clean(raw_mounts,placed_instances)
	var sanitized_walls: Dictionary = WallMountData.clean(raw_walls,placed_instances,blueprint)
	if cleaned == saved and sanitized_mounts == surface_mounts and sanitized_walls == wall_mounts and _layout_blocker().is_empty(): return
	restore(authored)
	for role: String in cleaned:
		_create_copy(role)
		nodes[role].position.x = cleaned[role].x
		nodes[role].position.z = cleaned[role].z
		nodes[role].rotation.y = cleaned[role].yaw
		clamp_pose(role)
	surface_mounts = sanitized_mounts
	for role: String in surface_mounts.keys():
		if not _mount_valid(role,surface_mounts[role]): surface_mounts.erase(role)
	_sync_mount_poses()
	wall_mounts = sanitized_walls
	_sync_wall_mount_poses()
	# Older layouts may touch or overlap after a model/bounds change. Keep the
	# table pose, but recover a usable equipment arrangement rather than loading penetration.
	if not _layout_blocker().is_empty():
		for role: String in world.devices: nodes[role].transform = authored[role]
	# Imported legacy table poses may intersect new room furniture or walls.
	# Recover the complete authored room rather than keeping a partially invalid save.
	if not _layout_blocker().is_empty():
		restore(authored)
		surface_mounts.clear()
		wall_mounts.clear()
	saved = cleaned
	committed_mounts = surface_mounts.duplicate(true)
	committed_wall_mounts = wall_mounts.duplicate(true)
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

func _apply_group_arrangement(targets: Dictionary) -> bool:
	if not active or not placing_role.is_empty() or not gesture.is_empty(): return false
	if group_selection.size() < 2 or targets.size() != group_selection.size(): return false
	var original := {}
	var max_distance := 0.0
	for role: String in group_selection:
		if not _group_eligible(role) or not targets.has(role): return false
		var start: Transform3D = nodes[role].transform
		var target: Transform3D = targets[role]
		if not start.basis.is_equal_approx(target.basis): return false
		original[role] = start
		max_distance = maxf(max_distance,start.origin.distance_to(target.origin))
	if max_distance < .002: return false
	var before: Dictionary = _draft()
	# Check the whole group at each intermediate pose so members cannot cross
	# each other, and sweep between poses so external objects cannot be tunneled.
	var steps := clampi(ceili(max_distance/.12),1,80)
	var previous := original
	for step in range(1,steps+1):
		var fraction := float(step)/float(steps)
		var next := {}
		for role: String in group_selection:
			var pose: Transform3D = original[role]
			var target: Transform3D = targets[role]
			pose.origin = pose.origin.lerp(target.origin,fraction)
			next[role] = pose
		var contact := ""
		for role: String in group_selection:
			contact = _sweep_blocker(role,previous[role],next[role],group_selection)
			if not contact.is_empty(): break
		if contact.is_empty():
			for role: String in group_selection:
				nodes[role].transform = next[role]
			contact = _layout_blocker()
		if not contact.is_empty():
			for role: String in group_selection:
				nodes[role].transform = original[role]
			update()
			message = "整组排列受阻：" + contact
			changed.emit()
			return false
		previous = next
	_remember(before)
	update()
	return true

func align_group(dimension: String) -> bool:
	if not active or dimension not in ["x","z"] or group_selection.size() < 2 or not group_selection.has(selected): return false
	var anchor: Vector3 = nodes[selected].position
	var targets := {}
	for role: String in group_selection:
		if not _group_eligible(role): return false
		var target: Transform3D = nodes[role].transform
		if dimension == "x": target.origin.x = anchor.x
		else: target.origin.z = anchor.z
		targets[role] = target
	return _apply_group_arrangement(targets)

func distribute_group(dimension: String) -> bool:
	if not active or dimension not in ["x","z"] or group_selection.size() < 3: return false
	var ordered: Array[String] = group_selection.duplicate()
	for role: String in ordered:
		if not _group_eligible(role): return false
	ordered.sort_custom(func(a: String,b: String) -> bool:
		var left: float = nodes[a].position.x if dimension == "x" else nodes[a].position.z
		var right: float = nodes[b].position.x if dimension == "x" else nodes[b].position.z
		return a < b if is_equal_approx(left,right) else left < right
	)
	var first: Vector3 = nodes[ordered[0]].position
	var last: Vector3 = nodes[ordered[-1]].position
	var start_value: float = first.x if dimension == "x" else first.z
	var end_value: float = last.x if dimension == "x" else last.z
	if end_value-start_value < .05: return false
	var targets := {}
	for i in range(ordered.size()):
		var role: String = ordered[i]
		var target: Transform3D = nodes[role].transform
		var goal := lerpf(start_value,end_value,float(i)/float(ordered.size()-1))
		if dimension == "x": target.origin.x = goal
		else: target.origin.z = goal
		targets[role] = target
	return _apply_group_arrangement(targets)

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
	return {"poses":snapshot(), "style":world.get_node("Room").style.duplicate(), "placements":placed_instances.duplicate(), "colors":furniture_colors.duplicate(), "mounts":surface_mounts.duplicate(true), "wall_mounts":wall_mounts.duplicate(true), "blueprint":blueprint.duplicate(true)}

func _restore_draft(draft: Dictionary) -> void:
	blueprint = draft.blueprint.duplicate(true)
	room_half_size = BlueprintData.half_size(blueprint)
	world.get_node("Room").apply_blueprint(blueprint)
	restore(draft.poses)
	placed_instances = draft.placements.duplicate()
	surface_mounts = draft.get("mounts",{}).duplicate(true)
	wall_mounts = draft.get("wall_mounts",{}).duplicate(true)
	_sync_mount_poses()
	_sync_wall_mount_poses()
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
	if group_copy_preview_active:
		cancel_group_copy_preview()
		return
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
	if group_copy_preview_active:
		cancel_group_copy_preview()
		return
	end_wall_stroke()
	end_aperture_drag()
	end_custom_edge_drag()
	end_drag()
	if redo_stack.is_empty(): return
	undo_stack.append(_draft())
	_restore_draft(redo_stack.pop_back())
	update()

func set_style(key: String, value: int, animate_weather: bool = false) -> void:
	if not active or not committed_style.has(key): return
	var before := _draft()
	var room: MemoirRoomView = world.get_node("Room")
	var previous: Array = room.atmosphere_visual_snapshot() if animate_weather and key == "atmosphere" and int(room.style.atmosphere) != value else []
	var next: Dictionary = room.style.duplicate()
	next[key] = value
	room.apply_style(next)
	if not previous.is_empty(): room.animate_atmosphere_from(previous)
	_remember(before)
	update()

func begin() -> void:
	cancel_group_copy_preview()
	active = true
	quick_groups.clear()
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
	surface_mounts = committed_mounts.duplicate(true)
	wall_mounts = committed_wall_mounts.duplicate(true)
	_sync_mount_poses()
	_sync_wall_mount_poses()
	_apply_furniture_appearance()
	update()

func finish(apply: bool) -> bool:
	if not active: return false
	# An unfinished copy preview is never part of an applied room layout.
	cancel_group_copy_preview()
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
		committed_mounts = surface_mounts.duplicate(true)
		committed_wall_mounts = wall_mounts.duplicate(true)
		committed_style = world.get_node("Room").style.duplicate()
		committed_blueprint = blueprint.duplicate(true)
		saved = export_layout()
	else:
		restore(committed)
		placed_instances = committed_placements.duplicate()
		furniture_colors = committed_colors.duplicate()
		surface_mounts = committed_mounts.duplicate(true)
		wall_mounts = committed_wall_mounts.duplicate(true)
		_sync_mount_poses()
		_sync_wall_mount_poses()
		_apply_furniture_appearance()
		world.get_node("Room").apply_style(committed_style)
		blueprint = committed_blueprint.duplicate(true)
		room_half_size = BlueprintData.half_size(blueprint)
		world.get_node("Room").apply_blueprint(blueprint)
	active = false
	group_selection.clear()
	quick_groups.clear()
	_clear_group_markers()
	gizmo.hide()
	return true

func _group_eligible(role: String) -> bool:
	return nodes.has(role) and placed_instances.has(role) and is_floor(role) and InventoryData.is_room_furniture_role(Data.base_role(role))

func quick_group_members(slot: int) -> Array[String]:
	var members: Array[String] = []
	if not active or slot < 1 or slot > QUICK_GROUP_SLOTS or not quick_groups.has(slot): return members
	var data: Dictionary = quick_groups[slot]
	for value in data.roles:
		var role: String = str(value)
		if not _group_eligible(role): continue
		if str(data.uids.get(role,"")) != str(placed_instances.get(role,"")): continue
		if not members.has(role): members.append(role)
	return members

func quick_group_size(slot: int) -> int:
	return quick_group_members(slot).size()

func quick_group_summary(slot: int) -> String:
	if not quick_groups.has(slot): return "未保存"
	var members: Array[String] = quick_group_members(slot)
	if members.size() < 2: return "已失效 · 可清空或重新保存"
	var labels: Array[String] = []
	for role: String in members.slice(0,2): labels.append(name_for(role))
	return "%d 件 · %s%s" % [members.size(),"、".join(labels),"…" if members.size() > 2 else ""]

func save_quick_group(slot: int) -> bool:
	if not active or slot < 1 or slot > QUICK_GROUP_SLOTS or not gesture.is_empty() or not placing_role.is_empty(): return false
	if group_selection.size() < 2 or not group_selection.has(selected): return false
	var uids := {}
	for role: String in group_selection:
		if not _group_eligible(role): return false
		uids[role] = str(placed_instances[role])
	quick_groups[slot] = {"roles":group_selection.duplicate(), "uids":uids, "primary":selected}
	changed.emit()
	return true

func recall_quick_group(slot: int) -> bool:
	if not active or not gesture.is_empty() or not placing_role.is_empty() or slot < 1 or slot > QUICK_GROUP_SLOTS: return false
	var members: Array[String] = quick_group_members(slot)
	if members.size() < 2: return false
	end_drag()
	group_selection = members
	var preferred: String = str(quick_groups[slot].get("primary",""))
	selected = preferred if members.has(preferred) else members.back()
	update()
	return true

func clear_quick_group(slot: int) -> bool:
	if not active or slot < 1 or slot > QUICK_GROUP_SLOTS or not quick_groups.has(slot): return false
	quick_groups.erase(slot)
	changed.emit()
	return true

func group_pivot() -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for role: String in group_selection:
		if not _group_eligible(role): continue
		center += Vector2(nodes[role].position.x,nodes[role].position.z)
		count += 1
	return center/float(count) if count > 0 else Vector2.ZERO

func group_center_world_point() -> Vector3:
	var pivot: Vector2 = group_pivot()
	var height := 0.0
	for role: String in group_selection:
		if _group_eligible(role):
			height = maxf(height,nodes[role].position.y + bounds_for(role).y)
	return world.to_global(Vector3(pivot.x,height+.24,pivot.y))

func set_primary_group_member(role: String) -> bool:
	if not active or not gesture.is_empty() or group_selection.size() < 2 or not group_selection.has(role): return false
	if selected == role: return false
	select(role,true)
	return true

func remove_group_member(role: String) -> bool:
	if group_selection.size() < 2 or not group_selection.has(role): return false
	return toggle_group_member(role)

func group_world_bounds(roles: Array[String] = []) -> Rect2:
	var members: Array[String] = group_selection if roles.is_empty() else roles
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	for role: String in members:
		if not _group_eligible(role): continue
		for corner: Vector2 in footprint(role):
			minimum = minimum.min(corner)
			maximum = maximum.max(corner)
	return Rect2(minimum,maximum-minimum) if minimum.x != INF else Rect2()

func marquee_candidates(window: Rect2, crossing: bool = false) -> Array[String]:
	var matches: Array[String] = []
	if not active or not placing_role.is_empty() or not gesture.is_empty() or not window.has_area(): return matches
	var camera: Camera3D = world.camera
	var view: Rect2 = Rect2(Vector2.ZERO,world.get_viewport().get_visible_rect().size)
	for role: String in nodes:
		if not _group_eligible(role): continue
		var node: Node3D = nodes[role]
		var half: Vector3 = bounds_for(role)*.5
		var minimum := Vector2(INF,INF)
		var maximum := Vector2(-INF,-INF)
		var behind := false
		for x in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				for y in [0.0,1.0]:
					var corner: Vector3 = node.to_global(Vector3(half.x*x,half.y*y*2.0,half.z*z))
					if camera.is_position_behind(corner):
						behind = true
						break
					var point: Vector2 = camera.unproject_position(corner)
					minimum = minimum.min(point)
					maximum = maximum.max(point)
				if behind: break
			if behind: break
		if behind: continue
		var footprint_rect := Rect2(minimum,maximum-minimum)
		if not view.intersects(footprint_rect): continue
		if crossing and window.intersects(footprint_rect) or not crossing and window.encloses(footprint_rect):
			matches.append(role)
	return matches

func marquee_select(window: Rect2, crossing: bool = false, additive: bool = false) -> int:
	if not active or not gesture.is_empty() or not placing_role.is_empty(): return 0
	var roles: Array[String] = marquee_candidates(window,crossing)
	if roles.is_empty() and additive: return 0
	var chosen: Array[String] = []
	if additive:
		for role: String in group_selection:
			if _group_eligible(role): chosen.append(role)
	for role: String in roles:
		if not chosen.has(role): chosen.append(role)
	end_drag()
	if chosen.is_empty():
		clear_group_selection()
		return 0
	group_selection = chosen
	selected = roles.back() if not roles.is_empty() else chosen.back()
	update()
	return roles.size()

func select(role: String, preserve_group: bool = false) -> void:
	if not nodes.has(role) or not placing_role.is_empty(): return
	if InventoryData.is_room_furniture_role(Data.base_role(role)) and not placed_instances.has(role): return
	end_drag()
	if not preserve_group or not group_selection.has(role):
		group_selection.clear()
		if _group_eligible(role): group_selection.append(role)
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
	group_selection.clear()
	if _group_eligible(selected): group_selection.append(selected)
	update()

func _clear_group_markers() -> void:
	for marker: MeshInstance3D in group_markers.values():
		if is_instance_valid(marker): marker.queue_free()
	group_markers.clear()
	if is_instance_valid(group_bounds_marker): group_bounds_marker.queue_free()
	group_bounds_marker = null

func _sync_group_bounds() -> void:
	var rect: Rect2 = group_world_bounds()
	if not rect.has_area(): return
	if not is_instance_valid(group_bounds_marker):
		group_bounds_marker = MeshInstance3D.new()
		group_bounds_marker.name = "GroupBoundsAndPivot"
		group_bounds_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(group_bounds_marker)
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = Color("61d9ff")
	lines.surface_begin(Mesh.PRIMITIVE_LINES,material)
	var minimum: Vector2 = rect.position
	var maximum: Vector2 = rect.end
	var y := .085
	var corners := [
		Vector3(minimum.x,y,minimum.y),
		Vector3(maximum.x,y,minimum.y),
		Vector3(maximum.x,y,maximum.y),
		Vector3(minimum.x,y,maximum.y)
	]
	for i in range(4):
		lines.surface_add_vertex(corners[i])
		lines.surface_add_vertex(corners[(i+1)%4])
	# This cross is the actual rotation pivot (mean of member centers),
	# rather than the potentially different bounding-box midpoint.
	var pivot: Vector2 = group_pivot()
	var radius := .14
	for displacement in [Vector2(radius,0),Vector2(0,radius)]:
		lines.surface_add_vertex(Vector3(pivot.x-displacement.x,y,pivot.y-displacement.y))
		lines.surface_add_vertex(Vector3(pivot.x+displacement.x,y,pivot.y+displacement.y))
	lines.surface_end()
	group_bounds_marker.mesh = lines

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
	_sync_group_bounds()

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
	surface_mounts.clear()
	wall_mounts.clear()
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
	if wall_mounts.has(role): return "wall"
	if surface_mounts.has(role): return "mount"
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
	if wall_mounts.has(selected): return
	if surface_mounts.has(selected):
		var mounted: Dictionary = surface_mounts[selected]
		edit_selected_mount(position_xz,float(mounted.yaw))
		return
	if not placing_role.is_empty():
		preview_placement(position_xz)
		return
	if group_selection.size() > 1:
		var before_group := _draft()
		var target := position_xz.snapped(Vector2.ONE*grid_step) if snapping else position_xz
		var anchor: Vector3 = nodes[selected].position
		var desired: Vector2 = target-Vector2(anchor.x,anchor.z)
		var magnet_delta: Vector2 = _group_wall_snap_delta(desired)
		var snapped: bool = not magnet_delta.is_equal_approx(desired)
		_transform_group(magnet_delta,0.0,snapped)
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
	if not active or wall_mounts.has(selected): return
	if surface_mounts.has(selected):
		var mounted: Dictionary = surface_mounts[selected]
		edit_selected_mount(Vector2(float(mounted.x),float(mounted.z)),yaw)
		return
	if not placing_role.is_empty():
		var target: float = wrapf(snappedf(yaw,deg_to_rad(angle_step)) if snapping else yaw,-PI,PI)
		if surface_mounts.has(placing_role):
			var mount: Dictionary = surface_mounts[placing_role].duplicate(true)
			var support: Node3D = nodes[mount.support]
			mount["yaw"] = wrapf(target-support.global_rotation.y,-PI,PI)
			if not _mount_collision(placing_role,mount).is_empty():
				message = "旋转会超出陈列表面或碰到其他物品"
				changed.emit()
				return
			surface_mounts[placing_role] = mount
			_sync_mount_poses()
		else:
			nodes[placing_role].rotation.y = target
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
	if wall_mounts.has(role): return _wall_mount_blocker(role,wall_mounts[role])
	if surface_mounts.has(role): return _mount_collision(role,surface_mounts[role])
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
	_sync_mount_poses()
	_sync_wall_mount_poses()
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

func _group_wall_snap_delta(delta: Vector2) -> Vector2:
	wall_magnet_active = false
	var temporary: bool = smart_snap and gesture == "move" and not snap_bypass
	var exterior: bool = not snap_bypass and (wall_snap or temporary)
	var interior: bool = not snap_bypass and (inner_wall_snap or temporary)
	if not exterior and not interior: return delta
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	var initial := {}
	for role: String in group_selection:
		var pose: Transform3D = nodes[role].transform
		initial[role] = pose
		pose.origin.x += delta.x
		pose.origin.z += delta.y
		for point: Vector2 in _footprint_at(role,pose,0.0):
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	var candidates: Array[Vector2] = []
	if exterior:
		var half: Vector2 = BlueprintData.half_size(blueprint)
		var safety := edge_margin+collision_margin+.015
		for axis_id in range(2):
			for direction in [-1.0,1.0]:
				var adjustment: float
				if axis_id == 0:
					adjustment = -half.x+safety-minimum.x if direction < 0 else half.x-safety-maximum.x
				else:
					adjustment = -half.y+safety-minimum.y if direction < 0 else half.y-safety-maximum.y
				if absf(adjustment) <= WALL_SNAP_RADIUS:
					candidates.append(delta+(Vector2(adjustment,0) if axis_id == 0 else Vector2(0,adjustment)))
	if interior:
		for part: Dictionary in blueprint.partitions:
			if str(part.kind) == "door": continue
			var extents: Vector2 = BlueprintData.extents(part)
			for direction in [-1.0,1.0]:
				var adjustment: float
				if part.axis == "x":
					if maximum.x < float(part.x)-extents.x or minimum.x > float(part.x)+extents.x: continue
					adjustment = float(part.z)-extents.y-WALL_SAFE_GAP-maximum.y if direction < 0 else float(part.z)+extents.y+WALL_SAFE_GAP-minimum.y
					if absf(adjustment) <= WALL_SNAP_RADIUS: candidates.append(delta+Vector2(0,adjustment))
				else:
					if maximum.y < float(part.z)-extents.y or minimum.y > float(part.z)+extents.y: continue
					adjustment = float(part.x)-extents.x-WALL_SAFE_GAP-maximum.x if direction < 0 else float(part.x)+extents.x+WALL_SAFE_GAP-minimum.x
					if absf(adjustment) <= WALL_SNAP_RADIUS: candidates.append(delta+Vector2(adjustment,0))
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_to(delta) < b.distance_to(delta))
	var pivot: Vector2 = group_pivot()
	for candidate: Vector2 in candidates:
		var target: Dictionary = _group_pose_targets(initial,candidate,0.0,1.0,pivot)
		if _group_swept_contact(initial,target).is_empty(): return candidate
	return delta

func _transform_group(delta: Vector2, yaw: float, magnet: bool = false) -> void:
	if group_selection.size() <= 1 or not _group_eligible(selected): return
	var initial := {}
	var pivot: Vector2 = group_pivot()
	for role: String in group_selection:
		if not _group_eligible(role): return
		var pose: Transform3D = nodes[role].transform
		initial[role] = pose
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
	wall_magnet_active = magnet and blocker.is_empty()
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
	if wall_mounts.has(selected):
		var before_wall: bool = snapping
		if fine: snapping = false
		# Screen Up should raise a wall frame; floor Z still follows the old keys.
		var changed_wall: bool = move_wall_mount(Vector2(direction.x,-direction.y).normalized() * (0.01 if fine else grid_step))
		snapping = before_wall
		return changed_wall
	var previous: Transform3D = nodes[selected].transform
	var mount_before: Dictionary = surface_mounts.get(selected,{}).duplicate(true)
	var step: float = 0.01 if fine else grid_step
	var previous_snap: bool = snapping
	if fine: snapping = false
	var origin := Vector2(float(mount_before.x),float(mount_before.z)) if not mount_before.is_empty() else Vector2(previous.origin.x,previous.origin.z)
	move_to(origin + direction.normalized() * step)
	snapping = previous_snap
	if fine: update()
	return mount_before != surface_mounts.get(selected,{}) if not mount_before.is_empty() else not previous.is_equal_approx(nodes[selected].transform)

func rotate_step(direction: float, fine: bool = false) -> void:
	if not active or not nodes.has(selected): return
	# 1-degree rotation must not be rounded back to the normal 15-degree grid.
	var previous_snap: bool = snapping
	if fine: snapping = false
	var yaw: float = float(surface_mounts[selected].yaw) if surface_mounts.has(selected) else nodes[selected].rotation.y
	rotate_to(yaw + deg_to_rad(1.0 if fine else angle_step) * direction)
	snapping = previous_snap
	if fine: update()

func _plane_point(pixel: Vector2) -> Variant:
	var frame: Node3D = world if is_floor(selected) else group
	var height := drag_height
	var plane := Plane(frame.global_basis.y.normalized(), frame.to_global(Vector3(0,height,0)))
	var hit: Variant = plane.intersects_ray(world.camera.project_ray_origin(pixel), world.camera.project_ray_normal(pixel))
	return frame.to_local(hit) if hit != null else null

func begin_drag(pixel: Vector2, operation: String = "move", direction: String = "plane", from_handle: bool = false) -> void:
	if not active or wall_mounts.has(selected): return
	if surface_mounts.has(selected):
		var mounted_hit: Variant = _mounted_hit(pixel)
		if mounted_hit == null: return
		var entry: Dictionary = surface_mounts[selected]
		drag_before = _draft()
		gesture = operation
		axis = direction
		start_hit = mounted_hit
		start_position = Vector3(float(entry.x),0.0,float(entry.z))
		start_yaw = float(entry.yaw)
		start_group_pivot = Vector2(start_position.x,start_position.z)
		start_axis = (Vector3.RIGHT if axis == "x" else Vector3.BACK)
		start_angle = atan2(mounted_hit.z-start_position.z,mounted_hit.x-start_position.x)
		update()
		return
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
	start_group_pivot = group_pivot() if group_selection.size() > 1 else Vector2(start_position.x,start_position.z)
	# Group gizmo is world-aligned even when the primary item's own yaw differs.
	start_axis = (Vector3.RIGHT if axis == "x" else Vector3.BACK) if group_selection.size() > 1 else (nodes[selected].basis.x if axis == "x" else nodes[selected].basis.z).normalized()
	start_angle = atan2(hit.z - start_group_pivot.y, hit.x - start_group_pivot.x)
	# Show the contextual gesture cue immediately on pointer-down, not only
	# after the first mouse motion event.
	update()

func drag_to(pixel: Vector2) -> void:
	if gesture.is_empty(): return
	if surface_mounts.has(selected):
		var mounted_hit: Variant = _mounted_hit(pixel)
		if mounted_hit == null: return
		if gesture == "move":
			var delta: Vector3 = mounted_hit-start_hit
			if axis in ["x","z"]: delta = start_axis * delta.dot(start_axis)
			var offset := Vector2(start_position.x+delta.x,start_position.z+delta.z)
			move_to(offset.snapped(Vector2.ONE*grid_step) if snapping else offset)
		else:
			var current := atan2(mounted_hit.z-start_group_pivot.y,mounted_hit.x-start_group_pivot.x)
			rotate_to(start_yaw - angle_difference(start_angle,current))
		return
	var hit: Variant = _plane_point(pixel)
	if hit == null: return
	if gesture == "move":
		var delta: Vector3 = hit - start_hit
		if axis in ["x", "z"]: delta = start_axis * delta.dot(start_axis)
		move_to(Vector2(start_position.x + delta.x, start_position.z + delta.z))
	else:
		var current := atan2(hit.z - start_group_pivot.y, hit.x - start_group_pivot.x)
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
		group_selection.clear()
		group_selection.append(selected)
	_sync_group_markers()
	var blocker := _layout_blocker()
	valid = blocker.is_empty()
	if not placing_role.is_empty(): _apply_furniture_appearance()
	message = "右键环绕 · 滚轮缩放 · 拖动物品布置房间"
	if not placing_role.is_empty():
		message = "贴面预览 · 左键放置 · Q/E 旋转 · 右键取消" if surface_mounts.has(placing_role) else "地面预览 · 移到桌面或书架可自动贴面 · 左键放置 · 右键取消"
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
	var multi: bool = group_selection.size() > 1
	var size := bounds_for(selected) * node.scale.abs()
	# Solo mode retains the familiar local gizmo. In group mode both tools
	# share the P34 centroid and world-aligned X/Z axes, not the primary yaw.
	var base_height := .06 if is_floor(selected) else .02
	var center: Vector3 = node.to_global(Vector3(0,tabletop_height,0)) if selected == "desk" else node.to_global(Vector3(0,base_height,0))
	var handle_height := 0.0 if selected == "desk" else size.y + .08
	if multi:
		var pivot: Vector2 = group_pivot()
		center = world.to_global(Vector3(pivot.x,.06,pivot.y))
		var peak := 0.0
		for role: String in group_selection:
			if _group_eligible(role):
				peak = maxf(peak,nodes[role].position.y + bounds_for(role).y)
		handle_height = maxf(.18,peak+.08)
	gizmo.global_position = center
	gizmo.global_rotation.y = 0.0 if multi else node.global_rotation.y
	var outline: MeshInstance3D = gizmo.get_node("Outline")
	# P34 already outlines the full group footprint without a physics collider.
	outline.visible = not multi
	if not multi:
		outline.scale = Vector3(size.x + .06,size.z + .06,1)
		outline.material_override.set_shader_parameter("line_color",Color("ff756a") if not valid else Color("ffc563") if contact else Color("82c6a3") if wall_magnet_active else Color("61d9ff"))
	gizmo.get_node("MoveHandles").position.y = handle_height
	gizmo.get_node("RotateHandles").position.y = handle_height
	gizmo.get_node("MoveHandles").visible = tool == "move"
	gizmo.get_node("RotateHandles").visible = tool == "rotate"
	# Hidden tools must not intercept picking.
	for handle in gizmo.find_children("*","CollisionShape3D",true,false):
		handle.disabled = (handle.get_parent().get_parent().name == "MoveHandles") != (tool == "move")
