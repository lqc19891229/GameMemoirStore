extends SceneTree
const Data = preload("res://scripts/life/workstation_layout_data.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame
	await physics_frame
	await process_frame
func dispatch(event: InputEvent) -> void:
	root.window_input.emit(event.xformed_by(root.get_final_transform()))
	root.push_input(event,true)
func clear(layout: Node) -> bool:
	var roles: Array = layout.world.devices.keys()
	for i in range(roles.size()):
		for p: Vector2 in layout.footprint(roles[i]):
			if absf(p.x)>layout.tabletop_half_size.x or absf(p.y)>layout.tabletop_half_size.y: return false
		for j in range(i+1,roles.size()):
			if Data.overlap(layout.footprint(roles[i]),layout.footprint(roles[j])): return false
	return true
func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	var desktop = game.desktop
	var world = desktop.world
	var layout = world.layout
	var original: Dictionary = layout.snapshot()
	# Bounds must enclose actual visible geometry, including case buttons and CRT glass.
	for role: String in world.devices:
		var device: Node3D = world.devices[role]
		for id in (["starter_monitor","lcd_monitor"] if role=="monitor" else ["starter_pc","workstation"] if role=="computer" else ["starter_mouse","precise_mouse"]):
			var spec = desktop.hardware_catalog.visual_for(role,id)
			var model: Node3D = spec.model.instantiate()
			root.add_child(model)
			var enclosed := true
			for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				var box: AABB = mesh.global_transform * mesh.get_aabb()
				for point: Vector3 in [box.position,box.end]:
					enclosed = enclosed and absf(point.x)<=spec.bounds.x/2+.001 and absf(point.z)<=spec.bounds.z/2+.001
			check(enclosed,"collision bounds enclose visible model: "+role+"/"+id)
			model.free()
	desktop.begin_layout()
	layout.select("mouse")
	await frames()
	# A single real mouse event crosses the entire keyboard, with a free endpoint.
	var pad: Node3D = layout.gizmo.get_node("MoveHandles/MovePlane")
	var start: Vector2 = world.camera.unproject_position(pad.global_position)
	var goal: Vector2 = world.camera.unproject_position(pad.global_position + layout.group.global_basis * Vector3(-2.05,0,0))
	var button := InputEventMouseButton.new()
	button.position = start
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	dispatch(button)
	var motion := InputEventMouseMotion.new()
	motion.position = goal
	motion.relative = goal-start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	dispatch(motion)
	button.position = goal
	button.pressed = false
	dispatch(button)
	await frames()
	check(world.devices.mouse.position.x>0.1 and world.devices.mouse.position.x<0.2,"fast pointer drag stops at keyboard edge instead of tunneling")
	check(clear(layout) and layout.valid,"drag contact leaves a valid non-overlapping layout")
	check(layout.message.contains("键盘"),"contact feedback names keyboard")
	for snapped in [true,false]:
		layout.restore(original)
		layout.snapping = snapped
		layout.select("mouse")
		layout.move_to(Vector2(-1.6,.74))
		check(world.devices.mouse.position.x>0.1 and world.devices.mouse.position.x<0.2,"sweep blocks free endpoint across obstacle; snap="+str(snapped))
		for i in range(10): layout.move_to(Vector2(-1.6,.74))
		check(clear(layout) and world.devices.mouse.position.x>0.1,"repeated blocked requests never creep through; snap="+str(snapped))
		layout.move_to(Vector2(.45,.74))
		check(world.devices.mouse.position.distance_to(original.mouse.origin)<.015,"contact can be moved away without sticking")
	# Nearly half a turn has a free endpoint, but its middle hits the mouse.
	for yaw in [deg_to_rad(170),deg_to_rad(-170)]:
		layout.restore(original)
		world.devices.monitor.position = Vector3(-1.5,.78,-.65)
		world.devices.computer.position = Vector3(1.5,.78,-.5)
		world.devices.keyboard.position = Vector3(0,.78,.3)
		world.devices.mouse.position = Vector3(0,.78,-.2)
		layout.update()
		check(clear(layout) and layout.valid,"rotation regression starts with separate equipment")
		layout.select("keyboard")
		layout.rotate_to(yaw)
		check(absf(world.devices.keyboard.rotation.y)<PI/2,"half-turn is stopped at intermediate collision")
		check(absf(world.devices.keyboard.rotation.y)>.01 and clear(layout),"rotation advances to a free contact pose")
		check(layout.message.contains("鼠标"),"rotation identifies the blocking mouse")
	# Transforms are relative to the table; a moved/rotated table cannot disable collision.
	layout.restore(original)
	layout.select("desk")
	layout.move_to(Vector2(.4,.3))
	layout.rotate_to(deg_to_rad(35))
	layout.select("mouse")
	layout.move_to(Vector2(-1.6,.74))
	check(clear(layout) and world.devices.mouse.position.x>0.1,"collision remains correct on a transformed table")
	layout.restore(original)
	layout.select("mouse")
	layout.move_to(Vector2(100,100))
	layout.rotate_to(PI/2)
	check(clear(layout) and layout.valid,"table edge constraint and rotation remain non-overlapping")
	desktop.finish_layout(false)
	# Recover old externally authored overlapping saves, while retaining the table pose.
	layout.load_saved({"desk":{"x":-.4,"z":-.8,"yaw":.1},"mouse":{"x":-.6,"z":.67,"yaw":0}})
	check(clear(layout),"overlapping loaded equipment recovers to default arrangement")
	check(is_equal_approx(layout.nodes.desk.position.x,-.4),"save recovery preserves table placement")
	check(world.devices.mouse.transform.is_equal_approx(original.mouse),"save recovery restores equipment rather than retaining penetration")
	layout.load_saved({})
	check(clear(layout),"empty legacy save remains usable")
	game.queue_free()
	await frames()
	print("WORKSTATION_COLLISION_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
