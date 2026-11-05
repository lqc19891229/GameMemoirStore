extends SceneTree
## Validate the gaming chair's authored baseline without changing GLB nodes
## or the save identity of any per-surface player customization.
const Chair = preload("res://scenes/room/seating/chair_gaming.tscn")
const Profile = preload("res://scripts/room/chair_gaming_material_profile.gd")
const Slots = preload("res://scripts/items/furniture_material_slots.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var chair := Chair.instantiate() as Node3D
	root.add_child(chair)
	await process_frame
	var profile := chair.get_node_or_null("MaterialProfile")
	check(profile != null, "chair scene contains material profile")
	var parts: Dictionary = Profile.PARTS
	check(parts.size() == 12, "all original gaming chair material groups configured")
	var slots := Slots.list_slots(chair)
	check(slots.size() == 12, "exact original 12 named mesh surfaces remain")
	var matched := 0
	var leather_texture := false
	for slot: Dictionary in slots:
		var mesh := slot["mesh"] as MeshInstance3D
		var config: Dictionary = parts.get(str(mesh.name), {})
		check(not config.is_empty(), "known material group: " + str(mesh.name))
		var current := mesh.get_surface_override_material(int(slot["surface"])) as StandardMaterial3D
		check(current != null, "material override assigned: " + str(mesh.name))
		if current == null or config.is_empty():
			continue
		matched += 1
		var baseline := Slots.build_material(str(config["preset"]), str(config["color"]))
		check(baseline != null and current.albedo_color.is_equal_approx(baseline.albedo_color),
			"baseline material color: " + str(mesh.name))
		if str(mesh.name) == "leather_pearl":
			leather_texture = current.albedo_texture != null and current.normal_texture != null
	check(matched == 12, "all mesh groups receive a material")
	check(leather_texture, "chair upholstery receives existing leather PBR maps")
	var entry := {"preset": "leather/leather_black", "color": "e03045",
		"tile_u": 1.5, "tile_v": 1.0, "flip_u": false, "flip_v": false}
	var leather_key := ""
	for slot: Dictionary in slots:
		if str((slot["mesh"] as MeshInstance3D).name) == "leather_pearl":
			leather_key = str(slot["key"])
			break
	if not leather_key.is_empty():
		var originals := {}
		Slots.apply(chair, {leather_key: entry}, originals)
		var leather_mesh: MeshInstance3D = null
		for slot: Dictionary in slots:
			if str(slot["key"]) == leather_key:
				leather_mesh = slot["mesh"] as MeshInstance3D
				break
		if leather_mesh != null:
			var changed := leather_mesh.get_surface_override_material(0) as StandardMaterial3D
			check(changed != null and changed.albedo_color.r > changed.albedo_color.g,
				"per-UID customization overrides authored chair material")
		Slots.restore_all(originals)
		if leather_mesh != null:
			var restored := leather_mesh.get_surface_override_material(0) as StandardMaterial3D
			check(restored != null and restored.albedo_color.is_equal_approx(
				Color("#" + str(parts["leather_pearl"]["color"]))),
				"clearing customization restores authored leather baseline")
	var other := Chair.instantiate() as Node3D
	root.add_child(other)
	await process_frame
	var a: MeshInstance3D = null
	var b: MeshInstance3D = null
	for slot: Dictionary in Slots.list_slots(chair):
		if str((slot["mesh"] as MeshInstance3D).name) == "leather_pearl":
			a = slot["mesh"] as MeshInstance3D
	for slot: Dictionary in Slots.list_slots(other):
		if str((slot["mesh"] as MeshInstance3D).name) == "leather_pearl":
			b = slot["mesh"] as MeshInstance3D
	check(a != null and b != null and a.get_surface_override_material(0) != b.get_surface_override_material(0),
		"separate chairs own independent tintable material instances")
	chair.queue_free()
	other.queue_free()
	await process_frame
	print("CHAIR_GAMING_MATERIAL_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
