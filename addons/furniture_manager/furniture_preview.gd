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
