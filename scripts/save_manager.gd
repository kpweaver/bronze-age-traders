class_name SaveManager

const ActorClass     = preload("res://scripts/entities/actor.gd")
const ItemClass      = preload("res://scripts/entities/item.gd")
const HostileAIClass = preload("res://scripts/components/hostile_ai.gd")
const GameMapClass   = preload("res://scripts/map/game_map.gd")

const SAVE_PATH := "user://save.json"


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if save_exists():
		DirAccess.open("user://").remove("save.json")


static func save_game(game_map, player, floor: int, floors: Dictionary) -> void:
	var data := {
		"floor": floor,
		"player": {
			"x": player.pos.x, "y": player.pos.y,
			"hp": player.hp, "max_hp": player.max_hp,
			"defense": player.defense, "power": player.power,
			"gold": player.gold,
			"inventory": _serialize_inventory(player.inventory),
		},
		"map": {
			"width": game_map.width,
			"height": game_map.height,
			"tiles": game_map.tiles,
			"explored": game_map.explored,
		},
		"entities": _serialize_entities(game_map.entities, player),
		"stored_floors": _serialize_stored_floors(floors),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


static func _serialize_stored_floors(floors: Dictionary) -> Dictionary:
	var result := {}
	for f in floors:
		var m = floors[f]
		result[str(f)] = {
			"tiles":    m.tiles,
			"explored": m.explored,
			"entities": _serialize_entities(m.entities, null),
		}
	return result


static func _serialize_inventory(inventory: Array) -> Array:
	var result := []
	for item in inventory:
		result.append({"item_type": item.item_type, "value": item.value,
			"dice_count": item.dice_count, "dice_sides": item.dice_sides})
	return result


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
		}
		if e is ActorClass:
			entry["type"]    = "actor"
			entry["hp"]      = e.hp
			entry["max_hp"]  = e.max_hp
			entry["defense"] = e.defense
			entry["power"]   = e.power
			entry["has_ai"]  = e.ai != null
		elif e is ItemClass:
			entry["type"]       = "item"
			entry["item_type"]  = e.item_type
			entry["value"]      = e.value
			entry["dice_count"] = e.dice_count
			entry["dice_sides"] = e.dice_sides
		else:
			entry["type"] = "entity"
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


# Returns [game_map, player, floor].
static func restore(data: Dictionary, fov_radius: int) -> Array:
	var floor: int = int(data.get("floor", 1))

	var md: Dictionary = data["map"]
	var game_map = GameMapClass.new(int(md["width"]), int(md["height"]))

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
	player.hp   = int(pd["hp"])
	player.gold = int(pd.get("gold", 0))
	for inv: Dictionary in pd.get("inventory", []):
		var item = ItemClass.new(Vector2i(0, 0), inv["item_type"], int(inv["value"]))
		player.inventory.append(item)
	player.game_map = game_map
	game_map.entities.append(player)

	for ed: Dictionary in data["entities"]:
		var color := Color(float(ed["cr"]), float(ed["cg"]), float(ed["cb"]))
		var pos   := Vector2i(int(ed["x"]), int(ed["y"]))
		match ed["type"]:
			"actor":
				var actor = ActorClass.new(pos, ed["char"], color, ed["name"],
						int(ed["max_hp"]), int(ed["defense"]), int(ed["power"]))
				actor.hp              = int(ed["hp"])
				actor.blocks_movement = bool(ed["blocks_movement"])
				if bool(ed["has_ai"]) and actor.is_alive:
					actor.ai = HostileAIClass.new(actor)
				actor.game_map = game_map
				game_map.entities.append(actor)
			"item":
				var item = ItemClass.new(pos, ed["item_type"], int(ed["value"]))
				item.game_map = game_map
				game_map.entities.append(item)
			"entity":
				var ent = load("res://scripts/entities/entity.gd").new(pos, ed["char"], color, ed["name"], bool(ed["blocks_movement"]))
				ent.game_map = game_map
				game_map.entities.append(ent)

	game_map.compute_fov(player.pos.x, player.pos.y, fov_radius)

	var floors := {}
	for f_str in data.get("stored_floors", {}).keys():
		var f_int := int(f_str)
		var fd: Dictionary = data["stored_floors"][f_str]
		var stored_map = GameMapClass.new(int(md["width"]), int(md["height"]))
		var st_raw: Array = fd["tiles"]
		var se_raw: Array = fd["explored"]
		for y in range(stored_map.height):
			for x in range(stored_map.width):
				stored_map.tiles[y][x]    = int(st_raw[y][x])
				stored_map.explored[y][x] = bool(se_raw[y][x])
		for ed: Dictionary in fd["entities"]:
			var color := Color(float(ed["cr"]), float(ed["cg"]), float(ed["cb"]))
			var pos   := Vector2i(int(ed["x"]), int(ed["y"]))
			match ed["type"]:
				"actor":
					var actor = ActorClass.new(pos, ed["char"], color, ed["name"],
							int(ed["max_hp"]), int(ed["defense"]), int(ed["power"]))
					actor.hp              = int(ed["hp"])
					actor.blocks_movement = bool(ed["blocks_movement"])
					if bool(ed["has_ai"]) and actor.is_alive:
						actor.ai = HostileAIClass.new(actor)
					actor.game_map = stored_map
					stored_map.entities.append(actor)
				"item":
					var item = ItemClass.new(pos, ed["item_type"], int(ed["value"]))
					item.game_map = stored_map
					stored_map.entities.append(item)
				"entity":
					var ent = load("res://scripts/entities/entity.gd").new(
							pos, ed["char"], color, ed["name"], bool(ed["blocks_movement"]))
					ent.game_map = stored_map
					stored_map.entities.append(ent)
		floors[f_int] = stored_map

	return [game_map, player, floor, floors]
