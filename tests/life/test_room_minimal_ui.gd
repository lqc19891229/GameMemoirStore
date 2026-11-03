extends SceneTree
## Room editor scene-first UI regression: left categories, contextual object actions,
## progressive disclosure and isolation from the independent PC app screen.
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

func frames() -> void:
	for i in range(5):
		await process_frame

func shortcut(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var ui = desktop.room_ui
	var tools = ui.scene_actions
	var layout = desktop.world.layout
	check(ui != null and tools != null, "scene-first room UI and object interaction controller exist")
	check(ui.bar != null and not ui.bar.visible, "editor toolbar is hidden during normal room viewing")
	check(not ui.dock.is_visible_in_tree() and not tools.rail.visible, "catalog and category controls never intercept monitor input outside editing")
	check(desktop.get_node("HUD/Interface").theme == load("res://assets/room_minimal_theme.tres"), "room HUD keeps its standalone modern sans-serif theme")
	check(desktop.get_node("%DesktopScreen").theme != desktop.get_node("HUD/Interface").theme, "computer applications retain independent UI styling")
	desktop.begin_layout()
	check(ui.bar.visible and ui.mode == "furniture", "compact icon toolbar appears on entering editing")
	check(not ui.catalog_open and not ui.dock.visible, "room begins scene-first without a large catalog covering the room")
	check(not desktop.get_node("%LayoutPanel").visible, "precision inspector stays hidden until requested")
	check(tools.rail.visible and tools.category_buttons.size() == 7, "left icon rail exposes all six shared product groups and all-items shortcut")
	check(not tools.action_strip.visible and not tools.swatches.visible, "object context actions are hidden until real furniture is selected")
	check(ui.mode_buttons["furniture"].icon != null and ui.mode_buttons["lighting"].icon != null, "compact room toolbar uses scalable icons")
	check(tools.category_buttons["seating"].icon != null and tools.category_buttons["storage"].icon != null, "each major product category has a recognizable pictogram")
	tools.category_buttons["seating"].pressed.emit()
	check(ui.catalog_open and ui.dock.visible and desktop.get_node("%FurnitureCatalogGroup").selected == 2, "clicking a left category reveals filtered furniture drawer")
	check(desktop.furniture_buttons["room_sofa"].visible and not desktop.furniture_buttons["room_lamp"].visible, "icon categories reuse the established taxonomy and filters")
	check(not desktop.get_node("%FurnitureCatalogGroup").visible, "drawer does not repeat the group selector already represented by the icon rail")
	check(not tools.action_strip.visible, "large inventory drawer and contextual action controls do not overlap")
	ui.catalog_toggle.pressed.emit()
	check(not ui.dock.visible and not ui.catalog_open, "a single click collapses the inventory drawer")
	layout.select("chair")
	check(layout.selected == "chair" and tools.action_strip.visible, "selecting placed 3D furniture replaces the right inspector with a nearby action ribbon")
	check(not desktop.get_node("%LayoutPanel").visible and tools.action_buttons.size() == 5, "normal edit shows only move, rotate, color, copy and store controls")
	check(tools.action_buttons["duplicate"].disabled, "copy is unavailable when no unplaced copy exists in inventory")
	tools.action_buttons["paint"].pressed.emit()
	check(tools.swatches.visible and tools.color_buttons.size() == 9, "a contextual palette reveals the original nine furniture finishes")
	tools.color_buttons[2].pressed.emit()
	check(layout.color_for("chair") == 2 and not tools.swatches.visible, "one-click swatch recolors only the selected instance in editor draft")
	check(not game.session.state.life.furniture_colors.has("starter_chair"), "preview swatch does not write unfinished furniture appearance to game save")
	tools.action_buttons["rotate"].pressed.emit()
	check(layout.tool == "rotate", "object context rotation opens existing working gizmo")
	tools.action_buttons["move"].pressed.emit()
	check(layout.tool == "move", "object context move restores existing gizmo without replacing direct dragging")
	ui.advanced_toggle.pressed.emit()
	check(ui.advanced and desktop.get_node("%LayoutPanel").visible, "precision controls can still be expanded on demand")
	check(desktop.get_node("%LayoutPose").visible and desktop.get_node("%FurnitureAlignmentTools").visible, "advanced mode keeps real transform and alignment controls")
	ui.advanced_toggle.pressed.emit()
	check(not ui.advanced and not desktop.get_node("%LayoutPanel").visible, "returning to direct manipulation hides precision inspector")
	tools.category_buttons["tables"].pressed.emit()
	check(ui.dock.visible and desktop.get_node("%FurnitureCatalogGroup").selected == 1, "category browsing does not change selected room furniture")
	check(not tools.action_strip.visible, "opening the category drawer clears screen-space contextual actions")
	ui.choose_mode("decor")
	check(not desktop.blueprint_mode and not ui.dock.visible and not tools.rail.visible, "decor mode hides furniture-only category rail")
	check(desktop.get_node("%LayoutPanel").visible and desktop.get_node("%Style_wall").visible, "wall finish editor remains accessible through a dedicated decor mode")
	check(not desktop.get_node("%CopyFurniture").is_visible_in_tree(), "decor mode does not expose furniture duplication")
	ui.choose_mode("lighting")
	check(desktop.get_node("%Style_rgb").visible and desktop.get_node("%Style_atmosphere").visible, "lighting editor retains light and atmospheric controls")
	check(not desktop.get_node("%Style_wall").visible, "lighting mode hides unrelated wall finishes")
	ui.choose_mode("build")
	check(desktop.blueprint_mode and desktop.get_node("%BlueprintPanel").visible, "build mode opens existing blueprint tools")
	check(ui.blueprint_content.get_node("BlueprintQuickTools").visible and not desktop.get_node("%BlueprintSchemeSave").visible, "build mode opens with only its main tools")
	ui.advanced_toggle.pressed.emit()
	check(desktop.get_node("%BlueprintSchemeSave").visible, "precision mode restores advanced blueprint schemes")
	ui.advanced_toggle.pressed.emit()
	check(not desktop.get_node("%BlueprintSchemeSave").visible, "advanced blueprint settings collapse safely")
	ui.choose_mode("furniture")
	check(not desktop.blueprint_mode and ui.dock.visible and tools.rail.visible, "returning to furniture reopens category drawer without changing 3D data")
	check(desktop.get_node("%UndoLayout").get_parent() == ui.bar.get_node("History"), "undo and redo stay reachable from the icon toolbar")
	ui._apply_layout_size(Vector2(850,660))
	check(desktop.get_node("%FurnitureCatalogItems").columns == 1 and ui.dock.offset_right == 321.0, "compact view uses narrow scrollable left panel without covering the entire viewport")
	check(ui.bar.position.x == 12.0 and tools.rail.position.x == 15.0, "icons and category rail remain at the left edge on narrower screens")
	ui._apply_layout_size(Vector2(1280,800))
	check(desktop.get_node("%FurnitureCatalogItems").columns == 2 and ui.dock.offset_left == 73.0, "desktop layout uses a two-column left drawer and large unobstructed 3D canvas")
	check(desktop.get_node("%FurnitureCatalogItems").get_parent() is ScrollContainer, "catalog remains scrollable inside left drawer")
	check(desktop.furniture_cards.cards.size() == 27, "all 27 existing purchasable furniture SKUs remain available")
	check(desktop.furniture_cards.renderer.get_child_count() == 1, "all catalog cards continue using the same 3D thumbnail cache")
	var sample_card: Dictionary = desktop.furniture_cards.cards["room_sofa"]
	check(sample_card.button.get_node("VisualCard/FurniturePreview") == sample_card.image, "item card still shows its true GLB model")
	check(sample_card.button.custom_minimum_size.x == 132.0, "narrow icon drawer uses compact inventory cards")
	check(desktop.get_node("%Place_chair") != null, "legacy Godot node IDs remain available for saved scenes")

	# Keyboard rules follow the same direct-edit grammar as the compact icons.
	desktop._input(shortcut(KEY_B))
	check(not ui.dock.visible and not ui.catalog_open, "B toggles closed the left drawer")
	desktop._input(shortcut(KEY_B))
	check(ui.catalog_open, "B toggles open the existing filtered drawer")
	desktop._input(shortcut(KEY_ESCAPE))
	check(layout.active and not ui.catalog_open, "Escape first dismisses the open catalog, not the entire room edit")
	desktop._input(shortcut(KEY_TAB))
	check(desktop.blueprint_mode and ui.mode == "build", "Tab toggles directly to blueprint mode")
	desktop._input(shortcut(KEY_TAB))
	check(not desktop.blueprint_mode and ui.mode == "furniture", "second Tab returns to furniture editing")
	desktop.finish_layout(false)
	check(not ui.bar.visible and not ui.dock.visible and not tools.rail.visible and not tools.action_strip.visible, "leaving editing restores an unobstructed room view")
	check(game.session.state.life.workstation_layout == Life.defaults().workstation_layout, "UI-only actions never change saved workstation poses")
	check(not game.session.state.life.furniture_colors.has("starter_chair"), "canceling editing discards the contextual color change")
	game.queue_free()
	await process_frame
	print("ROOM_MINIMAL_UI_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
