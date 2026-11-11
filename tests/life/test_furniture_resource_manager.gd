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
	_check(panel.total_furniture == 1, "only newly authored desk_basic remains in the furniture catalog")
	_check(panel.group_filter.item_count == 6, "five furniture groups plus all categories")
	_check(panel.item_tree.get_root() != null, "furniture tree built")
	var id_set := {}
	for item in panel.get_furniture_items():
		_check(item.item_id != "", "furniture has stable item_id")
		_check(not id_set.has(item.item_id), "no duplicate furniture item ID")
		id_set[item.item_id] = true
	for removed_id in ["starter_desk", "starter_cabinet", "oak_desk", "reading_lamp", "display_cabinet"]:
		_check(panel.catalog.lookup(removed_id) == null, "removed legacy furniture SKU absent from authoritative catalog: " + removed_id)
	panel.show_retired.button_pressed = true
	panel._populate_list()
	_check(panel.item_tree.get_root().get_child_count() == 1, "show retired still only lists desk_basic")
	panel.search_field.text = "desk_basic"
	panel._populate_list()
	_check(panel.item_tree.get_root().get_child_count() == 1, "search finds desk_basic")
	panel.search_field.text = ""
	panel.group_filter.select(4) # No active lighting furniture on the reset branch.
	panel._populate_list()
	_check(panel.item_tree.get_root().get_child_count() == 0, "cleared lighting group is empty")
	_check(panel.invalid_furniture == 0, "desk_basic has no resource validation errors")
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
		_check(panel.preview.authored_bounds.length() > 0.0, "read authored furniture bounds")
		_check(panel.bounds_toggle.button_pressed and panel.surfaces_toggle.button_pressed, "guides start enabled")
		_check(panel.preview.overlay != null, "bounds guide is visible")
		panel.bounds_toggle.button_pressed = false
		panel.surfaces_toggle.button_pressed = false
		panel._on_overlay_toggled(false)
		_check(panel.preview.overlay == null, "both overlays can be hidden")
		panel.bounds_toggle.button_pressed = true
		panel._on_overlay_toggled(false)
		_check(panel.preview.overlay != null, "bounds overlay can be shown independently")
		_check(panel.selected_item.item_id == "desk_basic", "desk_basic is the only selectable furniture")
		_check(panel.preview.support_anchors.size() >= 1, "desk_basic support surfaces are read from furniture metadata")
		panel.bounds_toggle.button_pressed = false
		panel.surfaces_toggle.button_pressed = true
		panel._on_overlay_toggled(false)
		_check(panel.preview.overlay != null, "desk support surface can be shown independently")

	# Clearing the viewer must not retain the last selected model.
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
