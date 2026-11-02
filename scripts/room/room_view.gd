@tool
class_name MemoirRoomView
extends Node3D
## Room appearance presets and cutaway visibility for the modern 3D sample room.

const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
var blueprint: Dictionary = Blueprint.DEFAULT.duplicate(true)
var partitions_editing := false

const WALLS := [Color("f1eee8"), Color("e5e1da"), Color("dce6df")]
# Style 0 follows the existing room-wide wall/floor presets.
const WALL_FINISHES := [Color("f1eee8"), Color("d8c5ae"), Color("9dad9f"), Color("8e9ca8")]
const FLOOR_FINISHES := [Color("b99572"), Color("e0d7c6"), Color("9aa69e"), Color("856e5c")]
const FLOORS := [Color("b99572"), Color("967153"), Color("a8ada8")]
const LIGHTS := [Color("fff0dc"), Color("e5efff"), Color("ffd1a1")]
const FILL_LIGHTS := [Color("d9e4df"), Color("d9e8f4"), Color("a8a09a")]
const ZONE_LIGHT_COLORS := [Color("9bcbd8"), Color("ffe3b9"), Color("d5b7ea")]
const ZONE_LIGHT_ENERGY := [0.34,0.28,0.22]
const ATMOSPHERE_NAMES := ["晴昼","日落","夜晚","雨天"]
const ATMOSPHERE_ENERGY := [1.0,.72,.28,.55]
const ATMOSPHERE_SKY := [Color("c6d7d8"), Color("f0b39d"), Color("354767"), Color("899fae")]
const ATMOSPHERE_BACKGROUND := [Color(.72,.76,.77),Color(.78,.57,.50),Color(.16,.20,.33),Color(.44,.52,.59)]
const ATMOSPHERE_TINT := [Color(1,1,1),Color(1,.79,.69),Color(.60,.73,1),Color(.75,.83,.90)]

signal style_changed(value: Dictionary)

var style := {"wall": 0, "floor": 0, "light": 0, "rgb": 0, "brightness": 70, "effect": 0, "wall_pattern":0, "floor_pattern":0, "atmosphere":0}
var _patterns: Dictionary = {}
var _environment_owned := false

static func clean_style(raw: Variant) -> Dictionary:
	var result := {"wall": 0, "floor": 0, "light": 0, "rgb": 0, "brightness": 70, "effect": 0, "wall_pattern":0, "floor_pattern":0, "atmosphere":0}
	if not raw is Dictionary:
		return result
	for key: String in ["wall", "floor", "light", "effect", "wall_pattern", "floor_pattern", "atmosphere"]:
		var value: Variant = raw.get(key, result[key])
		if (value is int or value is float) and is_finite(float(value)):
			result[key] = clampi(int(value), 0, 3 if key == "atmosphere" else 2)
	var rgb: Variant = raw.get("rgb", 0)
	if (rgb is int or rgb is float) and is_finite(float(rgb)):
		result.rgb = clampi(int(rgb), 0, 6)
	var brightness: Variant = raw.get("brightness", 70)
	if (brightness is int or brightness is float) and is_finite(float(brightness)):
		result.brightness = clampi(roundi(float(brightness)), 0, 100)
	return result

func _ready() -> void:
	_prepare_materials()
	apply_style(style)

func _pattern_texture(kind: String, index: int) -> Texture2D:
	if index <= 0: return null
	var key := kind + str(index)
	if _patterns.has(key): return _patterns[key]
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var shade := 1.0
			if kind == "wall":
				if index == 1:
					# Woven linen: alternating fine vertical and horizontal fibers.
					shade = .90 + .035 * float(x % 4 == 0) + .04 * float(y % 7 == 0)
				else:
					# Staggered brick courses and recessed mortar.
					var course: int = y / 16
					var offset: int = (x + (course % 2) * 16) % 32
					shade = .74 if y % 16 < 2 or offset < 2 else .97 - float((x + y) % 7) * .008
			else:
				if index == 1:
					# Directional oak grain with narrow, offset board seams.
					shade = .78 if x % 16 == 0 else .91 + .05 * sin(float(y) * .41 + float(x) * .12)
				else:
					# Matte stone tile with subtly varied squares and joints.
					shade = .76 if x % 16 == 0 or y % 16 == 0 else .90 + float((x/16+y/16) % 3) * .026
			image.set_pixel(x,y,Color(shade,shade,shade))
	var texture := ImageTexture.create_from_image(image)
	_patterns[key] = texture
	return texture

func _apply_atmosphere() -> void:
	var index: int = int(style.atmosphere)
	var world: Node3D = get_parent() as Node3D
	var atmosphere_energy: float = ATMOSPHERE_ENERGY[index]
	var tint: Color = ATMOSPHERE_TINT[index]
	var env_node := world.get_node_or_null("Environment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		if not _environment_owned:
			env_node.environment = env_node.environment.duplicate()
			_environment_owned = true
		env_node.environment.background_color = ATMOSPHERE_BACKGROUND[index]
		env_node.environment.ambient_light_color = tint
		env_node.environment.ambient_light_energy = [.34,.27,.14,.27][index]
	var sky := $Shell.get_node_or_null("Left_Wall/WindowSky") as MeshInstance3D
	if sky != null and sky.material_override is StandardMaterial3D:
		(sky.material_override as StandardMaterial3D).albedo_color = ATMOSPHERE_SKY[index]
	var rain := $Shell.get_node_or_null("Left_Wall/RainStreaks") as Node3D
	if rain != null: rain.visible = index == 3
	var key := world.get_node_or_null("KeyLight") as DirectionalLight3D
	if key != null:
		key.light_color = LIGHTS[style.light] * tint
		key.light_energy = [0.75,.92,.48][style.light] * atmosphere_energy
	var fill := world.get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.light_color = FILL_LIGHTS[style.light] * tint
		fill.light_energy = [.18,.24,.08][style.light] * maxf(.35,atmosphere_energy)
	var ceiling := world.get_node_or_null("CeilingLight") as OmniLight3D
	if ceiling != null:
		ceiling.light_color = LIGHTS[style.light]
		ceiling.light_energy = [0.12,.08,.32][style.light] * [1.0,1.5,2.5,1.8][index]
	for item: Node3D in $Furniture.get_children():
		if item.has_node("LampGlow"):
			item.get_node("LampGlow").light_energy = [0.36,.18,.85][style.light] * [1.0,1.25,2.1,1.55][index]


func _prepare_materials() -> void:
	for mesh: MeshInstance3D in $Shell.find_children("*", "MeshInstance3D", true, false):
		var role := str(mesh.get_meta("surface_role", ""))
		if role not in ["wall", "floor"]:
			continue
		var material := mesh.get_active_material(0)
		if material != null:
			mesh.material_override = material.duplicate()

func apply_blueprint(value: Variant) -> void:
	blueprint = Blueprint.clean(value)
	if not is_inside_tree(): return
	$Shell.rebuild(blueprint)
	_prepare_materials()
	set_partition_editing(partitions_editing)
	apply_style(style)

func set_partition_editing(enabled: bool) -> void:
	partitions_editing = enabled
	var partitions := $Shell.get_node_or_null("Partitions") as Node3D
	if partitions != null:
		partitions.scale.y = .23 if enabled else 1.0
	var returns := $Shell.get_node_or_null("Notch_Walls") as Node3D
	if returns != null:
		returns.scale.y = .23 if enabled else 1.0
	var freeform := $Shell.get_node_or_null("Custom_Exterior") as Node3D
	if freeform != null:
		freeform.scale.y = .23 if enabled else 1.0

func apply_style(value: Variant) -> void:
	style = clean_style(value)
	if not is_inside_tree():
		return
	for mesh: MeshInstance3D in $Shell.find_children("*", "MeshInstance3D", true, false):
		var role := str(mesh.get_meta("surface_role", ""))
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		if role == "wall":
			var finish: int = int(mesh.get_meta("finish_id", 0))
			material.albedo_color = WALL_FINISHES[finish] if finish > 0 and finish < WALL_FINISHES.size() else WALLS[style.wall]
			material.albedo_texture = _pattern_texture("wall",int(style.wall_pattern))
			material.uv1_scale = Vector3(2,2,1)
			material.roughness = .92 if int(style.wall_pattern) != 2 else .98
		elif role == "floor":
			var tone := float(mesh.get_meta("tone", 1.0))
			var finish: int = int(mesh.get_meta("finish_id", 0))
			material.albedo_color = (FLOOR_FINISHES[finish] if finish > 0 and finish < FLOOR_FINISHES.size() else FLOORS[style.floor]) * tone
			material.albedo_texture = _pattern_texture("floor",int(style.floor_pattern))
			material.uv1_scale = Vector3(3,3,1)
			material.roughness = .71 if int(style.floor_pattern) == 1 else .87 if int(style.floor_pattern) == 2 else .68

	_apply_atmosphere()
	_refresh_zone_lights()
	style_changed.emit(style)

func _refresh_zone_lights() -> void:
	var existing := get_node_or_null("ZoneLights")
	if existing != null: existing.free()
	if blueprint.shape != "custom" or blueprint.zone_cells.is_empty(): return
	var group := Node3D.new()
	group.name = "ZoneLights"
	add_child(group)
	var centroids: Dictionary = Blueprint.zone_centroids(blueprint)
	for zone: int in centroids:
		var config: Dictionary = Blueprint.zone_style(blueprint, zone)
		var light_id: int = int(config.light)
		var point: Vector2 = centroids[zone]
		var lamp := OmniLight3D.new()
		lamp.name = "Zone_%d" % zone
		lamp.position = Vector3(point.x, 2.2, point.y)
		lamp.light_color = ZONE_LIGHT_COLORS[light_id]
		lamp.light_energy = ZONE_LIGHT_ENERGY[light_id]
		lamp.omni_range = 3.0
		lamp.shadow_enabled = false
		group.add_child(lamp)

func update_cutaway(camera: Camera3D) -> void:
	# Hide a complete wall group so its window, door, trim and decoration disappear together.
	var left := $Shell.get_node_or_null("Left_Wall") as Node3D
	if left != null:
		left.visible = camera.global_position.x > -float(blueprint.width) * .5 + .2
	var back := $Shell.get_node_or_null("Back_Wall") as Node3D
	if back != null:
		back.visible = camera.global_position.z > -float(blueprint.depth) * .5 + .2
	var returns := $Shell.get_node_or_null("Notch_Walls") as Node3D
	if returns != null:
		var cutoff_x: float = float(blueprint.width) * .5 - float(blueprint.notch_width)
		var cutoff_z: float = float(blueprint.depth) * .5 - float(blueprint.notch_depth)
		# Match the original cutaway camera: do not obscure furniture from outside.
		returns.visible = partitions_editing or (camera.global_position.x < cutoff_x and camera.global_position.z < cutoff_z)
	var freeform := $Shell.get_node_or_null("Custom_Exterior") as Node3D
	if freeform != null:
		freeform.visible = partitions_editing or (camera.global_position.x < 0.0 and camera.global_position.z < 0.0)
