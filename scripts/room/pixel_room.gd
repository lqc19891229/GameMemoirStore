@tool
extends Node3D
## Fixed 8 × 6 metre cutaway room. Geometry is authored in complete GLB assets.
const WALLS := [Color("b6b99d"), Color("c9b899"), Color("829eaa")]
const FLOORS := [Color.WHITE, Color("b4c4b5"), Color("aa8468")]
const LIGHTS := [Color("ffe5bc"), Color("c4d8ed"), Color("ffb471")]
const FILL_LIGHTS := [Color("c5d8d6"), Color("d7e6f0"), Color("a9a0a5")]
signal style_changed(value: Dictionary)
var style := {"wall":0,"floor":0,"light":0,"rgb":0,"brightness":70,"effect":0}

static func clean_style(raw: Variant) -> Dictionary:
	var result := {"wall":0,"floor":0,"light":0,"rgb":0,"brightness":70,"effect":0}
	if not raw is Dictionary: return result
	for key: String in ["wall","floor","light","effect"]:
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
	for mesh: MeshInstance3D in $Shell.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name) == "Floor" or str(mesh.name).ends_with("Wall"):
			var material: Material = mesh.get_active_material(0)
			if material != null:
				mesh.material_override = material.duplicate()
	apply_style(style)

func apply_style(value: Variant) -> void:
	style = clean_style(value)
	if not is_inside_tree(): return
	for mesh: MeshInstance3D in $Shell.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override == null: continue
		if str(mesh.name) == "Floor": mesh.material_override.albedo_color = FLOORS[style.floor]
		elif str(mesh.name).ends_with("Wall"): mesh.material_override.albedo_color = WALLS[style.wall]
	var key := get_parent().get_node_or_null("KeyLight") as DirectionalLight3D
	if key != null:
		key.light_color = LIGHTS[style.light]
		key.light_energy = [0.75,0.65,0.35][style.light]
	var fill := get_parent().get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.light_color = FILL_LIGHTS[style.light]
		fill.light_energy = [0.20,0.24,0.07][style.light]
	for item: Node3D in $Furniture.get_children():
		if item.has_node("LampGlow"): item.get_node("LampGlow").light_energy = [0.55,0.25,1.4][style.light]
	style_changed.emit(style)

func update_cutaway(camera: Camera3D) -> void:
	# Looking from outside a wall hides that entire wall, window and trim together.
	for mesh: Node3D in $Shell.get_children():
		if str(mesh.name).begins_with("Left_"): mesh.visible = camera.global_position.x > -3.8
		elif str(mesh.name).begins_with("Back_"): mesh.visible = camera.global_position.z > -2.8
