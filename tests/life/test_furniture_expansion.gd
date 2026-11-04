extends SceneTree
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Inventory = preload("res://scripts/items/inventory_data.gd")
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var items: Array[MemoirItemDefinition] = Catalog.room_furniture()
	check(items.size() == 36, "36 purchasable furniture SKUs include the new luminous wall sconce")
	check(Inventory.initial_placements().size() == 5, "existing five starter pieces remain unchanged")
	check(Inventory.initial().size() == 10, "new furniture is not granted in starter inventory")
	var unique_roles := {}
	var unique_ids := {}
	var group_sizes := {}
	for item: MemoirItemDefinition in items:
		check(not unique_roles.has(item.subcategory) and not unique_ids.has(item.item_id), "distinct stable SKU and role: "+item.item_id)
		unique_roles[item.subcategory] = true
		unique_ids[item.item_id] = true
		check(Data.valid_role(item.subcategory) and Inventory.furniture_item_id(item.subcategory) == item.item_id, "each SKU is a persistent floor placement role: "+item.item_id)
		check(item.furniture_scene != null and item.price > 0 and item.placement_surface == "floor", "each item is purchasable with an actual 3D scene: "+item.item_id)
		var group: String = Taxonomy.group_for(item)
		group_sizes[group] = int(group_sizes.get(group,0))+1
		var node: Node3D = item.furniture_scene.instantiate()
		root.add_child(node)
		await process_frame
		check(node.has_node("Model") and node.get_node("Model").find_children("*","MeshInstance3D",true,false).size() >= 4, "authored 3D model has layered mesh parts: "+item.item_id)
		# The first two support-mount collectibles use explicit, testable
		# procedural meshes until their final authored GLBs are ready.
		if item.item_id not in ["room_chair","room_bookcase","room_lamp","room_rug","room_plant","room_sofa","room_stool","room_desk_memento","room_mini_book_stack","room_wall_sconce"]:
			var glb_path := "res://assets/models/room/catalog/%s.glb" % item.subcategory
			check(ResourceLoader.exists(glb_path), "new furniture GLB exists: " + glb_path)
			check(node.get_node("Model").scene_file_path == glb_path, "new furniture instances its imported GLB rather than procedural geometry: " + item.item_id)
		var mesh_nodes: Array = node.get_node("Model").find_children("*","MeshInstance3D",true,false)
		var within_bounds := not mesh_nodes.is_empty()
		var out_of_bounds_parts := PackedStringArray()
		for mesh: MeshInstance3D in mesh_nodes:
			var aabb: AABB = node.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
			var mesh_inside := true
			for point: Vector3 in [aabb.position,aabb.end]:
				mesh_inside = mesh_inside and absf(point.x) <= float(node.bounds.x)*.5+.015 and absf(point.z) <= float(node.bounds.z)*.5+.015 and point.y >= -.015 and point.y <= float(node.bounds.y)+.015
			if not mesh_inside:
				out_of_bounds_parts.append("%s: %s" % [mesh.name, str(aabb)])
			within_bounds = within_bounds and mesh_inside
		check(within_bounds, "mesh geometry fits collision bounds for %s (bounds=%s; offending meshes: %s)" % [item.item_id, str(node.bounds), ", ".join(out_of_bounds_parts)])
		if group == "lighting" and item.item_id.begins_with("room_lamp_"):
			check(node.get_node_or_null("LampGlow") is OmniLight3D, "new floor lamps contain actual local lights: "+item.item_id)
		if group == "decor" and Taxonomy.type_for(item) == "rug" and item.item_id != "room_rug":
			check(not node.blocking, "new thin rugs can overlap floor furniture")
		node.free()
	check(group_sizes.get("tables",0) == 5 and group_sizes.get("seating",0) == 8, "tables and seating have varied models")
	check(group_sizes.get("storage",0) == 6 and group_sizes.get("lighting",0) == 5 and group_sizes.get("decor",0) == 12, "storage, lighting and decoration include new SKUs")
	check(Data.is_copy("side_table_oak_1") and Data.base_role("side_table_oak_1") == "side_table_oak", "multiword placement role can be copied safely")
	check(not Data.is_copy("side_table_oak_9") and not Data.valid_role("unknown_furniture"), "unknown and unused historical numbered roles remain rejected")
	check(Data.valid_role("side_table_oak__instance__item_999") and Data.base_role("side_table_oak__instance__item_999") == "side_table_oak", "unlimited new UID-based room roles are valid")

	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 2000
	var desktop = game.desktop
	var layout = desktop.world.layout
	check(layout.nodes.size() == 10, "new catalog entries do not spawn unpaid furniture into a starter room")
	check(desktop.furniture_buttons.size() == 36, "every furniture SKU appears in the shared room catalog")
	check(desktop.get_node("%FurnitureCatalogGroup").item_count == 7, "all furniture groups remain available after bulk catalog expansion")

	var chosen := ["side_table_oak","lamp_cylinder","plant_cactus","side_table_oak"]
	var positions: Array[Vector2] = [
		Vector2(-2.9,2.45),Vector2(1.75,2.45),Vector2(2.35,2.4),Vector2(3.35,.3),
		Vector2(-3.4,1.5),Vector2(-2.4,1.6),Vector2(1.9,1.5),Vector2(3.4,-.25),
		Vector2(-3.4,-.25),Vector2(3.4,2.4),Vector2(2.2,.65),Vector2(-3.35,.55)
	]
	var finished: Array[String] = []
	# Inventory is snapshotted when entering layout mode: purchase the whole
	# batch through the regular shop before starting the editing session.
	for base: String in chosen:
		var item_id: String = "room_"+base
		check(game.session.buy_item(item_id).begins_with("已购买"), "shop purchase succeeds for new SKU: "+item_id)
	desktop.begin_layout()
	for base: String in chosen:
		var item_id: String = "room_"+base
		var uid: String = Inventory.unused_uid(state.life.inventory,layout.placed_instances,item_id)
		check(not uid.is_empty(), "purchase yields a free owned instance: "+item_id)
		var started: bool = layout.start_place(item_id,uid)
		check(started, "a new furniture item can enter placement: "+item_id)
		if not started:
			desktop.finish_layout(false)
			game.queue_free()
			await frames()
			quit(1)
			return
		var role: String = layout.placing_role
		check(layout.nodes.has(role) and layout.nodes[role].has_node("Model"), "newly bought item spawns its distinct mesh")
		var found := false
		for candidate: Vector2 in positions:
			layout.preview_placement(candidate)
			if layout.valid:
				found = true
				break
		check(found, "there is a collision-free location for "+role)
		if not found:
			desktop.finish_layout(false)
			game.queue_free()
			await frames()
			quit(1)
			return
		check(layout.confirm_placement(), "new furniture is confirmed into the room: "+role)
		finished.append(role)
	var first_role: String = finished[0]
	var last_role: String = finished[3]
	check(first_role != last_role and Data.base_role(first_role) == "side_table_oak" and Data.base_role(last_role) == "side_table_oak", "same SKU creates multiple unique instance roles")
	check(Data.is_instance_role(last_role) and Data.is_copy("side_table_oak_1"), "new UID roles and old numbered saves both remain recognized")
	check(layout.valid and layout._layout_blocker().is_empty(), "all new furniture respects existing room collision checks")
	layout.select(last_role)
	layout.set_furniture_color(2)
	check(layout.color_for(last_role) == 2, "new instances support independent recoloring")
	var stored_uid: String = layout.placed_instances[last_role]
	check(not stored_uid.is_empty() and stored_uid != layout.placed_instances[first_role], "each new SKU instance has its own persistent UID")
	check(desktop.furniture_buttons["room_side_table_oak"].disabled == false, "when all stock is placed, the catalog entry still selects the existing furniture")
	desktop._start_inventory_placement("room_side_table_oak")
	check(layout.selected in [first_role,last_role], "catalog selects a placed instance when there is no unused stock")

	state.save_path = "user://memoir_furniture_expansion_p14_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var stored = State.new()
	stored.save_path = state.save_path
	stored.load_state()
	check(stored.life.placements.get(last_role,"") == stored_uid, "UID-based multiword role survives JSON round trip")
	check(stored.life.workstation_layout.has(last_role), "UID-based instance transform persists after JSON round trip")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = stored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var restored = resumed.desktop.world.layout
	for role: String in finished:
		check(restored.nodes.has(role) and restored.placed_instances.has(role), "new game session reconstructs furniture and owned instance: "+role)
	check(restored.valid and restored._layout_blocker().is_empty(), "restored room remains safe and collision-free")
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.save_path))
	print("FURNITURE_EXPANSION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
