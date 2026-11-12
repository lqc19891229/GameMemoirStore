extends SceneTree
## Isolated regression for primary/secondary type filtering in Furniture Manager.
const Panel = preload("res://addons/furniture_manager/furniture_registration_panel.gd")
const Registrar = preload("res://addons/furniture_manager/furniture_catalog_registrar.gd")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("CATEGORY_LINKAGE: " + message)

func _run() -> void:
    var panel := Panel.new()
    root.add_child(panel)
    await process_frame
    for i in range(panel.group_choice.item_count):
        var group := str(panel.group_choice.get_item_metadata(i))
        panel.group_choice.select(i)
        panel.group_choice.item_selected.emit(i)
        var expected: Array = Taxonomy.types_for_group(group)
        var actual: Array = []
        for j in range(panel.type_choice.item_count):
            actual.append(str(panel.type_choice.get_item_metadata(j)))
        _check(actual == expected, "secondary types for " + group)
        _check(panel.type_choice.selected == 0, "valid default secondary type for " + group)
    var table_index := -1
    var seating_index := -1
    for i in range(panel.group_choice.item_count):
        var group := str(panel.group_choice.get_item_metadata(i))
        if group == "tables": table_index = i
        if group == "seating": seating_index = i
    _check(table_index >= 0 and seating_index >= 0, "required primary choices exist")
    if table_index >= 0 and seating_index >= 0:
        panel.group_choice.select(table_index)
        panel.group_choice.item_selected.emit(table_index)
        panel.type_choice.select(0)
        panel.group_choice.select(seating_index)
        panel.group_choice.item_selected.emit(seating_index)
        _check(str(panel.type_choice.get_item_metadata(panel.type_choice.selected)) == "office_chair", "selected subtype resets after primary switch")
    var mismatch := {"item_id":"cross_test", "name":"test", "role":"cross_test", "group":"tables", "type":"sofa", "price":2}
    _check("二级分类不属于选定的一级分类" in Registrar.validate_registration("res://scenes/room/tables/nonexistent.tscn", mismatch), "registrar rejects cross-category subtype")
    panel.queue_free()
    await process_frame
    print("FURNITURE_CATEGORY_LINKAGE: %s" % ("PASS" if failures == 0 else str(failures) + " failures"))
    quit(1 if failures else 0)
