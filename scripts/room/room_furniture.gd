@tool
extends Node3D
## Authored furniture dimensions and modern visual models for the room editor.
@export var bounds := Vector3.ONE
@export var blocking := true
@export var role := "chair"

const SupportSurfaces = preload("res://scripts/room/furniture_support_surfaces.gd")

func _ready() -> void:
	_register_support_surfaces()
	if not has_node("Model"):
		_build_visual()

func _register_support_surfaces() -> void:
	# Authored safe contact areas; no automatic stacking on chairs/lamps.
	var anchors: Array = []
	var base_role := role.get_slice("__instance__", 0)
	if base_role.ends_with("_1") or base_role.ends_with("_2") or base_role.ends_with("_3") or base_role.ends_with("_4") or base_role.ends_with("_5") or base_role.ends_with("_6") or base_role.ends_with("_7") or base_role.ends_with("_8"):
		base_role = base_role.substr(0, base_role.rfind("_"))
	match base_role:
		"bookcase":
			for level in range(4):
				anchors.append({"id": "shelf_%d" % level, "center": Vector3(0, [0.2575, 0.8375, 1.4175, 1.9975][level], 0), "size": Vector2(1.16, 0.42)})
		"writing_table", "side_table_oak", "coffee_table_round", "coffee_table_glass", "shelf_low":
			var top := SupportSurfaces.from_bounds(bounds, 0.08)
			if not top.is_empty():
				anchors.append(top)
	if not anchors.is_empty():
		set_meta("support_surfaces", anchors)

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
		"sofa":
			_build_sofa(model)
		"stool":
			_build_stool(model)

func _build_chair(model: Node3D) -> void:
	var fabric := _material(Color("666f73"), 0.94)
	var cushion := _material(Color("a6aaa7"), 0.92)
	var frame := _material(Color("353c40"), 0.38, 0.72)
	var rubber := _material(Color("202528"), 0.88)
	_box(model, "SeatShell", Vector3(0.86, 0.15, 0.68), Vector3(0, 0.72, 0), frame)
	_sphere(model, "SeatCushion", Vector3(0.80, 0.14, 0.64), Vector3(0, 0.84, 0), cushion)
	_box(model, "BackShell", Vector3(0.84, 0.64, 0.14), Vector3(0, 1.17, -0.27), frame)
	_sphere(model, "BackCushion", Vector3(0.77, 0.56, 0.12), Vector3(0, 1.18, -0.27), fabric)
	_sphere(model, "LumbarSupport", Vector3(0.70, 0.16, 0.13), Vector3(0, 1.03, -0.34), cushion)
	_sphere(model, "HeadrestShell", Vector3(0.56, 0.22, 0.16), Vector3(0, 1.47, -0.31), frame)
	_sphere(model, "HeadrestCushion", Vector3(0.50, 0.18, 0.14), Vector3(0, 1.48, -0.31), fabric)
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
	# Keep every visible part within the original 1.46 x 2.57 x 0.58 m
	# picking volume so legacy placements remain valid.
	var oak := _material(Color("ae8764"), 0.66)
	var edge := _material(Color("86674d"), 0.62)
	var dark := _material(Color("564b42"), 0.81)
	var brass := _material(Color("ac956f"), 0.48, 0.65)
	var ceramic := _material(Color("d8d0be"), 0.89)
	var sage := _material(Color("788d7c"), 0.86)
	var picture := _material(Color("c6b39e"), 0.91)
	var book_colors := [
		_material(Color("74868d"), 0.90),
		_material(Color("af7c6c"), 0.92),
		_material(Color("d6c7ac"), 0.93),
		_material(Color("768374"), 0.89),
		_material(Color("535d65"), 0.90)
	]
	_box(model, "BackPanel", Vector3(1.34, 2.43, 0.035), Vector3(0, 1.295, -0.259), dark)
	for x in [-0.685, 0.685]:
		_box(model, "SidePanel", Vector3(0.09, 2.48, 0.56), Vector3(x, 1.31, 0), oak)
		_box(model, "FrontEdge", Vector3(0.018, 2.43, 0.018), Vector3(x, 1.31, 0.278), edge)
	_box(model, "TopCap", Vector3(1.46, 0.06, 0.58), Vector3(0, 2.54, 0), oak)
	_box(model, "BottomPlinth", Vector3(1.40, 0.11, 0.53), Vector3(0, 0.095, 0), edge)
	for y in [0.23, 0.81, 1.39, 1.97]:
		_box(model, "Shelf", Vector3(1.34, 0.055, 0.53), Vector3(0, y, 0), oak)
		_box(model, "ShelfLip", Vector3(1.31, 0.018, 0.018), Vector3(0, y + 0.03, 0.265), edge)

	# Book spines vary in height and width; add fine spine bands instead of
	# repeating a single row of uniform boxes.
	for row in range(3):
		var bottom: float = [0.26, 0.84, 1.42][row]
		for index in range(7):
			var height: float = [0.31, 0.38, 0.35, 0.41, 0.34, 0.37, 0.32][(index + row) % 7]
			var width: float = [0.09, 0.11, 0.085, 0.10][(index + row) % 4]
			var x: float = -0.55 + float(index) * 0.167
			var color: Material = book_colors[(index + row * 2) % book_colors.size()]
			_box(model, "Book_%d_%d" % [row, index], Vector3(width, height, 0.28), Vector3(x, bottom + height * 0.5, 0.015), color)
			if index % 2 == 0:
				_box(model, "SpineBand_%d_%d" % [row, index], Vector3(width + 0.001, 0.012, 0.008), Vector3(x, bottom + height * 0.72, 0.159), brass)

	# Top shelf displays one framed picture, a vase and a small stack of books.
	_box(model, "DisplayFrame", Vector3(0.36, 0.31, 0.038), Vector3(-0.40, 2.23, 0.04), edge)
	_box(model, "DisplayPrint", Vector3(0.30, 0.25, 0.007), Vector3(-0.40, 2.23, 0.064), picture)
	_box(model, "DisplayArt", Vector3(0.17, 0.14, 0.008), Vector3(-0.40, 2.22, 0.070), sage)
	_cylinder(model, "CeramicVase", 0.085, 0.11, 0.28, Vector3(0.10, 2.137, 0.025), ceramic, 28)
	_cylinder(model, "VaseNeck", 0.047, 0.062, 0.085, Vector3(0.10, 2.31, 0.025), ceramic, 24)
	for index in range(3):
		_box(model, "DisplayBook_%d" % index, Vector3(0.28, 0.035, 0.19), Vector3(0.42, 2.035 + float(index) * 0.039, 0.02), book_colors[index + 1])

func _build_lamp(model: Node3D) -> void:
	var ceramic := _material(Color("e7dfd1"), 0.34)
	var brass := _material(Color("8d7657"), 0.38, 0.72)
	var diffuser := _material(Color("fff0d6"), 0.62)
	_cylinder(model, "LampBase", 0.22, 0.24, 0.08, Vector3(0, 0.04, 0), brass)
	_cylinder(model, "LampStem", 0.026, 0.026, 1.52, Vector3(0, 0.84, 0), brass, 20)
	_cylinder(model, "LampShade", 0.14, 0.31, 0.36, Vector3(0, 1.82, 0), ceramic)
	_sphere(model, "LampDiffuser", Vector3(0.18, 0.10, 0.18), Vector3(0, 1.62, 0), diffuser)

func _build_rug(model: Node3D) -> void:
	var fabric := _material(Color("9ca69c"), 0.98)
	var border := _material(Color("c6bdae"), 0.96)
	var pattern := _material(Color("718477"), 0.98)
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
	var stems := _material(Color("3f6348"), 0.98)
	_cylinder(model, "Pot", 0.25, 0.19, 0.40, Vector3(0, 0.20, 0), pot)
	_cylinder(model, "PotRim", 0.27, 0.25, 0.045, Vector3(0, 0.40, 0), rim)
	_cylinder(model, "Soil", 0.225, 0.225, 0.025, Vector3(0, 0.425, 0), soil)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var height: float = [0.70, 0.86, 0.92, 0.78, 0.96, 0.74, 0.84][index]
		var radius := 0.12 + float(index % 3) * 0.065
		var stem_center := Vector3(cos(angle) * radius * 0.45, 0.45 + height * 0.24, sin(angle) * radius * 0.45)
		_cylinder(model, "Stem_%02d" % index, 0.012, 0.016, height * 0.55, stem_center, stems, 10)
		var at := Vector3(cos(angle) * radius, 0.45 + height * 0.50, sin(angle) * radius)
		var size := Vector3(0.18, height * 0.58, 0.09)
		var leaf := _sphere(model, "Leaf_%02d" % index, size, at, leaf_light if index % 3 == 0 else leaves)
		leaf.rotation.z = -cos(angle) * 0.42
		leaf.rotation.x = sin(angle) * 0.42

func _build_sofa(model: Node3D) -> void:
	## Compact fabric sofa with a timber base and independently shaded cushions.
	## All geometry stays within the authored 1.98 x 1.06 x .88 collision box.
	var frame := _material(Color("66544b"), .67)
	var legs := _material(Color("343b3b"), .47, .28)
	var upholstery := _material(Color("b7b1a7"), .93)
	var cushions := [_material(Color("d4cbbd"), .96),_material(Color("b2c3b7"), .94)]
	var accent := _material(Color("8a9b8e"), .92)
	_box(model, "SofaFrame", Vector3(1.88,.21,.77), Vector3(0,.24,.03), frame)
	for x in [-.79,.79]:
		for z in [-.31,.31]:
			_cylinder(model, "SofaLeg",.042,.052,.16,Vector3(x,.08,z),legs,12)
	_box(model, "SofaBack", Vector3(1.86,.55,.20), Vector3(0,.68,-.31),upholstery)
	for x in [-.78,.78]:
		_box(model, "SofaArm", Vector3(.20,.48,.80),Vector3(x,.50,0),upholstery)
	for i in range(2):
		var x := -.39 if i == 0 else .39
		_box(model,"SeatCushion_%d" % i,Vector3(.73,.18,.64),Vector3(x,.43,.04),cushions[i])
		_box(model,"BackCushion_%d" % i,Vector3(.73,.44,.15),Vector3(x,.65,-.19),cushions[i])
	_box(model,"ThrowPillow",Vector3(.28,.28,.13),Vector3(.53,.68,.10),accent,-.22)

func _build_stool(model: Node3D) -> void:
	## Small walnut/linen accent stool with a decorative ceramic bowl.
	## Its visible model fits within .68 x .66 x .68 metres.
	var walnut := _material(Color("826046"),.58)
	var brass := _material(Color("af976e"),.34,.60)
	var textile := _material(Color("d2cab9"),.94)
	var ceramic := _material(Color("d7dbd0"),.67)
	for x in [-.23,.23]:
		for z in [-.23,.23]:
			_box(model,"StoolLeg",Vector3(.055,.44,.055),Vector3(x,.22,z),walnut)
			_box(model,"LegCap",Vector3(.057,.075,.057),Vector3(x,.065,z),brass)
	_box(model,"StoolApron",Vector3(.60,.09,.60),Vector3(0,.45,0),walnut)
	_box(model,"StoolCushion",Vector3(.66,.10,.66),Vector3(0,.535,0),textile)
	_cylinder(model,"AccentTray",.13,.15,.028,Vector3(0,.605,0),ceramic,24)
	_cylinder(model,"AccentTrayInset",.095,.095,.008,Vector3(0,.621,0),brass,24)
