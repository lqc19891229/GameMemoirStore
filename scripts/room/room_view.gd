@tool
class_name MemoirRoomView
extends Node3D
## Room appearance presets and cutaway visibility for the modern 3D sample room.

const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
var blueprint: Dictionary = Blueprint.DEFAULT.duplicate(true)
var partitions_editing := false

const WALLS := [Color("f1eee8"), Color("e5e1da"), Color("dce6df")]
const FLOORS := [Color("b99572"), Color("967153"), Color("a8ada8")]
const LIGHTS := [Color("fff0dc"), Color("e5efff"), Color("ffd1a1")]
const FILL_LIGHTS := [Color("d9e4df"), Color("d9e8f4"), Color("a8a09a")]

signal style_changed(value: Dictionary)

var style := {"wall": 0, "floor": 0, "light": 0, "rgb": 0, "brightness": 70, "effect": 0}

static func clean_style(raw: Variant) -> Dictionary:
	var result := {"wall": 0, "floor": 0, "light": 0, "rgb": 0, "brightness": 70, "effect": 0}
	if not raw is Dictionary:
		return result
	for key: String in ["wall", "floor", "light", "effect"]:
		var value: Variant = raw.get(key, result[key])
		if (value is int or value is float) and is_finite(float(value)):
			result[key] = clampi(int(value), 0, 2)
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
			material.albedo_color = WALLS[style.wall]
		elif role == "floor":
			var tone := float(mesh.get_meta("tone", 1.0))
			material.albedo_color = FLOORS[style.floor] * tone

	var key := get_parent().get_node_or_null("KeyLight") as DirectionalLight3D
	if key != null:
		key.light_color = LIGHTS[style.light]
		key.light_energy = [0.75, 0.92, 0.48][style.light]
	var fill := get_parent().get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.light_color = FILL_LIGHTS[style.light]
		fill.light_energy = [0.18, 0.24, 0.08][style.light]
	var ceiling := get_parent().get_node_or_null("CeilingLight") as OmniLight3D
	if ceiling != null:
		ceiling.light_color = LIGHTS[style.light]
		ceiling.light_energy = [0.12, 0.08, 0.32][style.light]
	for item: Node3D in $Furniture.get_children():
		if item.has_node("LampGlow"):
			item.get_node("LampGlow").light_energy = [0.36, 0.18, 0.85][style.light]
	style_changed.emit(style)

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
