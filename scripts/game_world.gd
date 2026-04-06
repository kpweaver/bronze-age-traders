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
const ItemDataClass    = preload("res://content/items.gd")
const ProcgenClass     = preload("res://scripts/map/procgen.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")
const HostileAIClass   = preload("res://scripts/components/hostile_ai.gd")
const WanderAIClass    = preload("res://scripts/components/wander_ai.gd")
const DocileAIClass    = preload("res://scripts/components/docile_ai.gd")

# ---------------------------------------------------------------------------
# Map size / FOV constants
# ---------------------------------------------------------------------------
const DUNGEON_W: int     = 160
const DUNGEON_H: int     = 70
const OVERWORLD_W: int   = 200
const OVERWORLD_H: int   = 200
const FOV_RADIUS: int    = 8
const FOV_OVERWORLD: int = 24   # daytime overworld sight range
const FOV_NIGHT: int     = 1    # night-time overworld sight range — near-zero, pre-industrial darkness
const MSG_MAX: int       = 3

# Day/night — one in-game day = TURNS_PER_DAY player actions.
# Tile: 0.1 miles (528 ft).  Walking pace: 3 mph → 2 min/tile → 720 turns/day.
# Chunk: 200×100 tiles = 20×10 miles (≈ one Bronze Age city-state territory).
const TURNS_PER_DAY: int = 720

# Game starts at dawn (turn 0 → 06:00).  Stored as a turn offset so that
# saving/loading turn preserves time-of-day correctly.
const START_HOUR: float  = 6.0   # what real-world hour turn 0 maps to

# Babylonian lunisolar calendar — 12 months of 30 days (360-day year).
# Bronze Age Mesopotamia, ~1500–1200 BCE equivalent.
const MONTHS_BABYLONIAN: Array[String] = [
	"Nisanu", "Ayaru", "Simanu", "Du'uzu",
	"Abu", "Ululu", "Tashritu", "Arakhsamna",
	"Kislimu", "Tebetu", "Shabatu", "Addaru",
]
const DAYS_PER_MONTH:   int = 30
const MONTHS_PER_YEAR:  int = 12

# ---------------------------------------------------------------------------
# Public state — read by the renderer, written only through methods below.
# ---------------------------------------------------------------------------
var map                              # GameMap — current active map
var player                           # Actor  — the player
var party: Array        = []         # player + active followers — survival drain iterates this
var depth: int          = 0          # 0 = overworld, 1+ = dungeon floor
var floors: Dictionary  = {}         # depth int  → GameMap
var chunk: Vector2i     = Vector2i.ZERO
var chunks: Dictionary  = {}         # Vector2i   → GameMap (visited overworld chunks)
var messages: Array[String] = []
var game_over: bool     = false
var nearby_npc                       # last bumped NPC, cleared when player moves away
var turn: int           = 0          # global turn counter — increments every resolved action
var _resting: bool      = false      # true when the player waited this turn (affects fatigue)
var _thirst_acc: float  = 0.0        # fractional thirst accumulator for rate < 1.0


# Time of day: 0.0 = midnight, 0.25 = 06:00, 0.5 = noon, 0.75 = 18:00.
var time_of_day: float:
	get:
		var raw: float = (turn % TURNS_PER_DAY) / float(TURNS_PER_DAY)
		return fmod(raw + START_HOUR / 24.0, 1.0)

var is_night: bool:
	get: return time_of_day < 0.2 or time_of_day >= 0.8  # 19:12–04:48


# Returns "D Monthname" in the Babylonian calendar (e.g. "3 Nisanu").
func get_calendar_string() -> String:
	var total_days: int  = turn / TURNS_PER_DAY
	var year_day:   int  = total_days % (DAYS_PER_MONTH * MONTHS_PER_YEAR)
	var month_idx:  int  = year_day / DAYS_PER_MONTH
	var day:        int  = (year_day % DAYS_PER_MONTH) + 1
	return "%d %s" % [day, MONTHS_BABYLONIAN[month_idx]]


# Returns a qualitative time-of-day label visible to the player.
func get_day_phase() -> String:
	var t: float = time_of_day
	# t: 0.0=midnight  0.25=06:00  0.5=noon  0.75=18:00
	if   t >= 0.20 and t < 0.27:  return "Dawn"   # ~04:48–06:28
	elif t >= 0.27 and t < 0.73:  return "Day"    # ~06:28–17:31
	elif t >= 0.73 and t < 0.80:  return "Dusk"   # ~17:31–19:12
	else:                          return "Night"


# Overworld FOV that smoothly interpolates across Dawn and Dusk transitions
# instead of snapping between FOV_OVERWORLD and FOV_NIGHT.
func overworld_fov() -> int:
	var t: float = time_of_day
	if t >= 0.27 and t < 0.73:
		return FOV_OVERWORLD                                      # full day
	elif t >= 0.20 and t < 0.27:
		var frac: float = (t - 0.20) / 0.07                      # dawn: 0→1
		return int(lerpf(float(FOV_NIGHT), float(FOV_OVERWORLD), frac))
	elif t >= 0.73 and t < 0.80:
		var frac: float = (t - 0.73) / 0.07                      # dusk: 0→1
		return int(lerpf(float(FOV_OVERWORLD), float(FOV_NIGHT), frac))
	else:
		return FOV_NIGHT                                          # full night


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
	_apply_archetype(player, GameState.player_class)
	player.game_map = ow_map
	ow_map.entities.append(player)
	map   = ow_map
	party = [player]

	# Player starts with one torch in their pack.
	var starting_torch := ItemClass.new(player.pos, ItemClass.TYPE_TORCH, 0)
	player.inventory.append(starting_torch)

	map.compute_fov(player.pos.x, player.pos.y, overworld_fov())
	add_msg("You stand beneath a merciless sun. The dungeon entrance lies nearby. Press < for the world map.")
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
	party = [player]
	_recompute_fov()
	add_msg("You return to where you left off...")
	map_changed.emit()


func save() -> void:
	SaveManagerClass.save_game(map, player, depth, floors, chunk, chunks, turn)


# ===========================================================================
# Turn loop
# ===========================================================================

func do_player_turn(dir: Vector2i, force_attack: bool = false) -> void:
	_resting = (dir == Vector2i.ZERO)
	if dir != Vector2i.ZERO:
		var next: Vector2i = player.pos + dir
		if not map.is_in_bounds(next.x, next.y):
			if map.map_type == GameMapClass.MAP_OVERWORLD:
				chunk_transition(dir)
			return

		var target = map.get_blocking_entity_at(next.x, next.y)
		if target != null:
			if target is NpcClass and (target as NpcClass).is_alive:
				if force_attack:
					# Shift+direction — attack the NPC directly.
					add_msg(player.attack(target as ActorClass))
					player.fatigue = mini(player.fatigue + 2, ActorClass.FATIGUE_MAX)
					if GameState.god_mode and (target as ActorClass).is_alive:
						(target as ActorClass).take_damage((target as ActorClass).hp)
					if not (target as ActorClass).is_alive:
						add_msg((target as ActorClass).die())
				else:
					nearby_npc = target
					var npc: NpcClass = target as NpcClass
					if npc.is_wildlife:
						add_msg(npc.greet())   # observation text in log; no dialogue panel
			elif target is ActorClass and (target as ActorClass).is_alive:
				add_msg(player.attack(target as ActorClass))
				# Combat is exhausting — extra fatigue on top of the base drain.
				player.fatigue = mini(player.fatigue + 2, ActorClass.FATIGUE_MAX)
				if GameState.god_mode and (target as ActorClass).is_alive:
					(target as ActorClass).take_damage((target as ActorClass).hp)
				if not (target as ActorClass).is_alive:
					add_msg((target as ActorClass).die())
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
		# Push current time-of-day so AI can honour diurnal schedules.
		if e.ai is WanderAIClass:
			(e.ai as WanderAIClass).world_is_night = night
		elif e.ai is DocileAIClass:
			(e.ai as DocileAIClass).world_is_night = night
		var msg: String = e.ai.take_turn(player, map)
		if msg != "":
			add_msg(msg)
		if not player.is_alive:
			if GameState.god_mode:
				player.hp = player.max_hp
			else:
				add_msg(player.die())
				add_msg("You are dead.  Press r to try again.")
				game_over = true
				return


func player_light_fov() -> int:
	var torch = player.equipped.get(ItemClass.SLOT_LIGHT)
	if torch == null:
		return 0
	var t := torch as ItemClass
	if t.light_fov > 0 and t.value > 0:
		return t.light_fov
	return 0


func _recompute_fov() -> void:
	var base_fov: int
	if map.map_type == GameMapClass.MAP_OVERWORLD:
		base_fov = overworld_fov()
	else:
		base_fov = FOV_RADIUS
	var fov: int = maxi(base_fov, player_light_fov())
	map.compute_fov(player.pos.x, player.pos.y, fov)
	# Expand FOV for any visible static light fixtures (braziers, road torches).
	for e in map.entities:
		if e.light_radius > 0 and map.is_in_bounds(e.pos.x, e.pos.y) \
				and map.visible[e.pos.y][e.pos.x]:
			map.compute_fov_additive(e.pos.x, e.pos.y, e.light_radius)


func _tick_torch() -> void:
	var torch = player.equipped.get(ItemClass.SLOT_LIGHT)
	if torch == null:
		return
	var t := torch as ItemClass
	if t.burn_turns > 0 and t.value > 0:
		t.value -= 1
		if t.value == 0:
			add_msg("Your torch gutters and dies. Darkness closes in.")
			player.equipped[ItemClass.SLOT_LIGHT] = null


func end_turn() -> void:
	_recompute_fov()
	turn += 1
	_tick_torch()
	if depth == 0:
		_drain_thirst()
	_drain_fatigue()
	turn_ended.emit(turn)


func try_skin() -> void:
	# Find the first adjacent wildlife corpse.
	var corpse  = null
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var check_pos: Vector2i = player.pos + Vector2i(dx, dy)
			for e in map.entities:
				if e is NpcClass and not (e as NpcClass).is_alive \
						and (e as NpcClass).is_wildlife \
						and e.pos == check_pos:
					corpse = e
					break
		if corpse != null:
			break

	if corpse == null:
		add_msg("There is no carcass nearby to skin.")
		return   # no turn consumed

	var corpse_type: String     = (corpse as NpcClass).npc_type
	var npc_data: Dictionary    = NpcDataClass.get_npc(corpse_type)
	var skin_table: Dictionary  = npc_data.get("skin_table", {})

	# d20 + WIS modifier; WIS knowledge of anatomy improves yield.
	var roll: int   = randi_range(1, 20) + player.wis_mod
	var tier: String
	if   roll >= 20: tier = "crit"
	elif roll >= 16: tier = "great"
	elif roll >= 11: tier = "good"
	elif roll >=  6: tier = "poor"
	else:            tier = "spoiled"

	var loot_pos: Vector2i = corpse.pos
	map.entities.erase(corpse)

	var wis_str: String = ("+%d" % player.wis_mod) if player.wis_mod >= 0 else str(player.wis_mod)
	if tier == "spoiled" or not skin_table.has(tier):
		add_msg("You butcher the %s but ruin the yield. [d20%s = %d]" \
				% [corpse_type, wis_str, roll])
	else:
		var loot: Array             = skin_table[tier]
		var names: PackedStringArray = []
		for entry in loot:
			var item_type: String = str(entry["item_type"])
			var qty: int          = int(entry.get("qty", 1))
			for _i in range(qty):
				var item := ItemClass.new(loot_pos, item_type, 0)
				item.game_map = map
				map.entities.append(item)
			var display: String = str(ItemDataClass.get_item(item_type).get("name", item_type))
			names.append("%dx %s" % [qty, display] if qty > 1 else display)
		add_msg("You skin the %s: %s. [d20%s = %d]" \
				% [corpse_type, ", ".join(names), wis_str, roll])
		if GameState.auto_pickup:
			auto_pickup()

	# Skinning consumes a turn.
	_resting = false
	do_enemy_turns()
	end_turn()


func auto_pickup() -> void:
	for e in map.entities.duplicate():
		if not (e is ItemClass) or e.pos != player.pos:
			continue
		if e.item_type == ItemClass.TYPE_GOLD:
			player.gold += e.value
			add_msg("You collect %d gold." % e.value)
			map.entities.erase(e)
		elif player.inventory.size() < player.max_inventory:
			player.inventory.append(e)
			var slot := char(ord("a") + player.inventory.size() - 1)
			add_msg("You pick up the %s. [%s]" % [e.name, slot])
			map.entities.erase(e)
		else:
			add_msg("Your pack is full!")


func add_msg(text: String) -> void:
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
		_place_chunk_encounter(new_map, chunk, Vector2i(new_x, new_y))
		map = new_map

	player.pos      = Vector2i(new_x, new_y)
	player.game_map = map
	map.entities.append(player)

	_recompute_fov()
	var arrival_v: Variant = get_village_at_chunk(chunk.x, chunk.y)
	if arrival_v != null:
		add_msg("You enter %s." % arrival_v.name)
	else:
		add_msg("You enter the %s." % _biome_label(get_chunk_biome(chunk)))
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

	_recompute_fov()
	add_msg("You descend to floor %d. The air grows heavier." % depth)
	map_changed.emit()


func _ascend() -> void:
	if depth <= 0:
		add_msg("There is nothing above.")
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

	_recompute_fov()
	if depth == 0:
		add_msg("You emerge into the blinding light of the open desert.")
	else:
		add_msg("You ascend to floor %d." % depth)
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
				add_msg("A dungeon entrance yawns in the earth. > to enter.")
			else:
				add_msg("Stairs lead down. > to descend.")
			return
		if e.char == "<":
			var hint := "< to ascend." if depth > 1 else "< to surface."
			add_msg("Stairs lead up. %s" % hint)
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
# Thirst / hydration (overworld only) and Fatigue (everywhere)
# Both iterate `party` so future followers are automatically covered.
# Add a follower with: party.append(follower_actor)
# Set actor.thirst_rate / fatigue_rate for non-human survival profiles.
# ===========================================================================

func _apply_archetype(actor, class_id: String) -> void:
	# Set base stat scores for each Bronze Age archetype.
	match class_id:
		"soldier":
			actor.str_score = 14; actor.dex_score = 12; actor.con_score = 14
			actor.int_score =  8; actor.wis_score =  8; actor.cha_score = 10
		"merchant":
			actor.str_score =  8; actor.dex_score = 10; actor.con_score = 10
			actor.int_score = 14; actor.wis_score = 12; actor.cha_score = 14
		"scout":
			actor.str_score = 10; actor.dex_score = 14; actor.con_score = 12
			actor.int_score = 10; actor.wis_score = 12; actor.cha_score =  8
		_:  # wanderer — all default 10, modifiers = 0
			pass
	# Apply stat effects to derived combat/survival values.
	actor.power       += actor.str_mod           # STR  → melee damage bonus
	actor.max_hp      += actor.con_mod * 3       # CON  → bonus hit points
	actor.hp           = actor.max_hp
	actor.thirst_rate  = maxf(0.1, 1.0 - actor.con_mod * 0.1)  # CON → slower dehydration


func _drain_thirst() -> void:
	if game_over or GameState.god_mode:
		return
	# Thirst is shared across the whole party — one bar represents everyone.
	# Check adjacency using the player's position as the party's reference point.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = player.pos.x + dx
			var ny: int = player.pos.y + dy
			if map.is_in_bounds(nx, ny) and \
					map.tiles[ny][nx] == GameMapClass.TILE_WATER:
				if player.thirst > 0:
					player.thirst   = 0
					_thirst_acc     = 0.0
					add_msg("You cup water from the spring and drink deeply.")
				return

	# Fractional accumulator — CON modifier slows dehydration via thirst_rate.
	_thirst_acc += player.thirst_rate
	while _thirst_acc >= 1.0:
		_thirst_acc   -= 1.0
		player.thirst  = mini(player.thirst + 1, ActorClass.THIRST_MAX)
	var t: int    = player.thirst
	var tmax: int = ActorClass.THIRST_MAX
	if t >= tmax * 9 / 10:
		player.take_damage(1)
		if not player.is_alive:
			add_msg(player.die())
			add_msg("You perish from thirst. Press r to try again.")
			game_over = true
		elif t % 60 == 0:
			add_msg("Your lips crack. You are dying of thirst!")
	elif t == tmax * 7 / 10:
		add_msg("Your throat is parched. Find water soon.")
	elif t == tmax / 2:
		add_msg("You are very thirsty.")
	elif t == tmax * 3 / 10:
		add_msg("You are thirsty.")


func _drain_fatigue() -> void:
	if game_over or GameState.god_mode:
		return
	# Fatigue is shared across the whole party — one bar represents everyone.
	if _resting:
		# CON modifier improves rest recovery (min 1 point even with CON penalty).
		player.fatigue = maxi(0, player.fatigue - maxi(1, 3 + player.con_mod))
		return

	var drain: int = 1
	if depth == 0 and is_night:
		drain += 1  # night travel is more disorienting and tiring
	player.fatigue = mini(player.fatigue + drain, ActorClass.FATIGUE_MAX)

	var f: int    = player.fatigue
	var fmax: int = ActorClass.FATIGUE_MAX
	if f >= fmax * 9 / 10:
		player.take_damage(1)
		if not player.is_alive:
			add_msg(player.die())
			add_msg("You collapse from exhaustion. Press r to try again.")
			game_over = true
		elif f % 60 == 0:
			add_msg("Your legs give out beneath you. You must rest!")
	elif f == fmax * 7 / 10:
		add_msg("Your feet drag. You need to rest soon.")
	elif f == fmax / 2:
		add_msg("You are very tired.")
	elif f == fmax * 3 / 10:
		add_msg("You are weary.")


# ===========================================================================
# Chunk encounters (overworld only)
# ===========================================================================

# Called once when a fresh (never-visited) overworld chunk is generated.
# Rolls for and pre-places encounter entities so the player discovers them
# naturally through FOV rather than watching them appear from thin air.
func _place_chunk_encounter(target_map, target_chunk: Vector2i, player_entry: Vector2i) -> void:
	if is_village_chunk(target_chunk.x, target_chunk.y):
		return

	var biome: int   = get_chunk_biome(target_chunk)
	var is_road: bool = is_road_chunk(target_chunk.x, target_chunk.y)

	# Bandit chance — higher at night and in hostile biomes.
	var bandit_chance: float = 0.15 if is_night else 0.07
	if biome == GameMapClass.BIOME_BADLANDS:
		bandit_chance *= 1.6
	elif biome == GameMapClass.BIOME_MOUNTAINS:
		bandit_chance *= 1.3

	# Traveling merchant — roads only, daytime.
	var merchant_chance: float = 0.25 if (is_road and not is_night) else 0.0

	var roll: float = randf()
	if roll < bandit_chance:
		_place_bandits_in(target_map, player_entry)
	elif roll < bandit_chance + merchant_chance:
		_place_merchant_in(target_map, player_entry)


# Returns a random walkable position at least min_dist tiles from player_entry,
# or Vector2i(-1,-1) if no suitable tile is found after max_attempts tries.
func _find_encounter_pos(target_map, player_entry: Vector2i, min_dist: int = 20) -> Vector2i:
	for _attempt in range(60):
		var tx: int = randi_range(5, OVERWORLD_W - 6)
		var ty: int = randi_range(5, OVERWORLD_H - 6)
		if not target_map.is_walkable(tx, ty):
			continue
		if target_map.get_blocking_entity_at(tx, ty) != null:
			continue
		var d: float = Vector2(tx, ty).distance_to(Vector2(player_entry))
		if d < min_dist:
			continue
		return Vector2i(tx, ty)
	return Vector2i(-1, -1)


# Places 1–2 desert bandits in target_map, away from the player entry point.
func _place_bandits_in(target_map, player_entry: Vector2i) -> void:
	var count: int = randi_range(1, 2)
	for _i in range(count):
		var pos: Vector2i = _find_encounter_pos(target_map, player_entry)
		if pos.x == -1:
			return
		var bandit := ActorClass.new(pos, "B", Color(0.72, 0.32, 0.20),
				"desert bandit", 12, 1, 3)
		bandit.ai       = HostileAIClass.new(bandit)
		bandit.game_map = target_map
		target_map.entities.append(bandit)


# Places a lone traveling merchant in target_map, away from the player entry point.
func _place_merchant_in(target_map, player_entry: Vector2i) -> void:
	var pos: Vector2i = _find_encounter_pos(target_map, player_entry)
	if pos.x == -1:
		return
	var npc_data: Dictionary = NpcDataClass.get_npc("merchant")
	var npc := NpcClass.new(pos, "merchant", npc_data)
	npc.ai       = DocileAIClass.new(npc, 0.25, false)  # travels day and night; flees if attacked
	npc.game_map = target_map
	target_map.entities.append(npc)


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
