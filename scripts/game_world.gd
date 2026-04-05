class_name GameWorld
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal turn_ended(turn_number: int)  # emitted every turn — hook day/night, events, etc.
signal map_changed()                  # emitted on any floor/chunk transition or new game

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
const GameMapClass     = preload("res://scripts/map/game_map.gd")
const EntityClass      = preload("res://scripts/entities/entity.gd")
const ActorClass       = preload("res://scripts/entities/actor.gd")
const ItemClass        = preload("res://scripts/entities/item.gd")
const NpcClass         = preload("res://scripts/entities/npc.gd")
const NpcDataClass     = preload("res://content/npcs.gd")
const ProcgenClass     = preload("res://scripts/map/procgen.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")
const HostileAIClass   = preload("res://scripts/components/hostile_ai.gd")
const WanderAIClass    = preload("res://scripts/components/wander_ai.gd")

# ---------------------------------------------------------------------------
# Map size / FOV constants
# ---------------------------------------------------------------------------
const DUNGEON_W: int     = 160
const DUNGEON_H: int     = 70
const OVERWORLD_W: int   = 200
const OVERWORLD_H: int   = 100
const FOV_RADIUS: int    = 8
const FOV_OVERWORLD: int = 24   # daytime overworld sight range
const FOV_NIGHT: int     = 14   # night-time overworld sight range
const MSG_MAX: int       = 3

# Day/night — one in-game day = TURNS_PER_DAY player actions.
# 240 turns = roughly 10 turns per in-game hour, 24 hours per day.
const TURNS_PER_DAY: int = 240

# Game starts at dawn (turn 0 → 06:00).  Stored as a turn offset so that
# saving/loading turn preserves time-of-day correctly.
const START_HOUR: float  = 6.0   # what real-world hour turn 0 maps to

# ---------------------------------------------------------------------------
# Public state — read by the renderer, written only through methods below.
# ---------------------------------------------------------------------------
var map                              # GameMap — current active map
var player                           # Actor  — the player
var depth: int          = 0          # 0 = overworld, 1+ = dungeon floor
var floors: Dictionary  = {}         # depth int  → GameMap
var chunk: Vector2i     = Vector2i.ZERO
var chunks: Dictionary  = {}         # Vector2i   → GameMap (visited overworld chunks)
var messages: Array[String] = []
var game_over: bool     = false
var nearby_npc                       # last bumped NPC, cleared when player moves away
var turn: int           = 0          # global turn counter — increments every resolved action

# Minimum turns between random encounter rolls (prevents back-to-back spawns).
const ENCOUNTER_COOLDOWN: int = 30
var _last_encounter_turn: int = -100

# Time of day: 0.0 = midnight, 0.25 = 06:00, 0.5 = noon, 0.75 = 18:00.
var time_of_day: float:
	get:
		var raw: float = (turn % TURNS_PER_DAY) / float(TURNS_PER_DAY)
		return fmod(raw + START_HOUR / 24.0, 1.0)

var is_night: bool:
	get: return time_of_day < 0.2 or time_of_day >= 0.8  # 19:12–04:48


# Returns the current time as a "HH:MM" string.
func get_time_string() -> String:
	var hours_f: float = fmod(time_of_day * 24.0, 24.0)
	var h: int = int(hours_f)
	var m: int = int((hours_f - h) * 60.0)
	return "%02d:%02d" % [h, m]


# ===========================================================================
# Initialisation
# ===========================================================================

func new_game() -> void:
	depth      = 0
	chunk      = Vector2i.ZERO
	floors.clear()
	chunks.clear()
	game_over  = false
	nearby_npc = null
	turn       = 0
	messages.clear()

	GameState.world_seed   = randi()
	GameState.world_biomes = ProcgenClass.generate_world_biomes(
			GameState.WORLD_W, GameState.WORLD_H, GameState.world_seed)
	GameState.villages     = ProcgenClass.generate_villages(
			GameState.WORLD_W, GameState.WORLD_H, GameState.world_biomes, GameState.world_seed)
	GameState.road_chunks  = ProcgenClass.generate_roads(
			GameState.villages, GameState.WORLD_W, GameState.WORLD_H)

	chunk = Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1)

	var ow_map = GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
	ProcgenClass.generate_overworld(ow_map,
			chunk.x * OVERWORLD_W, chunk.y * OVERWORLD_H,
			GameState.world_seed, GameMapClass.BIOME_DESERT, true,
			get_road_dirs(chunk), false)

	var entrance_pos: Vector2i = ProcgenClass.find_cave_entrance(ow_map)
	var dungeon_entry := EntityClass.new(
			entrance_pos, ">", Color(0.90, 0.85, 0.60), "dungeon entrance", false)
	dungeon_entry.game_map = ow_map
	ow_map.entities.append(dungeon_entry)

	var spawn_pos: Vector2i = _walk_toward_center(ow_map, entrance_pos, 6)
	player = ActorClass.new(spawn_pos, "@", Color(0.80, 0.72, 0.55), "you", 30, 2, 5)
	player.game_map = ow_map
	ow_map.entities.append(player)
	map = ow_map

	map.compute_fov(player.pos.x, player.pos.y, FOV_OVERWORLD)
	log("You stand beneath a merciless sun. The dungeon entrance lies nearby. Press < for the world map.")
	map_changed.emit()


func load_from_save() -> void:
	var data := SaveManagerClass.load_game()
	if data.is_empty():
		new_game()
		return
	game_over  = false
	nearby_npc = null
	messages.clear()
	var result := SaveManagerClass.restore(data, FOV_RADIUS)
	map    = result[0]
	player = result[1]
	depth  = result[2]
	floors = result[3]
	chunk  = result[4]
	chunks = result[5]
	turn   = result[6]
	GameState.world_biomes = ProcgenClass.generate_world_biomes(
			GameState.WORLD_W, GameState.WORLD_H, GameState.world_seed)
	GameState.villages     = ProcgenClass.generate_villages(
			GameState.WORLD_W, GameState.WORLD_H, GameState.world_biomes, GameState.world_seed)
	GameState.road_chunks  = ProcgenClass.generate_roads(
			GameState.villages, GameState.WORLD_W, GameState.WORLD_H)
	log("You return to where you left off...")
	map_changed.emit()


func save() -> void:
	SaveManagerClass.save_game(map, player, depth, floors, chunk, chunks, turn)


# ===========================================================================
# Turn loop
# ===========================================================================

func do_player_turn(dir: Vector2i) -> void:
	if dir != Vector2i.ZERO:
		var next: Vector2i = player.pos + dir
		if not map.is_in_bounds(next.x, next.y):
			if map.map_type == GameMapClass.MAP_OVERWORLD:
				chunk_transition(dir)
			return

		var target = map.get_blocking_entity_at(next.x, next.y)
		if target != null:
			if target is NpcClass and (target as NpcClass).is_alive:
				nearby_npc = target
				var npc: NpcClass = target as NpcClass
				log("%s says: \"%s\"" % [npc.name.capitalize(), npc.greet()])
			elif target is ActorClass and (target as ActorClass).is_alive:
				log(player.attack(target as ActorClass))
				if GameState.god_mode and (target as ActorClass).is_alive:
					(target as ActorClass).take_damage((target as ActorClass).hp)
				if not (target as ActorClass).is_alive:
					log((target as ActorClass).die())
		elif map.is_walkable(next.x, next.y):
			player.pos = next
			nearby_npc = null
			if GameState.auto_pickup:
				auto_pickup()
			_check_stairs()
		else:
			return  # wall — no turn consumed

	do_enemy_turns()
	end_turn()


func do_enemy_turns() -> void:
	var night: bool = is_night
	for e in map.entities:
		if not (e is ActorClass):
			continue
		if e == player or not e.is_alive or e.ai == null:
			continue
		# Push current time-of-day into WanderAI so NPCs can honour their schedule.
		if e.ai is WanderAI:
			(e.ai as WanderAI).world_is_night = night
		var msg: String = e.ai.take_turn(player, map)
		if msg != "":
			log(msg)
		if not player.is_alive:
			if GameState.god_mode:
				player.hp = player.max_hp
			else:
				log(player.die())
				log("You are dead.  Press r to try again.")
				game_over = true
				return


func end_turn() -> void:
	var fov: int
	if map.map_type == GameMapClass.MAP_OVERWORLD:
		fov = FOV_NIGHT if is_night else FOV_OVERWORLD
	else:
		fov = FOV_RADIUS
	map.compute_fov(player.pos.x, player.pos.y, fov)
	turn += 1
	_check_random_encounter()
	turn_ended.emit(turn)


func auto_pickup() -> void:
	for e in map.entities.duplicate():
		if not (e is ItemClass) or e.pos != player.pos:
			continue
		if e.item_type == ItemClass.TYPE_GOLD:
			player.gold += e.value
			log("You collect %d gold." % e.value)
			map.entities.erase(e)
		elif player.inventory.size() < ActorClass.MAX_INVENTORY:
			player.inventory.append(e)
			var slot := char(ord("a") + player.inventory.size() - 1)
			log("You pick up the %s. [%s]" % [e.name, slot])
			map.entities.erase(e)
		else:
			log("Your pack is full!")


func log(text: String) -> void:
	messages.append(text)
	if messages.size() > MSG_MAX:
		messages = messages.slice(messages.size() - MSG_MAX)


# ===========================================================================
# Map transitions
# ===========================================================================

func chunk_transition(dir: Vector2i) -> void:
	var next: Vector2i = player.pos + dir
	var dc             := Vector2i.ZERO
	var new_x: int     = next.x
	var new_y: int     = next.y

	if next.x < 0:
		dc.x  = -1;  new_x = OVERWORLD_W - 2
	elif next.x >= OVERWORLD_W:
		dc.x  =  1;  new_x = 1
	if next.y < 0:
		dc.y  = -1;  new_y = OVERWORLD_H - 2
	elif next.y >= OVERWORLD_H:
		dc.y  =  1;  new_y = 1

	map.entities.erase(player)
	chunks[chunk] = map
	chunk += dc

	if chunks.has(chunk):
		map = chunks[chunk]
	else:
		var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
		ProcgenClass.generate_overworld(new_map,
				chunk.x * OVERWORLD_W, chunk.y * OVERWORLD_H,
				GameState.world_seed, get_chunk_biome(chunk), false,
				get_road_dirs(chunk), is_village_chunk(chunk.x, chunk.y))
		map = new_map

	player.pos      = Vector2i(new_x, new_y)
	player.game_map = map
	map.entities.append(player)

	map.compute_fov(player.pos.x, player.pos.y, FOV_OVERWORLD)
	var arrival_v: Variant = get_village_at_chunk(chunk.x, chunk.y)
	if arrival_v != null:
		log("You enter %s." % arrival_v.name)
	else:
		log("You enter the %s." % _biome_label(get_chunk_biome(chunk)))
	map_changed.emit()


# World-map screen fast-travel: moves chunk without consuming a turn or logging.
func world_map_navigate(dir: Vector2i) -> void:
	var dest := Vector2i(
		clampi(chunk.x + dir.x, 0, GameState.WORLD_W - 1),
		clampi(chunk.y + dir.y, 0, GameState.WORLD_H - 1))
	if dest == chunk:
		return

	map.entities.erase(player)
	chunks[chunk] = map
	chunk = dest

	if chunks.has(chunk):
		map = chunks[chunk]
	else:
		var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
		ProcgenClass.generate_overworld(new_map,
				chunk.x * OVERWORLD_W, chunk.y * OVERWORLD_H,
				GameState.world_seed, get_chunk_biome(chunk), false,
				get_road_dirs(chunk), is_village_chunk(chunk.x, chunk.y))
		map = new_map

	player.pos      = Vector2i(OVERWORLD_W >> 1, OVERWORLD_H >> 1)
	player.game_map = map
	map.entities.append(player)
	# No FOV / log / turn increment here — world map navigation is instantaneous.


func try_descend() -> void:
	for e in map.entities:
		if not (e is ActorClass) and e.char == ">" and e.pos == player.pos:
			_descend()
			return


func try_ascend() -> void:
	for e in map.entities:
		if not (e is ActorClass) and e.char == "<" and e.pos == player.pos:
			_ascend()
			return


# ===========================================================================
# World / chunk query helpers  (used by renderer and internally)
# ===========================================================================

func get_chunk_biome(c: Vector2i) -> int:
	if c.y >= 0 and c.y < GameState.world_biomes.size() and \
	   c.x >= 0 and c.x < GameState.world_biomes[c.y].size():
		return int(GameState.world_biomes[c.y][c.x])
	return GameMapClass.BIOME_DESERT


func is_road_chunk(cx: int, cy: int) -> bool:
	return GameState.road_chunks.has("%d,%d" % [cx, cy])


func is_village_chunk(cx: int, cy: int) -> bool:
	for v in GameState.villages:
		if int(v.cx) == cx and int(v.cy) == cy:
			return true
	return false


func get_village_at_chunk(cx: int, cy: int) -> Variant:
	for v in GameState.villages:
		if int(v.cx) == cx and int(v.cy) == cy:
			return v
	return null


func get_road_dirs(c: Vector2i) -> Array:
	var dirs: Array = []
	for d: Vector2i in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
		var nc := c + d
		if GameState.road_chunks.has("%d,%d" % [nc.x, nc.y]):
			dirs.append(d)
	return dirs


# ===========================================================================
# Private helpers
# ===========================================================================

func _descend() -> void:
	map.entities.erase(player)
	if depth == 0:
		chunks[chunk] = map
		depth = 1
	else:
		floors[depth] = map
		depth += 1

	if floors.has(depth):
		map             = floors[depth]
		player.pos      = _stairs_pos(map, "<")
		player.game_map = map
		map.entities.append(player)
	else:
		var new_map = GameMapClass.new(DUNGEON_W, DUNGEON_H)
		player.game_map = new_map
		player.pos      = Vector2i(0, 0)
		new_map.entities.append(player)
		map = new_map
		var monsters := mini(2 + (depth - 1) >> 1, 4)
		ProcgenClass.generate_dungeon(map, 50, 5, 14, monsters, player, depth)
		var up_stairs := EntityClass.new(player.pos, "<", Color(0.55, 0.80, 0.95), "stairs up", false)
		up_stairs.game_map = map
		map.entities.append(up_stairs)

	map.compute_fov(player.pos.x, player.pos.y, FOV_RADIUS)
	log("You descend to floor %d. The air grows heavier." % depth)
	map_changed.emit()


func _ascend() -> void:
	if depth <= 0:
		log("There is nothing above.")
		return
	map.entities.erase(player)
	floors[depth] = map
	depth -= 1

	if depth == 0:
		if chunks.has(chunk):
			map             = chunks[chunk]
			player.pos      = _stairs_pos(map, ">")
			player.game_map = map
			map.entities.append(player)
		else:
			# Chunk was evicted — regenerate it.
			var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
			var is_center: bool = (chunk == Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1))
			ProcgenClass.generate_overworld(new_map,
					chunk.x * OVERWORLD_W, chunk.y * OVERWORLD_H,
					GameState.world_seed, get_chunk_biome(chunk), is_center,
					get_road_dirs(chunk), is_village_chunk(chunk.x, chunk.y))
			var entrance_pos: Vector2i = ProcgenClass.find_cave_entrance(new_map)
			var dungeon_entry := EntityClass.new(
					entrance_pos, ">", Color(0.90, 0.85, 0.60), "dungeon entrance", false)
			dungeon_entry.game_map = new_map
			new_map.entities.append(dungeon_entry)
			player.pos      = entrance_pos
			player.game_map = new_map
			new_map.entities.append(player)
			map = new_map
	else:
		if floors.has(depth):
			map             = floors[depth]
			player.pos      = _stairs_pos(map, ">")
			player.game_map = map
			map.entities.append(player)

	var fov := FOV_OVERWORLD if map.map_type == GameMapClass.MAP_OVERWORLD else FOV_RADIUS
	map.compute_fov(player.pos.x, player.pos.y, fov)
	if depth == 0:
		log("You emerge into the blinding light of the open desert.")
	else:
		log("You ascend to floor %d." % depth)
	map_changed.emit()


func _stairs_pos(m, ch: String) -> Vector2i:
	for e in m.entities:
		if not (e is ActorClass) and e.char == ch:
			return e.pos
	return Vector2i(0, 0)


func _check_stairs() -> void:
	for e in map.entities:
		if (e is ActorClass) or e.pos != player.pos:
			continue
		if e.char == ">":
			if (e.name as String) == "dungeon entrance":
				log("A dungeon entrance yawns in the earth. > to enter.")
			else:
				log("Stairs lead down. > to descend.")
			return
		if e.char == "<":
			var hint := "< to ascend." if depth > 1 else "< to surface."
			log("Stairs lead up. %s" % hint)
			return


func _walk_toward_center(m, from: Vector2i, steps: int) -> Vector2i:
	var cx: int = m.width  >> 1
	var cy: int = m.height >> 1
	var pos := from
	for _i in range(steps):
		var best_next := pos
		var best_dist := (pos.x - cx) * (pos.x - cx) + (pos.y - cy) * (pos.y - cy)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = pos.x + dx
				var ny: int = pos.y + dy
				if not m.is_walkable(nx, ny):
					continue
				var d: int = (nx - cx) * (nx - cx) + (ny - cy) * (ny - cy)
				if d < best_dist:
					best_dist = d
					best_next = Vector2i(nx, ny)
		if best_next == pos:
			break
		pos = best_next
	return pos


# ===========================================================================
# Random encounters (overworld only)
# ===========================================================================

# Called every turn; rolls for and spawns overworld random encounters.
func _check_random_encounter() -> void:
	if depth != 0 or game_over:
		return
	if turn - _last_encounter_turn < ENCOUNTER_COOLDOWN:
		return

	# Night-time bandit encounter — ~1-in-40 chance per eligible turn.
	if is_night and randf() < 0.025:
		_spawn_bandits()
		return

	# Road caravan encounter (day only) — ~1-in-60 chance per eligible turn.
	if not is_night and is_road_chunk(chunk.x, chunk.y) and randf() < 0.017:
		_spawn_caravan()


# Spawns 1-2 desert bandits near the player.
func _spawn_bandits() -> void:
	var count: int   = randi_range(1, 2)
	var spawned: int = 0
	# Try several random positions; give up if none are suitable.
	for _attempt in range(count * 10):
		if spawned >= count:
			break
		var angle: float = randf() * TAU
		var dist: int    = randi_range(5, 10)
		var tx: int      = player.pos.x + int(cos(angle) * dist)
		var ty: int      = player.pos.y + int(sin(angle) * dist)
		if not map.is_in_bounds(tx, ty):
			continue
		if not map.is_walkable(tx, ty):
			continue
		if map.get_blocking_entity_at(tx, ty) != null:
			continue
		var bandit := ActorClass.new(
				Vector2i(tx, ty), "B", Color(0.72, 0.32, 0.20),
				"desert bandit", 12, 1, 3)
		bandit.ai       = HostileAIClass.new(bandit)
		bandit.game_map = map
		map.entities.append(bandit)
		spawned += 1

	if spawned > 0:
		_last_encounter_turn = turn
		var plural: String = "Bandits emerge" if spawned > 1 else "A bandit emerges"
		log("%s from the night!" % plural)


# Spawns a lone traveling merchant on a road chunk.
func _spawn_caravan() -> void:
	var tx: int = 0
	var ty: int = 0
	var found: bool = false
	for _attempt in range(25):
		var angle: float = randf() * TAU
		var dist: int    = randi_range(6, 14)
		tx = player.pos.x + int(cos(angle) * dist)
		ty = player.pos.y + int(sin(angle) * dist)
		if map.is_in_bounds(tx, ty) and map.is_walkable(tx, ty) \
				and map.get_blocking_entity_at(tx, ty) == null:
			found = true
			break
	if not found:
		return
	var npc_data: Dictionary = NpcDataClass.get_npc("merchant")
	var npc := NpcClass.new(Vector2i(tx, ty), "merchant", npc_data)
	npc.ai       = WanderAIClass.new(npc, 0.25, false)  # travels day and night
	npc.game_map = map
	map.entities.append(npc)
	_last_encounter_turn = turn
	log("A traveling merchant appears on the road ahead.")


# Biome labels for in-game log messages.
# ascii_map has its own copy for rendering (biome_name / biome_char / biome_color).
func _biome_label(biome: int) -> String:
	match biome:
		GameMapClass.BIOME_DESERT:    return "arid desert"
		GameMapClass.BIOME_OASIS:     return "lush oasis"
		GameMapClass.BIOME_STEPPES:   return "open steppes"
		GameMapClass.BIOME_MOUNTAINS: return "rocky mountains"
		GameMapClass.BIOME_BADLANDS:  return "rugged badlands"
		_:                            return "unknown lands"
