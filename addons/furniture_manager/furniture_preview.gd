@tool
extends SubViewportContainer
## A single on-demand 3D preview, never one viewport per catalog row.
## Models are instantiated in an isolated World3D, not in the edited scene.
signal anchor_selected(index: int)
signal anchor_changed(index: int, data: Dictionary)

const Drag = preload("res://addons/furniture_manager/support_surface_drag.gd")

var viewport: SubViewport
var scene_root: Node3D
var camera: Camera3D
var model: Node3D
var orbit_degrees := 35.0
var measured_size := Vector3.ZERO
var authored_bounds := Vector3.ZERO
var support_anchors: Array[Dictionary] = []
var show_bounds := false
var show_surfaces := false
var overlay: MeshInstance3D
var edit_surfaces := false
var selected_anchor := -1
var drag_index := -1
var drag_handle := ""
var drag_start_anchor: Dictionary = {}
var drag_start_position := Vector3.ZERO
const SupportSurfaces = preload("res://scripts/room/furniture_support_surfaces.gd")


func _ready() -> void:
	custom_minimum_size = Vector2(230, 145)
	stretch = true
	viewport = SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.transparent_bg = false
	viewport.own_world_3d = true
	viewport.size = Vector2i(400, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)

	scene_root = Node3D.new()
	scene_root.name = "PreviewScene"
	viewport.add_child(scene_root)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.73, 0.78)
	env.ambient_light_energy = 0.75
	environment.environment = env
	scene_root.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -30, 0)
	key.light_energy = 1.1
	scene_root.add_child(key)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	scene_root.add_child(camera)
	_reposition_camera()


func show_furniture(scene: PackedScene) -> void:
	if model != null:
		model.free()
		model = null
	measured_size = Vector3.ZERO
	authored_bounds = Vector3.ZERO
	support_anchors.clear()
	selected_anchor = -1
	drag_index = -1
	if overlay != null:
		overlay.free()
		overlay = null
	orbit_degrees = 35.0
	if scene == null:
		return
	var instance := scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return
	model = instance as Node3D
	scene_root.add_child(model)
	# Measure actual geometry including offset meshes, not arbitrary collision data.
	var bounds := _mesh_bounds(model)
	if bounds.size.length_squared() > 0.0:
		measured_size = bounds.size
		model.position = -bounds.get_center()
	else:
		measured_size = Vector3.ONE
	authored_bounds = _read_authored_bounds(model)
	support_anchors = SupportSurfaces.anchors_for(model)
	_rebuild_overlays()
	_reposition_camera()


func rotate_preview(delta: float) -> void:
	orbit_degrees = fposmod(orbit_degrees + delta, 360.0)
	_reposition_camera()


func _reposition_camera() -> void:
	if camera == null:
		return
	var extent := maxf(measured_size.length(), 1.0)
	camera.size = maxf(extent * 1.35, 1.5)
	var angle := deg_to_rad(orbit_degrees)
	var distance := maxf(extent * 2.6, 4.0)
	camera.position = Vector3(sin(angle) * distance, distance * 0.6, cos(angle) * distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _mesh_bounds(root_model: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var nodes: Array[Node] = [root_model]
	while not nodes.is_empty():
		var node := nodes.pop_back()
		if node is MeshInstance3D and node.mesh != null:
			var mesh_node := node as MeshInstance3D
			var box := mesh_node.get_aabb()
			for x in [box.position.x, box.end.x]:
				for y in [box.position.y, box.end.y]:
					for z in [box.position.z, box.end.z]:
						var point := root_model.to_local(mesh_node.to_global(Vector3(x, y, z)))
						if not found:
							result = AABB(point, Vector3.ZERO)
							found = true
						else:
							result = result.expand(point)
		for child in node.get_children():
			nodes.append(child)
	return result

func _read_authored_bounds(node: Node3D) -> Vector3:
	for property in node.get_property_list():
		if property.name == "bounds" and property.type == TYPE_VECTOR3:
			var value: Vector3 = node.get("bounds")
			if is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and value.x > 0.0 and value.y > 0.0 and value.z > 0.0:
				return value
			return Vector3.ZERO
	return Vector3.ZERO


func preview_staged_surfaces(anchors: Array[Dictionary]) -> void:
	# Temporary visual only; does not mutate the furniture scene or runtime metadata.
	support_anchors = anchors.duplicate(true)
	if selected_anchor >= support_anchors.size():
		selected_anchor = -1
	_rebuild_overlays()


func set_overlay_visibility(bounds_visible: bool, surfaces_visible: bool) -> void:
	show_bounds = bounds_visible
	show_surfaces = surfaces_visible
	_rebuild_overlays()


func _rebuild_overlays() -> void:
	if overlay != null:
		overlay.free()
		overlay = null
	if model == null or (not show_bounds and not show_surfaces):
		return
	if (not show_bounds or authored_bounds == Vector3.ZERO) and (not show_surfaces or support_anchors.is_empty()):
		return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	if show_bounds and authored_bounds != Vector3.ZERO:
		_add_box_edges(mesh, Vector3(0, authored_bounds.y * 0.5, 0), authored_bounds, Color(1.0, 0.55, 0.16))
	if show_surfaces:
		for index in range(support_anchors.size()):
			var anchor := support_anchors[index]
			var center: Vector3 = anchor.center
			var footprint: Vector2 = anchor.size
			_add_rectangle_edges(mesh, center + Vector3(0, 0.01, 0), footprint, Color(1.0, 0.92, 0.28) if index == selected_anchor else Color(0.25, 0.96, 0.62))
			if edit_surfaces and index == selected_anchor:
				for handle in ["move", "left", "right", "near", "far"]:
					var point := _handle_local_point(anchor, handle) + Vector3(0, 0.025, 0)
					_add_cross(mesh, point, Color(1.0, 0.92, 0.28), 0.045)
	mesh.surface_end()
	overlay = MeshInstance3D.new()
	overlay.name = "PreviewGuides"
	overlay.mesh = mesh
	overlay.position = model.position
	scene_root.add_child(overlay)


func _add_edge(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(b)


func _add_box_edges(mesh: ImmediateMesh, center: Vector3, size: Vector3, color: Color) -> void:
	var half := size * 0.5
	for y in [-1.0, 1.0]:
		for x in [-1.0, 1.0]:
			_add_edge(mesh, center + Vector3(x * half.x, y * half.y, -half.z), center + Vector3(x * half.x, y * half.y, half.z), color)
		for z in [-1.0, 1.0]:
			_add_edge(mesh, center + Vector3(-half.x, y * half.y, z * half.z), center + Vector3(half.x, y * half.y, z * half.z), color)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_add_edge(mesh, center + Vector3(x * half.x, -half.y, z * half.z), center + Vector3(x * half.x, half.y, z * half.z), color)


func _add_rectangle_edges(mesh: ImmediateMesh, center: Vector3, size: Vector2, color: Color) -> void:
	var half := size * 0.5
	var a := center + Vector3(-half.x, 0, -half.y)
	var b := center + Vector3(half.x, 0, -half.y)
	var c := center + Vector3(half.x, 0, half.y)
	var d := center + Vector3(-half.x, 0, half.y)
	_add_edge(mesh, a, b, color)
	_add_edge(mesh, b, c, color)
	_add_edge(mesh, c, d, color)
	_add_edge(mesh, d, a, color)


func set_edit_surfaces(value: bool) -> void:
	edit_surfaces = value
	if not edit_surfaces:
		drag_index = -1
	_rebuild_overlays()


func set_selected_anchor(index: int) -> void:
	selected_anchor = index if index >= 0 and index < support_anchors.size() else -1
	_rebuild_overlays()


func _add_cross(mesh: ImmediateMesh, point: Vector3, color: Color, radius: float) -> void:
	_add_edge(mesh, point + Vector3(-radius, 0, 0), point + Vector3(radius, 0, 0), color)
	_add_edge(mesh, point + Vector3(0, 0, -radius), point + Vector3(0, 0, radius), color)


func _handle_local_point(anchor: Dictionary, handle: String) -> Vector3:
	var center: Vector3 = anchor.center
	var surface_size: Vector2 = anchor.size
	match handle:
		"left":
			return center + Vector3(-surface_size.x * 0.5, 0, 0)
		"right":
			return center + Vector3(surface_size.x * 0.5, 0, 0)
		"near":
			return center + Vector3(0, 0, -surface_size.y * 0.5)
		"far":
			return center + Vector3(0, 0, surface_size.y * 0.5)
	return center


func _screen_to_viewport(screen: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return screen
	return screen * Vector2(viewport.size) / size


func _viewport_to_screen(point: Vector2) -> Vector2:
	if viewport.size.x <= 0 or viewport.size.y <= 0:
		return point
	return point * size / Vector2(viewport.size)


func anchor_handle_screen_position(index: int, handle: String) -> Vector2:
	if model == null or index < 0 or index >= support_anchors.size():
		return Vector2(-9999, -9999)
	var location: Vector3 = model.to_global(_handle_local_point(support_anchors[index], handle))
	return _viewport_to_screen(camera.unproject_position(location))


func _pick_anchor_handle(screen: Vector2) -> Dictionary:
	var best := {}
	var distance := 15.0
	for i in range(support_anchors.size()):
		for handle in ["move", "left", "right", "near", "far"]:
			var pos := anchor_handle_screen_position(i, handle)
			var d := screen.distance_to(pos)
			if d <= distance:
				distance = d
				best = {"index": i, "handle": handle}
	return best


func _mouse_on_drag_plane(screen: Vector2, height: float) -> Variant:
	if camera == null or model == null:
		return null
	var projected := _screen_to_viewport(screen)
	var origin := camera.project_ray_origin(projected)
	var direction := camera.project_ray_normal(projected)
	var plane := Plane(Vector3.UP, model.to_global(Vector3(0, height, 0)).y)
	var point: Variant = plane.intersects_ray(origin, direction)
	if point == null:
		return null
	return model.to_local(point)


func _gui_input(event: InputEvent) -> void:
	if not edit_surfaces or not show_surfaces or model == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var picked := _pick_anchor_handle(event.position)
			if picked.is_empty():
				return
			drag_index = picked.index
			drag_handle = picked.handle
			selected_anchor = drag_index
			drag_start_anchor = support_anchors[drag_index].duplicate(true)
			var plane_point: Variant = _mouse_on_drag_plane(event.position, drag_start_anchor.center.y)
			if plane_point == null:
				drag_index = -1
				return
			drag_start_position = plane_point
			anchor_selected.emit(drag_index)
			_rebuild_overlays()
			accept_event()
		elif drag_index >= 0:
			drag_index = -1
			accept_event()
	elif event is InputEventMouseMotion and drag_index >= 0:
		var point: Variant = _mouse_on_drag_plane(event.position, drag_start_anchor.center.y)
		if point == null:
			return
		var delta := Vector2(point.x - drag_start_position.x, point.z - drag_start_position.z)
		var changed: Dictionary = Drag.changed_anchor(drag_start_anchor, drag_handle, delta)
		if changed != support_anchors[drag_index]:
			support_anchors[drag_index] = changed
			anchor_changed.emit(drag_index, changed.duplicate(true))
			_rebuild_overlays()
		accept_event()
