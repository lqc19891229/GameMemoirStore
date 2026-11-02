extends Node3D
## Lightweight editor-only spatial overlay. All three MeshInstance3D nodes are
## authored in workstation_3d.tscn; generated meshes are never persisted.
const Blueprint = preload("res://scripts/room/room_blueprint_data.gd")
const GRID_HEIGHT := .028
const REGION_HEIGHT := .052
const GRID_COLOR := Color(.56,.81,.90,.42)
const REGION_COLOR := Color(.33,.83,.65,.27)

var last_blueprint: Dictionary = {}
var show_grid := true
var region_keys: Dictionary = {}
var region_count := 0

func _ready() -> void:
	$GridLines.material_override = _mat(GRID_COLOR)
	$RegionFill.material_override = _mat(REGION_COLOR)
	$DoorHandle.material_override = _mat(Color(.95,.65,.25,.90))
	$WindowHandle.material_override = _mat(Color(.34,.72,.95,.90))
	$DoorHandle.mesh = BoxMesh.new()
	$WindowHandle.mesh = BoxMesh.new()
	($DoorHandle.mesh as BoxMesh).size = Vector3(.9,.065,.12)
	($WindowHandle.mesh as BoxMesh).size = Vector3(.12,.065,1.3)
	visible = false

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func set_grid_visible(enabled: bool) -> void:
	show_grid = enabled
	$GridLines.visible = enabled

func configure(blueprint: Dictionary) -> void:
	if blueprint == last_blueprint: return
	last_blueprint = blueprint.duplicate(true)
	var size: Vector2i = Blueprint.cell_count(blueprint)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for z in range(size.y):
		for x in range(size.x):
			var cell := {"ix":x,"iz":z}
			if not Blueprint.floor_cell_exists(blueprint,cell): continue
			var center: Vector2 = Blueprint.cell_center(blueprint,cell)
			var e := Blueprint.FLOOR_GRID * .5
			var a := Vector3(center.x-e,GRID_HEIGHT,center.y-e)
			var b := Vector3(center.x+e,GRID_HEIGHT,center.y-e)
			var c := Vector3(center.x+e,GRID_HEIGHT,center.y+e)
			var d := Vector3(center.x-e,GRID_HEIGHT,center.y+e)
			for pair: Array in [[a,b],[b,c],[c,d],[d,a]]:
				surface.add_vertex(pair[0])
				surface.add_vertex(pair[1])
	$GridLines.mesh = surface.commit()
	$DoorHandle.position = Vector3(float(blueprint.door_x),.085,-float(blueprint.depth)*.5 + .17)
	$WindowHandle.position = Vector3(-float(blueprint.width)*.5+.17,.085,float(blueprint.window_z))
	$GridLines.visible = show_grid
	clear_region()

func clear_region() -> void:
	region_keys.clear()
	region_count = 0
	$RegionFill.mesh = null

func preview_region(blueprint: Dictionary, at: Vector2) -> int:
	if blueprint != last_blueprint: configure(blueprint)
	var cell: Dictionary = Blueprint.cell_at(blueprint,at)
	var lookup := Vector2i(int(cell.ix),int(cell.iz))
	if region_keys.has(lookup): return region_count
	var region: Array = Blueprint.room_region_at(blueprint,at)
	if region.is_empty():
		clear_region()
		return 0
	region_keys.clear()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item: Dictionary in region:
		region_keys[Vector2i(int(item.ix),int(item.iz))] = true
		var center: Vector2 = Blueprint.cell_center(blueprint,item)
		var e := Blueprint.FLOOR_GRID * .5 - .015
		var a := Vector3(center.x-e,REGION_HEIGHT,center.y-e)
		var b := Vector3(center.x+e,REGION_HEIGHT,center.y-e)
		var c := Vector3(center.x+e,REGION_HEIGHT,center.y+e)
		var d := Vector3(center.x-e,REGION_HEIGHT,center.y+e)
		for vertex: Vector3 in [a,b,c,a,c,d]:
			surface.add_vertex(vertex)
	$RegionFill.mesh = surface.commit()
	region_count = region.size()
	return region_count
