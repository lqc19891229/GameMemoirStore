extends SceneTree
const Catalog = preload("res://data/items/_catalog.tres")
const Inventory = preload("res://scripts/items/inventory_data.gd")
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
const RoomView = preload("res://scripts/room/room_view.gd")
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
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	var state = game.session.state
	state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var layout = world.layout
	var room: MemoirRoomView = world.get_node("Room")
	check(not layout.nodes.has("sofa") and not layout.nodes.has("stool"), "new furniture is not given to players for free")
	check(Inventory.initial_placements().size() == 5, "legacy starter furnishing count stays unchanged")
	check(Inventory.ROOM_DEFAULTS.has("sofa") and Inventory.ROOM_DEFAULTS.has("stool"), "new furniture categories join inventory")
	check(Catalog.lookup("room_sofa").furniture_scene != null and Catalog.lookup("room_stool").furniture_scene != null, "shop entries reference actual purchasable 3D scenes")
	check(Catalog.lookup("room_sofa").price > 0 and Catalog.lookup("room_stool").price > 0, "new furniture is purchased through the normal economy")
	check(desktop.get_node("%Place_sofa") != null and desktop.get_node("%Place_stool") != null, "placement buttons are authored in the room editor")
	check(desktop.get_node("%Style_wall_pattern") != null and desktop.get_node("%Style_floor_pattern") != null and desktop.get_node("%Style_atmosphere") != null, "texture and weather selectors are scene authored")

	var clean: Dictionary = RoomView.clean_style({"wall_pattern":99,"floor_pattern":-4,"atmosphere":42})
	check(int(clean.wall_pattern) == 2 and int(clean.floor_pattern) == 0 and int(clean.atmosphere) == 3, "material and ambience style settings are range checked")
	check(RoomView.clean_style({}).atmosphere == 0, "old saves default to normal daylight")
	var wall_mesh: MeshInstance3D = room.get_node("Shell/Back_Wall/WallSurface_DoorRight")
	var floor_mesh: MeshInstance3D = room.get_node("Shell/Floor")
	var day_key: DirectionalLight3D = world.get_node("KeyLight")
	var default_energy: float = day_key.light_energy
	check(is_equal_approx(default_energy,.75), "legacy daylight remains the normal default key exposure")
	room.apply_style({"wall_pattern":1,"floor_pattern":1,"atmosphere":1})
	check((wall_mesh.material_override as StandardMaterial3D).albedo_texture != null, "woven wall pattern is assigned to real wall surfaces")
	check((floor_mesh.material_override as StandardMaterial3D).albedo_texture != null, "oak texture is assigned to room floor")
	check((floor_mesh.material_override as StandardMaterial3D).roughness > .5, "floor texture retains realistic non-mirror reflectivity")
	check(day_key.light_energy < default_energy, "sunset changes the room-wide key light energy")
	var sunset: Color = (room.get_node("Shell/Left_Wall/WindowSky").material_override as StandardMaterial3D).albedo_color
	room.apply_style({"wall_pattern":2,"floor_pattern":2,"atmosphere":2})
	check(int(room.style.wall_pattern) == 2 and int(room.style.floor_pattern) == 2, "brick and stone are independent, persistent texture choices")
	check((wall_mesh.material_override as StandardMaterial3D).albedo_texture != null and (floor_mesh.material_override as StandardMaterial3D).albedo_texture != null, "changing textures does not erase the other room surface material")
	check(day_key.light_energy < .3, "night atmosphere makes directional sun lighting dim")
	check(not sunset.is_equal_approx((room.get_node("Shell/Left_Wall/WindowSky").material_override as StandardMaterial3D).albedo_color), "window exterior changes from sunset to night")
	room.apply_style({"atmosphere":3})
	check(room.get_node("Shell/Left_Wall/RainStreaks").visible, "rain scene enables external rain overlay")
	check(room.get_node("Shell/Left_Wall/RainStreaks").get_child_count() >= 10, "rain streaks are real geometry instead of an interface placeholder")
	room.apply_style({"atmosphere":0})
	check(not room.get_node("Shell/Left_Wall/RainStreaks").visible, "daylight switches off rain rendering")
	check(is_equal_approx(day_key.light_energy,.75), "default light energy restores after weather changes")

	state.wallet = 800
	check(game.session.buy_item("room_sofa").begins_with("已购买"), "sofa can be purchased through gameplay")
	check(game.session.buy_item("room_stool").begins_with("已购买"), "stool can be purchased through gameplay")
	desktop.begin_layout()
	check(layout.templates.has("sofa") and layout.templates.has("stool"), "layout controller discovers purchased furniture scenes")
	var placed_roles: Dictionary = {}
	for entry: Dictionary in [
		{"role":"sofa","item":"room_sofa","pos":Vector2(-2.6,2.1),"mesh":"SeatCushion_0"},
		{"role":"stool","item":"room_stool","pos":Vector2(2.1,2.3),"mesh":"AccentTray"}
	]:
		var uid: String = Inventory.unused_uid(layout.available_inventory,layout.placed_instances,entry.item)
		check(not uid.is_empty(), "purchased furniture creates an unused stock instance: "+entry.item)
		check(layout.start_place(entry.item,uid), "new furniture can enter the ghost placement mode: "+entry.role)
		var instance_role: String = LayoutData.instance_role(str(entry.role),uid)
		placed_roles[str(entry.role)] = instance_role
		check(layout.nodes.has(instance_role) and layout.nodes[instance_role].has_node("Model/"+entry.mesh), "runtime geometry is instantiated for "+entry.role)
		check(layout.nodes[instance_role].get_node("Model").find_children("*","MeshInstance3D",true,false).size() >= 10, "new asset uses multiple actual textured meshes")
		layout.preview_placement(entry.pos)
		check(layout.valid, "initial proposed position for new furniture is collision-free: "+entry.role)
		check(layout.confirm_placement(), "new furniture can be confirmed into the current layout: "+entry.role)
	check(layout.placed_instances.has(placed_roles["sofa"]) and layout.placed_instances.has(placed_roles["stool"]), "both new assets are tracked as independent movable furniture")
	check(layout.valid, "additional furniture leaves the existing room layout collision-free")
	var history: int = layout.undo_stack.size()
	layout.select(placed_roles["sofa"])
	layout.move_to(Vector2(-2.45,2.1))
	check(layout.undo_stack.size() == history+1, "new furniture supports ordinary movement undo")
	layout.undo()
	check(layout.nodes.has(placed_roles["sofa"]), "undo does not lose the purchased sofa instance")
	layout.redo()
	check(layout.nodes.has(placed_roles["sofa"]), "redo restores new furniture move")

	layout.set_style("wall_pattern",1)
	layout.set_style("floor_pattern",2)
	layout.set_style("atmosphere",3)
	check(room.style.wall_pattern == 1 and room.style.floor_pattern == 2 and room.style.atmosphere == 3, "room editor controls apply material and atmosphere settings")
	state.save_path = "user://memoir_visual_polish_p12_test.json"
	state.persistence_enabled = true
	desktop.finish_layout(true)
	var stored = State.new()
	stored.save_path = state.save_path
	stored.load_state()
	check(stored.life.room_style.atmosphere == 3 and stored.life.room_style.wall_pattern == 1 and stored.life.room_style.floor_pattern == 2, "new texture and weather settings round trip through JSON")
	check(stored.life.placements.has(placed_roles["sofa"]) and stored.life.placements.has(placed_roles["stool"]), "new furniture ownership and placements survive JSON save")
	state.persistence_enabled = false
	game.queue_free()
	await frames()
	var resumed = load("res://scenes/main/game_root.tscn").instantiate()
	resumed.get_node("GameSession").state = stored
	root.add_child(resumed)
	resumed.session.timer.stop()
	await frames()
	var restored_room: MemoirRoomView = resumed.desktop.world.get_node("Room")
	var restored_layout = resumed.desktop.world.layout
	check(restored_layout.nodes.has(placed_roles["sofa"]) and restored_layout.nodes.has(placed_roles["stool"]), "new session reconstructs purchased furniture 3D scenes")
	check(restored_layout.placed_instances.has(placed_roles["sofa"]) and restored_layout.placed_instances.has(placed_roles["stool"]), "new session respects purchased furniture placements")
	check(restored_room.style.atmosphere == 3 and restored_room.style.floor_pattern == 2, "saved rain scene and materials restore in next session")
	check(restored_room.get_node("Shell/Left_Wall/RainStreaks").visible, "weather state restores external rain after reloading")
	check(restored_layout.valid, "restored furniture remains collision-free")
	resumed.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.save_path))
	print("ROOM_VISUAL_POLISH_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
