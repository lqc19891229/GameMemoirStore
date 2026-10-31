extends Node3D
@onready var camera: Camera3D = %Camera
@onready var layout: Node = %LayoutEditor
var mode := "overview"
var overview_camera: Transform3D
var devices: Dictionary = {}
var motion: Tween
var transitioning := false
var overview_yaw := 0.0
var overview_pitch := 0.25
var overview_distance := 6.0
var overview_view: Transform3D
@export var orbit_target := Vector3(0, 1.1, 0)
@export var minimum_distance := 1.8
@export var maximum_distance := 22.0

func _ready() -> void:
	overview_camera = camera.transform
	reset_overview()
	devices = {"monitor": %Monitor, "computer": %Computer, "keyboard": %Keyboard, "mouse": %Mouse}
	layout.setup(self)
	var room = $Room
	var lighting = $Lighting
	room.style_changed.connect(lighting.apply_style)
	lighting.apply_style(room.style)

func _process(_delta: float) -> void:
	$Room.update_cutaway(camera)

func set_screen_texture(texture: Texture2D) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	%Monitor.get_node("Screen").material_override = material

func set_mode(value: String, animate: bool = true) -> void:
	mode = value
	$PixelPass.visible = value != "screen"
	if motion != null and motion.is_valid(): motion.kill()
	var destination := overview_view
	if value == "screen":
		var screen: MeshInstance3D = %Monitor.get_node("Screen")
		var size: Vector2 = screen.mesh.size * Vector2(screen.global_basis.x.length(), screen.global_basis.y.length())
		var viewport_size := camera.get_viewport().get_visible_rect().size
		var fill_height := minf(0.82, 0.92 * (viewport_size.x / viewport_size.y) / (size.x / size.y))
		var distance := size.y / (2.0 * tan(deg_to_rad(camera.fov / 2.0)) * fill_height)
		var target: Vector3 = screen.global_position
		var front := screen.global_basis.z.normalized()
		var global_view := Transform3D(Basis.IDENTITY, target + front * distance).looking_at(target, screen.global_basis.y.normalized())
		destination = camera.get_parent().global_transform.affine_inverse() * global_view
	transitioning = animate
	if animate:
		motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		motion.tween_property(camera, "transform", destination, 0.35)
		motion.finished.connect(func() -> void: transitioning = false)
	else:
		camera.transform = destination

func reset_overview() -> void:
	if mode not in ["overview", "layout"] or transitioning: return
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
	if transitioning or mode not in ["overview", "layout"]: return
	overview_yaw = wrapf(overview_yaw - delta.x * 0.006, -PI, PI)
	overview_pitch = clampf(overview_pitch + delta.y * 0.005, 0.12, 1.18)
	_update_overview_camera()

func zoom_overview(amount: float) -> void:
	if transitioning or mode not in ["overview", "layout"]: return
	overview_distance = clampf(overview_distance * amount, minimum_distance, maximum_distance)
	_update_overview_camera()

func screen_uv(pixel: Vector2, clip: bool = true) -> Variant:
	var screen: MeshInstance3D = %Monitor.get_node("Screen")
	var normal := screen.global_basis.z.normalized()
	var direction := camera.project_ray_normal(pixel)
	if normal.dot(direction) >= 0.0: return null
	var plane := Plane(normal, screen.global_position)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(pixel), direction)
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
	if result.is_empty(): return ""
	return str(result.collider.get_meta("layout_role", "")) if result.collider.has_meta("layout_role") else str(result.collider.get_parent().role)
