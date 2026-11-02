extends SceneTree
## P22 verifies imported GLB vertices, embedded surface textures and collision bounds.
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const POLISHED := ["bench_cushion","lounge_chair","sofa_modular","side_table_oak","writing_table","media_console"]
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for role: String in POLISHED:
		var item: MemoirItemDefinition = Catalog.lookup("room_" + role)
		check(item != null and item.furniture_scene != null, "polished model retains its original purchasable SKU: " + role)
		if item == null or item.furniture_scene == null:
			continue
		var furniture: Node3D = item.furniture_scene.instantiate()
		root.add_child(furniture)
		await process_frame
		var model: Node3D = furniture.get_node("Model")
		var meshes: Array = model.find_children("*","MeshInstance3D",true,false)
		var rounded := 0
		var textured := 0
		var good_uv := 0
		var inside := true
		var bounds: Vector3 = furniture.bounds
		for node: Node in meshes:
			var part: MeshInstance3D = node as MeshInstance3D
			if part.mesh == null:
				continue
			for surface in range(part.mesh.get_surface_count()):
				var arrays: Array = part.mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				if positions.size() >= 100 and normals.size() == positions.size():
					rounded += 1
				if uv.size() == positions.size() and not uv.is_empty():
					good_uv += 1
				var material: Material = part.get_surface_override_material(surface)
				if material == null:
					material = part.mesh.surface_get_material(surface)
				if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
					textured += 1
			var aabb: AABB = furniture.global_transform.affine_inverse() * part.global_transform * part.get_aabb()
			for point: Vector3 in [aabb.position,aabb.end]:
				inside = inside and absf(point.x) <= bounds.x * .5 + .015 and absf(point.z) <= bounds.z * .5 + .015 and point.y >= -.015 and point.y <= bounds.y + .015
		check(meshes.size() >= 4 and rounded >= 4, "imported meshes contain actual rounded geometry: " + role)
		check(good_uv >= rounded, "rounded meshes carry complete UV coordinates: " + role)
		check(textured >= 1, "imported GLB exposes embedded PBR albedo microtexture: " + role)
		check(inside, "bevel does not escape authored collision/picking bounds: " + role)
		furniture.queue_free()
		await process_frame
	print("FURNITURE_PBR_CHECKS: %d / %d passed" % [checks - failures,checks])
	quit(1 if failures else 0)
