extends SceneTree
## P23: renderer-compatible filmic environment, per-weather sky reflection,
## soft sunlight, and camera focus without changing room layout/save data.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 5) -> void:
	for i in range(count):
		await process_frame

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var world = desktop.world
	var room: MemoirRoomView = world.get_node("Room")
	var env: Environment = (world.get_node("Environment") as WorldEnvironment).environment
	var sun: DirectionalLight3D = world.get_node("KeyLight")
	var fill: DirectionalLight3D = world.get_node("FillLight")
	var camera: Camera3D = world.camera
	var original_camera: Transform3D = camera.transform
	var original_layout: Dictionary = world.layout.snapshot()
	var original_style: Dictionary = room.style.duplicate()
	check(env.background_mode == Environment.BG_COLOR, "stylized visible studio backdrop is preserved")
	check(env.sky != null and env.sky.sky_material is ProceduralSkyMaterial, "procedural sky provides a genuine environment reflection source")
	check(env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "room materials sample sky radiance without Forward+-only SSR")
	check(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "soft filmic highlight rolloff replaces hard linear clipping")
	check(env.ssao_enabled and env.ssao_intensity <= 1.5 and env.ssao_radius <= 0.75, "local furniture contact ambient occlusion is gently tuned")
	check(not env.ssr_enabled and not env.ssil_enabled, "compatibility rendering avoids Forward+-only SSR and SSIL")
	check(sun.shadow_enabled and sun.directional_shadow_blend_splits, "primary sun uses smooth cascade transitions")
	check(sun.shadow_blur > 1.0 and sun.shadow_opacity < 0.8, "primary sunlight has soft low-contrast shadows")
	check(not fill.shadow_enabled and fill.light_energy > 0.0, "secondary indirect fill does not create an expensive hard shadow")
	check(is_equal_approx(sun.light_energy,0.75) and is_equal_approx(camera.fov,38.0), "default daylight and authored camera framing are backward compatible")
	var bounce: OmniLight3D = room.get_node("Shell/WindowBounce")
	var cove: OmniLight3D = room.get_node("Shell/WarmCoveFill")
	var facades: Node3D = room.get_node("Shell/Left_Wall/ExteriorWindows")
	check(not bounce.shadow_enabled and not cove.shadow_enabled and bounce.light_energy > .0 and cove.light_energy > .0, "soft complementary architectural bounce lights are compatible with existing renderer")
	check(facades.get_child_count() >= 10 and not facades.visible, "architectural window view has genuine small facade window meshes hidden under daylight")
	check(room.get_node_or_null("Shell/Left_Wall/WindowSillApron") != null and room.get_node_or_null("Shell/Left_Wall/CurtainHem") != null, "handcrafted window trim and fabric hem render as actual room geometry")

	var sky: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
	var day_top: Color = sky.sky_top_color
	var day_horizon: Color = sky.sky_horizon_color
	var day_exposure: float = env.tonemap_exposure
	room.apply_style({"atmosphere":1})
	check(sky.sky_top_color != day_top and sky.sky_horizon_color != day_horizon, "sunset changes both zenith and horizon reflection palette")
	check(sun.rotation_degrees.x > -40.0 and sun.shadow_blur > 2.0, "sunset lowers the sun and softens longer shadows")
	check(sun.light_energy < 0.75 and env.tonemap_exposure <= day_exposure, "sunset preserves highlight detail with controlled exposure")
	check(facades.visible and bounce.light_color.r > bounce.light_color.b and bounce.light_energy > .3, "sunset turns on distant warm windows and increases warm window bounce")
	room.apply_style({"atmosphere":2})
	check(sun.light_energy < 0.3 and sun.shadow_opacity < 0.4, "nighttime replaces harsh sunlight with gentle moonlight")
	check(sky.sky_top_color.b > sky.sky_top_color.r and sky.sky_top_color != day_top, "night reflection has cool blue sky radiance")
	check(env.tonemap_exposure > day_exposure, "night adjusts exposure without changing saved style keys")
	check(bounce.light_energy < .10 and cove.light_energy > .20 and facades.visible, "night dims natural window bounce while preserving interior warm illumination")
	room.apply_style({"atmosphere":3})
	check(sun.shadow_blur >= 2.5 and sun.shadow_opacity < 0.5, "overcast weather produces subdued soft shadows")
	check(room.get_node("Shell/Left_Wall/RainStreaks").visible, "existing rain overlay remains functional")
	check(bounce.light_color.b > bounce.light_color.r and facades.visible, "rain produces cooler window light and exterior city details")
	room.apply_style(original_style)
	check(sky.sky_top_color.is_equal_approx(day_top) and sky.sky_horizon_color.is_equal_approx(day_horizon), "switching back to daylight resets sky reflections")
	check(is_equal_approx(sun.light_energy,0.75) and room.style == original_style, "weather preview never modifies persistent style defaults")
	check(is_equal_approx(bounce.light_energy,.24) and not facades.visible, "returning to daylight resets secondary lighting and hides nighttime facade details")
	var previous_light: OmniLight3D = bounce
	room.apply_blueprint(room.blueprint)
	check(room.get_node("Shell/WindowBounce") != previous_light and room.get_node("Shell/WarmCoveFill") != null, "blueprint rebuild safely reconstructs generated light accents")
	check(not room.get_node("Shell/Left_Wall/ExteriorWindows").visible, "rebuilt architectural window respects current daytime atmosphere")

	check(not world.focus_selected(false), "camera cannot focus furniture outside layout mode")
	desktop.begin_layout()
	var layout = world.layout
	layout.select("bookcase")
	var selected: Node3D = layout.nodes["bookcase"]
	var bounds: Vector3 = layout.bounds_for("bookcase")
	check(world.focus_selected(false), "F focus API accepts an owned, selected furniture item")
	var expected := Vector3(selected.global_position.x,clampf(selected.global_position.y+bounds.y*.52,.5,1.8),selected.global_position.z)
	check(world.orbit_target.is_equal_approx(expected), "camera target is centered on selected furniture mass")
	check(camera.global_transform.basis.z.normalized().dot((camera.global_position-expected).normalized()) > .999, "camera looks directly at selected item")
	check(layout.snapshot() == original_layout, "focus changes camera only, never existing furniture transforms")
	world.reset_overview()
	check(camera.transform.is_equal_approx(original_camera), "reset view restores the exact authored room camera after focus")
	check(world.orbit_target.is_equal_approx(Vector3(0,1.1,0)), "reset view restores center-room orbit target")

	var hotkey := InputEventKey.new()
	hotkey.keycode = KEY_F
	hotkey.pressed = true
	desktop._input(hotkey)
	await create_timer(.37).timeout
	check(world.orbit_target.is_equal_approx(expected) and not world.transitioning, "F key gently frames the selected object and completes camera animation")
	world.reset_overview()
	var search: LineEdit = desktop.get_node("%FurnitureCatalogSearch")
	desktop.room_ui.catalog_open = true
	desktop.room_ui.sync()
	search.grab_focus()
	desktop._input(hotkey)
	check(world.orbit_target.is_equal_approx(Vector3(0,1.1,0)), "typing F in the furniture search does not steal camera focus")
	search.release_focus()
	desktop.finish_layout(false)
	check(layout.snapshot() == original_layout and room.style == original_style, "cancel preserves room layout and lighting state")
	check(not world.focus_selected(false), "camera focus is disabled outside editing to protect monitor interactions")
	game.queue_free()
	await frames()
	print("ROOM_CINEMATIC_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
