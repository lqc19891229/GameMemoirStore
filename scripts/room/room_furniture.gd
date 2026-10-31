@tool
extends Node3D
## Authored furniture dimensions and modern visual models for the room editor.
@export var bounds := Vector3.ONE
@export var blocking := true
@export var role := "chair"

func _ready() -> void:
	if not has_node("Model"):
		_build_visual()

func _material(color: Color, roughness: float = 0.78, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material, yaw: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = yaw
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node, node_name: String, top_radius: float, bottom_radius: float, height: float, at: Vector3, material: Material, radial_segments: int = 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _sphere(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.scale = size
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build_visual() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	match role.get_slice("_", 0):
		"chair":
			_build_chair(model)
		"bookcase":
			_build_bookcase(model)
		"lamp":
			_build_lamp(model)
		"rug":
			_build_rug(model)
		"plant":
			_build_plant(model)

func _build_chair(model: Node3D) -> void:
	var fabric := _material(Color("666f73"), 0.94)
	var cushion := _material(Color("a6aaa7"), 0.92)
	var frame := _material(Color("353c40"), 0.38, 0.72)
	var rubber := _material(Color("202528"), 0.88)
	_box(model, "SeatShell", Vector3(0.86, 0.15, 0.68), Vector3(0, 0.72, 0), frame)
	_sphere(model, "SeatCushion", Vector3(0.80, 0.14, 0.64), Vector3(0, 0.84, 0), cushion)
	_box(model, "BackShell", Vector3(0.84, 0.64, 0.14), Vector3(0, 1.17, -0.27), frame)
	_sphere(model, "BackCushion", Vector3(0.77, 0.56, 0.12), Vector3(0, 1.18, -0.27), fabric)
	for x in [-0.43, 0.43]:
		_box(model, "ArmSupport", Vector3(0.065, 0.28, 0.07), Vector3(x, 0.88, -0.02), frame)
		_sphere(model, "ArmRest", Vector3(0.10, 0.065, 0.54), Vector3(x, 1.04, 0.0), cushion)
	_cylinder(model, "GasLift", 0.045, 0.045, 0.42, Vector3(0, 0.38, 0), frame, 24)
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var spoke := _box(model, "BaseSpoke", Vector3(0.60, 0.055, 0.065), Vector3(0, 0.09, 0), frame, angle)
		spoke.position = Vector3(cos(angle) * 0.075, 0.09, sin(angle) * 0.075)
	for x in [-0.37, 0.37]:
		for z in [-0.25, 0.25]:
			_sphere(model, "Caster", Vector3(0.13, 0.13, 0.13), Vector3(x, 0.055, z), rubber)

func _build_bookcase(model: Node3D) -> void:
	var wood := _material(Color("a9825c"), 0.64)
	var dark := _material(Color("674d39"), 0.72)
	var book_colors := [
		_material(Color("71858a"), 0.9),
		_material(Color("a96f5c"), 0.9),
		_material(Color("d3c5aa"), 0.92),
		_material(Color("7c8973"), 0.9),
		_material(Color("555f68"), 0.9),
	]
	_box(model, "BackPanel", Vector3(1.34, 2.5, 0.055), Vector3(0, 1.27, -0.25), dark)
	for x in [-0.69, 0.69]:
		_box(model, "SidePanel", Vector3(0.08, 2.55, 0.58), Vector3(x, 1.275, 0), wood)
	for y in [0.07, 0.70, 1.33, 1.96, 2.50]:
		_box(model, "Shelf", Vector3(1.38, 0.075, 0.56), Vector3(0, y, 0), wood)
	for row in range(4):
		var base_y := 0.11 + float(row) * 0.63
		for index in range(6):
			var height: float = [0.34, 0.42, 0.38, 0.46, 0.32, 0.40][index]
			var width := 0.115 + float(index % 2) * 0.018
			var x := -0.54 + float(index) * 0.19
			_box(model, "Book", Vector3(width, height, 0.30), Vector3(x, base_y + height * 0.5, 0.045), book_colors[index % book_colors.size()], (float(index % 3) - 1.0) * 0.025)

func _build_lamp(model: Node3D) -> void:
	var ceramic := _material(Color("e7dfd1"), 0.34)
	var brass := _material(Color("8d7657"), 0.38, 0.72)
	var diffuser := _material(Color("fff0d6"), 0.62)
	_cylinder(model, "LampBase", 0.22, 0.24, 0.08, Vector3(0, 0.04, 0), brass)
	_cylinder(model, "LampStem", 0.026, 0.026, 1.52, Vector3(0, 0.84, 0), brass, 20)
	_cylinder(model, "LampShade", 0.14, 0.31, 0.36, Vector3(0, 1.82, 0), ceramic)
	_sphere(model, "LampDiffuser", Vector3(0.18, 0.10, 0.18), Vector3(0, 1.62, 0), diffuser)

func _build_rug(model: Node3D) -> void:
	var fabric := _material(Color("a8afa7"), 0.98)
	var border := _material(Color("ded6c8"), 0.96)
	var pattern := _material(Color("87988c"), 0.98)
	_box(model, "RugSurface", Vector3(3.58, 0.024, 2.18), Vector3(0, 0.014, 0), fabric)
	_box(model, "RugBorder", Vector3(3.42, 0.006, 0.045), Vector3(0, 0.028, -1.04), border)
	_box(model, "RugBorder", Vector3(3.42, 0.006, 0.045), Vector3(0, 0.028, 1.04), border)
	for x in [-1.70, 1.70]:
		_box(model, "RugBorder", Vector3(0.045, 0.006, 2.08), Vector3(x, 0.028, 0), border)
	for x in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		_box(model, "RugPattern", Vector3(0.025, 0.004, 0.76), Vector3(x, 0.029, 0), pattern)

func _build_plant(model: Node3D) -> void:
	var pot := _material(Color("b98268"), 0.72)
	var rim := _material(Color("d0a28a"), 0.62)
	var soil := _material(Color("453d32"), 1.0)
	var leaves := _material(Color("55775b"), 0.94)
	var leaf_light := _material(Color("829b70"), 0.92)
	_cylinder(model, "Pot", 0.25, 0.19, 0.40, Vector3(0, 0.20, 0), pot)
	_cylinder(model, "PotRim", 0.27, 0.25, 0.045, Vector3(0, 0.40, 0), rim)
	_cylinder(model, "Soil", 0.225, 0.225, 0.025, Vector3(0, 0.425, 0), soil)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var height: float = [0.70, 0.86, 0.92, 0.78, 0.96, 0.74, 0.84][index]
		var radius := 0.12 + float(index % 3) * 0.065
		var at := Vector3(cos(angle) * radius, 0.45 + height * 0.53, sin(angle) * radius)
		var size := Vector3(0.25, height * 0.48, 0.19)
		_sphere(model, "Leaf", size, at, leaf_light if index % 3 == 0 else leaves)
