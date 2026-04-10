class_name SaveManager

const ActorClass     = preload("res://scripts/entities/actor.gd")
const ItemClass      = preload("res://scripts/entities/item.gd")
const NpcClass       = preload("res://scripts/entities/npc.gd")
const NpcDataClass   = preload("res://content/npcs.gd")
const HostileAIClass = preload("res://scripts/components/hostile_ai.gd")
const WanderAIClass  = preload("res://scripts/components/wander_ai.gd")
const DocileAIClass  = preload("res://scripts/components/docile_ai.gd")
const GameMapClass   = preload("res://scripts/map/game_map.gd")

const SAVE_PATH := "user://save.json"


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if save_exists():
		DirAccess.open("user://").remove("save.json")


static func save_game(game_map, player, floor: int, floors: Dictionary, chunk: Vector2i, chunks: Dictionary, turn: int = 0, debug_data: Dictionary = {}) -> void:
	var data := {
		"floor": floor,
		"chunk_x": chunk.x,
		"chunk_y": chunk.y,
		"turn": turn,
		"world_seed": GameState.world_seed,
		"player_name":  GameState.player_name,
		"player_class": GameState.player_class,
		"debug": debug_data,
		"player": {
			"x": player.pos.x, "y": player.pos.y,
			"hp": player.hp, "max_hp": player.max_hp,
			"defense": player.defense, "power": player.power,
			"gold": player.gold,
			"level": player.level,
			"xp": player.xp,
			"xp_to_next": player.xp_to_next,
			"unspent_attribute_points": player.unspent_attribute_points,
			"thirst": player.thirst,
			"fatigue": player.fatigue,
			"str_score": player.str_score,
			"dex_score": player.dex_score,
			"con_score": player.con_score,
			"int_score": player.int_score,
			"wis_score": player.wis_score,
			"cha_score": player.cha_score,
			"thirst_rate": player.thirst_rate,
			"inventory": _serialize_inventory(player.inventory),
			"equipped":  _serialize_equipped(player.equipped),
		},
		"map": {
			"width":    game_map.width,
			"height":   game_map.height,
			"map_type": game_map.map_type,
			"tiles":    game_map.tiles,
			"explored": game_map.explored,
			"permanent_light": game_map.permanent_light,
		},
		"entities": _serialize_entities(game_map.entities, player),
		"stored_floors": _serialize_stored_floors(floors),
		"stored_chunks": _serialize_stored_chunks(chunks),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


static func _serialize_stored_floors(floors: Dictionary) -> Dictionary:
	var result := {}
	for f in floors:
		var m = floors[f]
		result[str(f)] = {
			"width":    m.width,
			"height":   m.height,
			"map_type": m.map_type,
			"tiles":    m.tiles,
			"explored": m.explored,
			"permanent_light": m.permanent_light,
			"entities": _serialize_entities(m.entities, null),
		}
	return result


static func _serialize_stored_chunks(chunks: Dictionary) -> Dictionary:
	# Keys are Vector2i — serialise as "x,y" strings.
	var result := {}
	for c in chunks:
		var m = chunks[c]
		result["%d,%d" % [c.x, c.y]] = {
			"width":    m.width,
			"height":   m.height,
			"map_type": m.map_type,
			"tiles":    m.tiles,
			"explored": m.explored,
			"permanent_light": m.permanent_light,
			"entities": _serialize_entities(m.entities, null),
		}
	return result


static func _serialize_inventory(inventory: Array) -> Array:
	var result := []
	for item in inventory:
		result.append({"item_type": item.item_type, "value": item.value})
	return result


static func _serialize_equipped(equipped: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot: String in equipped:
		var item = equipped[slot]
		if item != null:
			result[slot] = {"item_type": str(item.item_type), "value": int(item.value)}
		else:
			result[slot] = null
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
		if e is NpcClass:
			entry["type"]         = "npc"
			entry["npc_type"]     = (e as NpcClass).npc_type
			entry["hp"]           = e.hp
			entry["max_hp"]       = e.max_hp
			entry["is_mounted"]   = e.is_mounted
			entry["is_angered"]   = (e as NpcClass).is_angered
			entry["home_x"]       = (e as NpcClass).home_pos.x
			entry["home_y"]       = (e as NpcClass).home_pos.y
			entry["home_chunk_x"] = (e as NpcClass).home_chunk.x
			entry["home_chunk_y"] = (e as NpcClass).home_chunk.y
			entry["dialogue_idx"] = (e as NpcClass)._dialogue_idx
			entry["trade_stock"]  = (e as NpcClass).trade_stock.duplicate(true)
			# Persist flee state so a scared animal stays scared after reload.
			var ai = (e as NpcClass).ai
			entry["fleeing"] = (ai is DocileAIClass) and (ai as DocileAIClass)._fleeing
		elif e is ActorClass:
			entry["type"]    = "actor"
			entry["hp"]      = e.hp
			entry["max_hp"]  = e.max_hp
			entry["defense"] = e.defense
			entry["power"]   = e.power
			entry["is_mountable"] = e.is_mountable
			entry["is_mounted"] = e.is_mounted
			entry["has_ai"]  = e.ai != null
		elif e is ItemClass:
			entry["type"]       = "item"
			entry["item_type"]  = e.item_type
			entry["value"]      = e.value
			entry["dice_count"] = e.dice_count
			entry["dice_sides"] = e.dice_sides
		else:
			entry["type"]         = "entity"
			entry["light_radius"] = e.light_radius
		result.append(entry)
	return result


static func _restore_npc_ai(npc: NpcClass, ed: Dictionary) -> void:
	# Keep restoration rules identical across the active map and stored chunks.
	# Wildlife and traveling merchants use DocileAI; village merchants stay put.
	var mc: float = float(NpcDataClass.get_npc(npc.npc_type).get("move_chance", 0.35))
	npc.is_angered = bool(ed.get("is_angered", false))
	if npc.is_angered and npc.on_attacked == "retaliate":
		npc.ai = HostileAIClass.new(npc)
	elif npc.is_wildlife or npc.npc_type == "merchant" or npc.npc_type == "donkey" or npc.on_attacked == "flee":
		var dai := DocileAIClass.new(npc, mc, not npc.is_wildlife)
		dai._fleeing = bool(ed.get("fleeing", false)) or (npc.is_angered and npc.on_attacked == "flee")
		dai._last_hp = npc.hp
		npc.ai = dai
	else:
		npc.ai = null


static func load_game() -> Dictionary:
	if not save_exists():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


# Returns [game_map, player, floor, floors, chunk, chunks, turn, debug].
static func restore(data: Dictionary, fov_radius: int) -> Array:
	GameState.world_seed   = int(data.get("world_seed", 0))
	GameState.player_name  = str(data.get("player_name",  "Wanderer"))
	GameState.player_class = str(data.get("player_class", "wanderer"))
	var floor: int = int(data.get("floor", 1))
	var chunk := Vector2i(int(data.get("chunk_x", 0)), int(data.get("chunk_y", 0)))

	var md: Dictionary = data["map"]
	var game_map = GameMapClass.new(int(md["width"]), int(md["height"]))
	game_map.map_type = int(md.get("map_type", GameMapClass.MAP_DUNGEON))

	var tiles_raw: Array = md["tiles"]
	var explored_raw: Array = md["explored"]
	var permanent_light_raw: Array = md.get("permanent_light", [])
	for y in range(game_map.height):
		for x in range(game_map.width):
			game_map.tiles[y][x]    = int(tiles_raw[y][x])
			game_map.explored[y][x] = bool(explored_raw[y][x])
			if not permanent_light_raw.is_empty():
				game_map.permanent_light[y][x] = bool(permanent_light_raw[y][x])

	var pd: Dictionary = data["player"]
	var player = ActorClass.new(
		Vector2i(int(pd["x"]), int(pd["y"])),
		"@", Color(0.80, 0.50, 0.20), "you",
		int(pd["max_hp"]), int(pd["defense"]), int(pd["power"])
	)
	player.hp          = int(pd["hp"])
	player.gold        = int(pd.get("gold", 0))
	player.level       = int(pd.get("level", 1))
	player.xp          = int(pd.get("xp", 0))
	player.xp_to_next  = int(pd.get("xp_to_next", 100))
	player.unspent_attribute_points = int(pd.get("unspent_attribute_points", 0))
	player.thirst      = int(pd.get("thirst",  0))
	player.fatigue     = int(pd.get("fatigue", 0))
	player.str_score   = int(pd.get("str_score", 10))
	player.dex_score   = int(pd.get("dex_score", 10))
	player.con_score   = int(pd.get("con_score", 10))
	player.int_score   = int(pd.get("int_score", 10))
	player.wis_score   = int(pd.get("wis_score", 10))
	player.cha_score   = int(pd.get("cha_score", 10))
	player.thirst_rate = float(pd.get("thirst_rate", 1.0))
	for inv: Dictionary in pd.get("inventory", []):
		var item = ItemClass.new(Vector2i(0, 0), str(inv["item_type"]), int(inv.get("value", 0)))
		player.inventory.append(item)
	# Restore equipped gear (all fields re-derived from item_type in Item._init).
	for slot: String in pd.get("equipped", {}).keys():
		var eq_data = pd["equipped"][slot]
		if eq_data != null and eq_data is Dictionary:
			var eq_item = ItemClass.new(Vector2i(0,0), str(eq_data["item_type"]), int(eq_data.get("value",0)))
			player.equipped[slot] = eq_item
	game_map.add_entity(player)

	for ed: Dictionary in data["entities"]:
		var color := Color(float(ed["cr"]), float(ed["cg"]), float(ed["cb"]))
		var pos   := Vector2i(int(ed["x"]), int(ed["y"]))
		match ed["type"]:
			"npc":
				var npc_type: String     = str(ed.get("npc_type", "merchant"))
				var npc_data: Dictionary = NpcDataClass.get_npc(npc_type)
				var npc = NpcClass.new(pos, npc_type, npc_data)
				npc.hp             = int(ed.get("hp", npc.max_hp))
				npc.is_mounted     = bool(ed.get("is_mounted", false))
				npc.is_angered     = bool(ed.get("is_angered", false))
				npc.home_pos       = Vector2i(int(ed.get("home_x", npc.home_pos.x)), int(ed.get("home_y", npc.home_pos.y)))
				npc.home_chunk     = Vector2i(int(ed.get("home_chunk_x", npc.home_chunk.x)), int(ed.get("home_chunk_y", npc.home_chunk.y)))
				npc.blocks_movement = not npc.is_mounted
				npc._dialogue_idx  = int(ed.get("dialogue_idx", 0))
				# Restore per-instance stock (qtys may have changed from purchases).
				var saved_stock = ed.get("trade_stock", [])
				if not (saved_stock as Array).is_empty():
					npc.trade_stock = (saved_stock as Array).duplicate(true)
				if npc.is_mounted:
					npc.ai = null
				else:
					_restore_npc_ai(npc, ed)
				game_map.add_entity(npc)
			"actor":
				var actor = ActorClass.new(pos, ed["char"], color, ed["name"],
						int(ed["max_hp"]), int(ed["defense"]), int(ed["power"]))
				actor.hp              = int(ed["hp"])
				actor.is_mountable    = bool(ed.get("is_mountable", false))
				actor.is_mounted      = bool(ed.get("is_mounted", false))
				actor.blocks_movement = bool(ed["blocks_movement"])
				if bool(ed["has_ai"]) and actor.is_alive:
					actor.ai = HostileAIClass.new(actor)
				game_map.add_entity(actor)
			"item":
				var item = ItemClass.new(pos, str(ed["item_type"]), int(ed["value"]))
				game_map.add_entity(item)
			"entity":
				var ent = load("res://scripts/entities/entity.gd").new(pos, ed["char"], color, ed["name"], bool(ed["blocks_movement"]))
				ent.light_radius = int(ed.get("light_radius", 0))
				game_map.add_entity(ent)

	game_map.compute_fov(player.pos.x, player.pos.y, fov_radius)

	var floors := {}
	for f_str in data.get("stored_floors", {}).keys():
		var f_int := int(f_str)
		var fd: Dictionary = data["stored_floors"][f_str]
		var stored_map = GameMapClass.new(int(fd["width"]), int(fd["height"]))
		stored_map.map_type = int(fd.get("map_type", GameMapClass.MAP_DUNGEON))
		var st_raw: Array = fd["tiles"]
		var se_raw: Array = fd["explored"]
		var spl_raw: Array = fd.get("permanent_light", [])
		for y in range(stored_map.height):
			for x in range(stored_map.width):
				stored_map.tiles[y][x]    = int(st_raw[y][x])
				stored_map.explored[y][x] = bool(se_raw[y][x])
				if not spl_raw.is_empty():
					stored_map.permanent_light[y][x] = bool(spl_raw[y][x])
		for ed: Dictionary in fd["entities"]:
			var color := Color(float(ed["cr"]), float(ed["cg"]), float(ed["cb"]))
			var pos   := Vector2i(int(ed["x"]), int(ed["y"]))
			match ed["type"]:
				"npc":
					var npc_type: String     = str(ed.get("npc_type", "merchant"))
					var npc_data: Dictionary = NpcDataClass.get_npc(npc_type)
					var npc = NpcClass.new(pos, npc_type, npc_data)
					npc.hp            = int(ed.get("hp", npc.max_hp))
					npc.is_mounted    = bool(ed.get("is_mounted", false))
					npc.is_angered    = bool(ed.get("is_angered", false))
					npc.home_pos      = Vector2i(int(ed.get("home_x", npc.home_pos.x)), int(ed.get("home_y", npc.home_pos.y)))
					npc.home_chunk    = Vector2i(int(ed.get("home_chunk_x", npc.home_chunk.x)), int(ed.get("home_chunk_y", npc.home_chunk.y)))
					npc.blocks_movement = not npc.is_mounted
					npc._dialogue_idx = int(ed.get("dialogue_idx", 0))
					var saved_stock = ed.get("trade_stock", [])
					if not (saved_stock as Array).is_empty():
						npc.trade_stock = (saved_stock as Array).duplicate(true)
					if npc.is_mounted:
						npc.ai = null
					else:
						_restore_npc_ai(npc, ed)
					stored_map.add_entity(npc)
				"actor":
					var actor = ActorClass.new(pos, ed["char"], color, ed["name"],
							int(ed["max_hp"]), int(ed["defense"]), int(ed["power"]))
					actor.hp              = int(ed["hp"])
					actor.is_mountable    = bool(ed.get("is_mountable", false))
					actor.is_mounted      = bool(ed.get("is_mounted", false))
					actor.blocks_movement = bool(ed["blocks_movement"])
					if bool(ed["has_ai"]) and actor.is_alive:
						actor.ai = HostileAIClass.new(actor)
					stored_map.add_entity(actor)
				"item":
					var item = ItemClass.new(pos, ed["item_type"], int(ed["value"]))
					stored_map.add_entity(item)
				"entity":
					var ent = load("res://scripts/entities/entity.gd").new(
							pos, ed["char"], color, ed["name"], bool(ed["blocks_movement"]))
					ent.light_radius = int(ed.get("light_radius", 0))
					stored_map.add_entity(ent)
		floors[f_int] = stored_map

	# Restore visited overworld chunks.
	var chunks := {}
	for key: String in data.get("stored_chunks", {}).keys():
		var parts := key.split(",")
		var c     := Vector2i(int(parts[0]), int(parts[1]))
		var cd: Dictionary = data["stored_chunks"][key]
		var cw: int   = int(cd["width"])
		var ch_h: int = int(cd["height"])
		var cmap = GameMapClass.new(cw, ch_h)
		cmap.map_type = int(cd.get("map_type", GameMapClass.MAP_OVERWORLD))
		var ct_raw: Array = cd["tiles"]
		var ce_raw: Array = cd["explored"]
		var cpl_raw: Array = cd.get("permanent_light", [])
		for y in range(cmap.height):
			for x in range(cmap.width):
				cmap.tiles[y][x]    = int(ct_raw[y][x])
				cmap.explored[y][x] = bool(ce_raw[y][x])
				if not cpl_raw.is_empty():
					cmap.permanent_light[y][x] = bool(cpl_raw[y][x])
		for ed: Dictionary in cd.get("entities", []):
			var color := Color(float(ed["cr"]), float(ed["cg"]), float(ed["cb"]))
			var pos   := Vector2i(int(ed["x"]), int(ed["y"]))
			match ed["type"]:
				"npc":
					var npc_type: String     = str(ed.get("npc_type", "merchant"))
					var npc_data: Dictionary = NpcDataClass.get_npc(npc_type)
					var npc = NpcClass.new(pos, npc_type, npc_data)
					npc.hp            = int(ed.get("hp", npc.max_hp))
					npc.is_mounted    = bool(ed.get("is_mounted", false))
					npc.is_angered    = bool(ed.get("is_angered", false))
					npc.home_pos      = Vector2i(int(ed.get("home_x", npc.home_pos.x)), int(ed.get("home_y", npc.home_pos.y)))
					npc.home_chunk    = Vector2i(int(ed.get("home_chunk_x", npc.home_chunk.x)), int(ed.get("home_chunk_y", npc.home_chunk.y)))
					npc.blocks_movement = not npc.is_mounted
					npc._dialogue_idx = int(ed.get("dialogue_idx", 0))
					var saved_stock = ed.get("trade_stock", [])
					if not (saved_stock as Array).is_empty():
						npc.trade_stock = (saved_stock as Array).duplicate(true)
					if npc.is_mounted:
						npc.ai = null
					else:
						_restore_npc_ai(npc, ed)
					cmap.add_entity(npc)
				"actor":
					var actor = ActorClass.new(pos, ed["char"], color, ed["name"],
							int(ed["max_hp"]), int(ed["defense"]), int(ed["power"]))
					actor.hp              = int(ed["hp"])
					actor.is_mountable    = bool(ed.get("is_mountable", false))
					actor.is_mounted      = bool(ed.get("is_mounted", false))
					actor.blocks_movement = bool(ed["blocks_movement"])
					if bool(ed["has_ai"]) and actor.is_alive:
						actor.ai = HostileAIClass.new(actor)
					cmap.add_entity(actor)
				"entity":
					var ent = load("res://scripts/entities/entity.gd").new(
							pos, ed["char"], color, ed["name"], bool(ed["blocks_movement"]))
					ent.light_radius = int(ed.get("light_radius", 0))
					cmap.add_entity(ent)
				"item":
					var item = ItemClass.new(pos, str(ed["item_type"]), int(ed.get("value", 0)))
					cmap.add_entity(item)
		chunks[c] = cmap

	var turn: int = int(data.get("turn", 0))
	var debug_data: Dictionary = data.get("debug", {})
	return [game_map, player, floor, floors, chunk, chunks, turn, debug_data]
