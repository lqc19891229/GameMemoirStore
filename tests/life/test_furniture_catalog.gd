extends SceneTree
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Taxonomy = preload("res://scripts/items/item_taxonomy.gd")
const Inventory = preload("res://scripts/items/inventory_data.gd")
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()
func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	check(Taxonomy.GROUPS.size() == 6, "six shared groups cover tables seats storage lighting decor and hardware")
	check(Taxonomy.group_name("seating") == "座椅类", "seating category has a localized display label")
	check(Taxonomy.type_name("sofa") == "沙发", "catalog exposes a distinct sofa subtype")
	for group: String in ["tables","seating","storage","lighting","decor","hardware"]:
		check(Taxonomy.valid_group(group), "recognized catalog group: "+group)
	check(not Taxonomy.valid_group("unknown"), "unrecognized group is rejected")
	for case: Dictionary in [
		{"id":"room_chair","group":"seating","type":"office_chair"},
		{"id":"room_bookcase","group":"storage","type":"bookcase"},
		{"id":"room_lamp","group":"lighting","type":"floor_lamp"},
		{"id":"room_rug","group":"decor","type":"rug"},
		{"id":"room_plant","group":"decor","type":"plant"},
		{"id":"room_sofa","group":"seating","type":"sofa"},
		{"id":"room_stool","group":"seating","type":"stool"}
	]:
		var item: MemoirItemDefinition = Catalog.lookup(case.id)
		check(Taxonomy.group_for(item) == case.group, "item group: "+case.id)
		check(Taxonomy.type_for(item) == case.type, "item subtype: "+case.id)
	check(Catalog.room_furniture().size() == 27, "all 27 active furnishing SKUs are discoverable without a hard-coded list")
	check(Catalog.filtered_items(Catalog.room_furniture(),"seating").size() == 7, "seating filter returns chair, sofa and stool")
	check(Catalog.filtered_items(Catalog.room_furniture(),"lighting","floor_lamp").size() == 3, "subcategory filter selects floor lamps")
	check(Catalog.filtered_items(Catalog.room_furniture(),"seating","sofa","奶油").size() == 1, "localized name search combines with category and type")
	check(Catalog.filtered_items(Catalog.room_furniture(),"seating","sofa","missing").is_empty(), "unmatched search returns empty list")
	check(Taxonomy.group_for(Catalog.lookup("mechanical_keyboard")) == "hardware", "computer peripherals are displayed under hardware without becoming furniture")
	check(Catalog.item_for_placement_role("sofa").item_id == "room_sofa", "stable placement role maps to stock-keeping unit")
	check(Inventory.furniture_item_id("stool") == "room_stool", "inventory ownership mapping derives from catalog")
	check(Inventory.initial_placements().size() == 5, "new catalog metadata does not alter old starter inventory")
	check(LayoutData.valid_role("chair_8") and LayoutData.valid_role("sofa_7"), "existing copies remain valid")
	check(not LayoutData.valid_role("chair_9") and not LayoutData.valid_role("unknown"), "invalid roles remain excluded")
	var scene = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(scene)
	await frames()
	scene.session.timer.stop()
	scene.session.state.persistence_enabled = false
	var desktop = scene.desktop
	var layout = desktop.world.layout
	desktop.begin_layout()
	var group: OptionButton = desktop.get_node("%FurnitureCatalogGroup")
	var kind: OptionButton = desktop.get_node("%FurnitureCatalogType")
	var search: LineEdit = desktop.get_node("%FurnitureCatalogSearch")
	check(group.item_count == 7, "room editor has all six category tabs plus all items")
	check(desktop.furniture_buttons.size() == 27, "furniture catalogue builds one interactive button per saleable SKU")
	check(desktop.catalog_special_buttons.size() == 5, "desk and four equipped hardware objects share room catalogue navigation")
	check(desktop.furniture_buttons["room_sofa"].visible and desktop.furniture_buttons["room_chair"].visible, "all filter shows available furniture kinds")
	check(desktop.get_node("%Place_sofa") != null, "legacy furniture buttons remain for saved scene compatibility")
	group.select(2)
	desktop._update_catalog_types()
	check(desktop.furniture_buttons["room_sofa"].visible, "seating tab includes the sofa")
	check(not desktop.furniture_buttons["room_lamp"].visible, "seating tab excludes lighting")
	var sofa_index: int = desktop.catalog_type_ids.find("sofa")
	check(sofa_index > 0, "sofa type is available after selecting seating group")
	kind.select(sofa_index)
	desktop._filter_furniture_catalog()
	check(desktop.furniture_buttons["room_sofa"].visible and not desktop.furniture_buttons["room_chair"].visible, "second category level isolates sofa")
	search.text = "无法匹配"
	desktop._filter_furniture_catalog()
	check(not desktop.furniture_buttons["room_sofa"].visible, "search hides nonmatching catalogue entries")
	search.text = ""
	group.select(6)
	desktop._update_catalog_types()
	check(desktop.catalog_special_buttons["monitor"].button.visible, "hardware tab exposes monitor selector")
	check(not desktop.furniture_buttons["room_sofa"].visible, "hardware display does not misclassify floor furniture")
	desktop.catalog_special_buttons["monitor"].button.pressed.emit()
	check(layout.selected == "monitor" and layout.surface_for("monitor") == "desk", "room catalogue opens existing desktop hardware rather than floor placement")

	var browser = desktop.open_app("browser")
	check(browser != null and browser.get_node("%ShopCatalogGroup") != null, "shop has the same shared category filter")
	var browser_group: OptionButton = browser.get_node("%ShopCatalogGroup")
	browser_group.select(2)
	browser._update_catalog_types()
	check(browser.purchase_buttons.has("room_sofa") and not browser.purchase_buttons.has("room_lamp"), "shop filters the product list by furniture group")
	browser.get_node("%ShopCatalogSearch").text = "奶油"
	browser.refresh()
	check(browser.purchase_buttons.has("room_sofa") and not browser.purchase_buttons.has("room_stool"), "shop text search preserves the group filter")
	browser.get_node("%ShopCatalogSearch").text = ""
	browser_group.select(6)
	browser._update_catalog_types()
	check(browser.purchase_buttons.has("mechanical_keyboard") and not browser.purchase_buttons.has("room_sofa"), "shop hardware filter uses the same taxonomy")
	browser.set_tab("inventory")
	check(browser.tab == "inventory", "category filters also apply to owned inventory")
	desktop.finish_layout(false)
	scene.queue_free()
	await frames()
	print("FURNITURE_CATALOG_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
