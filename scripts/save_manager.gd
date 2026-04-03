class_name SaveManager

const ActorClass    = preload("res://scripts/entities/actor.gd")
const HostileAIClass = preload("res://scripts/components/hostile_ai.gd")
const GameMapClass  = preload("res://scripts/map/game_map.gd")

const SAVE_PATH := "user://save.json"


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if save_exists():
		DirAccess.open("user://").remove("save.json")


static func save_game(game_map, player) -> void:
	var data := {
		"player": {
			"x": player.pos.x, "y": player.pos.y,
			"hp": player.hp, "max_hp": player.max_hp,
			"defense": player.defense, "power": player.power,
		},
		"map": {
			"width": game_map.width,
			"height": game_map.height,
			"tiles": game_map.tiles,
			"explored": game_map.explored,
		},
		"entities": _serialize_entities(game_map.entities, player),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


static func _serialize_entities(entities: Array, player) -> Array:
	var result := []
	for e in entities:
		if e == player:
			continue
		var entry := {
			"x": e.pos.x, "y": e.pos.y,
			"char": e.char,
			"cr": e.color.r, "cg": e.color.g, "cb": e.color.b,
			"name": e.name,
			"blocks_movement": e.blocks_movement,
			"type": "actor" if e is ActorClass else "entity",
		}
		if e is ActorClass:
			entry["hp"]     = e.hp
			entry["max_hp"] = e.max_hp
			entry["defense"] = e.defense
			entry["power"]  = e.power
			entry["has_ai"] = e.ai != null
		result.append(entry)
	return result


static func load_game() -> Dictionary:
	if not save_exists():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


# Reconstructs GameMap + player Actor from saved data.
# Returns [game_map, player].
static func restore(data: Dictionary, fov_radius: int) -> Array:
	var md: Dictionary = data["map"]
	var game_map = GameMapClass.new(int(md["width"]), int(md["height"]))

	# JSON parses ints as floats — cast explicitly
	var tiles_raw: Array = md["tiles"]
	var explored_raw: Array = md["explored"]
	for y in range(game_map.height):
		for x in range(game_map.width):
			game_map.tiles[y][x]    = int(tiles_raw[y][x])
			game_map.explored[y][x] = bool(explored_raw[y][x])

	var pd: Dictionary = data["player"]
	var player = ActorClass.new(
		Vector2i(int(pd["x"]), int(pd["y"])),
		"@", Color(0.80, 0.50, 0.20), "You",
		int(pd["max_hp"]), int(pd["defense"]), int(pd["power"])
	)
	player.hp = int(pd["hp"])
	player.game_map = game_map
	game_map.entities.append(player)

	for ed: Dictionary in data["entities"]:
		var color := Color(float(ed["cr"]), float(ed["cg"]), float(ed["cb"]))
		var pos   := Vector2i(int(ed["x"]), int(ed["y"]))
		if ed["type"] == "actor":
			var actor = ActorClass.new(pos, ed["char"], color, ed["name"],
					int(ed["max_hp"]), int(ed["defense"]), int(ed["power"]))
			actor.hp = int(ed["hp"])
			actor.blocks_movement = bool(ed["blocks_movement"])
			if bool(ed["has_ai"]) and actor.is_alive:
				actor.ai = HostileAIClass.new(actor)
			actor.game_map = game_map
			game_map.entities.append(actor)

	game_map.compute_fov(player.pos.x, player.pos.y, fov_radius)
	return [game_map, player]
