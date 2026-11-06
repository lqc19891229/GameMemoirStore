extends SceneTree
## Temporary Godot-side bridge executed by the standalone Furniture Publisher.
const Importer = preload("res://addons/furniture_manager/furniture_importer.gd")
const Registrar = preload("res://addons/furniture_manager/furniture_catalog_registrar.gd")
const Surfaces = preload("res://scripts/room/furniture_support_surfaces.gd")

func _initialize() -> void:
    _run.call_deferred()

func fail(message: String) -> void:
    print("FURNITURE_PUBLISH_RESULT=" + JSON.stringify({"ok":false,"error":message}))
    quit(1)

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        fail("Missing publication manifest")
        return
    var manifest_path := str(args[0])
    if not manifest_path.begins_with("res://tools/_furniture_publish_") or not manifest_path.ends_with(".json"):
        fail("Invalid manifest path")
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not data is Dictionary:
        fail("Invalid manifest JSON")
        return
    var fields: Dictionary = data.get("fields", {})
    var model_path := str(data.get("model_path", ""))
    var scene_path := str(data.get("scene_path", ""))
    var expected := Importer.scene_path_for(model_path)
    if expected.is_empty() or scene_path != expected:
        fail("Model and scene paths do not match")
        return
    # Validate before creating any scene to minimize partial imports.
    var catalog := ResourceLoader.load(Registrar.CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirItemCatalog
    if catalog == null:
        fail("Could not read item catalog")
        return
    if catalog.lookup(str(fields.get("item_id", ""))) != null:
        fail("Product ID already registered")
        return
    var result: Dictionary = Importer.create_scene(model_path, scene_path)
    if not result.get("ok", false):
        fail("Scene generation failed: " + str(result.get("error", "")))
        return
    var anchors: Array = data.get("support_surfaces", [])
    if not anchors.is_empty():
        var packed := ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
        if packed == null:
            fail("Generated scene cannot be opened")
            return
        var chair: Node3D = packed.instantiate()
        var typed: Array = []
        var seen: Dictionary = {}
        for raw in anchors:
            if not raw is Dictionary:
                chair.free()
                fail("Invalid support surface")
                return
            var anchor := {
                "id": str(raw.get("id", "")),
                "center": Vector3(float(raw.get("x", 0)), float(raw.get("y", 0)), float(raw.get("z", 0))),
                "size": Vector2(float(raw.get("width", 0)), float(raw.get("depth", 0)))
            }
            var cleaned: Dictionary = Surfaces.clean_anchor(anchor)
            if cleaned.is_empty() or seen.has(str(cleaned.id)):
                chair.free()
                fail("Support surface has invalid or duplicate ID")
                return
            seen[str(cleaned.id)] = true
            typed.append(cleaned)
        chair.call("apply_custom_support_surfaces", true, typed)
        var new_scene := PackedScene.new()
        if new_scene.pack(chair) != OK or ResourceSaver.save(new_scene, scene_path) != OK:
            chair.free()
            fail("Could not save configured support surfaces")
            return
        chair.free()
    var errors := Registrar.validate_registration(scene_path, fields)
    if not errors.is_empty():
        fail("Registration validation failed: " + "；".join(errors))
        return
    var registration: Dictionary = Registrar.register(scene_path, fields, true)
    if not registration.get("ok", false):
        fail("Registration failed: " + str(registration.get("error", "")))
        return
    var registered := ResourceLoader.load(Registrar.CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MemoirItemCatalog
    if registered == null or registered.lookup(str(fields.item_id)) == null:
        fail("Catalog verification failed after registration")
        return
    print("FURNITURE_PUBLISH_RESULT=" + JSON.stringify({"ok":true,"item_id":fields.item_id,"scene":scene_path,"model":model_path,"bounds":result.get("bounds"),"backup":registration.get("backup", "")}))
    quit(0)
