extends SceneTree
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 5) -> void:
	for i in range(count):
		await process_frame
	await physics_frame
	await process_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	game.session.timer.stop()
	await frames()
	var world: Node3D = game.desktop.world
	var room = world.get_node("Room")
	var lighting = world.get_node("Lighting")
	check(lighting.rgb_surface_count >= 4, "RGB controller discovers emissive hardware and desk surfaces")
	check(lighting.fan_rotor_count == 6, "six independent case fan rotors are generated")
	check(world.get_node("%DeskGlow") is OmniLight3D, "desk underglow uses a real light")
	check(world.get_node("%Monitor/Backlight") is OmniLight3D, "monitor backlight is present")
	check(world.get_node("%Keyboard/KeyboardGlow") is OmniLight3D, "keyboard accent light is present")
	check(world.get_node("%Mouse/MouseGlow") is OmniLight3D, "mouse accent light is present")
	check(world.get_node("%Computer/CaseGlow") is OmniLight3D, "case side light is present")

	var computer: Node3D = world.devices["computer"]
	var upgrade: Node3D = computer.get_node("Models/UpgradeModel")
	var first_rotor: Node3D = upgrade.get_node("FrontFanRotor_0")
	var before := first_rotor.transform
	await frames(8)
	check(not first_rotor.transform.is_equal_approx(before), "case fan blades rotate continuously")

	room.apply_style({"rgb":3,"brightness":85,"effect":0})
	check(lighting.current_rgb_color.is_equal_approx(Color("e66ac5")), "selected RGB palette changes the shared color")
	var desk_glow: OmniLight3D = world.get_node("%DeskGlow")
	check(desk_glow.light_color.is_equal_approx(Color("e66ac5")) and desk_glow.light_energy > 0.0, "desk underglow follows RGB color and brightness")
	room.apply_style({"rgb":1,"brightness":0,"effect":0})
	check(is_zero_approx(desk_glow.light_energy), "zero brightness turns actual RGB lights off")
	room.apply_style({"rgb":1,"brightness":70,"effect":2})
	var cycle_color: Color = lighting.current_rgb_color
	await frames(24)
	check(not lighting.current_rgb_color.is_equal_approx(cycle_color), "rainbow effect animates the shared RGB color")
	check(world.get_node("KeyLight").light_energy == 0.75, "default room preset preserves warm key light")

	game.session.state.wallet = 1000
	game.session.buy_item("workstation")
	game.session.equip_item("workstation")
	game.session.buy_item("precise_mouse")
	game.session.equip_item("precise_mouse")
	await frames()
	check(upgrade.visible and world.get_node("%Computer/CaseGlow").visible, "premium case activates internal RGB light")
	check(world.get_node("%Keyboard/Models/UpgradeModel").visible and world.get_node("%Keyboard/KeyboardGlow").visible, "premium keyboard activates backlight")
	check(world.get_node("%Mouse/Models/UpgradeModel").visible and world.get_node("%Mouse/MouseGlow").visible, "premium mouse activates accent light")

	game.queue_free()
	await frames()
	print("WORKSTATION_LIGHTING_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
