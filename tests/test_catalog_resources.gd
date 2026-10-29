extends SceneTree

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var catalog: GameCatalog = load("res://data/games/_catalog.tres")
	check(catalog != null, "catalog must load")
	if catalog == null:
		quit(1)
		return
	check(catalog.games.size() == 1, "one enabled test game")
	check(catalog.available_at(200308).is_empty(), "hidden before release")
	check(catalog.available_at(200309).size() == 1, "test game is initially released")
	check(catalog.available_at(200310).size() == 1, "test game remains available")
	check(catalog.find_game(&"missing") == null, "missing ID returns null")
	var game: GameDefinition = catalog.find_game(&"CounterSquad")
	check(game != null, "find stable game ID")
	if game != null:
		check(game.capsule != null, "capsule is a texture reference")
		check(game.capsule.resource_path == "res://assets/art/CounterSquad/CounterSquad.png", "cover resolves to game ID filename")
		check(game.screenshots.size() == 4, "four typed screenshot references")
		for i in range(game.screenshots.size()):
			check(game.screenshots[i].resource_path == "res://assets/art/CounterSquad/CounterSquad%02d.png" % (i + 1), "screenshot path and order")
			check(game.screenshots[i].get_size() == Vector2(640, 360), "screenshot dimensions survive import")
		check(game.title == "反击小队", "Chinese title survives")
		check(game.base_price == 105, "base price survives")
		check(game.cpu == "COREI5-10600K", "CPU model preserved verbatim")
		check(game.gpu == "RTX3060", "GPU model preserved verbatim")
		check(game.genres == PackedStringArray(["射击", "动作", "多人"]), "genres typed array")
		var expected: Array[String] = ["game_id","title","announce_ym","store_release_ym","delist_ym","base_price","developer","genres","cpu","gpu","series_id","description","capsule","screenshots"]
		var actual: Array[String] = []
		for property in game.get_property_list():
			if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (property.usage & PROPERTY_USAGE_EDITOR) != 0:
				actual.append(property.name)
		expected.sort()
		actual.sort()
		check(actual == expected, "exactly 14 exported game fields; no enabled or old fields")
		var copy: GameDefinition = game.duplicate(true)
		copy.announce_ym = 200307
		copy.delist_ym = 200502
		check(copy.state_at(200306) == &"hidden", "before announcement")
		check(copy.state_at(200307) == &"coming_soon", "announcement inclusive")
		check(copy.state_at(200309) == &"available", "release inclusive")
		check(copy.state_at(200502) == &"delisted", "delist inclusive")
		check(game.delist_ym == 0, "definition not mutated")
	for entry in catalog.games:
		check(not entry.game_id.is_empty(), "nonempty ID")
		check(entry.capsule != null, "capsule texture loads")
		check(entry.cpu == "COREI5-10600K" and entry.gpu == "RTX3060", "hardware text loads")
	print("RESOURCE_CHECKS=%d FAILURES=%d" % [checks, failures])
	quit(1 if failures else 0)
