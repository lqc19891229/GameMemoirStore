class_name GameCatalog
extends Resource
## Keep this manifest referenced by your main scene/script so exports include it.
@export var games: Array[GameDefinition] = []

func find_game(id: StringName) -> GameDefinition:
	for game in games:
		if game.game_id == id:
			return game
	return null

func available_at(ym: int) -> Array[GameDefinition]:
	var result: Array[GameDefinition] = []
	for game in games:
		if game.is_available(ym):
			result.append(game)
	return result
