extends Node
## One shared offscreen viewport renders actual 3D furniture meshes on demand.
const Finishes = preload("res://scripts/items/furniture_finishes.gd")
const THUMB_SIZE := Vector2i(208, 152)
const MAX_CACHE := 90
var thumbnails: Dictionary = {}
var cache_order: Array[String] = []
var pending: Array[Dictionary] = []
var waiters: Dictionary = {}
var rendering := false
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = THUMB_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var atmosphere := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f0eee8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e9edf0")
	environment.ambient_light_energy = .82
	atmosphere.environment = environment
	stage.add_child(atmosphere)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -28, -12)
	key_light.light_energy = 1.15
	key_light.shadow_enabled = false
	stage.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-28, 140, 0)
	fill_light.light_energy = .48
	fill_light.shadow_enabled = false
	stage.add_child(fill_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	stage.add_child(camera)

func forget_requests() -> void:
	pending.clear()
	waiters.clear()

func request(item: MemoirItemDefinition, target: TextureRect, finish: int = 0) -> void:
	if item == null or item.furniture_scene == null or not Finishes.valid(finish):
		return
	var key: String = "%s:%d" % [item.item_id, finish]
	target.set_meta("thumbnail_key", key)
	target.texture = null
	if thumbnails.has(key):
		target.texture = thumbnails[key]
		return
	if not waiters.has(key):
		waiters[key] = []
		pending.append({"key": key, "item": item, "finish": finish})
	waiters[key].append(target)
	if not rendering:
		_render_next.call_deferred()

func _render_next() -> void:
	if rendering or pending.is_empty() or not is_inside_tree():
		return
	rendering = true
	var entry: Dictionary = pending.pop_front()
	var key: String = str(entry.key)
	var item: MemoirItemDefinition = entry.item
	var furniture: Node3D = item.furniture_scene.instantiate() as Node3D
	if furniture == null:
		rendering = false
		_render_next.call_deferred()
		return
	stage.add_child(furniture)
	var bounds: Vector3 = furniture.get("bounds")
	Finishes.apply_preview(furniture, int(entry.finish))
	var center := Vector3(0, bounds.y * .47, 0)
	var extent := maxf(bounds.y * 1.55, (bounds.x + bounds.z) * 1.11)
	var distance := maxf(3.0, extent * 2.2)
	camera.position = center + Vector3(1.35, 1.05, 1.6).normalized() * distance
	camera.look_at(center, Vector3.UP)
	camera.size = maxf(.75, extent)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var result: Image = viewport.get_texture().get_image()
	if result != null and not result.is_empty():
		var texture := ImageTexture.create_from_image(result)
		thumbnails[key] = texture
		cache_order.append(key)
		if cache_order.size() > MAX_CACHE:
			thumbnails.erase(cache_order.pop_front())
		for target: TextureRect in waiters.get(key, []):
			if is_instance_valid(target) and target.get_meta("thumbnail_key", "") == key:
				target.texture = texture
	waiters.erase(key)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	furniture.free()
	rendering = false
	if not pending.is_empty():
		_render_next.call_deferred()
