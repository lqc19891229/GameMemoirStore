extends SceneTree
## Reusable material assets, independent per-instance overrides and save sanitization.
const Slots = preload("res://scripts/items/furniture_material_slots.gd")
var checks := 0
var failures := 0

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(name)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(Slots.PRESETS.size() == 12, "twelve reusable PBR presets")
	for preset: String in Slots.PRESETS:
		check(ResourceLoader.exists(Slots.ROOT + preset + ".tres"), "exists: " + preset)
		check(Slots.build_material(preset, "ffffff") != null, "loads: " + preset)
	# The high-detail presets share four procedural normal textures. No GLB
	# edits or external image imports are required.
	for preset: String in [
		"leather/leather_black", "leather/leather_white",
		"fabric/fabric_gray", "fabric/fabric_beige",
		"wood/wood_oak_light", "wood/wood_walnut",
		"metal/metal_black_matte", "metal/metal_brushed_steel"
	]:
		var resource := load(Slots.ROOT + preset + ".tres") as StandardMaterial3D
		check(resource != null and resource.normal_enabled, "micro normal enabled: " + preset)
		check(resource != null and resource.normal_texture is NoiseTexture2D, "shared procedural texture: " + preset)
		var custom := Slots.build_material(preset, "ffffff")
		check(custom != null and custom.normal_texture == resource.normal_texture, "recolored instance retains shared normal map: " + preset)
	var known := {"inventory_123": true}
	var raw := {
		"inventory_123": {
			"Model/Chair:0": {"preset": "leather/leather_black", "color": "ff3344"},
			"invalid": {"preset": "../../evil", "color": "ffffff"}
		},
		"unknown": {"Model/Chair:0": {"preset": "leather/leather_white", "color": "ffffff"}}
	}
	var clean: Dictionary = Slots.clean(raw, known)
	check(clean.size() == 1 and clean["inventory_123"].size() == 1, "UID and preset sanitization")
	check(Slots.clean({}, known).is_empty(), "old saves without materials remain compatible")
	var furniture := Node3D.new()
	root.add_child(furniture)
	var mesh := MeshInstance3D.new()
	mesh.name = "Seat"
	mesh.mesh = BoxMesh.new()
	furniture.add_child(mesh)
	var slots := Slots.list_slots(furniture)
	check(slots.size() == 1, "surface discovery")
	var key := str(slots[0]["key"])
	var original := StandardMaterial3D.new()
	mesh.set_surface_override_material(0, original)
	var originals: Dictionary = {}
	var settings := {key: {"preset": "fabric/fabric_gray", "color": "ff0000"}}
	Slots.apply(furniture, settings, originals)
	var changed := mesh.get_surface_override_material(0) as StandardMaterial3D
	check(changed != null and changed != original, "runtime material uses independent instance")
	check(changed != null and changed.albedo_color.r > changed.albedo_color.g, "RGB tint is applied")
	var bright := Slots.build_material("leather/leather_black", "ffffff")
	check(bright != null and bright.albedo_color.r > 0.95, "black leather can be recolored to white")
	check(Slots.preset_label("leather/leather_black") != "leather/leather_black", "localized preset label")
	check(Slots.slot_label(slots[0]).contains("Seat"), "mesh surface label exposes source identity")
	Slots.restore_all(originals)
	check(mesh.get_surface_override_material(0) == original, "clearing preserves authored override")
	furniture.queue_free()
	await process_frame
	print("FURNITURE_MATERIAL_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
