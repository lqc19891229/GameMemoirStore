extends SceneTree
## Screenshot the REAL imported candidate GLB in an isolated Godot 3D scene.
## Used only by the opt-in GLB bake CI workflow, not at game runtime.
const CHAIR := preload("res://scenes/room/seating/chair_gaming.tscn")
const OUTPUT := "build/chair"
const SIZE := Vector2i(1280, 800)

func _initialize() -> void:
    render_previews.call_deferred()

func render_previews() -> void:
    root.size = SIZE
    var stage := Node3D.new()
    stage.name = "ChairPreviewStage"
    root.add_child(stage)
    var chair: Node3D = CHAIR.instantiate()
    stage.add_child(chair)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.13, 0.16, 0.20)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.74, 0.78)
    env.ambient_light_energy = 0.38
    environment.environment = env
    stage.add_child(environment)
    var camera := Camera3D.new()
    camera.current = true
    camera.fov = 38.0
    stage.add_child(camera)
    var key := DirectionalLight3D.new()
    key.light_energy = 0.92
    key.light_color = Color(1.0, 0.96, 0.91)
    key.rotation_degrees = Vector3(-52, -28, 0)
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.light_energy = 0.26
    fill.light_color = Color(0.71, 0.82, 1.0)
    fill.rotation_degrees = Vector3(-18, 140, 0)
    stage.add_child(fill)
    var floor := MeshInstance3D.new()
    var slab := PlaneMesh.new()
    slab.size = Vector2(4.0, 4.0)
    floor.mesh = slab
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.28, 0.31, 0.34)
    mat.roughness = 0.88
    floor.material_override = mat
    stage.add_child(floor)
    var folder := ProjectSettings.globalize_path("res://").path_join(OUTPUT)
    var result := DirAccess.make_dir_recursive_absolute(folder)
    if result != OK:
        push_error("Failed to create chair preview directory: " + error_string(result))
        quit(1)
        return
    for view in [
        {"name": "front", "position": Vector3(2.0, 1.70, 2.30)},
        {"name": "rear", "position": Vector3(-2.05, 1.75, -2.30)},
    ]:
        camera.position = view.position
        camera.look_at(Vector3(0, 0.72, 0))
        for frame in range(24):
            await process_frame
        await RenderingServer.frame_post_draw
        var screenshot := root.get_texture().get_image()
        if screenshot == null or screenshot.is_empty():
            push_error("Godot returned an empty chair preview frame")
            quit(1)
            return
        var filename := folder.path_join("chair_gaming_" + str(view.name) + ".png")
        var err := screenshot.save_png(filename)
        if err != OK:
            push_error("Could not save chair preview: " + error_string(err))
            quit(1)
            return
        print("CHAIR_PREVIEW=" + filename)
    stage.queue_free()
    await process_frame
    quit(0)
