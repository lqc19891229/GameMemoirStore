extends SceneTree
## P43: six purchasable authored GLB decor assets, real room placement and save.
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Inventory = preload("res://scripts/items/inventory_data.gd")
const Data = preload("res://scripts/life/workstation_layout_data.gd")
const State = preload("res://scripts/store_state.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var all_roles := ["vinyl_crate","collectible_podium","poster_floor_frame","game_display_shelf","lounge_cushion_pair","retro_speaker_tower"]
	check(Catalog.room_furniture().size() == 36 and Catalog.lookup("room_wall_sconce") != null,"P43 decor and new wall sconce remain in 36-item furniture catalog")
	for base: String in all_roles:
		var id: String = "room_"+base
		var item: MemoirItemDefinition = Catalog.lookup(id)
		check(item != null and item.furniture_scene != null and item.placement_surface == "floor" and item.price > 0,"all P43 props have real purchasable floor scene: "+id)
		check(Data.valid_role(base) and Inventory.furniture_item_id(base) == id,"new decor role resolves to a stable inventory item: "+base)
		check(ResourceLoader.exists("res://assets/models/room/catalog/"+base+".glb"),"authored 3D glTF model is imported: "+base)
		var scene: Node3D = item.furniture_scene.instantiate()
		root.add_child(scene)
		await process_frame
		var meshes: Array = scene.get_node("Model").find_children("*","MeshInstance3D",true,false)
		check(meshes.size() >= 7 and scene.get_node("Model").scene_file_path.ends_with("/"+base+".glb"),"multi-part PBR model is actually instanced, not a placeholder: "+base)
		var pbr := false
		for mesh: MeshInstance3D in meshes:
			var material: Material = mesh.get_active_material(0)
			if material is StandardMaterial3D:
				var standard: StandardMaterial3D = material
				if standard.roughness > .1 and standard.roughness < 1.0:
					pbr = true
					break
		check(pbr,"imported GLB decor contains authored roughness-based PBR materials: "+base)
		scene.free()
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	state.wallet = 2500
	var desktop = game.desktop
	var layout = desktop.world.layout
	for base: String in all_roles:
		check(desktop.furniture_buttons.has("room_"+base),"new P43 item has an ordinary scene-first catalog card: "+base)
	for base: String in ["vinyl_crate","collectible_podium","poster_floor_frame"]:
		check(game.session.buy_item("room_"+base).begins_with("已购买"),"new decor item can be bought through regular shop economy: "+base)
	desktop.begin_layout()
	var placed := []
	for base: String in ["vinyl_crate","collectible_podium","poster_floor_frame"]:
		var id: String = "room_"+base
		var uid: String = Inventory.unused_uid(layout.available_inventory,layout.placed_instances,id)
		check(not uid.is_empty(),"owned decor inventory contains one unused unique UID: "+base)
		if uid.is_empty(): continue
		var started: bool = layout.start_place(id,uid)
		check(started,"decor enters existing ghost placement mode: "+base)
		if not started: continue
		var role: String = str(layout.placing_role)
		var position_found := false
		for z_step in range(-6,7):
			for x_step in range(-7,8):
				var candidate := Vector2(float(x_step)*.5,float(z_step)*.5)
				layout.preview_placement(candidate)
				if layout.valid:
					position_found = true
					break
			if position_found: break
		check(position_found,"a collision-free floor landing exists for purchased decor: "+base)
		if not position_found:
			layout.cancel_placement()
			continue
		check(layout.confirm_placement(),"scene-first editor commits the 3D decoration to a real room position: "+base)
		check(layout.nodes.has(role) and layout.placed_instances.get(role,"") == uid,"placed decoration role has correct original owned UID: "+base)
		placed.append(role)
	check(placed.size() == 3 and layout.valid and layout._layout_blocker().is_empty(),"three actual P43 decor pieces coexist with starter furniture without collisions")
	var poses: Dictionary = layout.snapshot()
	state.save_path = "user://memoir_p43_decor_collectibles_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var saved = State.new()
	saved.save_path = state.save_path
	saved.load_state()
	for role: String in placed:
		check(saved.life.placements.has(role) and saved.life.workstation_layout.has(role),"P43 decor placement and stock UID survive actual JSON persistence: "+role)
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var restored = load("res://scenes/main/game_root.tscn").instantiate()
	restored.get_node("GameSession").state = saved
	root.add_child(restored)
	restored.session.timer.stop()
	await frames()
	var next_layout = restored.desktop.world.layout
	for role: String in placed:
		check(next_layout.nodes.has(role) and next_layout.placed_instances.has(role) and next_layout.nodes[role].has_node("Model"),"new session restores each purchasable GLB decoration: "+role)
	check(next_layout.valid and next_layout._layout_blocker().is_empty(),"restored decorated room stays collision-safe")
	restored.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.save_path))
	print("ROOM_DECOR_COLLECTIBLES_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
