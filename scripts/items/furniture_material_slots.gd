extends RefCounted
## Runtime material slots. Stored keys are stable relative mesh paths and surface indices.
const ROOT := "res://assets/materials/furniture/"
const PRESETS := [
	"leather/leather_black", "leather/leather_white",
	"fabric/fabric_gray", "fabric/fabric_beige",
	"wood/wood_oak_light", "wood/wood_walnut",
	"metal/metal_black_matte", "metal/metal_brushed_steel",
	"plastic/plastic_black", "plastic/plastic_white",
	"rubber/rubber_black", "glass/glass_clear"
]
const PRESET_NAMES := {
	"leather/leather_black": "皮革 · 黑色",
	"leather/leather_white": "皮革 · 浅色",
	"fabric/fabric_gray": "布料 · 灰色",
	"fabric/fabric_beige": "布料 · 米色",
	"wood/wood_oak_light": "木材 · 浅橡木",
	"wood/wood_walnut": "木材 · 深胡桃木",
	"metal/metal_black_matte": "金属 · 哑光黑",
	"metal/metal_brushed_steel": "金属 · 拉丝钢",
	"plastic/plastic_black": "塑料 · 黑色",
	"plastic/plastic_white": "塑料 · 白色",
	"rubber/rubber_black": "橡胶 · 黑色",
	"glass/glass_clear": "玻璃 · 透明"
}
const MAX_SLOTS := 96
const MAX_UIDS := 512
const TILE_MIN := 0.25
const TILE_MAX := 8.0

static func valid_tile(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= TILE_MIN and float(value) <= TILE_MAX


static func tile_for(settings: Dictionary, key: String) -> float:
	var value: Variant = settings.get(key, 1.0)
	return float(value) if valid_tile(value) else 1.0


static func preset_label(preset: String) -> String:
	return str(PRESET_NAMES.get(preset, preset))


static func slot_label(slot: Dictionary) -> String:
	# Human-readable labels are only hints, never persisted identifiers.
	# Keep imported GLB mesh paths/surface indices unchanged in saves.
	var key := str(slot.get("key", ""))
	var mesh := slot.get("mesh") as MeshInstance3D
	var name := str(mesh.name) if mesh != null else key
	var surface := int(slot.get("surface", 0))
	var source: Material = mesh.get_surface_override_material(surface) if mesh != null else null
	if source == null and mesh != null and mesh.mesh != null:
		source = mesh.mesh.surface_get_material(surface)
	var material_name := source.resource_name if source != null else ""
	var lowered := (name + " " + material_name).to_lower()
	var category := "网格"
	for rule: Dictionary in [
		{"words": ["seat", "cushion", "坐垫", "座垫"], "label": "坐垫"},
		{"words": ["back", "靠背", "椅背"], "label": "靠背"},
		{"words": ["arm", "扶手"], "label": "扶手"},
		{"words": ["wheel", "caster", "滚轮"], "label": "滚轮"},
		{"words": ["base", "leg", "frame", "支架", "底座"], "label": "支架"},
		{"words": ["leather", "皮革"], "label": "皮革表面"},
		{"words": ["fabric", "cloth", "布料"], "label": "布料表面"},
		{"words": ["metal", "steel", "金属"], "label": "金属表面"},
		{"words": ["plastic", "塑料"], "label": "塑料表面"}
	]:
		for word: String in rule["words"]:
			if lowered.contains(word):
				category = str(rule["label"])
				break
		if category != "网格":
			break
	var detail := material_name if not material_name.is_empty() else name
	return "%s · %s [%d]" % [category, detail, surface]


static func valid_preset(preset: String) -> bool:
	return PRESETS.has(preset)

static func clean(raw: Variant, known_uids: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary:
		return result
	for raw_uid: Variant in raw:
		if result.size() >= MAX_UIDS:
			break
		var uid := str(raw_uid)
		if not known_uids.has(uid) or not raw[raw_uid] is Dictionary:
			continue
		var entries: Dictionary = {}
		for raw_slot: Variant in raw[raw_uid]:
			if entries.size() >= MAX_SLOTS:
				break
			var key := str(raw_slot)
			if key.length() > 200 or key.is_empty() or not raw[raw_uid][raw_slot] is Dictionary:
				continue
			var entry: Dictionary = raw[raw_uid][raw_slot]
			var preset := str(entry.get("preset", ""))
			var hex := str(entry.get("color", "")).to_lower()
			if not valid_preset(preset) or hex.length() != 6 or not hex.is_valid_hex_number():
				continue
			var cleaned := {"preset": preset, "color": hex}
			for tile_key: String in ["tile_u", "tile_v"]:
				if valid_tile(entry.get(tile_key, 1.0)):
					cleaned[tile_key] = float(entry.get(tile_key, 1.0))
			for flip_key: String in ["flip_u", "flip_v"]:
				if entry.get(flip_key, false) is bool:
					cleaned[flip_key] = entry.get(flip_key, false)
			entries[key] = cleaned
		if not entries.is_empty():
			result[uid] = entries
	return result

static func list_slots(furniture: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in furniture.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var key := "%s:%d" % [str(furniture.get_path_to(mesh)), surface]
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			result.append({"key": key, "mesh": mesh, "surface": surface,
				"has_uv": not uv.is_empty()})
	return result

static func build_material(preset: String, color_hex: String, settings: Dictionary = {}) -> StandardMaterial3D:
	if not valid_preset(preset):
		return null
	var resource := load(ROOT + preset + ".tres") as StandardMaterial3D
	if resource == null:
		return null
	var material := resource.duplicate() as StandardMaterial3D
	if material == null:
		return null
	# Preserve base texture and PBR values, tint only albedo.
	# An RGB picker is an absolute color, not a multiplier of the preset base
	# (multiplying black leather by white makes it impossible to recolor).
	# Preserve base material alpha, texture maps, roughness and metallic values.
	var chosen := Color("#" + color_hex)
	chosen.a = resource.albedo_color.a
	material.albedo_color = chosen
	var tile_u := tile_for(settings, "tile_u")
	var tile_v := tile_for(settings, "tile_v")
	var flip_u: bool = settings.get("flip_u", false) == true
	var flip_v: bool = settings.get("flip_v", false) == true
	material.uv1_scale = Vector3(
		resource.uv1_scale.x * tile_u * (-1.0 if flip_u else 1.0),
		resource.uv1_scale.y * tile_v * (-1.0 if flip_v else 1.0),
		resource.uv1_scale.z)
	material.resource_local_to_scene = true
	return material

static func apply(furniture: Node3D, entries: Dictionary, originals: Dictionary) -> void:
	for slot: Dictionary in list_slots(furniture):
		var mesh := slot["mesh"] as MeshInstance3D
		var surface: int = slot["surface"]
		var key: String = slot["key"]
		var identity := "%d:%d" % [mesh.get_instance_id(), surface]
		if entries.has(key):
			if not originals.has(identity):
				originals[identity] = {"mesh": weakref(mesh), "surface": surface, "material": mesh.get_surface_override_material(surface)}
			var setting: Dictionary = entries[key]
			var material := build_material(str(setting["preset"]), str(setting["color"]), setting)
			if material != null:
				mesh.set_surface_override_material(surface, material)
		elif originals.has(identity):
			var prior: Dictionary = originals[identity]
			mesh.set_surface_override_material(surface, prior["material"])
			originals.erase(identity)

static func restore_all(originals: Dictionary) -> void:
	for identity: String in originals.keys():
		var prior: Dictionary = originals[identity]
		var target: MeshInstance3D = (prior["mesh"] as WeakRef).get_ref() as MeshInstance3D
		if target != null:
			target.set_surface_override_material(int(prior["surface"]), prior["material"])
	originals.clear()
