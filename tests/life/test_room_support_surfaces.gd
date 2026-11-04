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
	assert(Finishes.LABELS.size() == 16)
	assert(Finishes.LABELS.size() == Finishes.HEX.size())
	assert(Finishes.LABELS.size() == Finishes.ALPHA.size())
	assert(Finishes.LABELS.size() == Finishes.ROUGHNESS.size())
	assert(Finishes.LABELS.size() == Finishes.METALLIC.size())
	for i in range(Finishes.LABELS.size()):
		assert(Finishes.valid(i))
		if i > 0: assert(Finishes.overlay(i) != null)
	assert(not Finishes.valid(16))
	support.free()
	print("PASS room support surfaces and expanded palette")
	quit()
