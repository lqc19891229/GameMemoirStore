@tool
extends SubViewportContainer
## A single on-demand 3D preview, never one viewport per catalog row.
## Models are instantiated in an isolated World3D, not in the edited scene.

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
		for anchor in support_anchors:
			var center: Vector3 = anchor.center
			var footprint: Vector2 = anchor.size
			_add_rectangle_edges(mesh, center + Vector3(0, 0.01, 0), footprint, Color(0.25, 0.96, 0.62))
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
