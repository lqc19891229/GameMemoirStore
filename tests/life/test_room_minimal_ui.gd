extends SceneTree
## Room editor scene-first UI regression: left categories, contextual object actions,
## progressive disclosure and isolation from the independent PC app screen.
const Life = preload("res://scripts/life/life_data.gd")
const Inventory = preload("res://scripts/items/inventory_data.gd")
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

func shortcut(code: Key, shift: bool = false, ctrl: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
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
	check(ui.feedback_pose_text != null and ui.feedback_pose_text.mouse_filter == Control.MOUSE_FILTER_IGNORE, "transform readout shares the existing nonblocking floating feedback")
	check(tools.rail.visible and tools.category_buttons.size() == 7, "left icon rail exposes all six shared product groups and all-items shortcut")
	check(not tools.action_strip.visible and not tools.swatches.visible, "object context actions are hidden until real furniture is selected")
	check(not tools.marquee_box.visible and tools.marquee_box.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the scene marquee starts hidden and never intercepts pointer picking")
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
	check(tools.selection_chip.visible and tools.selection_chip.text.contains(layout.name_for("chair")), "selected furniture displays its real name near the action ribbon")
	check(tools.selection_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "selected-item label never intercepts direct 3D mouse picking")
	check(not desktop.get_node("%LayoutPanel").visible and tools.action_buttons.size() == 6, "normal editing includes the compact alignment and same-type arrangement entry")
	check(tools.action_buttons["move"].toggle_mode and tools.action_buttons["rotate"].toggle_mode and tools.action_buttons["paint"].toggle_mode, "movement, rotation and paint controls expose persistent active states")
	check(tools.action_buttons["move"].button_pressed and not tools.action_buttons["rotate"].button_pressed, "move button is highlighted when its gizmo is active")
	check(tools.action_buttons["duplicate"].disabled and tools.action_buttons["duplicate"].tooltip_text.contains("没有可用库存"), "copy is disabled and explains missing same-item stock")
	check(tools.action_buttons["arrange"].icon != null and tools.arrange_buttons.size() == 4, "arrangement uses a vector toolbar icon and four X/Z buttons")
	tools.action_buttons["arrange"].pressed.emit()
	check(tools.arrange_panel.visible and tools.action_buttons["arrange"].button_pressed, "contextual arrangement opens beside selected furniture and highlights its button")
	check(tools.arrange_summary.text.contains("等距需至少 3 件") and tools.arrange_buttons["space_x"].disabled and tools.arrange_buttons["space_z"].disabled, "arrangement explains the three-piece minimum and disables unavailable spacing buttons")
	check(tools.arrange_buttons["align_x"].disabled == layout.nearest_alignment("chair","x").is_empty() and tools.arrange_buttons["align_z"].disabled == layout.nearest_alignment("chair","z").is_empty(), "alignment buttons reflect collision-safe nearby guides")
	var pose_before_arrange: Transform3D = layout.nodes["chair"].transform
	var history_before_arrange: int = layout.undo_stack.size()
	tools.arrange_buttons["space_x"].pressed.emit()
	check(layout.nodes["chair"].transform.is_equal_approx(pose_before_arrange) and layout.undo_stack.size() == history_before_arrange, "unavailable distribution cannot move furniture or add undo entries")
	tools.action_strip.hide()
	tools.selection_chip.hide()
	tools._process(0.0)
	check(tools.action_strip.visible and tools.selection_chip.visible, "context controls reappear when an already-selected object is visible again")
	tools.action_buttons["paint"].pressed.emit()
	check(not tools.arrange_panel.visible and tools.swatches.visible and tools.color_buttons.size() == 9, "opening the color palette closes arrangement and preserves existing finishes")
	check(tools.action_buttons["paint"].button_pressed, "open finish palette highlights its contextual button")
	tools.color_buttons[2].pressed.emit()
	check(layout.color_for("chair") == 2 and not tools.swatches.visible, "one-click swatch recolors only the selected instance in editor draft")
	check(not tools.action_buttons["paint"].button_pressed, "finish button exits pressed state after applying a color")
	check(not game.session.state.life.furniture_colors.has("starter_chair"), "preview swatch does not write unfinished furniture appearance to game save")
	tools.action_buttons["rotate"].pressed.emit()
	check(layout.tool == "rotate", "object context rotation opens existing working gizmo")
	check(tools.action_buttons["rotate"].button_pressed and not tools.action_buttons["move"].button_pressed, "rotation button becomes the only highlighted transform tool")
	tools.action_buttons["move"].pressed.emit()
	check(layout.tool == "move", "object context move restores existing gizmo without replacing direct dragging")
	check(tools.action_buttons["move"].button_pressed and not tools.action_buttons["rotate"].button_pressed, "returning to movement restores its active highlight")
	tools.action_buttons["arrange"].pressed.emit()
	check(tools.arrange_panel.visible, "arrangement can be reopened after other contextual actions")
	desktop._input(shortcut(KEY_ESCAPE))
	check(layout.active and not tools.arrange_panel.visible, "Escape closes arrangement first rather than leaving the room editor")
	layout.toggle_group_member("plant")
	check(layout.group_selection.size() == 2 and tools.selection_chip.text.contains("已选 2 件"), "multi-selection shows count and primary furniture beside scene")
	check(tools.action_buttons["paint"].disabled and tools.action_buttons["store"].disabled and tools.action_buttons["arrange"].disabled and tools.action_buttons["duplicate"].disabled, "group mode disables single-item paint, store, arrange and duplicate actions")
	check(not tools.action_buttons["move"].disabled and not tools.action_buttons["rotate"].disabled, "group editing leaves move and rotate enabled")
	check(tools.hint.text.contains("Ctrl+框选") and tools.hint.text.contains("拖动整组"), "group hint explains additive marquee selection and group dragging")
	check(tools.group_button.visible and tools.group_button.text.contains("2") and not tools.group_panel.visible, "multi-selection reveals a compact member management button without opening a modal")
	var pose_before_members: Dictionary = layout.snapshot()
	var history_before_members: int = layout.undo_stack.size()
	tools.group_button.pressed.emit()
	check(tools.group_panel.visible and tools.group_button.button_pressed and tools.group_member_buttons.size() == 2, "member manager shows one editable row per selected furniture instance")
	check(tools.group_summary.text.contains("2 件") and tools.group_member_buttons["plant"].primary.disabled, "member panel identifies current primary and displays the group count")
	tools.group_member_buttons["chair"].primary.pressed.emit()
	check(layout.selected == "chair" and layout.group_selection.size() == 2 and tools.group_member_buttons["chair"].primary.disabled, "setting another primary updates member controls without clearing the group")
	check(layout.snapshot() == pose_before_members and layout.undo_stack.size() == history_before_members, "member primary changes do not touch furniture poses or create undo entries")
	tools.group_member_buttons["plant"].remove.pressed.emit()
	check(layout.group_selection.size() == 1 and layout.selected == "chair" and not tools.group_panel.visible and not tools.group_button.visible, "removing a member drops only its selection and closes the manager when one remains")
	check(layout.snapshot() == pose_before_members and layout.undo_stack.size() == history_before_members, "removing from selection never stores furniture, moves it or consumes undo history")
	layout.toggle_group_member("plant")
	tools.group_button.pressed.emit()
	check(tools.group_panel.visible, "member manager can reopen after a fresh multi-selection")
	desktop._input(shortcut(KEY_ESCAPE))
	check(layout.active and not tools.group_panel.visible and layout.group_selection.size() == 2, "Escape closes the members panel before canceling the group")
	ui.show_keyboard_feedback("整组平移测试")
	check(ui.feedback_pose_text.text.contains("整组 2 件"), "floating transform readout labels group pivot behavior")
	desktop._input(shortcut(KEY_ESCAPE))
	check(layout.active and layout.group_selection.size() == 1 and layout.group_markers.is_empty(), "second Escape clears group selection without closing the editor")
	layout.select("chair")
	check(not tools.action_buttons["paint"].disabled and not tools.action_buttons["arrange"].disabled, "returning to a single item restores individual contextual controls")
	ui.advanced_toggle.pressed.emit()
	check(ui.advanced and desktop.get_node("%LayoutPanel").visible, "precision controls can still be expanded on demand")
	check(desktop.get_node("%LayoutPose").visible and ui.inspector_content.get_node("FurnitureAlignmentTools").visible, "advanced mode keeps real transform and alignment controls")
	ui.advanced_toggle.pressed.emit()
	check(not ui.advanced and not desktop.get_node("%LayoutPanel").visible, "returning to direct manipulation hides precision inspector")
	tools.category_buttons["tables"].pressed.emit()
	check(ui.dock.visible and desktop.get_node("%FurnitureCatalogGroup").selected == 1, "category browsing does not change selected room furniture")
	check(not tools.action_strip.visible and not tools.selection_chip.visible and not tools.arrange_panel.visible, "opening the category drawer clears all contextual actions and popup panels")
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

	# Placement previews should own the 3D canvas. Opening other modes must
	# discard the ghost without consuming a furniture UID or changing the save.
	layout.select("chair")
	layout.store_selected()
	var staged_placements: Dictionary = layout.placed_instances.duplicate()
	var free_chair: String = Inventory.unused_uid(layout.available_inventory,layout.placed_instances,"room_chair")
	check(not free_chair.is_empty() and layout.start_place("room_chair",free_chair), "stored owned furniture can be previewed from an open catalog")
	check(not ui.catalog_open and not ui.dock.visible, "starting placement automatically clears the catalog overlay")
	check(not tools.rail.visible and not ui.catalog_toggle.visible and not tools.action_strip.visible, "preview hides category rail, catalog toggle and context actions")
	var original_group: int = desktop.get_node("%FurnitureCatalogGroup").selected
	tools.open_category(2)
	check(desktop.get_node("%FurnitureCatalogGroup").selected == original_group and not ui.catalog_open, "category clicks cannot reopen drawer during a pending placement")
	desktop._input(shortcut(KEY_B))
	check(not ui.catalog_open and not ui.dock.visible, "B does not reopen the drawer over the placement ghost")
	desktop._input(shortcut(KEY_ESCAPE))
	check(layout.active and layout.placing_role.is_empty() and tools.rail.visible, "Escape cancels preview and restores the category rail without leaving the editor")
	check(layout.placed_instances == staged_placements and Inventory.unused_uid(layout.available_inventory,layout.placed_instances,"room_chair") == free_chair, "canceling preview retains the original stock UID and placements")
	check(layout.start_place("room_chair",free_chair), "the same inventory UID remains available for a second preview")
	ui.choose_mode("decor")
	check(layout.placing_role.is_empty() and ui.mode == "decor" and desktop.get_node("%Style_wall").visible, "switching to decoration safely cancels pending placement")
	check(layout.placed_instances == staged_placements and Inventory.unused_uid(layout.available_inventory,layout.placed_instances,"room_chair") == free_chair, "mode switch never consumes the previewed furniture UID")
	ui.choose_mode("furniture")
	check(ui.catalog_open and tools.rail.visible, "returning to furniture restores normal browsing after preview cancellation")

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

	# Scene hotkeys use the same constrained movement, rotation and undo stack
	# as dragging. Keep them independent of the catalog and blueprint inputs.
	ui.catalog_open = false
	ui.sync()
	layout.select("rug")
	layout.move_to(Vector2.ZERO)
	check(layout.selected == "rug" and layout.valid, "floor rug is available for safe X/Z keyboard placement checks")
	var original_rug: Transform3D = layout.nodes["rug"].transform
	var undo_depth: int = layout.undo_stack.size()
	desktop._input(shortcut(KEY_RIGHT))
	var after_grid: Transform3D = layout.nodes["rug"].transform
	check(absf(after_grid.origin.x - original_rug.origin.x - layout.grid_step) < 0.003, "right arrow moves exactly one configured X grid step")
	check(layout.undo_stack.size() == undo_depth + 1 and ui.feedback_state == "keyboard", "keyboard nudge creates one undo record and a temporary in-scene transform readout")
	check(ui.feedback_pose_text.text.contains("X ") and ui.feedback_pose_text.text.contains("Z "), "keyboard feedback displays the actual nudge coordinates")
	check(ui.scene_actions.hint.text.contains("网格开"), "keyboard shortcut hint reflects enabled grid snapping")
	desktop._input(shortcut(KEY_UP,true))
	var after_fine: Transform3D = layout.nodes["rug"].transform
	check(absf(after_fine.origin.z - after_grid.origin.z + 0.01) < 0.003, "Shift+Up moves one centimeter even while the grid is enabled")
	check(layout.snapping and ui.feedback_text.text.contains("1 cm"), "fine nudge temporarily bypasses grid rounding without switching the global snap mode")
	desktop._input(shortcut(KEY_Z,false,true))
	check(layout.nodes["rug"].transform.is_equal_approx(after_grid), "Ctrl+Z reverts a fine nudge without undoing the earlier grid step")
	desktop._input(shortcut(KEY_Q))
	var after_turn: float = layout.nodes["rug"].rotation.y
	check(absf(angle_difference(original_rug.basis.get_euler().y,after_turn) + deg_to_rad(layout.angle_step)) < 0.02, "Q rotates by the configured snapped angle step")
	desktop._input(shortcut(KEY_Q,true))
	var after_fine_turn: float = layout.nodes["rug"].rotation.y
	check(absf(angle_difference(after_turn,after_fine_turn) + deg_to_rad(1.0)) < 0.02, "Shift+Q rotates by one degree without being rounded to 15 degrees")
	check(layout.snapping and ui.feedback_text.text.contains("1°"), "fine rotation retains snapping mode and displays its precision")
	desktop._input(shortcut(KEY_S))
	check(not layout.snapping and ui.feedback_text.text.contains("网格吸附：关闭") and ui.feedback_pose_text.text.contains("自由定位"), "S turns grid snapping off and updates the scene precision readout")
	check(ui.scene_actions.hint.text.contains("网格关"), "shortcut hint displays current grid-off state")
	desktop._input(shortcut(KEY_S))
	check(layout.snapping and ui.scene_actions.hint.text.contains("网格开"), "S restores grid snapping with an updated hint")
	var held_snap := shortcut(KEY_S)
	held_snap.echo = true
	desktop._input(held_snap)
	desktop._input(shortcut(KEY_S,false,true))
	check(layout.snapping, "held S repeats and Ctrl+S do not unexpectedly toggle grid snapping")
	var pose_before_catalog: Transform3D = layout.nodes["rug"].transform
	ui.catalog_open = true
	ui.sync()
	desktop._input(shortcut(KEY_LEFT))
	desktop._input(shortcut(KEY_S))
	check(layout.nodes["rug"].transform.is_equal_approx(pose_before_catalog) and layout.snapping, "open inventory drawer keeps arrow navigation and S from editing room furniture")
	ui.catalog_open = false
	ui.sync()
	desktop._input(shortcut(KEY_TAB))
	var pose_before_blueprint: Transform3D = layout.nodes["rug"].transform
	desktop._input(shortcut(KEY_LEFT))
	desktop._input(shortcut(KEY_S))
	check(desktop.blueprint_mode and layout.snapping and layout.nodes["rug"].transform.is_equal_approx(pose_before_blueprint), "blueprint mode rejects furniture movement and grid-switch hotkeys")
	desktop._input(shortcut(KEY_TAB))
	check(not desktop.blueprint_mode, "after precision-key checks Tab returns to furniture mode")
	desktop.finish_layout(false)
	check(not ui.bar.visible and not ui.dock.visible and not tools.rail.visible and not tools.action_strip.visible and not tools.selection_chip.visible and not tools.arrange_panel.visible, "leaving editing restores an unobstructed room view")
	check(game.session.state.life.workstation_layout == Life.defaults().workstation_layout, "UI-only actions never change saved workstation poses")
	check(not game.session.state.life.furniture_colors.has("starter_chair"), "canceling editing discards the contextual color change")
	game.queue_free()
	await process_frame
	print("ROOM_MINIMAL_UI_CHECKS: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
