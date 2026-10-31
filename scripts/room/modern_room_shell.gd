@tool
extends Node3D
## Runtime-authored architectural shell for the modern sample room.
## Dimensions are in metres; the front and right sides remain open for the showcase camera.

func _ready() -> void:
	if not has_node("Floor"):
		_build()

func _material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _group(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node

func _box(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material, surface_role: String = "", tone: float = 1.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	if not surface_role.is_empty():
		instance.set_meta("surface_role", surface_role)
	if surface_role == "floor":
		instance.set_meta("tone", tone)
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
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.scale = size
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build() -> void:
	var wall := _material(Color("f1eee8"), 0.94)
	var trim := _material(Color("e1ddd4"), 0.72)
	var wood := _material(Color("bd9569"), 0.62)
	var dark_wood := _material(Color("795b43"), 0.68)
	var metal := _material(Color("555e61"), 0.38, 0.72)
	var linen := _material(Color("ded5c5"), 0.96)
	var canvas := _material(Color("e8e1d6"), 0.92)
	var art_blue := _material(Color("7d9ca6"), 0.82)
	var art_sage := _material(Color("9eaa91"), 0.86)
	var art_ochre := _material(Color("c69b65"), 0.82)
	var glass := _material(Color(0.62, 0.79, 0.84, 0.12), 0.22, 0.03)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_build_floor()
	_build_left_wall(wall, trim, wood, metal, linen, glass)
	_build_back_wall(wall, trim, wood, dark_wood, metal, canvas, art_blue, art_sage, art_ochre)
	_build_ceiling_trim(trim, metal)

func _build_floor() -> void:
	var base := _material(Color("b99572"), 0.68)
	_box(self, "Floor", Vector3(8.24, 0.2, 6.24), Vector3(0, -0.1, 0), base, "floor")
	var tones := [0.96, 1.02, 0.99, 1.04]
	for row in range(12):
		var tone: float = tones[row % tones.size()]
		var plank := _material(Color("b99572") * tone, 0.61)
		var z := -2.75 + float(row) * 0.5
		_box(self, "FloorBoard_%02d" % row, Vector3(8.0, 0.014, 0.486), Vector3(0, 0.006, z), plank, "floor", tone)

func _build_left_wall(wall: Material, trim: Material, wood: Material, metal: Material, linen: Material, glass: Material) -> void:
	var left := _group(self, "Left_Wall")
	# A real window opening is formed by four wall sections rather than a picture painted over a wall.
	_box(left, "WallSurface_Lower", Vector3(0.12, 1.26, 6.24), Vector3(-4.06, 0.63, 0), wall, "wall")
	_box(left, "WallSurface_Upper", Vector3(0.12, 0.48, 6.24), Vector3(-4.06, 2.96, 0), wall, "wall")
	_box(left, "WallSurface_WindowLeft", Vector3(0.12, 1.44, 1.12), Vector3(-4.06, 2.0, -2.56), wall, "wall")
	_box(left, "WallSurface_WindowRight", Vector3(0.12, 1.44, 2.76), Vector3(-4.06, 2.0, 1.74), wall, "wall")

	# Window glazing, sill and slim painted frame.
	_box(left, "WindowGlass", Vector3(0.025, 1.43, 2.25), Vector3(-3.99, 1.99, -0.8), glass)
	_box(left, "WindowSill", Vector3(0.20, 0.065, 2.48), Vector3(-3.88, 1.245, -0.8), wood)
	for z in [-1.96, 0.36]:
		_box(left, "WindowFrame", Vector3(0.10, 1.55, 0.075), Vector3(-3.91, 1.99, z), trim)
	for y in [1.22, 2.76]:
		_box(left, "WindowFrame", Vector3(0.10, 0.075, 2.43), Vector3(-3.91, y, -0.8), trim)
	_box(left, "WindowMullion", Vector3(0.055, 1.43, 0.045), Vector3(-3.925, 1.99, -0.8), trim)
	_box(left, "WindowMullion", Vector3(0.055, 0.045, 2.25), Vector3(-3.925, 1.99, -0.8), trim)

	# Soft linen curtains with narrow folds and a dark metal rail.
	var rail := _cylinder(left, "CurtainRail", 0.025, 0.025, 2.72, Vector3(-3.82, 2.84, -0.8), metal, 20)
	rail.rotation.x = PI / 2.0
	for panel_center in [-1.72, 0.12]:
		_box(left, "CurtainPanel", Vector3(0.075, 1.62, 0.42), Vector3(-3.83, 1.98, panel_center), linen)
		for fold in range(5):
			var fold_z: float = float(panel_center) - 0.16 + float(fold) * 0.08
			_box(left, "CurtainFold", Vector3(0.018, 1.55, 0.025), Vector3(-3.785, 1.98, fold_z), trim)

	# Outside view: a quiet, softly coloured neighbourhood rather than pixel skyline artwork.
	var sky := _material(Color("c6d7d8"), 1.0)
	var distant := _material(Color("a8b8b5"), 1.0)
	var near_building := _material(Color("899d9b"), 0.96)
	_box(left, "WindowSky", Vector3(0.04, 1.34, 2.18), Vector3(-5.0, 1.99, -0.8), sky)
	_box(left, "DistantBuilding", Vector3(0.08, 0.58, 0.62), Vector3(-4.72, 1.58, -1.48), distant)
	_box(left, "DistantBuilding", Vector3(0.08, 0.90, 0.48), Vector3(-4.72, 1.73, -0.72), near_building)
	_box(left, "DistantBuilding", Vector3(0.08, 0.48, 0.58), Vector3(-4.72, 1.52, 0.12), distant)

	# Warm painted skirting and a small timber cap at the window.
	_box(left, "Left_Skirting", Vector3(0.10, 0.16, 6.05), Vector3(-3.94, 0.08, 0), trim)
	_box(left, "Left_CapTrim", Vector3(0.16, 0.055, 6.12), Vector3(-4.0, 3.19, 0), trim)

func _build_back_wall(wall: Material, trim: Material, wood: Material, dark_wood: Material, metal: Material, canvas: Material, art_blue: Material, art_sage: Material, art_ochre: Material) -> void:
	var back := _group(self, "Back_Wall")
	# Door opening at the left; remaining wall is split around the opening.
	_box(back, "WallSurface_DoorLeft", Vector3(0.88, 3.2, 0.12), Vector3(-3.68, 1.6, -3.06), wall, "wall")
	_box(back, "WallSurface_DoorRight", Vector3(6.38, 3.2, 0.12), Vector3(0.94, 1.6, -3.06), wall, "wall")
	_box(back, "WallSurface_DoorLintel", Vector3(1.0, 0.95, 0.12), Vector3(-2.75, 2.725, -3.06), wall, "wall")

	# Contemporary flush door and restrained hardware.
	_box(back, "DoorLeaf", Vector3(0.92, 2.18, 0.055), Vector3(-2.75, 1.09, -2.975), dark_wood)
	_box(back, "DoorInset", Vector3(0.72, 1.75, 0.018), Vector3(-2.75, 1.16, -2.94), wood)
	_box(back, "DoorFrame", Vector3(0.075, 2.28, 0.09), Vector3(-3.255, 1.14, -2.91), trim)
	_box(back, "DoorFrame", Vector3(0.075, 2.28, 0.09), Vector3(-2.245, 1.14, -2.91), trim)
	_box(back, "DoorHeader", Vector3(1.08, 0.08, 0.09), Vector3(-2.75, 2.30, -2.91), trim)
	_sphere(back, "DoorHandle", Vector3(0.075, 0.075, 0.075), Vector3(-2.38, 1.05, -2.88), metal)

	# Wall art: framed, muted geometric composition; deliberately not pixel art.
	_box(back, "WallArtFrame", Vector3(1.58, 1.08, 0.07), Vector3(0.95, 2.08, -2.955), dark_wood)
	_box(back, "WallArtCanvas", Vector3(1.47, 0.97, 0.025), Vector3(0.95, 2.08, -2.91), canvas)
	_box(back, "WallArtBlue", Vector3(0.48, 0.72, 0.025), Vector3(0.63, 2.08, -2.885), art_blue)
	_box(back, "WallArtSage", Vector3(0.48, 0.30, 0.026), Vector3(1.12, 1.86, -2.882), art_sage)
	_box(back, "WallArtOchre", Vector3(0.28, 0.28, 0.028), Vector3(1.28, 2.35, -2.88), art_ochre)

	# A small horizontal trim line gives the wall a finished architectural edge.
	_box(back, "Back_Skirting", Vector3(8.0, 0.16, 0.10), Vector3(0, 0.08, -2.94), trim)
	_box(back, "Back_CapTrim", Vector3(8.16, 0.055, 0.16), Vector3(0, 3.19, -3.0), trim)

func _build_ceiling_trim(trim: Material, metal: Material) -> void:
	var ceiling := _group(self, "CeilingDetails")
	# Open-top cutaway architecture keeps the room readable while implying a finished ceiling line.
	_box(ceiling, "Left_CeilingCove", Vector3(0.20, 0.11, 6.2), Vector3(-3.99, 3.16, 0), trim)
	_box(ceiling, "Back_CeilingCove", Vector3(8.2, 0.11, 0.20), Vector3(0, 3.16, -2.99), trim)
	_cylinder(ceiling, "RecessedSpotTrim", 0.12, 0.12, 0.035, Vector3(0.1, 3.08, -2.72), metal, 32)
