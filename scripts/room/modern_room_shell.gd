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

const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
var blueprint: Dictionary = Blueprint.DEFAULT.duplicate()

func rebuild(config: Dictionary) -> void:
	blueprint = Blueprint.clean(config)
	if not is_inside_tree(): return
	for child: Node in get_children():
		if child.name != "GeneratedGeometry": child.free()
	_build()

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
	_build_partitions(wall, trim)

func _build_floor() -> void:
	var width: float = blueprint.width
	var depth: float = blueprint.depth
	var base := _material(Color("b99572"), 0.68)
	_box(self, "Floor", Vector3(width + 0.24, 0.2, depth + 0.24), Vector3(0, -0.1, 0), base, "floor")
	var tones := [0.96, 1.02, 0.99, 1.04]
	for row in range(roundi(depth / 0.5)):
		var tone: float = tones[row % tones.size()]
		var plank := _material(Color("b99572") * tone, 0.61)
		var z := -depth / 2.0 + .25 + float(row) * .5
		_box(self, "FloorBoard_%02d" % row, Vector3(width, .014, .486), Vector3(0, .006, z), plank, "floor", tone)

func _build_left_wall(wall: Material, trim: Material, wood: Material, metal: Material, linen: Material, glass: Material) -> void:
	var left := _group(self, "Left_Wall")
	var half_x: float = blueprint.width * 0.5
	var half_z: float = blueprint.depth * 0.5
	var window_z: float = blueprint.window_z
	var x := -half_x - .06
	var left_end := window_z - 1.18
	var right_start := window_z + 1.16
	var lower_z := -half_z - .12
	var upper_z := half_z + .12
	_box(left, "WallSurface_Lower", Vector3(.12, 1.26, blueprint.depth + .24), Vector3(x, .63, 0), wall, "wall")
	_box(left, "WallSurface_Upper", Vector3(.12, .48, blueprint.depth + .24), Vector3(x, 2.96, 0), wall, "wall")
	_box(left, "WallSurface_WindowLeft", Vector3(.12, 1.44, left_end - lower_z), Vector3(x, 2.0, (lower_z + left_end) * .5), wall, "wall")
	_box(left, "WallSurface_WindowRight", Vector3(.12, 1.44, upper_z - right_start), Vector3(x, 2.0, (right_start + upper_z) * .5), wall, "wall")
	_box(left, "WindowGlass", Vector3(.025, 1.43, 2.25), Vector3(x + .07, 1.99, window_z), glass)
	_box(left, "WindowSill", Vector3(.2, .065, 2.48), Vector3(x + .18, 1.245, window_z), wood)
	for z in [window_z - 1.16, window_z + 1.16]:
		_box(left, "WindowFrame", Vector3(.10, 1.55, .075), Vector3(x + .15, 1.99, z), trim)
	for y in [1.22, 2.76]:
		_box(left, "WindowFrame", Vector3(.10, .075, 2.43), Vector3(x + .15, y, window_z), trim)
	_box(left, "WindowMullion", Vector3(.055, 1.43, .045), Vector3(x + .135, 1.99, window_z), trim)
	_box(left, "WindowMullion", Vector3(.055, .045, 2.25), Vector3(x + .135, 1.99, window_z), trim)
	var rail := _cylinder(left, "CurtainRail", .025, .025, 2.72, Vector3(x + .24, 2.84, window_z), metal, 20)
	rail.rotation.x = PI / 2.0
	for panel_center in [window_z - .92, window_z + .92]:
		_box(left, "CurtainPanel", Vector3(.075, 1.62, .42), Vector3(x + .23, 1.98, panel_center), linen)
		for fold in range(5):
			_box(left, "CurtainFold", Vector3(.018, 1.55, .025), Vector3(x + .275, 1.98, float(panel_center) - .16 + float(fold) * .08), trim)
	var sky := _material(Color("c6d7d8"), 1.0)
	var distant := _material(Color("a8b8b5"), 1.0)
	var near_building := _material(Color("899d9b"), .96)
	_box(left, "WindowSky", Vector3(.04, 1.34, 2.18), Vector3(x - .94, 1.99, window_z), sky)
	_box(left, "DistantBuilding", Vector3(.08, .58, .62), Vector3(x - .66, 1.58, window_z - .68), distant)
	_box(left, "DistantBuilding", Vector3(.08, .90, .48), Vector3(x - .66, 1.73, window_z + .08), near_building)
	_box(left, "DistantBuilding", Vector3(.08, .48, .58), Vector3(x - .66, 1.52, window_z + .92), distant)
	_box(left, "Left_Skirting", Vector3(.10, .16, blueprint.depth + .05), Vector3(x + .12, .08, 0), trim)
	_box(left, "Left_CapTrim", Vector3(.16, .055, blueprint.depth + .12), Vector3(x + .06, 3.19, 0), trim)

func _build_back_wall(wall: Material, trim: Material, wood: Material, dark_wood: Material, metal: Material, canvas: Material, art_blue: Material, art_sage: Material, art_ochre: Material) -> void:
	var back := _group(self, "Back_Wall")
	var half_x: float = blueprint.width * .5
	var z: float = -blueprint.depth * .5 - .06
	var door_x: float = blueprint.door_x
	var left_edge := -half_x - .12
	var right_edge := half_x + .12
	var door_left := door_x - .5
	var door_right := door_x + .5
	_box(back, "WallSurface_DoorLeft", Vector3(door_left - left_edge, 3.2, .12), Vector3((left_edge + door_left) * .5, 1.6, z), wall, "wall")
	_box(back, "WallSurface_DoorRight", Vector3(right_edge - door_right, 3.2, .12), Vector3((right_edge + door_right) * .5, 1.6, z), wall, "wall")
	_box(back, "WallSurface_DoorLintel", Vector3(1.0, .95, .12), Vector3(door_x, 2.725, z), wall, "wall")
	_box(back, "DoorLeaf", Vector3(.92, 2.18, .055), Vector3(door_x, 1.09, z + .085), dark_wood)
	_box(back, "DoorInset", Vector3(.72, 1.75, .018), Vector3(door_x, 1.16, z + .12), wood)
	for dx in [-.505, .505]:
		_box(back, "DoorFrame", Vector3(.075, 2.28, .09), Vector3(door_x + dx, 1.14, z + .15), trim)
	_box(back, "DoorHeader", Vector3(1.08, .08, .09), Vector3(door_x, 2.30, z + .15), trim)
	_sphere(back, "DoorHandle", Vector3(.075, .075, .075), Vector3(door_x + .37, 1.05, z + .18), metal)
	# Keep wall art on the longer uninterrupted section away from the doorway.
	var art_x: float = (door_right + right_edge) * .5 if right_edge - door_right >= door_left - left_edge else (left_edge + door_left) * .5
	var art_available: float = maxf(right_edge - door_right, door_left - left_edge)
	if art_available > 1.8:
		_box(back, "WallArtFrame", Vector3(1.58, 1.08, .07), Vector3(art_x, 2.08, z + .105), dark_wood)
		_box(back, "WallArtCanvas", Vector3(1.47, .97, .025), Vector3(art_x, 2.08, z + .15), canvas)
		_box(back, "WallArtBlue", Vector3(.48, .72, .025), Vector3(art_x - .32, 2.08, z + .175), art_blue)
		_box(back, "WallArtSage", Vector3(.48, .30, .026), Vector3(art_x + .17, 1.86, z + .178), art_sage)
		_box(back, "WallArtOchre", Vector3(.28, .28, .028), Vector3(art_x + .33, 2.35, z + .18), art_ochre)
	_box(back, "Back_Skirting", Vector3(blueprint.width, .16, .10), Vector3(0, .08, z + .12), trim)
	_box(back, "Back_CapTrim", Vector3(blueprint.width + .16, .055, .16), Vector3(0, 3.19, z + .06), trim)

func _build_ceiling_trim(trim: Material, metal: Material) -> void:
	var ceiling := _group(self, "CeilingDetails")
	var half_x: float = blueprint.width * .5
	var half_z: float = blueprint.depth * .5
	_box(ceiling, "Left_CeilingCove", Vector3(.20, .11, blueprint.depth + .2), Vector3(-half_x + .01, 3.16, 0), trim)
	_box(ceiling, "Back_CeilingCove", Vector3(blueprint.width + .2, .11, .20), Vector3(0, 3.16, -half_z + .01), trim)
	_cylinder(ceiling, "RecessedSpotTrim", .12, .12, .035, Vector3(.1, 3.08, -half_z + .28), metal, 32)

func _build_partitions(wall: Material, trim: Material) -> void:
	var pieces := _group(self, "Partitions")
	for index in range(blueprint.partitions.size()):
		var part: Dictionary = blueprint.partitions[index]
		var piece := _group(pieces, "Segment_%02d" % index)
		piece.position = Vector3(float(part.x), 0, float(part.z))
		var along_x: bool = part.axis == "x"
		var horizontal: Vector3 = Vector3(1.0, 0, .14) if along_x else Vector3(.14, 0, 1.0)
		if part.kind == "door":
			# Structural posts and lintel leave a real passable opening.
			for sign in [-1.0, 1.0]:
				var post: Vector3 = Vector3(sign * .47, 1.48, 0) if along_x else Vector3(0, 1.48, sign * .47)
				var dims: Vector3 = Vector3(.06, 2.96, .14) if along_x else Vector3(.14, 2.96, .06)
				_box(piece, "DoorPost", dims, post, trim, "wall")
			_box(piece, "DoorLintel", Vector3(1.0, .3, .14) if along_x else Vector3(.14, .3, 1.0), Vector3(0, 3.05, 0), wall, "wall")
		else:
			_box(piece, "WallBody", Vector3(horizontal.x, 3.2, horizontal.z), Vector3(0, 1.6, 0), wall, "wall")
		# A subtle top rail makes individual one-metre pieces readable from above.
		_box(piece, "TopTrim", Vector3(horizontal.x, .045, horizontal.z), Vector3(0, 3.22, 0), trim)
