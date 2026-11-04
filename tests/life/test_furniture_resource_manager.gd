extends SceneTree
## Lightweight headless regression for the development-only editor browser.
const Catalog = preload("res://scripts/items/item_catalog.gd")
const FurnitureManagerPanel = preload("res://addons/furniture_manager/furniture_manager_panel.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := FurnitureManagerPanel.new()
	root.add_child(panel)
	await process_frame
	_check(panel.catalog is MemoirItemCatalog, "catalog loads")
	_check(panel.total_furniture >= 30, "existing furniture definitions listed")
	_check(panel.group_filter.item_count == 6, "five furniture groups plus all categories")
	_check(panel.item_tree.get_root() != null, "furniture tree built")
	var id_set := {}
	for item in panel.get_furniture_items():
		_check(item.item_id != "", "furniture has stable item_id")
		_check(not id_set.has(item.item_id), "no duplicate furniture item ID")
		id_set[item.item_id] = true
	panel.search_field.text = "room_wall_sconce"
	panel._populate_list()
	_check(panel.item_tree.get_root().get_child_count() == 1, "search filters by existing item ID")
	panel.search_field.text = ""
	panel.group_filter.select(4) # Lighting group in the shared taxonomy.
	panel._populate_list()
	_check(panel.item_tree.get_root().get_child_count() >= 4, "group filter selects existing lighting")
	_check(panel.invalid_furniture == 0, "existing active furniture has no resource validation errors")
	# The viewport must not create one renderer per catalog item.
	_check(panel.preview != null and panel.preview.viewport != null, "single preview viewport available")
	_check(panel.preview.model == null, "preview starts without an instantiated model")
	panel.group_filter.select(0)
	panel._populate_list()
	var first := panel.item_tree.get_root().get_first_child()
	_check(first != null, "furniture list has selectable row")
	if first != null:
		panel.item_tree.set_selected(first, 0)
		panel._on_item_selected()
		_check(panel.selected_item != null, "selection binds a catalog item")
		_check(panel.preview.model != null, "preview instantiates selected furniture")
		_check(panel.preview.measured_size.length() > 0.0, "preview calculates model dimensions")
		var angle: float = panel.preview.orbit_degrees
		panel.preview.rotate_preview(30.0)
		_check(panel.preview.orbit_degrees != angle, "preview camera rotates")
		_check(panel.source_paths is PackedStringArray, "model paths inspected safely")
	# Legacy retired items have no scene; selecting one should clear the viewport.
	panel.preview.show_furniture(null)
	_check(panel.preview.model == null, "clearing preview removes instantiated furniture")
	panel.queue_free()
	await process_frame
	print("FURNITURE_RESOURCE_MANAGER_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
