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
# Reflection gradient remains independent of the visible background color. The
# Compatibility renderer can sample sky radiance without Forward+-only SSR.
const SKY_ZENITH := [Color("849fb8"),Color("d78c80"),Color("1b2d51"),Color("8197a9")]
const SKY_HORIZON := [Color("f2e3c8"),Color("efaf8d"),Color("677798"),Color("c4d0d2")]
const SKY_GROUND := [Color("4c5358"),Color("654b48"),Color("1f3042"),Color("4c5a61")]
const SKY_GROUND_HORIZON := [Color("b3aea3"),Color("c3a08b"),Color("59627b"),Color("9aadb0")]
const CAMERA_EXPOSURE := [1.02,1.00,1.08,1.01]
const SUN_ORIENTATION := [Vector3(-43,-30,0),Vector3(-25,-66,0),Vector3(-38,-18,0),Vector3(-54,-38,0)]
const SUN_SHADOW_STRENGTH := [.68,.74,.30,.42]
const SUN_SHADOW_SOFTNESS := [1.6,2.25,3.2,2.8]

signal style_changed(value: Dictionary)

var style := {"wall": 0, "floor": 0, "light": 0, "rgb": 0, "brightness": 70, "effect": 0, "wall_pattern":0, "floor_pattern":0, "atmosphere":0, "ambience_volume":70}
var _patterns: Dictionary = {}
var _environment_owned := false

# P44: visual rain is animated only while the rain preset is active.
# Procedural audio is local to this room, not part of the save format.
var _rain_elapsed := 0.0
var _rain_sound: AudioStreamPlayer

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or int(style.atmosphere) != 3:
		return
	var rain := $Shell.get_node_or_null("Left_Wall/RainStreaks") as Node3D
	if rain == null or not rain.visible:
		return
	_rain_elapsed = fmod(_rain_elapsed + minf(delta, .1), 60.0)
	for i in range(rain.get_child_count()):
		var streak := rain.get_child(i) as Node3D
		if streak == null: continue
		# Independent looping drops, constrained to the existing window pane.
		var phase := fposmod(float(i) * .37 + _rain_elapsed * (1.35 + float(i % 5) * .13), 1.55)
		streak.position.y = 1.38 + phase

func _make_rain_loop() -> AudioStreamWAV:
	# Deterministic, low-volume filtered-noise bed. No external asset or
	# platform codec dependency; created only on the first rainy preview.
	const RATE := 11025
	const SAMPLES := 11025
	var pcm := PackedByteArray()
	pcm.resize(SAMPLES * 2)
	var seed_value := 1731
	var smoothed := 0.0
	for i in range(SAMPLES):
		seed_value = int((seed_value * 48271) % 2147483647)
		var noise := float(seed_value) / 1073741823.5 - 1.0
		smoothed = smoothed * .82 + noise * .18
		var fade := minf(1.0, minf(float(i), float(SAMPLES - 1 - i)) / 300.0)
		var sample := int(clampf(smoothed * fade * 2800.0, -32767.0, 32767.0))
		pcm[i * 2] = sample & 255
		pcm[i * 2 + 1] = (sample >> 8) & 255
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = RATE
	audio.stereo = false
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.data = pcm
	return audio

func _update_rain_sound(index: int) -> void:
	if Engine.is_editor_hint(): return
	if index != 3:
		if _rain_sound != null: _rain_sound.stop()
		return
	if _rain_sound == null:
		_rain_sound = AudioStreamPlayer.new()
		_rain_sound.name = "RainAmbience"
		_rain_sound.volume_db = -24.0
		_rain_sound.stream = _make_rain_loop()
		add_child(_rain_sound)
	if int(style.ambience_volume) <= 0:
		_rain_sound.stop()
		return
	# Map the 1-100 control to quiet playback, reserving 0 for silence.
	_rain_sound.volume_db = -39.0 + float(style.ambience_volume) * .15
	if not _rain_sound.playing: _rain_sound.play()


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
	var volume: Variant = raw.get("ambience_volume", 70)
	if (volume is int or volume is float) and is_finite(float(volume)):
		result.ambience_volume = clampi(roundi(float(volume)), 0, 100)
	var brightness: Variant = raw.get("brightness", 70)
	if (brightness is int or brightness is float) and is_finite(float(brightness)):
		result.brightness = clampi(roundi(float(brightness)), 0, 100)
	return result

func _ready() -> void:
	_prepare_materials()
	apply_style(style)

func _pattern_texture(kind: String, index: int) -> Texture2D:
	# P42 makes the existing default oak floor a finished material rather
	# than an untextured flat color. Default walls stay matte and quiet.
	if index < 0 or index == 0 and kind != "floor": return null
	var key := kind + str(index)
	if _patterns.has(key): return _patterns[key]
	var dimension := 128 if kind == "floor" and index == 0 else 64
	var image := Image.create(dimension,dimension,false,Image.FORMAT_RGBA8)
	for y in range(dimension):
		for x in range(dimension):
			var shade := 1.0
			if kind == "floor" and index == 0:
				# Continuous, subtle oak fibers, not opaque painted stripes.
				# Two frequencies introduce believable lengthwise variation
				# without disturbing the player's floor finish color.
				var along := float(x)/float(dimension)
				var across := float(y)/float(dimension)
				var bend := .018*sin(across*TAU*3.0) + .008*sin(across*TAU*9.0)
				var wide := sin(TAU*(along*7.0+bend))
				var narrow := sin(TAU*(along*29.0+bend*2.6))
				var pores := sin(TAU*(along*45.0+across*5.0))
				shade = clampf(.947+.032*wide+.013*narrow+.005*pores,.88,.997)
			elif kind == "wall":
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
	if kind == "floor" and index == 0: image.generate_mipmaps()
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
			var local_environment: Environment = env_node.environment.duplicate() as Environment
			if local_environment.sky != null:
				# Both environment and procedural sky are scene resources. Each
				# room instance must own its sky before switching time of day.
				local_environment.sky = local_environment.sky.duplicate(true)
			env_node.environment = local_environment
			_environment_owned = true
		var environment: Environment = env_node.environment
		environment.background_color = ATMOSPHERE_BACKGROUND[index]
		environment.ambient_light_color = tint
		environment.ambient_light_energy = [.34,.27,.14,.27][index]
		environment.tonemap_exposure = CAMERA_EXPOSURE[index]
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		var gradient: ProceduralSkyMaterial = environment.sky.sky_material as ProceduralSkyMaterial if environment.sky != null else null
		if gradient != null:
			gradient.sky_top_color = SKY_ZENITH[index]
			gradient.sky_horizon_color = SKY_HORIZON[index]
			gradient.ground_bottom_color = SKY_GROUND[index]
			gradient.ground_horizon_color = SKY_GROUND_HORIZON[index]
	var sky := $Shell.get_node_or_null("Left_Wall/WindowSky") as MeshInstance3D
	if sky != null and sky.material_override is StandardMaterial3D:
		(sky.material_override as StandardMaterial3D).albedo_color = ATMOSPHERE_SKY[index]
	var rain := $Shell.get_node_or_null("Left_Wall/RainStreaks") as Node3D
	if rain != null: rain.visible = index == 3
	_update_rain_sound(index)
	var windows := $Shell.get_node_or_null("Left_Wall/ExteriorWindows") as Node3D
	if windows != null: windows.visible = index in [1,2,3]
	# Daylight must read as window light; moonlight and rain become less warm.
	# No shadow maps are added, so these accents work in Compatibility mode.
	var bounce := $Shell.get_node_or_null("WindowBounce") as OmniLight3D
	if bounce != null:
		bounce.light_energy = [.24,.34,.065,.13][index]
		bounce.light_color = [Color("ffe8c5"),Color("ffbb8c"),Color("a7c1df"),Color("d0dce2")][index]
	var cove := $Shell.get_node_or_null("WarmCoveFill") as OmniLight3D
	if cove != null:
		cove.light_energy = [.09,.16,.24,.19][index]
		cove.light_color = [Color("ffe7d0"),Color("ffc3a1"),Color("ffdab2"),Color("eedac4")][index]
	var key := world.get_node_or_null("KeyLight") as DirectionalLight3D
	if key != null:
		key.light_color = LIGHTS[style.light] * tint
		key.light_energy = [0.75,.92,.48][style.light] * atmosphere_energy
		key.rotation_degrees = SUN_ORIENTATION[index]
		key.shadow_opacity = SUN_SHADOW_STRENGTH[index]
		key.shadow_blur = SUN_SHADOW_SOFTNESS[index]
	var fill := world.get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.light_color = FILL_LIGHTS[style.light] * tint
		fill.light_energy = [.18,.24,.08][style.light] * maxf(.35,atmosphere_energy)
		# Soft diffuse bounce, no second expensive shadow map.
		fill.shadow_enabled = false
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
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		lamp.light_energy = ZONE_LIGHT_ENERGY[light_id] * [0.85,1.1,1.6,1.25][int(style.atmosphere)]
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
