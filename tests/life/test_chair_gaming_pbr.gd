extends SceneTree
## Verifies the baked GLB PBR MATERIALS as imported by Godot, not just JSON metadata.
const CHAIR := preload("res://scenes/room/seating/chair_gaming.tscn")
const TEXTURED := ["gunmetal", "wheel_hub", "steel", "grey_inset", "leather_pearl", "leather_cream", "stitch", "edge_welt", "leather_shadow"]
const EXPECTED := ["graphite", "gunmetal", "rubber", "wheel_hub", "steel", "dark_shell", "grey_inset", "leather_pearl", "leather_cream", "stitch", "edge_welt", "leather_shadow"]
var checks := 0
var failures := 0

func _initialize() -> void:
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("CHAIR_PBR: " + message)

func run() -> void:
    var chair := CHAIR.instantiate() as Node3D
    root.add_child(chair)
    await process_frame
    var model := chair.get_node_or_null("Model")
    check(model != null, "imported model is present")
    if model == null:
        quit(1)
        return
    var meshes := model.find_children("*", "MeshInstance3D", true, false)
    check(meshes.size() == EXPECTED.size(), "all 12 mesh groups imported")
    var found := {}
    for node in meshes:
        var mesh_instance := node as MeshInstance3D
        var part := str(mesh_instance.name)
        found[part] = true
        if mesh_instance.mesh == null:
            check(false, "mesh missing: " + part)
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_surface_override_material(surface)
            if material == null:
                material = mesh_instance.mesh.surface_get_material(surface)
            check(material is BaseMaterial3D, "PBR material imported: " + part)
            if not material is BaseMaterial3D:
                continue
            var pbr := material as BaseMaterial3D
            check(pbr.roughness >= 0.0 and pbr.roughness <= 1.0, "valid roughness: " + part)
            if part in TEXTURED:
                check(pbr.albedo_texture != null, "embedded base color texture: " + part)
                check(pbr.normal_texture != null, "embedded normal texture: " + part)
                check(pbr.metallic_texture != null, "embedded metal-rough texture: " + part)
    for name in EXPECTED:
        check(found.has(name), "original mesh group retained: " + name)
    var pick := chair.get_node_or_null("PickArea/Hit") as CollisionShape3D
    check(pick != null and pick.shape is BoxShape3D, "picking hit box intact")
    if pick != null and pick.shape is BoxShape3D:
        check((pick.shape as BoxShape3D).size.is_equal_approx(chair.get("bounds")), "picking dimensions equal configured bounds")
    chair.queue_free()
    await process_frame
    print("CHAIR_GAMING_PBR_CHECKS: %d / %d passed" % [checks - failures, checks])
    quit(1 if failures > 0 else 0)
