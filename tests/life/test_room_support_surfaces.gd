extends SceneTree
## Execute with: godot --headless --path . --script res://tests/life/test_room_support_surfaces.gd

const Surfaces = preload("res://scripts/room/furniture_support_surfaces.gd")
const Finishes = preload("res://scripts/items/furniture_finishes.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var anchor := Surfaces.from_bounds(Vector3(1.5, 0.82, 0.78), 0.08)
	assert(anchor.id == "top")
	assert(Surfaces.fits(anchor, Vector3(0.0, 0.82, 0.0), Vector2(0.4, 0.3)))
	assert(not Surfaces.fits(anchor, Vector3(0.70, 0.82, 0.0), Vector2(0.4, 0.3)))
	assert(not Surfaces.fits(anchor, Vector3(0.0, 0.55, 0.0), Vector2(0.4, 0.3)))
	assert(Surfaces.clean_anchor({"id": "invalid", "center": Vector3.ZERO, "size": Vector2(-1.0, 1.0)}).is_empty())
	var support := Node3D.new()
	support.set_meta("support_surfaces", [anchor, anchor, {"id": "", "center": Vector3.ZERO, "size": Vector2.ONE}])
	assert(Surfaces.anchors_for(support).size() == 1)
	assert(Surfaces.find_fit(support, Vector3(0, 0.82, 0), Vector2(0.3, 0.3)).id == "top")
	assert(Surfaces.find_fit(support, Vector3(2, 0.82, 0), Vector2(0.3, 0.3)).is_empty())
	assert(Surfaces.from_bounds(Vector3(-1, 1, 1)).is_empty())
	# Every legacy support has the same authored contact geometry after the
	# role-driven fallback is removed. Other furniture never auto-generates it.
	var expected := [
		{"scene": "res://scenes/room/storage/bookcase.tscn", "count": 4,
			"heights": [0.2575, 0.8375, 1.4175, 1.9975]},
		{"scene": "res://scenes/room/tables/writing_table.tscn", "count": 1, "height": 0.82, "size": Vector2(1.34, 0.62)},
		{"scene": "res://scenes/room/tables/side_table_oak.tscn", "count": 1, "height": 0.69, "size": Vector2(0.62, 0.56)},
		{"scene": "res://scenes/room/tables/coffee_table_round.tscn", "count": 1, "height": 0.56, "size": Vector2(1.08, 1.08)},
		{"scene": "res://scenes/room/tables/coffee_table_glass.tscn", "count": 1, "height": 0.54, "size": Vector2(1.26, 0.63)},
		{"scene": "res://scenes/room/storage/shelf_low.tscn", "count": 1, "height": 0.99, "size": Vector2(1.30, 0.32)}
	]
	for spec: Dictionary in expected:
		var instance: Node3D = (load(str(spec.scene)) as PackedScene).instantiate()
		root.add_child(instance)
		var surfaces := Surfaces.anchors_for(instance)
		assert(surfaces.size() == int(spec.count))
		assert(bool(instance.get("use_custom_support_surfaces")))
		if spec.has("heights"):
			for i in range(surfaces.size()):
				assert(str(surfaces[i].id) == "shelf_%d" % i)
				assert(is_equal_approx(float(surfaces[i].center.y), float(spec.heights[i])))
				assert(surfaces[i].size.is_equal_approx(Vector2(1.16, 0.42)))
		else:
			assert(str(surfaces[0].id) == "top")
			assert(is_equal_approx(float(surfaces[0].center.y), float(spec.height)))
			assert(surfaces[0].size.is_equal_approx(spec.size))
		instance.free()
	var non_support: Node3D = (load("res://scenes/room/seating/chair.tscn") as PackedScene).instantiate()
	root.add_child(non_support)
	assert(Surfaces.anchors_for(non_support).is_empty())
	non_support.free()
	assert(Finishes.LABELS.size() == 16)
	assert(Finishes.LABELS.size() == Finishes.HEX.size())
	assert(Finishes.LABELS.size() == Finishes.ALPHA.size())
	assert(Finishes.LABELS.size() == Finishes.ROUGHNESS.size())
	assert(Finishes.LABELS.size() == Finishes.METALLIC.size())
	for i in range(Finishes.LABELS.size()):
		assert(Finishes.valid(i))
		if i > 0: assert(Finishes.overlay(i) != null)
	# Old indices must remain untouched; custom RGB encodes losslessly.
	assert(Finishes.LABELS[8] == "陶土橙")
	var rgb := Color8(18, 121, 224)
	var packed: int = Finishes.from_color(rgb)
	assert(Finishes.is_custom(packed))
	assert(Finishes.is_saved_finish(packed))
	assert(not Finishes.is_saved_finish(-1))
	assert(not Finishes.is_saved_finish(0x2000000))
	var unpacked: Color = Finishes.color_for(packed)
	assert(unpacked.to_html(false) == "1279e0")
	assert(is_equal_approx(Finishes.overlay(packed).albedo_color.a, 0.52))
	assert(not Finishes.valid(16))
	support.free()
	print("PASS room support surfaces and expanded palette")
	quit()
