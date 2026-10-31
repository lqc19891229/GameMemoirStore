extends SceneTree

var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var catalog: GameCatalog = load("res://data/games/_catalog.tres")
	check(catalog != null and not catalog.games.is_empty(), "enabled game catalog must load")
	if catalog == null:
		quit(1)
		return
	check(catalog.find_game(&"missing") == null, "missing ID returns null")
	var generated_ids: Array[String] = []
	for file in DirAccess.get_files_at("res://data/games"):
		if file.ends_with(".tres") and file != "_catalog.tres": generated_ids.append(file.get_basename())
	check(generated_ids.size() == catalog.games.size(), "manifest includes every generated game")
	var seen: Array[String] = []
	for game: GameDefinition in catalog.games:
		var id := str(game.game_id)
		check(not id.is_empty() and not seen.has(id.to_lower()), "game IDs are nonempty and unique: " + id)
		seen.append(id.to_lower())
		check(generated_ids.has(id) and catalog.find_game(game.game_id) == game, "ID resolves to its generated resource: " + id)
		check(not game.title.strip_edges().is_empty() and game.base_price >= 0, "valid title and price: " + id)
		check(game.store_release_ym > 0 and game.store_release_ym % 100 in range(1,13), "valid release month: " + id)
		check(game.announce_ym == 0 or game.announce_ym <= game.store_release_ym, "announcement precedes release: " + id)
		check(game.delist_ym == 0 or game.delist_ym > game.store_release_ym, "delisting follows release: " + id)
		check(game.capsule != null and game.capsule.resource_path == "res://assets/art/%s/%s.png" % [id,id], "cover resolves by game ID: " + id)
		check(game.screenshots.size() == 4, "four typed screenshot references: " + id)
		for i in range(game.screenshots.size()):
			var shot := game.screenshots[i]
			check(shot != null and shot.resource_path == "res://assets/art/%s/%s%02d.png" % [id,id,i+1], "ordered screenshot reference: " + id)
			if shot != null:
				var size := shot.get_size()
				check(size.x > 0 and size.y > 0, "screenshot has nonempty dimensions: " + id)
		check(typeof(game.cpu) == TYPE_STRING and typeof(game.gpu) == TYPE_STRING, "hardware text loads: " + id)
		var expected: Array[String] = ["game_id","title","announce_ym","store_release_ym","delist_ym","base_price","developer","genres","cpu","gpu","series_id","description","capsule","screenshots"]
		var actual: Array[String] = []
		for property in game.get_property_list():
			if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (property.usage & PROPERTY_USAGE_EDITOR) != 0: actual.append(property.name)
		expected.sort()
		actual.sort()
		check(actual == expected, "exactly 14 exported game fields: " + id)
		var copy: GameDefinition = game.duplicate(true)
		copy.announce_ym = 200307
		copy.store_release_ym = 200309
		copy.delist_ym = 200502
		check(copy.state_at(200306) == &"hidden", "hidden before announcement")
		check(copy.state_at(200307) == &"coming_soon", "announcement is inclusive")
		check(copy.state_at(200309) == &"available", "release is inclusive")
		check(copy.state_at(200502) == &"delisted", "delisting is inclusive")
	print("RESOURCE_CHECKS=%d FAILURES=%d" % [checks, failures])
	quit(1 if failures else 0)
