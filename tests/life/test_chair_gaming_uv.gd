extends SceneTree
## Imported game-chair UV regression. Run after editor imports the updated GLB.
const CHAIR := "res://scenes/room/seating/chair_gaming.tscn"
const EXPECTED_NAMES := [
	"graphite", "gunmetal", "rubber", "wheel_hub",
	"steel", "dark_shell", "grey_inset", "leather_pearl",
	"leather_cream", "stitch", "edge_welt", "leather_shadow"
]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene := ResourceLoader.load(CHAIR) as PackedScene
	check(scene != null, "game chair wrapper scene still loads")
	if scene == null:
		quit(1)
		return
	var chair := scene.instantiate() as Node3D
	root.add_child(chair)
	await process_frame
	var model := chair.get_node_or_null("Model")
	check(model != null, "game chair GLB is instantiated as Model")
	if model == null:
		chair.queue_free()
		quit(1)
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 12, "original 12 chair mesh groups retained")
	var found: Dictionary = {}
	var total_surfaces := 0
	var all_uv := true
	var all_normals := true
	var within_bounds := true
	var dimensions: Vector3 = chair.get("bounds")
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		found[str(mesh.name)] = true
		if mesh.mesh == null:
			all_uv = false
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			total_surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			all_uv = all_uv and not vertices.is_empty() and uv.size() == vertices.size()
			all_normals = all_normals and normals.size() == vertices.size()
			for coord: Vector2 in uv:
				all_uv = all_uv and is_finite(coord.x) and is_finite(coord.y)
			# Bounds are evaluated in the furniture's frame, not the GLB mesh frame.
			var aabb: AABB = chair.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			for corner: Vector3 in [aabb.position, aabb.end]:
				within_bounds = within_bounds and absf(corner.x) <= dimensions.x * 0.5 + 0.02
				within_bounds = within_bounds and absf(corner.z) <= dimensions.z * 0.5 + 0.02
				within_bounds = within_bounds and corner.y >= -0.02 and corner.y <= dimensions.y + 0.02
	for name: String in EXPECTED_NAMES:
		check(found.has(name), "chair material/mesh name retained: " + name)
	check(total_surfaces == 12, "same 12 mesh surfaces available for persisted material slots")
	check(all_uv, "all game-chair surfaces contain usable UV coordinates")
	check(all_normals, "all game-chair surfaces have normals")
	check(within_bounds, "UV unwrap does not change authored furniture bounds")
	var pick := chair.get_node_or_null("PickArea/Hit") as CollisionShape3D
	check(pick != null and pick.shape is BoxShape3D, "existing picking volume retained")
	chair.queue_free()
	await process_frame
	print("CHAIR_GAMING_UV_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
