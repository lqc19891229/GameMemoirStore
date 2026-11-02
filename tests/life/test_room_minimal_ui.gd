extends SceneTree
## Room presentation regression: mode tab, compact catalog, progressive disclosure
## and PC desktop application theme isolation.
const Life = preload("res://scripts/life/life_data.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	for i in range(5):
		await process_frame
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var ui = desktop.room_ui
	check(ui != null, "room UI controller is present")
	check(ui.bar != null and not ui.bar.visible, "minimal mode bar is hidden in overview")
	check(desktop.get_node("HUD/Interface").theme == load("res://assets/room_minimal_theme.tres"), "room HUD uses dedicated sans-serif theme")
	check(desktop.get_node("%DesktopScreen").theme != desktop.get_node("HUD/Interface").theme, "PC screen retains independent UI styling")
	desktop.begin_layout()
	check(ui.bar.visible, "compact four-mode bar appears when editing")
	check(ui.dock.visible and ui.mode == "furniture", "bottom catalog is visible in furniture mode")
	check(ui.inspector_content.get_node("Tools").visible and ui.inspector_content.get_node("Copies").visible, "only core object actions are shown")
	check(not ui.inspector_content.get_node("FurnitureAlignmentTools").visible, "alignment options are folded into advanced settings")
	check(not desktop.get_node("%LayoutPose").visible, "raw X/Z position is not visible by default")
	var start_window: Vector2i = root.size
	root.size = Vector2i(850, 660)
	await process_frame
	ui._resize_layout()
	check(desktop.get_node("%FurnitureCatalogItems").columns == 2 and ui.dock.offset_right == -14.0, "narrow display stacks catalog below inspector with two card columns")
	check(ui.bar.position.x == 16.0, "compact mode toolbar keeps controls inside narrow window")
	root.size = Vector2i(1280, 800)
	await process_frame
	ui._resize_layout()
	check(desktop.get_node("%FurnitureCatalogItems").columns == 3 and ui.dock.offset_right == -348.0, "desktop layout restores three-column bottom dock and right inspector")
	root.size = start_window
	await process_frame
	ui._resize_layout()
	check(desktop.get_node("%FurnitureCatalogItems").get_parent() is ScrollContainer, "large catalog is scrollable instead of an endless panel")
	check(desktop.get_node("%FurnitureCatalogItems") is GridContainer, "catalog cards render in a three-column grid")
	check(desktop.get_node("%Place_chair") != null, "legacy scene identifiers stay addressable")
	check(desktop.furniture_cards.cards.size() == 27, "all 27 furniture SKUs have compact visual cards")
	check(desktop.furniture_cards.renderer.get_child_count() == 1, "room cards reuse one shared offscreen thumbnail viewport")
	var sample_card: Dictionary = desktop.furniture_cards.cards["room_sofa"]
	check(sample_card.button.get_node("VisualCard/FurniturePreview") == sample_card.image, "3D thumbnail is embedded in the clickable purchase card")
	check(sample_card.button.text.is_empty() and not sample_card.stock.text.is_empty(), "card renders its own title and current inventory badge")
	check(ui.mode_buttons["furniture"].icon != null and ui.mode_buttons["lighting"].icon != null, "room modes use consistent scalable line icons")
	
	var dock_button: Button = ui.catalog_toggle
	dock_button.pressed.emit()
	check(not ui.dock.visible and not ui.catalog_open, "player can hide catalog to enlarge visible room area")
	dock_button.pressed.emit()
	check(ui.dock.visible, "catalog drawer can reopen without losing data")
	ui.choose_mode("decor")
	check(not desktop.blueprint_mode and not ui.dock.visible, "decor mode hides unrelated furniture catalog")
	check(desktop.get_node("%Style_wall").visible and desktop.get_node("%Style_floor_pattern").visible, "decor mode displays wall and floor controls")
	check(not desktop.get_node("%CopyFurniture").is_visible_in_tree(), "decor mode hides object duplication")
	ui.choose_mode("lighting")
	check(desktop.get_node("%Style_rgb").visible and desktop.get_node("%Style_atmosphere").visible, "lighting mode exposes atmosphere and RGB")
	check(not desktop.get_node("%Style_wall").visible, "lighting does not clutter wall color controls")
	ui.choose_mode("build")
	check(desktop.blueprint_mode and desktop.get_node("%BlueprintPanel").visible, "build mode opens existing interactive blueprint system")
	check(ui.blueprint_content.get_node("BlueprintQuickTools").visible and not desktop.get_node("%BlueprintSchemeSave").visible, "build mode starts with only primary blueprint controls")
	ui.advanced_toggle.pressed.emit()
	check(desktop.get_node("%BlueprintSchemeSave").visible, "advanced options restore all building tools")
	ui.advanced_toggle.pressed.emit()
	check(not desktop.get_node("%BlueprintSchemeSave").visible, "advanced settings fold back")
	ui.choose_mode("furniture")
	check(not desktop.blueprint_mode and ui.dock.visible, "returning to furniture closes blueprint without changing model data")
	check(desktop.get_node("%UndoLayout").get_parent() == ui.bar.get_node("History"), "undo/redo are in top toolbar")
	desktop.finish_layout(false)
	check(not ui.bar.visible and not ui.dock.visible, "exit editing restores unobstructed room view")
	check(game.session.state.life.workstation_layout == Life.defaults().workstation_layout, "canceling UI-only changes does not write layout state")
	game.queue_free()
	await process_frame
	print("ROOM_MINIMAL_UI_CHECKS: %d / %d passed" % [checks-failures, checks])
	quit(1 if failures else 0)
