extends SceneTree
## Invalid historical placements must not strand owned furniture UIDs.
const Inventory = preload("res://scripts/items/inventory_data.gd")
const LayoutData = preload("res://scripts/life/workstation_layout_data.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	for i in range(5):
		await process_frame
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var layout = game.desktop.world.layout
	var uid := "item_999"
	var copy_role := LayoutData.instance_role("chair", uid)
	_check(not copy_role.is_empty(), "test purchased instance role exists")
	layout.available_inventory.append({"uid": uid, "item_id": "room_chair"})
	layout.placed_instances[copy_role] = uid
	var incoming: Dictionary = layout.export_layout()
	# A duplicate chair occupying exactly the starter chair's position
	# must cause the invalid-layout rollback.
	incoming[copy_role] = incoming["chair"].duplicate(true)
	layout.load_saved(incoming)
	_check(not layout.nodes.has(copy_role), "invalid purchased copy removed from scene")
	_check(not layout.placed_instances.has(copy_role), "orphan placement record removed")
	_check(not layout.committed_placements.has(copy_role), "committed placement map agrees with scene")
	_check(not layout.export_layout().has(copy_role), "recovered save excludes deleted copy pose")
	_check(Inventory.unused_uid(layout.available_inventory, layout.placed_instances, "room_chair") == uid, "owned chair returned to free inventory")
	_check(layout.surface_mounts.is_empty() and layout.wall_mounts.is_empty(), "invalid attachments removed")
	_check(layout.saved == layout.export_layout(), "recovery does not cache invalid incoming poses")
	game.queue_free()
	for i in range(3):
		await process_frame
	print("ROOM_SAVE_RECOVERY_CHECKS: %s" % ("PASS" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
