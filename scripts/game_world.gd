class_name GameWorld
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal turn_ended(turn_number: int)  # emitted every turn — hook day/night, events, etc.
signal map_changed()                  # emitted on any floor/chunk transition or new game
signal attribute_points_changed(unspent_points: int)
signal entity_attacked(attacker_pos: Vector2i, target_pos: Vector2i, glyph: String, color: Color)
signal entity_fired(attacker_pos: Vector2i, target_pos: Vector2i, projectile_char: String, projectile_color: Color)

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
const OVERWORLD_W: int   = 100
const OVERWORLD_H: int   = 100
const DEBUG_HUB_W: int   = 120
const DEBUG_HUB_H: int   = 44
const FOV_RADIUS: int    = 6
const FOV_OVERWORLD: int = 24   # daytime overworld sight range
const FOV_NIGHT: int     = 3    # night-time overworld sight range — dangerous, but not blind
const MSG_MAX: int       = 3
const ACTION_COST_BASE: int = 100
const MOVE_COST_FOOT: int = 100
const MOVE_COST_MOUNTED: int = 70
const ACTION_COST_STANDARD: int = 100
const WORLD_MAP_TRAVEL_COST_BASE: int = 100
const WORLD_MAP_TRAVEL_COST_MIN: int = 60
const WORLD_MAP_THREAT_RANGE: int = 8

# Turns of thirst/fatigue drain applied per chunk moved on the world map.
# One chunk = 10 miles; at 3 mph that is ~3.3 hours = ~100 turns.
const TURNS_PER_CHUNK_TRAVEL: int = 100
const XP_FLOOR_DISCOVERY: int = 25
const XP_KILL_WEAK: int = 10
const XP_KILL_DANGEROUS: int = 20
const TRAVEL_EVENT_NONE: String = ""
const TRAVEL_EVENT_MERCHANT: String = "traveling_merchant"
const TRAVEL_EVENT_BANDITS: String = "bandit_ambush"

# Day/night — one in-game day = TURNS_PER_DAY player actions.
# Tile: 0.1 miles (528 ft).  Walking pace: 3 mph → 2 min/tile → 720 turns/day.
# Chunk: 100×100 tiles = 10×10 miles (≈ a tighter local territory scale).
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
var _fatigue_acc: float = 0.0        # fractional fatigue accumulator for rate < 1.0
var _turn_progress_accum: int = 0
var _enemy_turn_accum: int = 0
var pending_travel_event: Dictionary = {}
var debug_hub_active: bool = false
var debug_return_depth: int = 0
var debug_return_chunk: Vector2i = Vector2i.ZERO
var debug_return_pos: Vector2i = Vector2i.ZERO


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


func cleanup() -> void:
	_break_ai_refs_in_map(map)
	for stored_map in floors.values():
		_break_ai_refs_in_map(stored_map)
	for stored_chunk in chunks.values():
		_break_ai_refs_in_map(stored_chunk)
	map = null
	player = null
	party.clear()
	floors.clear()
	chunks.clear()
	messages.clear()
	nearby_npc = null
	pending_travel_event.clear()


func _break_ai_refs_in_map(target_map) -> void:
	if target_map == null:
		return
	for e in target_map.entities:
		if e is ActorClass and e.ai != null:
			e.ai.actor = null
			e.ai.world = null
			e.ai = null
	target_map.entities.clear()


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
	_turn_progress_accum = 0
	_enemy_turn_accum = 0
	_fatigue_acc = 0.0
	pending_travel_event.clear()
	debug_hub_active = false
	debug_return_depth = 0
	debug_return_chunk = Vector2i.ZERO
	debug_return_pos = Vector2i.ZERO
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
	ow_map.add_entity(dungeon_entry)

	var spawn_pos: Vector2i = _walk_toward_center(ow_map, entrance_pos, 6)
	player = ActorClass.new(spawn_pos, "@", Color(0.80, 0.72, 0.55), "you", 30, 2, 5)
	_apply_archetype(player, GameState.player_class)
	player.xp = 0
	player.xp_to_next = _xp_threshold_for_level(player.level)
	player.unspent_attribute_points = 0
	ow_map.add_entity(player)
	map   = ow_map
	party = [player]

	# Player starts with one torch in their pack.
	var starting_torch := ItemClass.new(player.pos, ItemClass.TYPE_TORCH, 0)
	player.inventory.append(starting_torch)
	_grant_starting_gear(player, GameState.player_class)
	_place_starting_mount(ow_map, player.pos)

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
	pending_travel_event.clear()
	debug_hub_active = false
	messages.clear()
	var result := SaveManagerClass.restore(data, FOV_RADIUS)
	map    = result[0]
	player = result[1]
	depth  = result[2]
	floors = result[3]
	chunk  = result[4]
	chunks = result[5]
	turn   = result[6]
	_turn_progress_accum = 0
	_enemy_turn_accum = 0
	_fatigue_acc = 0.0
	var debug_data: Dictionary = result[7]
	debug_hub_active = bool(debug_data.get("active", false))
	debug_return_depth = int(debug_data.get("return_depth", 0))
	debug_return_chunk = Vector2i(int(debug_data.get("return_chunk_x", 0)), int(debug_data.get("return_chunk_y", 0)))
	debug_return_pos = Vector2i(int(debug_data.get("return_pos_x", 0)), int(debug_data.get("return_pos_y", 0)))
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
	var debug_data := {
		"active": debug_hub_active,
		"return_depth": debug_return_depth,
		"return_chunk_x": debug_return_chunk.x,
		"return_chunk_y": debug_return_chunk.y,
		"return_pos_x": debug_return_pos.x,
		"return_pos_y": debug_return_pos.y,
	}
	SaveManagerClass.save_game(map, player, depth, floors, chunk, chunks, turn, debug_data)


func has_pending_travel_event() -> bool:
	return not pending_travel_event.is_empty()


func can_use_debug_tools() -> bool:
	return GameState.debug_tools_enabled


func toggle_debug_hub() -> void:
	if not can_use_debug_tools():
		add_msg("Debug tools are disabled.")
		return
	if debug_hub_active:
		exit_debug_hub()
	else:
		enter_debug_hub()


func ignore_pending_travel_event() -> void:
	if pending_travel_event.is_empty():
		return
	var event_type: String = str(pending_travel_event.get("type", TRAVEL_EVENT_NONE))
	pending_travel_event.clear()
	if event_type == TRAVEL_EVENT_MERCHANT:
		add_msg("You keep your distance and continue on your way.")
	else:
		add_msg("You press on.")


func attempt_pending_travel_flee() -> Dictionary:
	if pending_travel_event.is_empty() or not bool(pending_travel_event.get("can_flee", false)):
		return {"resolved": false}

	var dc: int = 12
	if bool(pending_travel_event.get("is_road", false)):
		dc -= 2
	if is_night:
		dc += 2
	if player.fatigue >= ActorClass.FATIGUE_MAX * 7 / 10:
		dc += 2

	var roll: int = randi_range(1, 20) + player.dex_mod
	var dex_str: String = ("%+d" % player.dex_mod)
	if roll >= dc:
		pending_travel_event.clear()
		add_msg("You slip away before the trap can close. [1d20%s = %d vs DC %d]" %
				[dex_str, roll, dc])
		return {"resolved": true, "entered": false}

	add_msg("You fail to break away. The threat closes in. [1d20%s = %d vs DC %d]" %
			[dex_str, roll, dc])
	enter_pending_travel_event()
	return {"resolved": true, "entered": true}


func enter_pending_travel_event() -> void:
	if pending_travel_event.is_empty():
		return
	var event_data: Dictionary = pending_travel_event.duplicate(true)
	pending_travel_event.clear()

	var entry_dir: Vector2i = event_data.get("entry_dir", Vector2i.ZERO)
	player.pos = _nearest_walkable_overworld_pos(map, _world_map_entry_pos(entry_dir))
	_place_travel_event_in_map(map, event_data, player.pos)
	_recompute_fov()
	if event_data.get("type", TRAVEL_EVENT_NONE) == TRAVEL_EVENT_MERCHANT:
		add_msg("You turn off the road to meet the travelers.")
	else:
		add_msg("You are forced into the encounter.")
	map_changed.emit()


# ===========================================================================
# Turn loop
# ===========================================================================

func do_player_turn(dir: Vector2i, force_attack: bool = false) -> void:
	_resting = (dir == Vector2i.ZERO)
	var action_cost: int = ACTION_COST_STANDARD if dir == Vector2i.ZERO else get_move_action_cost(dir)
	if dir != Vector2i.ZERO:
		var next: Vector2i = player.pos + dir
		if not map.is_in_bounds(next.x, next.y):
			if map.map_type == GameMapClass.MAP_OVERWORLD:
				chunk_transition(dir, action_cost)
			return

		var target = map.get_blocking_entity_at(next.x, next.y)
		if target != null:
			if target is NpcClass and (target as NpcClass).is_alive:
				var npc: NpcClass = target as NpcClass
				if force_attack or npc.is_angered:
					_player_attack_target(npc)
				else:
					nearby_npc = target
					if npc.is_wildlife:
						add_msg(npc.greet())   # observation text in log; no dialogue panel
			elif target is ActorClass and (target as ActorClass).is_alive:
				_player_attack_target(target as ActorClass)
		elif map.is_walkable(next.x, next.y):
			map.move_entity(player, next)
			_sync_mount_position()
			nearby_npc = null
			if GameState.auto_pickup:
				auto_pickup()
			_check_stairs()
			_check_debug_fixture()
		else:
			return  # wall — no turn consumed

	resolve_action(action_cost)


func _player_attack_target(target: ActorClass) -> void:
	entity_attacked.emit(player.pos, target.pos, str(player.char), player.color)
	add_msg(player.attack(target))
	if not GameState.god_mode:
		player.fatigue = mini(player.fatigue + 2, ActorClass.FATIGUE_MAX)
	if GameState.god_mode and target.is_alive:
		target.take_damage(target.hp)
	if target is NpcClass and target.is_alive:
		_on_npc_attacked(target as NpcClass)
	if not target.is_alive:
		_award_kill_xp(target)
		add_msg(target.die())
		map.refresh_entity(target)


func _on_npc_attacked(npc: NpcClass) -> void:
	if npc == null or not npc.is_alive:
		return
	if not npc.is_angered:
		npc.is_angered = true
		match npc.on_attacked:
			"flee":
				var dai := DocileAIClass.new(npc, float(NpcDataClass.get_npc(npc.npc_type).get("move_chance", 0.35)), not npc.is_wildlife)
				dai._fleeing = true
				dai._last_hp = npc.hp
				npc.ai = dai
				add_msg("The %s panics and tries to flee!" % npc.name)
			_:
				npc.ai = HostileAIClass.new(npc)
				add_msg("The %s turns hostile!" % npc.name)
	elif npc.on_attacked == "retaliate" and not (npc.ai is HostileAIClass):
		npc.ai = HostileAIClass.new(npc)


func get_equipped_ranged_weapon():
	return player.equipped.get(ItemClass.SLOT_RANGED)


func get_matching_ammo(weapon = null):
	var ranged_weapon = weapon if weapon != null else get_equipped_ranged_weapon()
	if ranged_weapon == null:
		return null
	for item in player.inventory:
		if item.category == ItemClass.CATEGORY_AMMO and item.item_type == (ranged_weapon as ItemClass).ammo_type and item.stack_count() > 0:
			return item
	return null


func can_fire_ranged() -> bool:
	return get_equipped_ranged_weapon() != null and get_matching_ammo() != null


func get_ranged_targets() -> Array:
	var weapon = get_equipped_ranged_weapon()
	if weapon == null:
		return []
	var result: Array = []
	for e in map.entities:
		if not (e is ActorClass) or e == player or not e.is_alive:
			continue
		if not map.visible[e.pos.y][e.pos.x]:
			continue
		if _cheb(player.pos, e.pos) > int((weapon as ItemClass).weapon_range):
			continue
		if _first_actor_on_line(player.pos, e.pos) == e:
			result.append(e)
	result.sort_custom(func(a, b): return _cheb(player.pos, a.pos) < _cheb(player.pos, b.pos))
	return result


func fire_ranged_at(target_pos: Vector2i) -> void:
	var weapon = get_equipped_ranged_weapon()
	if weapon == null:
		add_msg("You have no ranged weapon ready.")
		return
	var ammo = get_matching_ammo(weapon)
	if ammo == null:
		add_msg("You have no ammunition for the %s." % (weapon as ItemClass).name)
		return
	if not map.is_in_bounds(target_pos.x, target_pos.y):
		add_msg("You cannot fire there.")
		return
	if _cheb(player.pos, target_pos) > int((weapon as ItemClass).weapon_range):
		add_msg("That is beyond the reach of your %s." % (weapon as ItemClass).name)
		return

	_consume_ammo(ammo)
	entity_fired.emit(player.pos, target_pos, str((ammo as ItemClass).char), (ammo as ItemClass).color)
	var hit_actor = _first_actor_on_line(player.pos, target_pos)
	if hit_actor == null:
		add_msg("You loose a shot into empty ground.")
		resolve_action(ACTION_COST_STANDARD)
		return

	add_msg(player.ranged_attack(hit_actor, weapon as ItemClass, ammo as ItemClass))
	if not GameState.god_mode:
		player.fatigue = mini(player.fatigue + 1, ActorClass.FATIGUE_MAX)
	if GameState.god_mode and hit_actor.is_alive:
		hit_actor.take_damage(hit_actor.hp)
	if hit_actor is NpcClass and hit_actor.is_alive:
		_on_npc_attacked(hit_actor as NpcClass)
	if not hit_actor.is_alive:
		_award_kill_xp(hit_actor)
		add_msg(hit_actor.die())
		map.refresh_entity(hit_actor)
	resolve_action(ACTION_COST_STANDARD)


func _consume_ammo(ammo: ItemClass) -> void:
	if ammo == null:
		return
	ammo.value = maxi(0, ammo.value - 1)
	if ammo.stack_count() <= 0:
		player.inventory.erase(ammo)


func _first_actor_on_line(from_pos: Vector2i, to_pos: Vector2i):
	var line: Array = _bresenham_line(from_pos, to_pos)
	for i in range(1, line.size()):
		var pos: Vector2i = line[i]
		if not map.is_in_bounds(pos.x, pos.y):
			return null
		if not map.is_transparent(pos.x, pos.y):
			return null
		var actor_on_tile = map.get_blocking_entity_at(pos.x, pos.y)
		if actor_on_tile is ActorClass and actor_on_tile != player and (actor_on_tile as ActorClass).is_alive:
			return actor_on_tile
	return null


func _bresenham_line(from_pos: Vector2i, to_pos: Vector2i) -> Array:
	var points: Array = []
	var x0: int = from_pos.x
	var y0: int = from_pos.y
	var x1: int = to_pos.x
	var y1: int = to_pos.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return points


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func do_enemy_turns() -> void:
	var night: bool = is_night
	for e in map.entities.duplicate():
		if not (e is ActorClass):
			continue
		if e == player or not e.is_alive or e.ai == null or e.is_mounted:
			continue
		e.ai.world = self
		# Push current time-of-day so AI can honour diurnal schedules.
		if e.ai is WanderAIClass:
			(e.ai as WanderAIClass).world_is_night = night
		elif e.ai is DocileAIClass:
			(e.ai as DocileAIClass).world_is_night = night
		# Emit before the turn so the renderer can start the bump animation.
		if e.ai is HostileAIClass:
			var ddx: int = player.pos.x - e.pos.x
			var ddy: int = player.pos.y - e.pos.y
			if maxi(absi(ddx), absi(ddy)) <= 1:
				entity_attacked.emit(e.pos, player.pos, str(e.char), e.color)
		var msg: String = e.ai.take_turn(player, map)
		if msg != "":
			add_msg(msg)
		if not player.is_alive:
			if GameState.god_mode:
				player.hp = player.max_hp
			else:
				add_msg(player.die())
				map.refresh_entity(player)
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
	if debug_hub_active:
		# The debug hub is a fixed test room, not a gameplay stealth space.
		# Revealing it wholesale avoids an expensive full-room LOS pass every turn.
		map.reveal_all()
		return
	elif map.map_type == GameMapClass.MAP_OVERWORLD:
		base_fov = overworld_fov()
	else:
		base_fov = FOV_RADIUS
	var fov: int = maxi(base_fov, player_light_fov())
	map.compute_fov(player.pos.x, player.pos.y, fov)
	# Expand FOV for static light fixtures (braziers, road torches) whose light
	# pool reaches the player — checked by distance, not prior visibility, so
	# their glow is perceptible before the player can see the fixture directly.
	for e in map.entities:
		if e.light_radius <= 0 or not map.is_in_bounds(e.pos.x, e.pos.y):
			continue
		var dx: int = absi(e.pos.x - player.pos.x)
		var dy: int = absi(e.pos.y - player.pos.y)
		if maxi(dx, dy) <= fov + e.light_radius:
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


func resolve_action(action_cost: int = ACTION_COST_STANDARD) -> void:
	_enemy_turn_accum += action_cost
	while _enemy_turn_accum >= ACTION_COST_BASE and not game_over:
		_enemy_turn_accum -= ACTION_COST_BASE
		do_enemy_turns()
	end_turn(action_cost)


func end_turn(action_cost: int = ACTION_COST_STANDARD) -> void:
	_recompute_fov()
	_turn_progress_accum += action_cost
	while _turn_progress_accum >= ACTION_COST_BASE:
		_turn_progress_accum -= ACTION_COST_BASE
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
			for e in map.get_entities_at(check_pos.x, check_pos.y):
				if e is NpcClass and not (e as NpcClass).is_alive \
						and (e as NpcClass).is_wildlife:
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
	add_msg("You kneel beside the %s and begin skinning." % corpse_type)

	# d20 + WIS modifier; WIS knowledge of anatomy improves yield.
	var roll: int   = randi_range(1, 20) + player.wis_mod
	var tier: String
	if   roll >= 20: tier = "crit"
	elif roll >= 16: tier = "great"
	elif roll >= 11: tier = "good"
	elif roll >=  6: tier = "poor"
	else:            tier = "spoiled"

	var loot_pos: Vector2i = corpse.pos
	map.remove_entity(corpse)

	var wis_str: String = ("+%d" % player.wis_mod) if player.wis_mod >= 0 else str(player.wis_mod)
	var result_msg: String = ""
	if tier == "spoiled" or not skin_table.has(tier):
		result_msg = "You butcher the %s but ruin the yield. [d20%s = %d]" \
				% [corpse_type, wis_str, roll]
		add_msg(result_msg)
	else:
		var loot: Array             = skin_table[tier]
		var names: PackedStringArray = []
		for entry in loot:
			var item_type: String = str(entry["item_type"])
			var qty: int          = int(entry.get("qty", 1))
			for _i in range(qty):
				var item := ItemClass.new(loot_pos, item_type, 0)
				map.add_entity(item)
			var display: String = str(ItemDataClass.get_item(item_type).get("name", item_type))
			names.append("%dx %s" % [qty, display] if qty > 1 else display)
		result_msg = "You skin the %s: %s. [d20%s = %d]" \
				% [corpse_type, ", ".join(names), wis_str, roll]
		add_msg(result_msg)
		if GameState.auto_pickup:
			auto_pickup()

	# Skinning consumes a turn.
	_resting = false
	resolve_action(ACTION_COST_STANDARD)


func auto_pickup() -> void:
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if not (e is ItemClass):
			continue
		if e.item_type == ItemClass.TYPE_GOLD:
			player.gold += e.value
			add_msg("You collect %d gold." % e.value)
			map.remove_entity(e)
		elif player.can_carry(e):
			player.inventory.append(e)
			var item_idx: int = player.inventory.size() - 1
			if item_idx < 26:
				var slot := char(ord("a") + item_idx)
				add_msg("You pick up the %s. [%s]" % [e.name, slot])
			else:
				add_msg("You pick up the %s." % e.name)
			map.remove_entity(e)
		else:
			add_msg("The %s would put you over your carry limit." % e.name)


func get_player_mount():
	for e in map.entities:
		if e != player and e is ActorClass and e.is_mounted:
			return e
	return null


func get_move_action_cost(_dir: Vector2i = Vector2i.ZERO) -> int:
	var mount = get_player_mount()
	if mount != null:
		return MOVE_COST_MOUNTED
	return MOVE_COST_FOOT


func get_move_cost_label() -> String:
	var speed_mult: float = float(ACTION_COST_BASE) / float(get_move_action_cost())
	return "%.1fx" % speed_mult


func get_world_map_travel_cost(target_chunk: Vector2i) -> int:
	var cost: float = float(WORLD_MAP_TRAVEL_COST_BASE)
	if get_player_mount() != null:
		cost *= 0.75
	if is_road_chunk(target_chunk.x, target_chunk.y):
		cost *= 0.90
	return maxi(WORLD_MAP_TRAVEL_COST_MIN, int(round(cost)))


func toggle_mount() -> void:
	if game_over:
		return
	var current_mount = get_player_mount()
	if current_mount != null:
		_dismount(current_mount as ActorClass)
		return

	var mount = _find_adjacent_mount()
	if mount == null:
		add_msg("There is no mountable beast beside you.")
		return
	_mount(mount)


func _find_adjacent_mount():
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			for e in map.get_entities_at(player.pos.x + dx, player.pos.y + dy):
				if e is ActorClass and e.is_alive and e.is_mountable and not e.is_mounted:
					return e
	return null


func _mount(mount: ActorClass) -> void:
	map.move_entity(mount, player.pos)
	mount.is_mounted = true
	mount.blocks_movement = false
	mount.ai = null
	map.refresh_entity(mount)
	add_msg("You mount the %s." % mount.name)
	_resting = false
	resolve_action(ACTION_COST_STANDARD)


func _dismount(mount: ActorClass) -> void:
	var dismount_pos := _find_dismount_pos()
	if dismount_pos == Vector2i(-1, -1):
		add_msg("There is no room to dismount here.")
		return
	map.move_entity(mount, dismount_pos)
	mount.is_mounted = false
	mount.blocks_movement = true
	_restore_mount_ai(mount)
	map.refresh_entity(mount)
	add_msg("You dismount the %s." % mount.name)
	_resting = false
	resolve_action(ACTION_COST_STANDARD)


func _find_dismount_pos() -> Vector2i:
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for dir: Vector2i in dirs:
		var pos: Vector2i = player.pos + dir
		if not map.is_in_bounds(pos.x, pos.y) or not map.is_walkable(pos.x, pos.y):
			continue
		if map.get_blocking_entity_at(pos.x, pos.y) != null:
			continue
		return pos
	return Vector2i(-1, -1)


func _restore_mount_ai(mount: ActorClass) -> void:
	if mount is NpcClass:
		var npc := mount as NpcClass
		var move_chance: float = float(NpcDataClass.get_npc(npc.npc_type).get("move_chance", 0.35))
		if npc.is_angered and npc.on_attacked == "retaliate":
			npc.ai = HostileAIClass.new(npc)
		elif npc.is_angered and npc.on_attacked == "flee":
			var dai := DocileAIClass.new(npc, move_chance, not npc.is_wildlife)
			dai._fleeing = true
			dai._last_hp = npc.hp
			npc.ai = dai
		elif npc.is_wildlife or npc.npc_type == "merchant" or npc.npc_type == "donkey":
			npc.ai = DocileAIClass.new(npc, move_chance, not npc.is_wildlife)
		else:
			npc.ai = null


func _sync_mount_position() -> void:
	var current_mount = get_player_mount()
	if current_mount != null and current_mount.pos != player.pos:
		map.move_entity(current_mount, player.pos)


func _place_starting_mount(target_map, origin: Vector2i) -> void:
	var spawn_pos := _find_adjacent_open_tile(target_map, origin)
	if spawn_pos == Vector2i(-1, -1):
		return
	var donkey_data: Dictionary = NpcDataClass.get_npc("donkey")
	var donkey := NpcClass.new(spawn_pos, "donkey", donkey_data)
	donkey.home_chunk = chunk
	donkey.ai = DocileAIClass.new(donkey, float(donkey_data.get("move_chance", 0.20)), true)
	target_map.add_entity(donkey)


func _find_adjacent_open_tile(target_map, origin: Vector2i) -> Vector2i:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var pos := origin + Vector2i(dx, dy)
			if not target_map.is_in_bounds(pos.x, pos.y):
				continue
			if not target_map.is_walkable(pos.x, pos.y):
				continue
			if target_map.get_blocking_entity_at(pos.x, pos.y) != null:
				continue
			return pos
	return Vector2i(-1, -1)


func autoexplore(max_steps: int = 256) -> void:
	if game_over:
		return
	if _visible_hostile_exists():
		add_msg("Autoexplore stops: danger is already in sight.")
		return

	var moved: bool = false
	for _i in range(max_steps):
		var dir: Vector2i = _next_autoexplore_step()
		if dir == Vector2i.ZERO:
			add_msg("Autoexplore complete." if moved else "There is nothing left to explore.")
			return
		do_player_turn(dir)
		moved = true
		if game_over:
			return
		if _visible_hostile_exists():
			add_msg("Autoexplore stops: danger spotted.")
			return
	add_msg("Autoexplore pauses.")


func travel_to(target: Vector2i, max_steps: int = 512) -> void:
	if game_over:
		return
	if not map.is_in_bounds(target.x, target.y):
		return
	if target == player.pos:
		return
	if _visible_hostile_exists():
		add_msg("Travel stops: danger is already in sight.")
		return

	var path: Array = _path_to(target, true)
	if path.is_empty():
		add_msg("You cannot find a clear path there.")
		return

	var moved: bool = false
	var steps_taken: int = 0
	for step in path:
		if steps_taken >= max_steps:
			add_msg("Travel pauses.")
			return
		var next_pos: Vector2i = step
		var dir: Vector2i = next_pos - player.pos
		if maxi(absi(dir.x), absi(dir.y)) > 1:
			break
		do_player_turn(dir)
		moved = true
		steps_taken += 1
		if game_over:
			return
		if _visible_hostile_exists():
			add_msg("Travel stops: danger spotted.")
			return
		if player.pos == target:
			return
	if not moved:
		add_msg("You cannot find a clear path there.")


func _next_autoexplore_step() -> Vector2i:
	var path: Array = _path_to_nearest_unexplored()
	if path.is_empty():
		return Vector2i.ZERO
	return path[0] - player.pos


func _path_to_nearest_unexplored() -> Array:
	var start: Vector2i = player.pos
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var came_from: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for dir: Vector2i in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if not map.is_in_bounds(next.x, next.y) or not map.is_walkable(next.x, next.y):
				continue
			var blocker = map.get_blocking_entity_at(next.x, next.y)
			if blocker != null and next != player.pos:
				continue
			visited[next] = true
			came_from[next] = current
			if not map.explored[next.y][next.x]:
				return _reconstruct_path(came_from, start, next)
			frontier.append(next)
	return []


func _path_to(target: Vector2i, require_explored: bool = false) -> Array:
	var start: Vector2i = player.pos
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var came_from: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == target:
			return _reconstruct_path(came_from, start, target)
		for dir: Vector2i in dirs:
			var next: Vector2i = current + dir
			if visited.has(next):
				continue
			if not map.is_in_bounds(next.x, next.y) or not map.is_walkable(next.x, next.y):
				continue
			if require_explored and not map.explored[next.y][next.x] and next != target:
				continue
			var blocker = map.get_blocking_entity_at(next.x, next.y)
			if blocker != null and next != target:
				continue
			visited[next] = true
			came_from[next] = current
			frontier.append(next)
	return []


func _reconstruct_path(came_from: Dictionary, start: Vector2i, target: Vector2i) -> Array:
	var path: Array = []
	var current: Vector2i = target
	while current != start:
		path.push_front(current)
		if not came_from.has(current):
			return []
		current = came_from[current]
	return path


func _visible_hostile_exists() -> bool:
	for e in map.entities:
		if e == player or not (e is ActorClass) or not e.is_alive:
			continue
		if e.ai is HostileAIClass and map.visible[e.pos.y][e.pos.x]:
			return true
	return false


func hostile_within_world_map_range() -> bool:
	for e in map.entities:
		if e == player or not (e is ActorClass) or not e.is_alive:
			continue
		if not (e.ai is HostileAIClass):
			continue
		if not map.visible[e.pos.y][e.pos.x]:
			continue
		if maxi(absi(e.pos.x - player.pos.x), absi(e.pos.y - player.pos.y)) <= WORLD_MAP_THREAT_RANGE:
			return true
	return false


func can_enter_world_map() -> bool:
	return depth == 0 and not hostile_within_world_map_range()


func _player_on_stairs() -> bool:
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if e is ActorClass:
			continue
		if e.char == ">" or e.char == "<":
			return true
	return false


func _item_at_player_pos() -> bool:
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if e is ItemClass:
			return true
	return false


func add_msg(text: String) -> void:
	messages.append(text)
	if messages.size() > MSG_MAX:
		messages = messages.slice(messages.size() - MSG_MAX)


func get_overworld_global_pos(local_pos: Vector2i, chunk_pos: Vector2i = chunk) -> Vector2i:
	return Vector2i(chunk_pos.x * OVERWORLD_W + local_pos.x, chunk_pos.y * OVERWORLD_H + local_pos.y)


func get_npc_home_global_pos(npc: NpcClass) -> Vector2i:
	return Vector2i(npc.home_chunk.x * OVERWORLD_W + npc.home_pos.x, npc.home_chunk.y * OVERWORLD_H + npc.home_pos.y)


func _get_or_create_overworld_chunk(chunk_pos: Vector2i):
	if chunks.has(chunk_pos):
		return chunks[chunk_pos]
	var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
	ProcgenClass.generate_overworld(new_map,
			chunk_pos.x * OVERWORLD_W, chunk_pos.y * OVERWORLD_H,
			GameState.world_seed, get_chunk_biome(chunk_pos), false,
			get_road_dirs(chunk_pos), is_village_chunk(chunk_pos.x, chunk_pos.y))
	chunks[chunk_pos] = new_map
	return new_map


func get_overworld_step_option(actor: ActorClass, dir: Vector2i, respect_home_radius: bool = false) -> Dictionary:
	if map.map_type != GameMapClass.MAP_OVERWORLD or dir == Vector2i.ZERO:
		return {}
	var next: Vector2i = actor.pos + dir
	var dc := Vector2i.ZERO
	var new_x: int = next.x
	var new_y: int = next.y
	if next.x < 0:
		dc.x = -1
		new_x = OVERWORLD_W - 1
	elif next.x >= OVERWORLD_W:
		dc.x = 1
		new_x = 0
	if next.y < 0:
		dc.y = -1
		new_y = OVERWORLD_H - 1
	elif next.y >= OVERWORLD_H:
		dc.y = 1
		new_y = 0

	var dest_chunk: Vector2i = chunk + dc
	if dest_chunk.x < 0 or dest_chunk.x >= GameState.WORLD_W or dest_chunk.y < 0 or dest_chunk.y >= GameState.WORLD_H:
		return {}

	var dest_map = map if dest_chunk == chunk else _get_or_create_overworld_chunk(dest_chunk)
	if not dest_map.is_walkable(new_x, new_y):
		return {}
	if dest_map.get_blocking_entity_at(new_x, new_y) != null:
		return {}

	var global_pos: Vector2i = get_overworld_global_pos(Vector2i(new_x, new_y), dest_chunk)
	if respect_home_radius and actor is NpcClass:
		var npc: NpcClass = actor as NpcClass
		if maxi(absi(global_pos.x - get_npc_home_global_pos(npc).x), absi(global_pos.y - get_npc_home_global_pos(npc).y)) > npc.wander_radius:
			return {}

	return {
		"dir": dir,
		"chunk": dest_chunk,
		"pos": Vector2i(new_x, new_y),
		"global_pos": global_pos,
		"cross_chunk": dest_chunk != chunk,
	}


func move_overworld_actor(actor: ActorClass, dir: Vector2i, respect_home_radius: bool = false) -> bool:
	var step: Dictionary = get_overworld_step_option(actor, dir, respect_home_radius)
	if step.is_empty():
		return false
	var dest_chunk: Vector2i = step["chunk"]
	var dest_pos: Vector2i = step["pos"]
	if dest_chunk == chunk:
		map.move_entity(actor, dest_pos)
		return true

	map.remove_entity(actor)
	chunks[chunk] = map
	var dest_map = _get_or_create_overworld_chunk(dest_chunk)
	actor.pos = dest_pos
	dest_map.add_entity(actor)
	chunks[dest_chunk] = dest_map
	return true


# ===========================================================================
# Map transitions
# ===========================================================================

func chunk_transition(dir: Vector2i, action_cost: int = ACTION_COST_STANDARD) -> void:
	var current_mount = get_player_mount()
	var next: Vector2i = player.pos + dir
	var dc             := Vector2i.ZERO
	var new_x: int     = next.x
	var new_y: int     = next.y

	if next.x < 0:
		dc.x  = -1;  new_x = OVERWORLD_W - 1
	elif next.x >= OVERWORLD_W:
		dc.x  =  1;  new_x = 0
	if next.y < 0:
		dc.y  = -1;  new_y = OVERWORLD_H - 1
	elif next.y >= OVERWORLD_H:
		dc.y  =  1;  new_y = 0

	var dest_chunk := chunk + dc
	if dest_chunk.x < 0 or dest_chunk.x >= GameState.WORLD_W \
	or dest_chunk.y < 0 or dest_chunk.y >= GameState.WORLD_H:
		add_msg("Beyond this lies only empty horizon. You cannot travel farther.")
		return

	map.remove_entity(player)
	if current_mount != null:
		map.remove_entity(current_mount)
	chunks[chunk] = map
	chunk = dest_chunk

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

	player.pos      = _nearest_walkable_overworld_pos(map, Vector2i(new_x, new_y))
	map.add_entity(player)
	if current_mount != null:
		current_mount.pos = player.pos
		map.add_entity(current_mount)

	_recompute_fov()
	var arrival_v: Variant = get_village_at_chunk(chunk.x, chunk.y)
	if arrival_v != null:
		add_msg("You enter %s." % arrival_v.name)
	else:
		add_msg("You enter the %s." % _biome_label(get_chunk_biome(chunk)))
	resolve_action(action_cost)
	map_changed.emit()


# World-map screen fast-travel: moves one chunk and drains thirst/fatigue
# proportional to the travel time (TURNS_PER_CHUNK_TRAVEL).
func world_map_navigate(dir: Vector2i) -> void:
	var current_mount = get_player_mount()
	var dest := Vector2i(
		clampi(chunk.x + dir.x, 0, GameState.WORLD_W - 1),
		clampi(chunk.y + dir.y, 0, GameState.WORLD_H - 1))
	if dest == chunk:
		return
	var travel_cost: int = get_world_map_travel_cost(dest)

	map.remove_entity(player)
	if current_mount != null:
		map.remove_entity(current_mount)
	chunks[chunk] = map
	chunk = dest

	var is_fresh_chunk: bool = not chunks.has(chunk)
	if chunks.has(chunk):
		map = chunks[chunk]
	else:
		var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
		ProcgenClass.generate_overworld(new_map,
				chunk.x * OVERWORLD_W, chunk.y * OVERWORLD_H,
				GameState.world_seed, get_chunk_biome(chunk), false,
				get_road_dirs(chunk), is_village_chunk(chunk.x, chunk.y))
		map = new_map

	player.pos      = _nearest_walkable_overworld_pos(map, Vector2i(OVERWORLD_W >> 1, OVERWORLD_H >> 1))
	map.add_entity(player)
	if current_mount != null:
		current_mount.pos = player.pos
		map.add_entity(current_mount)

	turn += travel_cost
	_drain_travel(travel_cost)
	pending_travel_event = _roll_world_map_travel_event(chunk, dir, is_fresh_chunk)
	if current_mount != null:
		add_msg("You cover the distance quickly from the saddle. [%d]" % travel_cost)
	elif is_road_chunk(chunk.x, chunk.y):
		add_msg("The road shortens the journey. [%d]" % travel_cost)
	turn_ended.emit(turn)


func try_descend() -> void:
	if get_player_mount() != null:
		add_msg("You should dismount before taking the stairs down.")
		return
	if debug_hub_active:
		add_msg("There are no stairs leading down from the developer's oasis.")
		return
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if not (e is ActorClass) and e.char == ">":
			_descend()
			return


func try_ascend() -> void:
	if get_player_mount() != null and not debug_hub_active:
		add_msg("You should dismount before taking the stairs up.")
		return
	if debug_hub_active:
		exit_debug_hub()
		return
	if depth == 0 and not can_enter_world_map():
		add_msg("Hostiles are too close. You need to get clear before checking the world map.")
		return
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if not (e is ActorClass) and e.char == "<":
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
	map.remove_entity(player)
	if depth == 0:
		chunks[chunk] = map
		depth = 1
	else:
		floors[depth] = map
		depth += 1

	if floors.has(depth):
		map             = floors[depth]
		player.pos      = _stairs_pos(map, "<")
		map.add_entity(player)
	else:
		var new_map = GameMapClass.new(DUNGEON_W, DUNGEON_H)
		player.pos      = Vector2i(0, 0)
		new_map.add_entity(player)
		map = new_map
		var monsters := mini(2 + (depth - 1) >> 1, 4)
		ProcgenClass.generate_dungeon(map, 50, 5, 14, monsters, player, depth)
		var up_stairs := EntityClass.new(player.pos, "<", Color(0.55, 0.80, 0.95), "stairs up", false)
		map.add_entity(up_stairs)
		award_xp(XP_FLOOR_DISCOVERY, "for discovering dungeon floor %d" % depth)

	_recompute_fov()
	add_msg("You descend to floor %d. The air grows heavier." % depth)
	map_changed.emit()


func _ascend() -> void:
	if depth <= 0:
		add_msg("There is nothing above.")
		return
	map.remove_entity(player)
	floors[depth] = map
	depth -= 1

	if depth == 0:
		if chunks.has(chunk):
			map             = chunks[chunk]
			player.pos      = _stairs_pos(map, ">")
			map.add_entity(player)
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
			new_map.add_entity(dungeon_entry)
			player.pos      = entrance_pos
			new_map.add_entity(player)
			map = new_map
	else:
		if floors.has(depth):
			map             = floors[depth]
			player.pos      = _stairs_pos(map, ">")
			map.add_entity(player)

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
	if debug_hub_active:
		return
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if e is ActorClass:
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


func enter_debug_hub() -> void:
	if debug_hub_active:
		return
	if depth == 0:
		chunks[chunk] = map
	else:
		floors[depth] = map
	map.remove_entity(player)
	debug_return_depth = depth
	debug_return_chunk = chunk
	debug_return_pos = player.pos

	var hub_map = GameMapClass.new(DEBUG_HUB_W, DEBUG_HUB_H)
	ProcgenClass.generate_debug_hub(hub_map)
	map = hub_map
	depth = -1
	debug_hub_active = true
	player.pos = Vector2i(8, DEBUG_HUB_H >> 1)
	map.add_entity(player)
	_recompute_fov()
	add_msg("You step into the developer's oasis.")
	add_msg("Quartermaster west. Training center ahead. Arena east. Waystone to return.")
	map_changed.emit()


func exit_debug_hub() -> void:
	if not debug_hub_active:
		return
	map.remove_entity(player)
	depth = debug_return_depth
	chunk = debug_return_chunk

	if depth == 0:
		if chunks.has(chunk):
			map = chunks[chunk]
		else:
			var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
			var is_center: bool = (chunk == Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1))
			ProcgenClass.generate_overworld(new_map,
					chunk.x * OVERWORLD_W, chunk.y * OVERWORLD_H,
					GameState.world_seed, get_chunk_biome(chunk), is_center,
					get_road_dirs(chunk), is_village_chunk(chunk.x, chunk.y))
			map = new_map
			chunks[chunk] = map
	else:
		map = floors.get(depth, map)

	player.pos = debug_return_pos
	map.add_entity(player)
	debug_hub_active = false
	_recompute_fov()
	add_msg("You leave the developer's oasis.")
	map_changed.emit()


func _check_debug_fixture() -> void:
	if not debug_hub_active:
		return
	for e in map.get_entities_at(player.pos.x, player.pos.y):
		if e is ActorClass:
			continue
		match e.name:
			"training obelisk":
				award_xp(100, "from the training obelisk")
				return
			"healing spring":
				player.hp = player.max_hp
				player.thirst = 0
				player.fatigue = maxi(0, player.fatigue - 120)
				_thirst_acc = 0.0
				_fatigue_acc = 0.0
				add_msg("You refresh yourself at the healing spring.")
				return
			"trial brazier":
				player.hp = maxi(1, player.hp - 10)
				player.thirst = mini(ActorClass.THIRST_MAX - 1, ActorClass.THIRST_MAX * 7 / 10)
				player.fatigue = mini(ActorClass.FATIGUE_MAX - 1, ActorClass.FATIGUE_MAX * 7 / 10)
				_thirst_acc = 0.0
				_fatigue_acc = 0.0
				add_msg("Heat and strain wash over you.")
				return
			"speed marker":
				add_msg("Current movement speed: %s. Mounted travel should advance time and enemy turns more slowly." % get_move_cost_label())
				return
			"return waystone":
				exit_debug_hub()
				return
			"bandit marker":
				_spawn_debug_enemy("bandit")
				return
			"raider marker":
				_spawn_debug_enemy("raider")
				return
			"beast marker":
				_spawn_debug_enemy("beast")
				return


func _spawn_debug_enemy(kind: String) -> void:
	var spawn_points: Array[Vector2i] = [
		Vector2i(104, 14), Vector2i(108, 18), Vector2i(104, 22),
		Vector2i(108, 26), Vector2i(104, 30),
	]
	var spawn_pos := Vector2i(-1, -1)
	for pos: Vector2i in spawn_points:
		if map.is_walkable(pos.x, pos.y) and map.get_blocking_entity_at(pos.x, pos.y) == null:
			spawn_pos = pos
			break
	if spawn_pos.x == -1:
		add_msg("The arena is crowded already.")
		return

	var actor: ActorClass
	match kind:
		"bandit":
			actor = ActorClass.new(spawn_pos, "B", Color(0.72, 0.32, 0.20), "desert bandit", 12, 1, 3)
		"raider":
			actor = ActorClass.new(spawn_pos, "r", Color(0.72, 0.22, 0.10), "raider", 16, 1, 4)
		_:
			actor = ActorClass.new(spawn_pos, "B", Color(0.48, 0.32, 0.12), "desert beast", 22, 2, 5)
	actor.ai = HostileAIClass.new(actor)
	map.add_entity(actor)
	add_msg("A %s enters the arena." % actor.name)


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


func _world_map_entry_pos(entry_dir: Vector2i) -> Vector2i:
	var px: int = OVERWORLD_W >> 1
	var py: int = OVERWORLD_H >> 1
	if entry_dir.x > 0:
		px = 0
	elif entry_dir.x < 0:
		px = OVERWORLD_W - 1
	if entry_dir.y > 0:
		py = 0
	elif entry_dir.y < 0:
		py = OVERWORLD_H - 1
	return Vector2i(px, py)


func _nearest_walkable_overworld_pos(target_map, preferred: Vector2i) -> Vector2i:
	if target_map == null:
		return preferred
	var clamped := Vector2i(
		clampi(preferred.x, 0, OVERWORLD_W - 1),
		clampi(preferred.y, 0, OVERWORLD_H - 1)
	)
	if target_map.is_walkable(clamped.x, clamped.y) and target_map.get_blocking_entity_at(clamped.x, clamped.y) == null:
		return clamped
	for radius in range(1, 24):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var nx: int = clamped.x + dx
				var ny: int = clamped.y + dy
				if nx < 0 or nx >= OVERWORLD_W or ny < 0 or ny >= OVERWORLD_H:
					continue
				if not target_map.is_walkable(nx, ny):
					continue
				if target_map.get_blocking_entity_at(nx, ny) != null:
					continue
				return Vector2i(nx, ny)
	return _walk_toward_center(target_map, clamped, 24)


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
	actor.thirst_rate  = maxf(0.1, 1.0 - actor.con_mod * 0.1)   # CON → slower dehydration
	actor.fatigue_rate = maxf(0.4, 0.75 - actor.con_mod * 0.05) # softer baseline fatigue pressure


func _xp_threshold_for_level(level_value: int) -> int:
	return 100 + maxi(0, level_value - 1) * 50


func _grant_starting_gear(actor: ActorClass, class_id: String) -> void:
	match class_id:
		"scout":
			actor.inventory.append(ItemClass.new(actor.pos, ItemClass.TYPE_SLING, 0))
			actor.inventory.append(ItemClass.new(actor.pos, ItemClass.TYPE_SLING_STONE, 0))
		"soldier":
			actor.inventory.append(ItemClass.new(actor.pos, ItemClass.TYPE_SPEAR, 0))


func award_xp(amount: int, reason: String = "") -> void:
	if amount <= 0 or player == null:
		return
	player.xp += amount
	if reason.is_empty():
		add_msg("You gain %d XP." % amount)
	else:
		add_msg("You gain %d XP %s." % [amount, reason])
	_check_level_up()


func _check_level_up() -> void:
	while player.xp >= player.xp_to_next:
		player.xp -= player.xp_to_next
		_apply_level_up()


func _apply_level_up() -> void:
	player.level += 1
	var hp_gain: int = maxi(1, randi_range(1, 6) + player.con_mod)
	player.max_hp += hp_gain
	player.hp = mini(player.max_hp, player.hp + hp_gain)
	player.xp_to_next = _xp_threshold_for_level(player.level)
	add_msg("You advance to level %d." % player.level)
	add_msg("You gain %d max HP." % hp_gain)
	if player.level >= 3 and player.level % 2 == 1:
		player.unspent_attribute_points += 1
		add_msg("Choose an attribute to increase.")
		attribute_points_changed.emit(player.unspent_attribute_points)


func has_unspent_attribute_points() -> bool:
	return player != null and player.unspent_attribute_points > 0


func apply_attribute_increase(stat_name: String) -> bool:
	if not has_unspent_attribute_points():
		return false

	var attr_value: int
	match stat_name:
		"str":
			player.str_score += 1
			attr_value = player.str_score
		"dex":
			player.dex_score += 1
			attr_value = player.dex_score
		"con":
			player.con_score += 1
			attr_value = player.con_score
			player.thirst_rate = maxf(0.1, 1.0 - player.con_mod * 0.1)
			player.fatigue_rate = maxf(0.4, 0.75 - player.con_mod * 0.05)
		"int":
			player.int_score += 1
			attr_value = player.int_score
		"wis":
			player.wis_score += 1
			attr_value = player.wis_score
		"cha":
			player.cha_score += 1
			attr_value = player.cha_score
		_:
			return false

	player.unspent_attribute_points -= 1
	add_msg("Your %s increases to %d." % [_attribute_label(stat_name), attr_value])
	attribute_points_changed.emit(player.unspent_attribute_points)
	return true


func _attribute_label(stat_name: String) -> String:
	match stat_name:
		"str": return "Strength"
		"dex": return "Dexterity"
		"con": return "Constitution"
		"int": return "Intelligence"
		"wis": return "Wisdom"
		"cha": return "Charisma"
		_:     return "Attribute"


func _award_kill_xp(target: ActorClass) -> void:
	if target == null or target == player:
		return
	var amount: int = XP_KILL_DANGEROUS if target.max_hp >= 12 or target.power >= 3 else XP_KILL_WEAK
	award_xp(amount, "for defeating %s" % _xp_target_name(target))


func _xp_target_name(target: ActorClass) -> String:
	return "the %s" % target.name if target.name != "you" else "your foe"


# Apply n turns of thirst + fatigue in one batch — used by world-map travel.
# Skips the per-turn warning cadence; emits a single status message instead.
func _drain_travel(n: int) -> void:
	if game_over or GameState.god_mode:
		return
	# Thirst (overworld only; respects thirst_rate and fractional accumulator).
	var thirst_add: float = player.thirst_rate * n + _thirst_acc
	var thirst_int: int   = int(thirst_add)
	_thirst_acc           = thirst_add - thirst_int
	player.thirst         = mini(player.thirst + thirst_int, ActorClass.THIRST_MAX)
	# Fatigue — night travel costs more.
	var fat_per_turn: float = 1.5 if is_night else 1.0
	var fatigue_add: float = player.fatigue_rate * fat_per_turn * n + _fatigue_acc
	var fatigue_int: int = int(fatigue_add)
	_fatigue_acc = fatigue_add - fatigue_int
	player.fatigue = mini(player.fatigue + fatigue_int, ActorClass.FATIGUE_MAX)
	# Single threshold message after the journey.
	var t: int    = player.thirst
	var f: int    = player.fatigue
	var tmax: int = ActorClass.THIRST_MAX
	var fmax: int = ActorClass.FATIGUE_MAX
	if t >= tmax * 9 / 10:
		add_msg("The journey has left you dangerously parched.")
	elif t >= tmax * 7 / 10:
		add_msg("The journey has left you very thirsty.")
	elif t >= tmax / 2:
		add_msg("The journey has left you thirsty.")
	if f >= fmax * 9 / 10:
		add_msg("The journey has left you near collapse from exhaustion.")
	elif f >= fmax * 7 / 10:
		add_msg("The journey has left you very weary.")
	elif f >= fmax / 2:
		add_msg("The journey has left you tired.")


func _drain_thirst() -> void:
	if GameState.god_mode:
		player.thirst = 0
		_thirst_acc = 0.0
		return
	if game_over:
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
			map.refresh_entity(player)
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
	if GameState.god_mode:
		player.fatigue = 0
		_fatigue_acc = 0.0
		return
	if game_over:
		return
	# Fatigue is shared across the whole party — one bar represents everyone.
	if _resting:
		# CON modifier improves rest recovery (min 1 point even with CON penalty).
		player.fatigue = maxi(0, player.fatigue - maxi(1, 3 + player.con_mod))
		_fatigue_acc = 0.0
		return

	var drain: int = 1
	if depth == 0 and is_night:
		drain += 1  # night travel is more disorienting and tiring
	var fatigue_add: float = player.fatigue_rate * drain + _fatigue_acc
	var fatigue_int: int = int(fatigue_add)
	_fatigue_acc = fatigue_add - fatigue_int
	player.fatigue = mini(player.fatigue + fatigue_int, ActorClass.FATIGUE_MAX)

	var f: int    = player.fatigue
	var fmax: int = ActorClass.FATIGUE_MAX
	if f >= fmax * 9 / 10:
		player.take_damage(1)
		if not player.is_alive:
			add_msg(player.die())
			map.refresh_entity(player)
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

func _roll_world_map_travel_event(target_chunk: Vector2i, dir: Vector2i, is_fresh_chunk: bool) -> Dictionary:
	if not is_fresh_chunk or is_village_chunk(target_chunk.x, target_chunk.y):
		return {}

	var biome: int    = get_chunk_biome(target_chunk)
	var on_road: bool = is_road_chunk(target_chunk.x, target_chunk.y)

	var bandit_chance: float = 0.15 if is_night else 0.07
	if biome == GameMapClass.BIOME_BADLANDS:
		bandit_chance *= 1.6
	elif biome == GameMapClass.BIOME_MOUNTAINS:
		bandit_chance *= 1.3

	var merchant_chance: float = 0.25 if (on_road and not is_night) else 0.0
	var roll: float = randf()
	if roll < bandit_chance:
		return {
			"type": TRAVEL_EVENT_BANDITS,
			"title": "AMBUSH",
			"desc": "Bandits surge from the dunes and move to cut off your path.",
			"entry_dir": dir,
			"dest_chunk": target_chunk,
			"is_road": on_road,
			"can_ignore": false,
			"can_flee": true,
		}
	if roll < bandit_chance + merchant_chance:
		return {
			"type": TRAVEL_EVENT_MERCHANT,
			"title": "ROADSIDE ENCOUNTER",
			"desc": "A merchant caravan is making camp beside the road ahead.",
			"entry_dir": dir,
			"dest_chunk": target_chunk,
			"is_road": on_road,
			"can_ignore": true,
			"can_flee": false,
		}
	return {}


func _place_travel_event_in_map(target_map, event_data: Dictionary, player_entry: Vector2i) -> void:
	match str(event_data.get("type", TRAVEL_EVENT_NONE)):
		TRAVEL_EVENT_BANDITS:
			_place_bandits_in(target_map, player_entry)
		TRAVEL_EVENT_MERCHANT:
			_place_merchant_in(target_map, player_entry)

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
func _find_encounter_pos(target_map, player_entry: Vector2i, min_dist: int = 20, max_dist: int = -1) -> Vector2i:
	var fallback: Vector2i = Vector2i(-1, -1)
	var fallback_dist: float = 999999.0
	for _attempt in range(80):
		var tx: int = randi_range(5, OVERWORLD_W - 6)
		var ty: int = randi_range(5, OVERWORLD_H - 6)
		if not target_map.is_walkable(tx, ty):
			continue
		if target_map.get_blocking_entity_at(tx, ty) != null:
			continue
		var d: float = Vector2(tx, ty).distance_to(Vector2(player_entry))
		if d < min_dist:
			continue
		if max_dist > 0 and d > max_dist:
			if d < fallback_dist:
				fallback = Vector2i(tx, ty)
				fallback_dist = d
			continue
		return Vector2i(tx, ty)
	return fallback


# Places 1–2 desert bandits in target_map, away from the player entry point.
func _place_bandits_in(target_map, player_entry: Vector2i) -> void:
	var count: int = randi_range(1, 2)
	var anchor: Vector2i = _find_encounter_pos(target_map, player_entry, 5, 9)
	if anchor.x == -1:
		return
	for _i in range(count):
		var pos: Vector2i = anchor if _i == 0 else _find_nearby_open_tile(target_map, anchor, 3)
		if pos.x == -1:
			return
		var bandit := ActorClass.new(pos, "B", Color(0.72, 0.32, 0.20),
				"desert bandit", 12, 1, 3)
		bandit.ai       = HostileAIClass.new(bandit)
		target_map.add_entity(bandit)
		anchor = pos


# Places a lone traveling merchant in target_map, away from the player entry point.
func _place_merchant_in(target_map, player_entry: Vector2i) -> void:
	var pos: Vector2i = _find_encounter_pos(target_map, player_entry, 6, 10)
	if pos.x == -1:
		return
	var npc_data: Dictionary = NpcDataClass.get_npc("merchant")
	var npc := NpcClass.new(pos, "merchant", npc_data)
	npc.home_chunk = chunk
	npc.ai       = DocileAIClass.new(npc, 0.25, false)  # travels day and night; flees if attacked
	target_map.add_entity(npc)


func _find_nearby_open_tile(target_map, origin: Vector2i, radius: int) -> Vector2i:
	for _attempt in range(24):
		var tx: int = clampi(origin.x + randi_range(-radius, radius), 1, OVERWORLD_W - 2)
		var ty: int = clampi(origin.y + randi_range(-radius, radius), 1, OVERWORLD_H - 2)
		if not target_map.is_walkable(tx, ty):
			continue
		if target_map.get_blocking_entity_at(tx, ty) != null:
			continue
		return Vector2i(tx, ty)
	return Vector2i(-1, -1)


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
