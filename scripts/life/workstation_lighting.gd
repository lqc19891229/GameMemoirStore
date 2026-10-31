extends Node
## Runtime RGB and lighting controller for the desktop showcase.
const RGB_PALETTE := [
	Color("62dff5"), # ice cyan
	Color("547cff"), # deep blue
	Color("8d72ed"), # violet
	Color("e66ac5"), # magenta
	Color("ffb85e"), # amber
	Color("72d9ad"), # mint
	Color("f07891"), # rose
]
var _world: Node3D
var _rgb_surfaces: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _rotors: Array[Dictionary] = []
var _style := {"rgb":0,"brightness":70,"effect":0}
var _time := 0.0
var current_rgb_color := RGB_PALETTE[0]

var rgb_surface_count: int:
	get:
		return _rgb_surfaces.size()

var fan_rotor_count: int:
	get:
		return _rotors.size()

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_world = get_parent() as Node3D
	if _world == null:
		return
	_collect_rgb_surfaces()
	_register_lights()
	_build_fan_rotors()
	apply_style(_world.get_node("Room").style)

func _collect_rgb_surfaces() -> void:
	var roots: Array[Node] = []
	var devices: Dictionary = _world.get("devices")
	for role: String in devices:
		var device := devices[role] as Node
		if device != null:
			roots.append(device)
	var desk := _world.get_node_or_null("%Desk") as Node
	if desk != null:
		roots.append(desk)
	for root: Node in roots:
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				continue
			for surface in range(mesh.mesh.get_surface_count()):
				var source := mesh.get_active_material(surface) as StandardMaterial3D
				if source == null or not _is_rgb_material(source):
					continue
				var dynamic := source.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, dynamic)
				_rgb_surfaces.append({
					"material": dynamic,
					"base_energy": source.emission_energy_multiplier,
				})

func _is_rgb_material(material: StandardMaterial3D) -> bool:
	var name := material.resource_name.to_lower()
	if name.contains("rgb") or name.contains("cyan") or name.contains("magenta") or name.contains("blue"):
		return true
	if not material.emission_enabled:
		return false
	var color := material.emission
	return (color.b > color.g * 1.2 and color.r < color.g * 0.5) or (color.r > color.g * 1.8 and color.b > color.g * 1.8)

func _register_lights() -> void:
	_register_light(NodePath("%DeskGlow"), "desk")
	_register_light(NodePath("%Monitor/Backlight"), "monitor")
	_register_light(NodePath("%Computer/CaseGlow"), "case")
	_register_light(NodePath("%Keyboard/KeyboardGlow"), "keyboard")
	_register_light(NodePath("%Mouse/MouseGlow"), "mouse")

func _register_light(path: NodePath, role: String) -> void:
	var light := _world.get_node_or_null(path) as OmniLight3D
	if light == null:
		return
	_lights.append({
		"node": light,
		"role": role,
		"base_energy": light.light_energy,
	})

func _build_fan_rotors() -> void:
	var devices: Dictionary = _world.get("devices")
	var computer := devices.get("computer") as Node3D
	if computer == null:
		return
	var upgrade := computer.get_node_or_null("Models/UpgradeModel") as Node3D
	if upgrade == null:
		return
	for y in [0.72, 0.50, 0.28]:
		_add_rotor(upgrade, "FrontFanRotor", Vector3(0, y, 0.466), 0.073, false, 5.0)
	_add_rotor(upgrade, "CpuFanRotor", Vector3(0.224, 0.68, -0.02), 0.062, true, 4.2)
	for z in [-0.15, 0.08]:
		_add_rotor(upgrade, "GpuFanRotor", Vector3(0.216, 0.31, z), 0.045, true, 4.8)

func _add_rotor(parent: Node3D, rotor_name: String, center: Vector3, radius: float, side_axis: bool, speed: float) -> void:
	var rotor := Node3D.new()
	rotor.name = rotor_name
	rotor.position = center
	if side_axis:
		rotor.rotation.y = PI / 2.0
	parent.add_child(rotor)
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(radius * 0.72, radius * 0.15, 0.007)
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color("202a2e")
	blade_material.roughness = 0.62
	for index in range(5):
		var blade := MeshInstance3D.new()
		blade.name = "Blade_%d" % index
		blade.mesh = blade_mesh
		blade.position = Vector3(radius * 0.39, 0, 0)
		blade.rotation.z = TAU * float(index) / 5.0 + 0.38
		blade.material_override = blade_material
		rotor.add_child(blade)
	_rotors.append({"node": rotor, "speed": speed})

func apply_style(value: Variant) -> void:
	if value is Dictionary:
		_style = value.duplicate()
	_apply_lighting()

func _light_available(role: String) -> bool:
	var devices: Dictionary = _world.get("devices")
	var model_role := ""
	match role:
		"case": model_role = "computer"
		"keyboard": model_role = "keyboard"
		"mouse": model_role = "mouse"
	if model_role.is_empty():
		return true
	var device := devices.get(model_role) as Node3D
	if device == null:
		return false
	var upgrade := device.get_node_or_null("Models/UpgradeModel") as Node3D
	return upgrade != null and upgrade.visible

func _apply_lighting() -> void:
	var color_index := clampi(int(_style.get("rgb", 0)), 0, RGB_PALETTE.size() - 1)
	var color: Color = RGB_PALETTE[color_index]
	var effect := int(_style.get("effect", 0))
	if effect == 2:
		color = Color.from_hsv(fposmod(_time * 0.09 + float(color_index) / RGB_PALETTE.size(), 1.0), 0.72, 1.0)
	var pulse := 1.0
	if effect == 1:
		pulse = 0.58 + 0.42 * (0.5 + 0.5 * sin(_time * 2.1))
	var brightness := clampf(float(_style.get("brightness", 70)), 0.0, 100.0) / 70.0
	current_rgb_color = color
	for entry: Dictionary in _rgb_surfaces:
		var material := entry["material"] as StandardMaterial3D
		if material == null:
			continue
		material.emission = color
		material.emission_enabled = brightness > 0.001
		material.emission_energy_multiplier = float(entry["base_energy"]) * brightness * pulse
	for entry: Dictionary in _lights:
		var light := entry["node"] as OmniLight3D
		if light == null:
			continue
		light.light_color = color
		light.light_energy = float(entry["base_energy"]) * brightness * pulse
		light.visible = brightness > 0.001 and _light_available(str(entry["role"]))

func _process(delta: float) -> void:
	_time += delta
	for entry: Dictionary in _rotors:
		var rotor := entry["node"] as Node3D
		if is_instance_valid(rotor):
			rotor.rotate_object_local(Vector3(0, 0, 1), delta * float(entry["speed"]))
	_apply_lighting()
