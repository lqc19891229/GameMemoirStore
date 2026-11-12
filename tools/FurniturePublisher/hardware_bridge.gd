extends SceneTree
## Restricted bridge: updates one existing MemoirDeviceModel for a replaced GLB.
## The external publisher holds verified backups and handles restoration.
const PREFIX := "HARDWARE_PUBLISH_RESULT="

func _initialize() -> void:
    _run.call_deferred()

func _fail(message: String) -> void:
    print(PREFIX + JSON.stringify({"ok":false, "error":message}))
    quit(1)

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        _fail("Missing hardware manifest")
        return
    var path := str(args[0])
    if not path.begins_with("res://tools/_hardware_publish_") or not path.ends_with(".json"):
        _fail("Invalid manifest path")
        return
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not manifest is Dictionary:
        _fail("Invalid manifest")
        return
    var role := str(manifest.get("role", ""))
    var resource_path := str(manifest.get("resource_path", ""))
    var model_path := str(manifest.get("model_path", ""))
    if not role in ["monitor", "computer", "keyboard", "mouse"]:
        _fail("Invalid hardware role")
        return
    if not resource_path.begins_with("res://data/hardware/") or not model_path.begins_with("res://assets/models/hardware/"):
        _fail("Invalid resource location")
        return
    if resource_path.get_file().get_basename() != model_path.get_file().get_basename():
        _fail("Hardware resource/model mismatch")
        return
    if not ResourceLoader.exists(resource_path) or not ResourceLoader.exists(model_path):
        _fail("Hardware model or resource not imported")
        return
    var appearance := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirDeviceModel
    if appearance == null or appearance.model == null or appearance.model.resource_path != model_path:
        _fail("Existing hardware appearance does not reference the requested model")
        return
    var raw_bounds: Variant = manifest.get("bounds", [])
    var raw_size: Variant = manifest.get("screen_size", [])
    var raw_position: Variant = manifest.get("screen_position", [])
    if not raw_bounds is Array or raw_bounds.size() != 3 or not raw_size is Array or raw_size.size() != 2 or not raw_position is Array or raw_position.size() != 3:
        _fail("Invalid dimensions in hardware manifest")
        return
    var bounds := Vector3(float(raw_bounds[0]), float(raw_bounds[1]), float(raw_bounds[2]))
    var size := Vector2(float(raw_size[0]), float(raw_size[1]))
    var position := Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
    if bounds.x <= 0 or bounds.y <= 0 or bounds.z <= 0:
        _fail("Invalid bounds")
        return
    if role == "monitor" and (size.x <= 0 or size.y <= 0):
        _fail("Monitor display area is required")
        return
    if role != "monitor" and (size != Vector2.ZERO or position != Vector3.ZERO):
        _fail("Only monitors may specify display coordinates")
        return
    appearance.bounds = bounds
    appearance.screen_size = size
    appearance.screen_position = position
    if ResourceSaver.save(appearance, resource_path) != OK:
        _fail("Failed to save hardware resource")
        return
    var check := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirDeviceModel
    if check == null or check.model == null or check.model.resource_path != model_path or not check.bounds.is_equal_approx(bounds) or not check.screen_size.is_equal_approx(size) or not check.screen_position.is_equal_approx(position):
        _fail("Hardware configuration verification failed")
        return
    print(PREFIX + JSON.stringify({"ok":true, "model":model_path, "resource":resource_path}))
    quit(0)
