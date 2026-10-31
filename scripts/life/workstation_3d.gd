extends Node3D
@onready var camera: Camera3D = %Camera
@onready var equipment: Node3D = %Equipment
var mode := "overview"
var selected := "monitor"
var overview_camera: Transform3D
var placements: Dictionary = {}
var devices: Dictionary = {}
var motion: Tween
var transitioning := false
var inspect_distance := 2.5
var inspect_target := Vector3.ZERO
var overview_yaw := 0.0
var overview_pitch := 0.25
var overview_distance := 6.0
var overview_view: Transform3D
@export var orbit_target := Vector3(0, 1.15, 0)
@export var minimum_distance := 1.8
@export var maximum_distance := 10.5
var inspect_pitch := 0.35

func _ready() -> void:
	overview_camera = camera.transform
	reset_overview()
	devices = {"monitor": %Monitor, "computer": %Computer, "keyboard": %Keyboard, "mouse": %Mouse}
	for role: String in devices: placements[role] = devices[role].transform

func set_screen_texture(texture: Texture2D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	%Monitor.get_node("Screen").material_override = material

func set_mode(value: String, role: String = "monitor", animate: bool = true) -> void:
	mode = value
	selected = role
	if motion != null and motion.is_valid(): motion.kill()
	for key: String in devices:
		devices[key].transform = placements[key]
		devices[key].visible = value != "inspect" or key == role
	%Desk.visible = value != "inspect"
	%Pedestal.visible = value == "inspect"
	var destination := overview_view
	if value == "screen":
		var screen: MeshInstance3D = %Monitor.get_node("Screen")
		var size: Vector2 = screen.mesh.size * Vector2(screen.global_basis.x.length(), screen.global_basis.y.length())
		var viewport_size := camera.get_viewport().get_visible_rect().size
		var fill_height := minf(0.82, 0.92 * (viewport_size.x / viewport_size.y) / (size.x / size.y))
		var distance := size.y / (2.0 * tan(deg_to_rad(camera.fov / 2.0)) * fill_height)
		var target: Vector3 = screen.global_position
		var front := screen.global_basis.z.normalized()
		destination = Transform3D(Basis.IDENTITY, target + front * distance).looking_at(target, screen.global_basis.y.normalized())
	elif value == "inspect":
		var device: Node3D = devices[role]
		device.position = Vector3(0, 0.94, 0)
		device.rotation = Vector3.ZERO
		var bounds: Vector3 = device.appearance.bounds
		inspect_target = device.position + Vector3(0, bounds.y / 2.0, 0)
		inspect_distance = maxf(bounds.x, maxf(bounds.y, bounds.z)) * 2.8
		inspect_pitch = 0.8 if role in ["keyboard", "mouse"] else 0.35
		%Pedestal.scale = Vector3.ONE * 1.0
		%Pedestal.scale.x = maxf(bounds.x, bounds.z) * 0.8
		%Pedestal.scale.z = maxf(bounds.x, bounds.z) * 0.8
		destination = _inspect_camera()
	transitioning = animate
	if animate:
		motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		motion.tween_property(camera, "transform", destination, 0.35)
		motion.finished.connect(func() -> void: transitioning = false)
	else:
		camera.transform = destination

func _inspect_camera() -> Transform3D:
	var direction := Vector3(0.2 * cos(inspect_pitch), sin(inspect_pitch), cos(inspect_pitch)).normalized()
	return Transform3D(Basis.IDENTITY, inspect_target + direction * inspect_distance).looking_at(inspect_target)

func rotate_product(delta: Vector2) -> void:
	if transitioning or mode != "inspect": return
	var device: Node3D = devices[selected]
	device.rotation.y += delta.x * 0.012
	inspect_pitch = clampf(inspect_pitch + delta.y * 0.005, 0.12, 1.15)
	camera.transform = _inspect_camera()

func zoom_product(amount: float) -> void:
	if transitioning or mode != "inspect": return
	var bounds: Vector3 = devices[selected].appearance.bounds
	var base := maxf(bounds.x, maxf(bounds.y, bounds.z))
	inspect_distance = clampf(inspect_distance * amount, base * 1.5, base * 4.0)
	camera.transform = _inspect_camera()

func reset_overview() -> void:
	if mode != "overview" or transitioning: return
	overview_view = overview_camera
	var offset := overview_camera.origin - orbit_target
	overview_distance = offset.length()
	overview_yaw = atan2(offset.x, offset.z)
	overview_pitch = asin(clampf(offset.y / overview_distance, -1.0, 1.0))
	camera.transform = overview_view

func _update_overview_camera() -> void:
	var direction := Vector3(sin(overview_yaw) * cos(overview_pitch), sin(overview_pitch), cos(overview_yaw) * cos(overview_pitch))
	overview_view = Transform3D(Basis.IDENTITY, orbit_target + direction * overview_distance).looking_at(orbit_target)
	camera.transform = overview_view

func orbit_overview(delta: Vector2) -> void:
	if transitioning or mode != "overview": return
	overview_yaw = wrapf(overview_yaw - delta.x * 0.006, -PI, PI)
	overview_pitch = clampf(overview_pitch + delta.y * 0.005, 0.12, 1.18)
	_update_overview_camera()

func zoom_overview(amount: float) -> void:
	if transitioning or mode != "overview": return
	overview_distance = clampf(overview_distance * amount, minimum_distance, maximum_distance)
	_update_overview_camera()

func screen_uv(pixel: Vector2, clip: bool = true) -> Variant:
	var screen: MeshInstance3D = %Monitor.get_node("Screen")
	var normal := screen.global_basis.z.normalized()
	var plane := Plane(normal, screen.global_position)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
	if hit == null: return null
	var local: Vector3 = screen.to_local(hit)
	var dimensions: Vector2 = screen.mesh.size
	var uv := Vector2(local.x / dimensions.x + 0.5, 0.5 - local.y / dimensions.y)
	if clip and not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv): return null
	return uv

func pixel_for_screen(uv: Vector2) -> Vector2:
	var screen: MeshInstance3D = %Monitor.get_node("Screen")
	var dimensions: Vector2 = screen.mesh.size
	return camera.unproject_position(screen.to_global(Vector3((uv.x - 0.5) * dimensions.x, (0.5 - uv.y) * dimensions.y, 0)))

func pick_at(pixel: Vector2) -> String:
	var origin := camera.project_ray_origin(pixel)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pixel) * 30.0, 1)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return str(result.collider.get_parent().role) if not result.is_empty() else ""
