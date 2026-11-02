extends SceneTree
## One-time authoring step. Convert original procedural furniture to portable GLB.
## The exported GLBs are the final runtime assets, not generated during gameplay.
const SOURCES := ["side_table_oak","side_table_steel","coffee_table_round","coffee_table_glass","writing_table","lounge_chair","chair_mesh","sofa_modular","bench_cushion","shelf_low","shelf_ladder","media_console","display_cabinet","lamp_tripod","lamp_arc","lamp_cylinder","plant_cactus","plant_palm","rug_geometric","rug_round"]
const OUT_DIR := "res://assets/models/room/catalog"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if err != OK:
		push_error("Cannot create GLB output directory: " + str(err))
		quit(1)
		return
	var errors := 0
	for furniture_name: String in SOURCES:
		var source: PackedScene = load("res://scenes/room/%s.tscn" % furniture_name)
		if source == null:
			push_error("Missing source scene: " + furniture_name)
			errors += 1
			continue
		var furniture: Node3D = source.instantiate()
		root.add_child(furniture)
		await process_frame
		var model := furniture.get_node_or_null("Model") as Node3D
		if model == null:
			push_error("No modeled parts: " + furniture_name)
			errors += 1
			furniture.free()
			continue
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var append_err: Error = doc.append_from_scene(model, state)
		if append_err != OK:
			push_error("Cannot serialize mesh for " + furniture_name + ": " + str(append_err))
			errors += 1
			furniture.free()
			continue
		var path := OUT_DIR + "/" + furniture_name + ".glb"
		var write_err: Error = doc.write_to_filesystem(state, ProjectSettings.globalize_path(path))
		if write_err != OK:
			push_error("Cannot write " + path + ": " + str(write_err))
			errors += 1
		else:
			print("FURNITURE_GLB_EXPORTED: " + path)
		furniture.free()
	print("FURNITURE_GLB_EXPORT_RESULT: %d models, %d failures" % [SOURCES.size(), errors])
	quit(1 if errors > 0 else 0)
