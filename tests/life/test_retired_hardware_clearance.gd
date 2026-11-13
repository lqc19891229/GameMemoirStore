extends SceneTree
## Clearing retired visuals must not delete the starter desk or computer APIs.
var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world = load("res://scenes/computer/workstation_3d.tscn").instantiate()
    root.add_child(world)
    await process_frame
    var desk = world.get_node("TableGroup/Desk")
    check(desk.visible and desk.scene_file_path == "res://scenes/room/tables/desk_basic.tscn", "desk_basic stays visible")
    check(world.devices.size() == 4, "all four device API identities remain")
    for role in ["monitor", "computer", "keyboard", "mouse"]:
        var device: Node3D = world.devices[role]
        check(not device.visible, role + " retired visual is hidden")
        check(not device.is_visible_in_tree(), role + " retired visual cannot render")
        check(device.has_node("PickArea"), role + " existing edit/picking interface survives")
    check(world.get_node("%Monitor").has_node("Screen"), "screen UV mapping and computer interaction node survives")
    world.queue_free()
    await process_frame
    print("RETIRED_HARDWARE_CLEARANCE: %s" % ("PASS" if failures == 0 else str(failures) + " failures"))
    quit(1 if failures else 0)
