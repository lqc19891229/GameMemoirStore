extends SceneTree
const Catalog: MemoirItemCatalog = preload("res://data/items/_catalog.tres")
const Finishes = preload("res://scripts/items/furniture_finishes.gd")
const LifeData = preload("res://scripts/life/life_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(Finishes.LABELS.size() == 16 and Finishes.HEX.size() == 16, "sixteen shared finishes")
	check(Finishes.LABELS[1] == "奶油白" and Finishes.LABELS[5] == "浅橡木", "old finish indices unchanged")
	check(Finishes.LABELS[8] == "陶土橙" and Finishes.valid(9) and not Finishes.valid(16), "new finish index validated")
	var raw := LifeData.defaults()
	raw["furniture_colors"] = {"starter_chair": 8, "starter_bookcase": 2, "starter_lamp": 16}
	var empty: Array[String] = []
	var clean: Dictionary = LifeData.clean(raw, empty, empty)
	check(clean.furniture_colors.get("starter_chair", 0) == 8, "new finish survives save sanitation")
	check(clean.furniture_colors.get("starter_bookcase", 0) == 2, "old finish survives save sanitation")
	check(not clean.furniture_colors.has("starter_lamp"), "invalid finish discarded")
	var game = load("res://scenes/main/game_root.tscn").instantiate()
	root.add_child(game)
	for i in range(5):
		await process_frame
	game.session.timer.stop()
	game.session.state.persistence_enabled = false
	var desktop = game.desktop
	var layout = desktop.world.layout
	check(layout.FURNITURE_COLOR_LABELS.size() == 16, "editor reads shared finish list")
	desktop.begin_layout()
	layout.select("chair")
	layout.set_furniture_color(8)
	check(layout.color_for("chair") == 8, "editor supports new finish")
	desktop.finish_layout(true)
	check(game.session.state.life.furniture_colors.get("starter_chair", 0) == 8, "per-instance finish committed")
	var browser = desktop.open_app("browser")
	check(browser != null, "browser opens")
	if browser != null:
		var picker: OptionButton = browser.get_node("%ShopPreviewFinish")
		check(picker.item_count == 16, "sixteen preview choices in shop")
		var thumbs := 0
		var sample: TextureRect
		for row: Node in browser.get_node("%Rows").get_children():
			var texture: TextureRect = row.get_node_or_null("%Thumbnail") as TextureRect
			if texture != null and row.get_node("%ThumbnailBackdrop").visible:
				thumbs += 1
				if sample == null:
					sample = texture
				check(not row.get_node("%FurnitureMeta").text.is_empty(), "furniture metadata appears")
		check(thumbs == Catalog.room_furniture().size(), "all furniture has a thumbnail slot")
		check(sample != null and str(sample.get_meta("thumbnail_key", "")).ends_with(":0"), "default finish preview")
		picker.select(8)
		browser.refresh()
		for row: Node in browser.get_node("%Rows").get_children():
			var texture: TextureRect = row.get_node_or_null("%Thumbnail") as TextureRect
			if texture != null and row.get_node("%ThumbnailBackdrop").visible:
				check(str(texture.get_meta("thumbnail_key", "")).ends_with(":8"), "preview tint switches thumbnail request")
		check(browser.thumbnail_cache.get_child_count() == 1, "one shared 3D viewport")
		check(browser.purchase_buttons.size() >= 27, "original purchase actions remain")
	game.queue_free()
	await process_frame
	print("FURNITURE_SHOWCASE_CHECKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
