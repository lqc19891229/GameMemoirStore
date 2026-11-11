@tool
extends Node3D
## Runtime-authored architectural shell for the modern sample room.
## Dimensions are in metres; the front and right sides remain open for the showcase camera.
## P42: architectural finish improvements reuse the same room dimensions and
## have no physics or layout_role metadata, preserving free furniture editing.

var _sky_gradient_cache: Texture2D
var _linen_weave_cache: Texture2D

func _sky_gradient_texture() -> Texture2D:
	if _sky_gradient_cache != null: return _sky_gradient_cache
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var u := float(x)/127.0
			var v := float(y)/127.0
			# Slight horizon brightness and thin wispy clouds. This grayscale
			# texture is tinted by the existing four weather palettes.
			var cloud_level := .36+.023*sin(u*TAU*2.0)+.014*sin(u*TAU*5.0)
			var cloud := exp(-pow((v-cloud_level)/.065,2.0))
			var value := clampf(.885+.075*(1.0-v)+.032*cloud,.86,1.0)
			image.set_pixel(x,y,Color(value,value,value))
	image.generate_mipmaps()
	_sky_gradient_cache = ImageTexture.create_from_image(image)
	return _sky_gradient_cache

func _linen_weave_texture() -> Texture2D:
	if _linen_weave_cache != null: return _linen_weave_cache
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var warp := .030 if x % 5 == 0 else .009 if x % 5 == 1 else 0.0
			var weft := .025 if y % 7 == 0 else 0.0
			var shade := .925+warp+weft+.011*sin(float(x)*.74+float(y)*.23)
			image.set_pixel(x,y,Color(shade,shade,shade))
	image.generate_mipmaps()
	_linen_weave_cache = ImageTexture.create_from_image(image)
	return _linen_weave_cache

func _curtain_point(u: float, v: float, width: float, height: float) -> Vector3:
	# Pleats are actual shaded folds rather than 2D lines on a flat box.
	var swell := .030*sin(u*TAU*4.0)*(.48+.52*(1.0-v))
	var ripple := .006*sin(u*TAU*8.0+v*3.0)
	return Vector3(swell+ripple,(v-.5)*height,(u-.5)*width)

func _add_curtain_vertex(tool: SurfaceTool, u: float, v: float, width: float, height: float) -> void:
	tool.set_uv(Vector2(u*2.0,v*2.0))
	tool.add_vertex(_curtain_point(u,v,width,height))

func _curtain_panel(parent: Node, at: Vector3, width: float, height: float, fabric: Material, label: String) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iy in range(10):
		for ix in range(32):
			var u0 := float(ix)/32.0
			var u1 := float(ix+1)/32.0
			var v0 := float(iy)/10.0
			var v1 := float(iy+1)/10.0
			_add_curtain_vertex(tool,u0,v0,width,height)
			_add_curtain_vertex(tool,u1,v0,width,height)
			_add_curtain_vertex(tool,u0,v1,width,height)
			_add_curtain_vertex(tool,u1,v0,width,height)
			_add_curtain_vertex(tool,u1,v1,width,height)
			_add_curtain_vertex(tool,u0,v1,width,height)
	tool.generate_normals()
	var panel := MeshInstance3D.new()
	panel.name = label
	panel.mesh = tool.commit()
	panel.position = at
	panel.material_override = fabric
	parent.add_child(panel)
	return panel

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

func _finish_box(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material, finish: int, role: String) -> MeshInstance3D:
	var mesh: MeshInstance3D = _box(parent, node_name, size, at, material, role)
	if finish > 0: mesh.set_meta("finish_id", finish)
	return mesh

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
	linen.albedo_texture = _linen_weave_texture()
	linen.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	linen.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	_build_lighting_accents()
	_build_notch_walls(wall, trim)
	_build_custom_exterior(wall, trim)
	_build_partitions(wall, trim)

func _build_floor() -> void:
	if blueprint.shape == "custom":
		_build_grid_floor()
		return
	var width: float = blueprint.width
	var depth: float = blueprint.depth
	var cutout: bool = blueprint.shape == "l"
	var notch_w: float = blueprint.notch_width if cutout else 0.0
	var notch_d: float = blueprint.notch_depth if cutout else 0.0
	var cut_z: float = depth * .5 - notch_d
	var base := _material(Color("b99572"), .68)
	if cutout:
		# Two adjoining rectangles make a real hole in the floor mesh (not a color mask).
		_box(self, "Floor", Vector3(width + .24, .1, depth - notch_d + .12), Vector3(0, -.05, -(notch_d + .12) * .5), base, "floor")
		_box(self, "FloorWing", Vector3(width - notch_w + .12, .1, notch_d + .12), Vector3(-(notch_w + .12) * .5, -.05, depth * .5 - notch_d * .5 + .06), base, "floor")
	else:
		_box(self, "Floor", Vector3(width + .24, .1, depth + .24), Vector3(0, -.05, 0), base, "floor")
	var tones := [.96, 1.02, .99, 1.04]
	for row in range(roundi(depth / .5)):
		var tone: float = tones[row % tones.size()]
		var plank := _material(Color("b99572") * tone, .61)
		var z: float = -depth * .5 + .25 + float(row) * .5
		var wing: bool = cutout and z >= cut_z
		var plank_width := width - notch_w if wing else width
		var plank_x := -notch_w * .5 if wing else 0.0
		_box(self, "FloorBoard_%02d" % row, Vector3(plank_width, .014, .486), Vector3(plank_x, .006, z), plank, "floor", tone)

func _build_left_wall(wall: Material, trim: Material, wood: Material, metal: Material, linen: Material, glass: Material) -> void:
	var left := _group(self, "Left_Wall")
	var half_x: float = blueprint.width * 0.5
	var half_z: float = blueprint.depth * 0.5
	var window_z: float = blueprint.window_z
	var x := -half_x - .06
	var left_end := window_z - .78
	var right_start := window_z + .78
	var lower_z := -half_z - .12
	var upper_z := half_z + .12
	_box(left, "WallSurface_Lower", Vector3(.12, .9, blueprint.depth + .24), Vector3(x, .45, 0), wall, "wall")
	_box(left, "WallSurface_Upper", Vector3(.12, .6, blueprint.depth + .24), Vector3(x, 2.4, 0), wall, "wall")
	_box(left, "WallSurface_WindowLeft", Vector3(.12, 1.2, left_end - lower_z), Vector3(x, 1.5, (lower_z + left_end) * .5), wall, "wall")
	_box(left, "WallSurface_WindowRight", Vector3(.12, 1.2, upper_z - right_start), Vector3(x, 1.5, (right_start + upper_z) * .5), wall, "wall")
	_box(left, "WindowGlass", Vector3(.025, 1.2, 1.5), Vector3(x + .07, 1.5, window_z), glass)
	_box(left, "WindowSill", Vector3(.2, .06, 1.68), Vector3(x + .18, .9, window_z), wood)
	_box(left, "WindowSillApron", Vector3(.09,.08,1.58), Vector3(x+.25,.83,window_z), trim)
	_box(left, "WindowSillHighlight", Vector3(.26,.018,1.69), Vector3(x+.18,.93,window_z), _material(Color("e9ddcb"),.48))
	for z in [window_z - .78, window_z + .78]:
		_box(left, "WindowFrame", Vector3(.10, 1.32, .075), Vector3(x + .15, 1.5, z), trim)
	for y in [.9, 2.1]:
		_box(left, "WindowFrame", Vector3(.10, .06, 1.56), Vector3(x + .15, y, window_z), trim)
	_box(left, "WindowMullion", Vector3(.055, 1.2, .045), Vector3(x + .135, 1.5, window_z), trim)
	_box(left, "WindowMullion", Vector3(.055, .045, 1.5), Vector3(x + .135, 1.5, window_z), trim)
	var rail := _cylinder(left, "CurtainRail",  .025, .025, 1.85, Vector3(x + .24, 2.18, window_z), metal, 20)
	rail.rotation.x = PI / 2.0
	for panel_index in range(2):
		var center_z: float = window_z+(-.62 if panel_index == 0 else .62)
		_curtain_panel(left,Vector3(x+.25,1.5,center_z),.30,1.2,linen,"CurtainPanel" if panel_index == 0 else "CurtainPanel_%d" % panel_index)
		_box(left,"CurtainHeader" if panel_index == 0 else "CurtainHeader_%d" % panel_index,Vector3(.042,.045,.30),Vector3(x+.25,2.13,center_z),linen)
		_box(left,"CurtainHem" if panel_index == 0 else "CurtainHem_%d" % panel_index,Vector3(.048,.025,.31),Vector3(x+.25,.91,center_z),linen)
		for hook in range(4):
			var hook_z := center_z-.11+float(hook)*.073
			_box(left,"CurtainHook_%d_%d" % [panel_index,hook],
				Vector3(.045,.055,.026),Vector3(x+.25,2.16,hook_z),metal)
	var sky := _material(Color("c6d7d8"), 1.0)
	sky.albedo_texture = _sky_gradient_texture()
	sky.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var distant := _material(Color("a8b8b5"), 1.0)
	var near_building := _material(Color("899d9b"), .96)
	_box(left, "WindowSky", Vector3(.04, 1.1, 1.42), Vector3(x - .64, 1.5, window_z), sky)
	# Exterior rain strips share the window group so cutaway hides them too.
	# Streaks are deliberately outside the real pane, not inside the room.
	var streaks := _group(left, "RainStreaks")
	streaks.visible = false
	var water := _material(Color(.75,.85,.95,.42), .18)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for index in range(14):
		var offset: float = -1.03 + float(index) * .158
		var y: float = 1.10 + float(index % 4) * .24
		_box(streaks,"Rain_%02d" % index,Vector3(.008,.27 + float(index % 3)*.05,.009),
			Vector3(x-.45,y,window_z+offset),water)

	# P44: subtle beads on the outside of the glass give rainfall depth.
	# They belong to RainStreaks so all existing weather/cutaway toggles
	# still control the entire effect. Never add collision or picking.
	var droplets := _group(streaks, "GlassDroplets")
	var bead_mat := _material(Color(.76,.88,.96,.32), .16)
	bead_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for bead in range(12):
		var bead_z: float = window_z - .98 + float(bead % 6) * .39
		var bead_y: float = 1.12 + floorf(float(bead) / 6.0) * .55 + float(bead % 3) * .07
		var size := .012 + float(bead % 3) * .006
		_sphere(droplets,"GlassBead_%02d" % bead,Vector3(.009,size,size*.70),
			Vector3(x+.045,bead_y,bead_z),bead_mat)

	_box(left, "DistantBuilding", Vector3(.08, .58, .62), Vector3(x - .66, 1.58, window_z - .68), distant)
	_box(left, "DistantBuilding", Vector3(.08, .90, .48), Vector3(x - .66, 1.73, window_z + .08), near_building)
	_box(left, "DistantBuilding", Vector3(.08, .48, .58), Vector3(x - .66, 1.52, window_z + .92), distant)
	# Three simple facade silhouettes and a handful of lit windows add depth
	# behind the pane without a texture atlas, imported meshes or weather DLC.
	var facade_lights := _group(left,"ExteriorWindows")
	var warm_panes := _material(Color("ffd9a0"),.76)
	warm_panes.emission_enabled = true
	warm_panes.emission = Color("ffd9a0")
	warm_panes.emission_energy_multiplier = .35
	for section in range(3):
		var section_z: float = window_z + [-.68,.08,.92][section]
		var section_height: int = [2,3,2][section]
		for level in range(section_height):
			for column in range(2):
				var pane_z: float = section_z + (float(column)-.5)*.21
				var pane_y: float = 1.46+float(level)*.19
				_box(facade_lights,"WarmWindow_%d_%d_%d" % [section,level,column],Vector3(.012,.075,.063),
					Vector3(x-.601,pane_y,pane_z),warm_panes)
	facade_lights.visible = false
	_box(left, "Left_Skirting", Vector3(.10, .08, blueprint.depth + .05), Vector3(x + .12, .04, 0), trim)
	_box(left, "Left_CapTrim", Vector3(.16, .045, blueprint.depth + .12), Vector3(x + .06, 2.68, 0), trim)

func _build_back_wall(wall: Material, trim: Material, wood: Material, dark_wood: Material, metal: Material, canvas: Material, art_blue: Material, art_sage: Material, art_ochre: Material) -> void:
	var back := _group(self, "Back_Wall")
	var half_x: float = blueprint.width * .5
	var z: float = -blueprint.depth * .5 - .06
	var door_x: float = blueprint.door_x
	var left_edge := -half_x - .12
	var right_edge := half_x + .12
	var door_left := door_x - .5
	var door_right := door_x + .5
	_box(back, "WallSurface_DoorLeft", Vector3(door_left - left_edge, 2.7, .12), Vector3((left_edge + door_left) * .5, 1.35, z), wall, "wall")
	_box(back, "WallSurface_DoorRight", Vector3(right_edge - door_right, 2.7, .12), Vector3((right_edge + door_right) * .5, 1.35, z), wall, "wall")
	_box(back, "WallSurface_DoorLintel", Vector3(1.0, .6, .12), Vector3(door_x, 2.4, z), wall, "wall")
	_box(back, "DoorLeaf", Vector3(.86, 2.1, .055), Vector3(door_x, 1.05, z + .085), dark_wood)
	_box(back, "DoorInset", Vector3(.68, 1.7, .018), Vector3(door_x, 1.1, z + .12), wood)
	for dx in [-.465, .465]:
		_box(back, "DoorFrame", Vector3(.065, 2.18, .09), Vector3(door_x + dx, 1.09, z + .15), trim)
	_box(back, "DoorHeader", Vector3(1.0, .07, .09), Vector3(door_x, 2.16, z + .15), trim)
	_sphere(back, "DoorHandle", Vector3(.075, .075, .075), Vector3(door_x + .34, 1.0, z + .18), metal)
	# Keep wall art on the longer uninterrupted section away from the doorway.
	var art_x: float = (door_right + right_edge) * .5 if right_edge - door_right >= door_left - left_edge else (left_edge + door_left) * .5
	var art_available: float = maxf(right_edge - door_right, door_left - left_edge)
	if art_available > 1.4:
		_box(back, "WallArtFrame", Vector3(1.2, .82, .07), Vector3(art_x, 1.8, z + .105), dark_wood)
		_box(back, "WallArtCanvas", Vector3(1.1, .72, .025), Vector3(art_x, 1.8, z + .15), canvas)
		_box(back, "WallArtInnerBevel",Vector3(1.16,.76,.012),Vector3(art_x,1.8,z+.132),metal)
		_box(back, "WallArtBlue", Vector3(.36, .54, .025), Vector3(art_x - .24, 1.8, z + .175), art_blue)
		_box(back, "WallArtSage", Vector3(.36, .24, .026), Vector3(art_x + .13, 1.64, z + .178), art_sage)
		_box(back, "WallArtOchre", Vector3(.21, .21, .028), Vector3(art_x + .25, 1.99, z + .18), art_ochre)
	_box(back, "Back_Skirting", Vector3(blueprint.width, .08, .10), Vector3(0, .04, z + .12), trim)
	_box(back, "Back_CapTrim", Vector3(blueprint.width + .16, .045, .16), Vector3(0, 2.68, z + .06), trim)

func _build_ceiling_trim(trim: Material, metal: Material) -> void:
	var ceiling := _group(self, "CeilingDetails")
	var half_x: float = blueprint.width * .5
	var half_z: float = blueprint.depth * .5
	_box(ceiling, "Left_CeilingCove", Vector3(.20, .11, blueprint.depth + .2), Vector3(-half_x + .01, 2.66, 0), trim)
	_box(ceiling, "Back_CeilingCove", Vector3(blueprint.width + .2, .11, .20), Vector3(0, 2.66, -half_z + .01), trim)
	_cylinder(ceiling, "RecessedSpotTrim", .12, .12, .035, Vector3(.1, 2.62, -half_z + .28), metal, 32)

func _build_lighting_accents() -> void:
	# Renderer-compatible, unshadowed diffuse bounce fills the dark half of
	# a cutaway room. They are separate from wall geometry so camera cutaway
	# never turns the actual lighting off.
	var bounce := OmniLight3D.new()
	bounce.name = "WindowBounce"
	bounce.position = Vector3(-float(blueprint.width)*.5+.72,1.55,float(blueprint.window_z))
	bounce.omni_range = 2.8
	bounce.light_energy = .24
	bounce.light_color = Color("ffe8c5")
	bounce.shadow_enabled = false
	bounce.distance_fade_enabled = true
	bounce.distance_fade_begin = 5.0
	bounce.distance_fade_length = 3.0
	add_child(bounce)
	var cove := OmniLight3D.new()
	cove.name = "WarmCoveFill"
	cove.position = Vector3(.15,2.55,-float(blueprint.depth)*.5+.32)
	cove.omni_range = 3.3
	cove.light_energy = .12
	cove.light_color = Color("ffdfb3")
	cove.shadow_enabled = false
	add_child(cove)

func _build_partitions(wall: Material, trim: Material) -> void:
	var pieces := _group(self, "Partitions")
	for index in range(blueprint.partitions.size()):
		var part: Dictionary = blueprint.partitions[index]
		var piece := _group(pieces, "Segment_%02d" % index)
		piece.position = Vector3(float(part.x), 0, float(part.z))
		var along_x: bool = part.axis == "x"
		var horizontal: Vector3 = Vector3(1.0, 0, .14) if along_x else Vector3(.14, 0, 1.0)
		var finish: int = Blueprint.effective_wall_finish(blueprint, Vector2(float(part.x),float(part.z)), int(part.get("finish",0)))
		if part.kind == "door":
			# Structural posts and lintel leave a real passable opening.
			for sign in [-1.0, 1.0]:
				var post: Vector3 = Vector3(sign * .47, 1.05, 0) if along_x else Vector3(0, 1.05, sign * .47)
				var dims: Vector3 = Vector3(.06, 2.1, .14) if along_x else Vector3(.14, 2.1, .06)
				_box(piece, "DoorPost", dims, post, trim, "wall")
			_finish_box(piece, "DoorLintel", Vector3(1.0, .6, .14) if along_x else Vector3(.14, .6, 1.0), Vector3(0, 2.4, 0), wall, finish, "wall")
		else:
			_finish_box(piece, "WallBody", Vector3(horizontal.x, 2.7, horizontal.z), Vector3(0, 1.35, 0), wall, finish, "wall")
		# A subtle top rail makes individual one-metre pieces readable from above.
		_box(piece, "TopTrim", Vector3(horizontal.x, .045, horizontal.z), Vector3(0, 2.72, 0), trim)

func _build_notch_walls(wall: Material, trim: Material) -> void:
	if blueprint.shape != "l": return
	var group := _group(self, "Notch_Walls")
	var half_w: float = blueprint.width * .5
	var half_d: float = blueprint.depth * .5
	var cut_x: float = half_w - float(blueprint.notch_width)
	var cut_z: float = half_d - float(blueprint.notch_depth)
	var notch_w: float = blueprint.notch_width
	var notch_d: float = blueprint.notch_depth
	# Concave outer contour: two return walls where the missing front-right corner begins.
	_box(group, "NotchBack", Vector3(notch_w, 2.7, .12), Vector3(cut_x + notch_w * .5, 1.35, cut_z + .06), wall, "wall")
	_box(group, "NotchSide", Vector3(.12, 2.7, notch_d), Vector3(cut_x + .06, 1.35, cut_z + notch_d * .5), wall, "wall")
	_box(group, "NotchBackTrim", Vector3(notch_w, .07, .16), Vector3(cut_x + notch_w * .5, 2.68, cut_z + .06), trim)
	_box(group, "NotchSideTrim", Vector3(.16, .07, notch_d), Vector3(cut_x + .06, 2.68, cut_z + notch_d * .5), trim)

func _build_grid_floor() -> void:
	# Generate contiguous runs of retained cells; no geometry remains below a hole.
	var size: Vector2i = Blueprint.cell_count(blueprint)
	var material := _material(Color("b99572"), .68)
	var removed: Dictionary = {}
	for cell: Dictionary in blueprint.removed_cells:
		removed[Vector2i(cell.ix, cell.iz)] = true
	var index := 0
	var tones := [.96, 1.02, .99, 1.04]
	for iz in range(size.y):
		var ix := 0
		while ix < size.x:
			if removed.has(Vector2i(ix, iz)):
				ix += 1
				continue
			var begin := ix
			var first_cell := {"ix":begin,"iz":iz}
			var finish: int = Blueprint.effective_floor_finish(blueprint, first_cell)
			while ix < size.x and not removed.has(Vector2i(ix, iz)) and Blueprint.effective_floor_finish(blueprint, {"ix":ix,"iz":iz}) == finish:
				ix += 1
			var length := float(ix - begin) * Blueprint.FLOOR_GRID
			var center_x := -float(blueprint.width) * .5 + (float(ix + begin) * .5) * Blueprint.FLOOR_GRID
			var center_z := -float(blueprint.depth) * .5 + (float(iz) + .5) * Blueprint.FLOOR_GRID
			var floor_mesh := _finish_box(self, "Floor" if index == 0 else "FloorSegment_%03d" % index,
				Vector3(length + .008, .1, Blueprint.FLOOR_GRID + .008),
				Vector3(center_x, -.05, center_z), material, finish, "floor")
			var tone: float = tones[iz % tones.size()]
			var plank := _material(Color("b99572") * tone, .61)
			var board := _finish_box(self, "FloorBoard_%02d_%02d" % [iz,begin],
				Vector3(length, .014, Blueprint.FLOOR_GRID - .014),
				Vector3(center_x, .006, center_z), plank, finish, "floor")
			board.set_meta("tone", tone)
			index += 1

func _build_custom_exterior(wall: Material, trim: Material) -> void:
	if blueprint.shape != "custom": return
	var group := _group(self, "Custom_Exterior")
	var edges: Array = Blueprint.exposed_edges(blueprint)
	var clear_glass := _material(Color(0.52, 0.75, 0.86, .34), .22)
	clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for counter in range(edges.size()):
		var edge: Dictionary = edges[counter]
		var config: Dictionary = Blueprint.edge_edit(blueprint, edge)
		var kind: String = str(config.kind)
		var adjacent_cell := {"ix":int(edge.ix)+int(edge.dx),"iz":int(edge.iz)+int(edge.dz)}
		var adjacent_position: Vector2 = Blueprint.cell_center(blueprint,adjacent_cell)
		var finish: int = Blueprint.effective_wall_finish(blueprint, adjacent_position, int(config.finish))
		var center: Vector2 = Blueprint.edge_center(blueprint, edge)
		var longitudinal: bool = edge.dx != 0
		var span := Vector3(.12,2.7,Blueprint.FLOOR_GRID) if longitudinal else Vector3(Blueprint.FLOOR_GRID,2.7,.12)
		var at := Vector3(center.x, 1.35, center.y)
		var section := _group(group, "Edge_%03d" % counter)
		if kind == "wall":
			_finish_box(section, "ReturnWall_%03d" % counter, span, at, wall, finish, "wall")
		elif kind == "door":
			# One grid edge is a 0.5m narrow doorway module; door-sized
			# openings can later span multiple neighboring edges.
			var header := span
			header.y = .6
			_finish_box(section, "DoorHead", header, Vector3(center.x, 2.4, center.y), wall, finish, "wall")
			for direction in [-1,1]:
				if Blueprint.same_opening_neighbor(blueprint,edge,direction): continue
				var offset: float = float(direction) * (Blueprint.FLOOR_GRID * .5 - .025)
				var post_at := Vector3(center.x, 1.05, center.y)
				var post_size := Vector3(.05,2.1,.14) if not longitudinal else Vector3(.14,2.1,.05)
				if longitudinal: post_at.z += offset
				else: post_at.x += offset
				_box(section, "DoorFrame", post_size, post_at, trim)
		elif kind == "window":
			var lower := span
			lower.y = .9
			_finish_box(section, "WindowLower", lower, Vector3(center.x,.45,center.y), wall, finish, "wall")
			var upper := span
			upper.y = .6
			_finish_box(section, "WindowUpper", upper, Vector3(center.x,2.4,center.y), wall, finish, "wall")
			var glass_length: float = Blueprint.FLOOR_GRID if Blueprint.same_opening_neighbor(blueprint,edge,-1) or Blueprint.same_opening_neighbor(blueprint,edge,1) else Blueprint.FLOOR_GRID-.08
			var glass_size := Vector3(.026,1.2,glass_length) if longitudinal else Vector3(glass_length,1.2,.026)
			_box(section, "WindowGlass", glass_size, Vector3(center.x,1.5,center.y), clear_glass)
			var sill := Vector3(.2,.06,Blueprint.FLOOR_GRID+.03) if longitudinal else Vector3(Blueprint.FLOOR_GRID+.03,.06,.2)
			_box(section, "WindowSill", sill, Vector3(center.x,.9,center.y), trim)
		_box(section, "ReturnTrim_%03d" % counter,
			Vector3(span.x,.06,span.z), Vector3(center.x,2.72,center.y), trim)
