extends SceneTree
## P42: room visual-quality geometry, deterministic textures and blueprint-safe rebuild.
## Rendering evidence is also captured by the existing modern-room CI preview.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var room: MemoirRoomView = world.get_node("Room")
	var layout = world.layout
	var original_layout: Dictionary = layout.snapshot()
	var original_placements: Dictionary = layout.placed_instances.duplicate()
	var original_style: Dictionary = room.style.duplicate()
	var original_blueprint: Dictionary = room.blueprint.duplicate(true)

	var floor: MeshInstance3D = room.get_node("Shell/FloorBoard_00")
	var floor_material := floor.material_override as StandardMaterial3D
	var grain: Texture2D = floor_material.albedo_texture
	check(grain != null, "default room oak planks use an actual material texture instead of plain albedo")
	if grain != null:
		var image: Image = grain.get_image()
		check(image.get_width() >= 128 and image.get_height() >= 128 and image.has_mipmaps(), "default wood grain has enough resolution and mipmaps for normal overview distances")
		var darkest := 1.0
		var lightest := 0.0
		for y in range(0,128,8):
			for x in range(0,128,8):
				var shade := image.get_pixel(x,y).r
				darkest = minf(darkest,shade)
				lightest = maxf(lightest,shade)
		check(lightest-darkest > .04 and darkest > .85, "oak texture is visibly directional but avoids harsh high-contrast painted stripes")
		check(floor_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "room planks use filtered mipmaps rather than pixelated nearest-neighbor shading")

	var left: Node3D = room.get_node("Shell/Left_Wall")
	var curtains: Array[Node] = left.find_children("CurtainPanel*","MeshInstance3D",true,false)
	check(curtains.size() == 2, "window has two real pleated curtain meshes")
	check(left.find_children("CurtainHeader*","MeshInstance3D",true,false).size() == 2 and left.find_children("CurtainHem*","MeshInstance3D",true,false).size() == 2, "curtains have physically separate header and weighted hems")
	check(left.find_children("CurtainHook*","MeshInstance3D",true,false).size() == 8, "curtains hang from visible metal hooks along the rod")
	for sheet: Node in curtains:
		var curtain := sheet as MeshInstance3D
		check(curtain.mesh is ArrayMesh and curtain.mesh.get_surface_count() == 1, "curtain uses triangulated fabric instead of a flat block")
		var arrays: Array = curtain.mesh.surface_get_arrays(0)
		check((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 100 and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() >= 100 and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() >= 100, "pleats have true shaded geometry, generated normals and fabric UVs")
		var aabb: AABB = curtain.mesh.get_aabb()
		check(aabb.size.x > .04 and aabb.size.z >= .44, "fabric has visible three-dimensional folds rather than paper-flat strips")
		check(curtain.position.y-aabb.size.y*.5 >= 1.25 and curtain.position.y+aabb.size.y*.5 <= 2.78, "curtain fits the existing window recess without covering wall openings")
		check(curtain.material_override is StandardMaterial3D and (curtain.material_override as StandardMaterial3D).albedo_texture != null, "fabric has a subtle woven linen material")
		check(curtain.find_children("*","CollisionObject3D",true,false).is_empty(), "decorative fabric never intercepts physics object picking")
	var sill: MeshInstance3D = left.get_node("WindowSillHighlight")
	check(sill != null and left.has_node("WindowSillApron"), "existing P42 window sill retains separate wood highlight and apron")
	var facades: Node3D = left.get_node("ExteriorWindows")
	check(facades.get_child_count() >= 10, "existing P42 warm distant facade windows remain intact")

	var sky: MeshInstance3D = left.get_node("WindowSky")
	var sky_material := sky.material_override as StandardMaterial3D
	check(sky_material.albedo_texture != null and sky_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "window sky uses a gradient unaffected by indoor artificial lighting")
	if sky_material.albedo_texture != null:
		var sky_image: Image = sky_material.albedo_texture.get_image()
		check(sky_image.get_width() == 128 and sky_image.has_mipmaps(), "sky gradient is a filtered reusable texture")
		check(absf(sky_image.get_pixel(2,8).r-sky_image.get_pixel(2,120).r) > .04, "sky has a light horizon gradient rather than a uniform flat rectangle")
	var initial_sky: Color = sky_material.albedo_color
	for atmosphere in [1,2,3,0]:
		room.apply_style({"atmosphere":atmosphere})
		check(sky_material.albedo_texture != null, "gradient stays applied for each weather preset " + str(atmosphere))
		check(room.get_node("Shell/Left_Wall/RainStreaks").visible == (atmosphere == 3), "rain geometry is enabled for rain only: " + str(atmosphere))
		check(facades.visible == (atmosphere != 0), "existing weather-dependent distant illuminated windows still behave correctly: " + str(atmosphere))
	check(sky_material.albedo_color.is_equal_approx(initial_sky) and room.style == original_style, "returning to default atmosphere recovers the original sky tint and saved style fields")

	# Existing floor patterns, wallpaper and customization still work.
	room.apply_style({"floor_pattern":1,"wall_pattern":1})
	check((floor.material_override as StandardMaterial3D).albedo_texture != grain, "selecting oak patterned flooring does not silently retain the default material map")
	var wall: MeshInstance3D = room.get_node("Shell/Back_Wall/WallSurface_DoorRight")
	check((wall.material_override as StandardMaterial3D).albedo_texture != null, "wallpaper texture remains independent from floor material")
	room.apply_style(original_style)
	check((floor.material_override as StandardMaterial3D).albedo_texture == grain, "switching back reuses exactly the same cached default grain texture")

	# Blueprint rebuild must regenerate decor in exactly one copy and preserve
	# the same material appearance, source furniture poses and stock.
	room.apply_blueprint(original_blueprint)
	await frames()
	var rebuilt: Node3D = room.get_node("Shell/Left_Wall")
	check(rebuilt.find_children("CurtainPanel*","MeshInstance3D",true,false).size() == 2, "blueprint shell rebuild restores exactly two fabric panels without duplicates")
	check(rebuilt.get_node("ExteriorWindows").get_child_count() >= 10 and not rebuilt.get_node("ExteriorWindows").visible, "blueprint rebuild preserves main's night-lit facade details and daytime visibility")
	check((room.get_node("Shell/FloorBoard_00").material_override as StandardMaterial3D).albedo_texture == grain, "shell rebuild shares cached floor texture and does not regenerate inconsistent wood")
	check((rebuilt.get_node("WindowSky").material_override as StandardMaterial3D).albedo_texture != null, "shell rebuild retains its filtered sky gradient")

	var camera: Camera3D = world.camera
	var before_camera: Transform3D = camera.transform
	camera.global_position = Vector3(-10,5,7)
	room.update_cutaway(camera)
	check(not rebuilt.visible, "exterior cutaway hides curtains, windows and skylines with their parent wall")
	camera.transform = before_camera
	room.update_cutaway(camera)
	check(rebuilt.visible, "returning to interior viewpoint restores complete window dressing")
	check(layout.snapshot() == original_layout and layout.placed_instances == original_placements, "visual polishing never moves furniture or changes ownership and available stock")
	check(room.style == original_style and room.blueprint == original_blueprint, "visual polishing and rebuild leave existing style and floor-plan save schemas unchanged")
	game.queue_free()
	await frames()
	print("ROOM_ART_DIRECTION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
