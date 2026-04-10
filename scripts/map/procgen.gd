class_name Procgen

const VILLAGE_NAMES := [
	"Ugarit", "Byblos", "Jericho", "Hazor", "Megiddo",
	"Lachish", "Gezer", "Timna", "Kadesh", "Ebla",
	"Mari", "Nippur", "Uruk", "Ur", "Lagash",
	"Nineveh", "Assur", "Carchemish", "Alalakh", "Qatna",
]

const GameMapClass   = preload("res://scripts/map/game_map.gd")
const EntityClass    = preload("res://scripts/entities/entity.gd")
const ActorClass     = preload("res://scripts/entities/actor.gd")
const ItemClass      = preload("res://scripts/entities/item.gd")
const ItemDataClass  = preload("res://content/items.gd")
const NpcClass       = preload("res://scripts/entities/npc.gd")
const NpcDataClass   = preload("res://content/npcs.gd")
const HostileAIClass = preload("res://scripts/components/hostile_ai.gd")
const WanderAIClass  = preload("res://scripts/components/wander_ai.gd")
const DocileAIClass  = preload("res://scripts/components/docile_ai.gd")


class RectRoom:
	var x1: int
	var y1: int
	var x2: int  # exclusive right edge
	var y2: int  # exclusive bottom edge

	func _init(p_x: int, p_y: int, p_w: int, p_h: int) -> void:
		x1 = p_x
		y1 = p_y
		x2 = p_x + p_w
		y2 = p_y + p_h

	func center() -> Vector2i:
		return Vector2i((x1 + x2) / 2, (y1 + y2) / 2)

	func intersects(other: RectRoom) -> bool:
		return x1 <= other.x2 and x2 >= other.x1 and y1 <= other.y2 and y2 >= other.y1


static func generate_dungeon(
	map,
	max_rooms: int,
	min_size: int,
	max_size: int,
	max_monsters_per_room: int,
	player,
	floor: int = 1
) -> void:
	var rooms: Array = []

	for _i in range(max_rooms):
		var w := randi_range(min_size, max_size)
		var h := randi_range(min_size, max_size)
		var x := randi_range(1, map.width - w - 2)
		var y := randi_range(1, map.height - h - 2)
		var new_room := RectRoom.new(x, y, w, h)

		var overlaps := false
		for room in rooms:
			var padded := RectRoom.new(
				room.x1 - 1, room.y1 - 1,
				(room.x2 - room.x1) + 2,
				(room.y2 - room.y1) + 2
			)
			if new_room.intersects(padded):
				overlaps = true
				break
		if overlaps:
			continue

		var room_is_lit: bool = _room_is_lit(floor)
		_carve_room(map, new_room, room_is_lit)

		if rooms.is_empty():
			player.pos = new_room.center()
		else:
			_carve_tunnel(map, rooms.back().center(), new_room.center())
			_place_monsters(map, new_room, max_monsters_per_room, floor)
			_place_items(map, new_room, 2, floor)

		rooms.append(new_room)

	# Stairs at the center of the last room
	if not rooms.is_empty():
		var stairs_pos: Vector2i = rooms.back().center()
		var stairs := EntityClass.new(stairs_pos, ">", Color(0.90, 0.85, 0.60), "stairs down", false)
		map.add_entity(stairs)


static func _carve_room(map, room: RectRoom, is_lit: bool = false) -> void:
	for y in range(room.y1, room.y2):
		for x in range(room.x1, room.x2):
			map.tiles[y][x] = GameMapClass.TILE_FLOOR
			if is_lit:
				map.permanent_light[y][x] = true


static func _room_is_lit(floor: int) -> bool:
	# Angband-inspired: shallow rooms are frequently lit; deeper rooms trend dark.
	var lit_chance: float = clampf(0.85 - float(maxi(0, floor - 1)) * 0.12, 0.18, 0.85)
	return randf() < lit_chance


static func _carve_tunnel(map, a: Vector2i, b: Vector2i) -> void:
	if randf() < 0.5:
		_hline(map, a.x, b.x, a.y)
		_vline(map, a.y, b.y, b.x)
	else:
		_vline(map, a.y, b.y, a.x)
		_hline(map, a.x, b.x, b.y)


static func _hline(map, x0: int, x1: int, y: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		map.tiles[y][x] = GameMapClass.TILE_FLOOR


static func _vline(map, y0: int, y1: int, x: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		map.tiles[y][x] = GameMapClass.TILE_FLOOR


static func _place_monsters(map, room: RectRoom, max_monsters: int, floor: int) -> void:
	var count := randi_range(0, max_monsters)
	for _i in range(count):
		var x := randi_range(room.x1 + 1, room.x2 - 2)
		var y := randi_range(room.y1 + 1, room.y2 - 2)
		if map.get_blocking_entity_at(x, y):
			continue
		# Deeper floors spawn more Desert Beasts
		var beast_chance := minf(0.1 + (floor - 1) * 0.1, 0.5)
		var monster
		if randf() < beast_chance:
			var hp    := 18 + (floor - 1) * 3
			var power := 4  + (floor - 1)
			monster = ActorClass.new(Vector2i(x, y), "B", Color(0.48, 0.32, 0.12), "desert beast", hp, 2, power)
		else:
			var hp    := 10 + (floor - 1) * 2
			var power := 3  + (floor - 1)
			monster = ActorClass.new(Vector2i(x, y), "r", Color(0.72, 0.22, 0.10), "raider", hp, 0, power)
		monster.ai       = HostileAIClass.new(monster)
		map.add_entity(monster)


static func _place_items(map, room: RectRoom, max_items: int, floor: int) -> void:
	var count := randi_range(0, max_items)
	for _i in range(count):
		var x := randi_range(room.x1 + 1, room.x2 - 2)
		var y := randi_range(room.y1 + 1, room.y2 - 2)
		if _item_at(map, x, y):
			continue
		var item
		if randf() < 0.6:
			# From floor 3 onward, Healing Draughts (2d6) can appear alongside
			# basic Health Potions (1d6). Chance grows with depth, capped at 50%.
			var draught_chance := clampf((floor - 2) * 0.15, 0.0, 0.5)
			if floor >= 3 and randf() < draught_chance:
				item = ItemClass.new(Vector2i(x, y), ItemClass.TYPE_HEALING_DRAUGHT, 0)
			else:
				item = ItemClass.new(Vector2i(x, y), ItemClass.TYPE_HEALTH_POTION, 0)
		else:
			# Gold — scales with floor
			var amount := randi_range(5, 15) * floor
			item = ItemClass.new(Vector2i(x, y), ItemClass.TYPE_GOLD, amount)
		map.add_entity(item)


static func _item_at(map, x: int, y: int) -> bool:
	for e in map.entities:
		if e.pos.x == x and e.pos.y == y and (e is ItemClass):
			return true
	return false


static func find_cave_entrance(map) -> Vector2i:
	# Search for a walkable tile beside rocky outcroppings — a natural cave mouth.
	# Constraints:
	#   • 2–4 diagonal+orthogonal rock neighbours  (cave aesthetic)
	#   • at least 2 walkable cardinal neighbours   (player can actually move)
	# Score = rock_neighbours * 100 − distance from centre (prefers closer).
	var cx: int = map.width  >> 1
	var cy: int = map.height >> 1
	var best_pos   := Vector2i(cx + 20, cy)
	var best_score := -1

	for dy in range(-70, 71):
		for dx in range(-70, 71):
			var dist: int = absi(dx) + absi(dy)
			if dist < 15 or dist > 80:
				continue
			var tx: int = cx + dx
			var ty: int = cy + dy
			if not map.is_in_bounds(tx, ty):
				continue
			var t: int = map.tiles[ty][tx]
			if t != GameMapClass.TILE_SAND and t != GameMapClass.TILE_DUNE:
				continue
			# Count 8-directional rock neighbours.
			var rocks := 0
			for ndy in range(-1, 2):
				for ndx in range(-1, 2):
					if ndx == 0 and ndy == 0:
						continue
					var nx: int = tx + ndx
					var ny: int = ty + ndy
					if map.is_in_bounds(nx, ny) and map.tiles[ny][nx] == GameMapClass.TILE_ROCK:
						rocks += 1
			# Must have 2–4 rock neighbours (cave mouth, not a pit).
			if rocks < 2 or rocks > 4:
				continue
			# Must have at least 2 walkable cardinal neighbours so the player isn't trapped.
			var open_cardinals := 0
			for card in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nx: int = tx + card.x
				var ny: int = ty + card.y
				if map.is_walkable(nx, ny):
					open_cardinals += 1
			if open_cardinals < 2:
				continue
			var score: int = rocks * 100 - dist
			if score > best_score:
				best_score = score
				best_pos   = Vector2i(tx, ty)
	return best_pos


static func generate_world_biomes(world_w: int, world_h: int, world_seed: int) -> Array:
	# Returns a 2D Array[world_h][world_w] of BIOME_* constants.
	# Two noise passes: elevation (determines terrain roughness) and
	# aridity (determines moisture / vegetation).
	var elev_noise := FastNoiseLite.new()
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.seed       = world_seed + 100
	elev_noise.frequency  = 0.14

	var arid_noise := FastNoiseLite.new()
	arid_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	arid_noise.seed       = world_seed + 200
	arid_noise.frequency  = 0.11

	var grid: Array = []
	for cy in range(world_h):
		var row: Array = []
		for cx in range(world_w):
			var elev: float = elev_noise.get_noise_2d(float(cx), float(cy))
			var arid: float = arid_noise.get_noise_2d(float(cx), float(cy))
			var biome: int
			if elev > 0.35:
				biome = GameMapClass.BIOME_MOUNTAINS
			elif elev > 0.10:
				biome = GameMapClass.BIOME_BADLANDS
			elif arid > 0.20:
				biome = GameMapClass.BIOME_DESERT
			elif arid > -0.20:
				biome = GameMapClass.BIOME_STEPPES
			else:
				biome = GameMapClass.BIOME_OASIS
			row.append(biome)
		grid.append(row)

	# The starting chunk (world centre) is always desert — dungeon entrance is there.
	var cx_start: int = world_w >> 1
	var cy_start: int = world_h >> 1
	grid[cy_start][cx_start] = GameMapClass.BIOME_DESERT
	return grid


static func generate_overworld(map, world_x: int, world_y: int, world_seed: int, biome: int = 0, safe_center: bool = false, road_dirs: Array = [], is_village: bool = false) -> void:
	# GDC-inspired layered generation (Grinblat, GDC 2019):
	# Pass 1 — broad terrain via low-frequency noise (biome skeleton).
	# Pass 2 — detail via higher-frequency noise (local dune ripple).
	#
	# KEY: noise is sampled at WORLD coordinates (world_x+x, world_y+y) with a
	# FIXED seed. Adjacent chunks therefore share continuous noise values at
	# their shared border — no blending or stitching needed for seamless terrain.
	map.map_type = GameMapClass.MAP_OVERWORLD

	var base_noise := FastNoiseLite.new()
	base_noise.noise_type         = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base_noise.seed               = world_seed
	base_noise.frequency          = 0.018
	base_noise.fractal_octaves    = 4
	base_noise.fractal_lacunarity = 2.0
	base_noise.fractal_gain       = 0.5

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.seed       = world_seed + 1  # offset so it differs from base
	detail_noise.frequency  = 0.06

	# Biome threshold tables: each entry is [min_combined_value, tile_type].
	# Entries are checked highest-to-lowest; first match wins.
	# detail_amp scales the fine-detail noise layer per biome.
	var detail_amp: float
	var thresholds: Array
	match biome:
		GameMapClass.BIOME_MOUNTAINS:
			# Rock-dominant — narrow sand corridors between outcroppings.
			detail_amp = 0.15
			thresholds = [
				[0.00, GameMapClass.TILE_ROCK],
				[-0.50, GameMapClass.TILE_DUNE],
				[-2.00, GameMapClass.TILE_SAND],
			]
		GameMapClass.BIOME_BADLANDS:
			# Heavy dune coverage, moderate rock — eroded feel.
			detail_amp = 0.35
			thresholds = [
				[0.20, GameMapClass.TILE_ROCK],
				[-0.30, GameMapClass.TILE_DUNE],
				[-2.00, GameMapClass.TILE_SAND],
			]
		GameMapClass.BIOME_STEPPES:
			# Grass dominant with scattered rock and sand patches.
			detail_amp = 0.20
			thresholds = [
				[0.50, GameMapClass.TILE_ROCK],
				[-0.10, GameMapClass.TILE_SAND],
				[-2.00, GameMapClass.TILE_GRASS],
			]
		GameMapClass.BIOME_OASIS:
			# Water bodies ringed by grass and sand, light rock at edges.
			detail_amp = 0.20
			thresholds = [
				[0.55, GameMapClass.TILE_ROCK],
				[-0.05, GameMapClass.TILE_SAND],
				[-0.35, GameMapClass.TILE_GRASS],
				[-2.00, GameMapClass.TILE_WATER],
			]
		_:  # BIOME_DESERT (default)
			# Classic desert: sand flats, dune ridges, rocky outcroppings.
			detail_amp = 0.25
			thresholds = [
				[0.30, GameMapClass.TILE_ROCK],
				[-0.15, GameMapClass.TILE_DUNE],
				[-2.00, GameMapClass.TILE_SAND],
			]

	for y in range(map.height):
		for x in range(map.width):
			var wx: float  = float(world_x + x)
			var wy: float  = float(world_y + y)
			var v: float   = base_noise.get_noise_2d(wx, wy)
			var d: float   = detail_noise.get_noise_2d(wx, wy) * detail_amp
			var combined   := v + d
			var tile: int  = int(thresholds.back()[1])
			for entry in thresholds:
				if combined > float(entry[0]):
					tile = int(entry[1])
					break
			map.tiles[y][x] = tile

	if safe_center:
		# Clear a landing zone around the chunk centre. Rock and water are
		# replaced with sand so the player spawn is always passable.
		var cx: int = map.width  >> 1
		var cy: int = map.height >> 1
		for y in range(maxi(0, cy - 6), mini(map.height, cy + 7)):
			for x in range(maxi(0, cx - 6), mini(map.width, cx + 7)):
				var t: int = map.tiles[y][x]
				if t == GameMapClass.TILE_ROCK or t == GameMapClass.TILE_WATER:
					map.tiles[y][x] = GameMapClass.TILE_SAND

	# Deterministic per-chunk RNG for light placement.
	var rng_lights := RandomNumberGenerator.new()
	rng_lights.seed = world_seed ^ (world_x * 97531) ^ (world_y * 13579)

	# Roads carved first so village buildings are placed around them, not over them.
	if road_dirs.size() > 0:
		_carve_roads(map, road_dirs, world_seed, world_x, world_y)
		_place_road_lights(map, rng_lights)

	# Village structures placed after roads; they preserve existing TILE_ROAD tiles.
	if is_village:
		_place_village(map, world_seed, world_x, world_y)
		_place_village_lights(map, rng_lights)

	# Wildlife skip village chunks — animals keep away from settled areas.
	if not is_village:
		_spawn_wildlife(map, biome, world_seed, world_x, world_y, safe_center)


static func generate_debug_hub(map) -> void:
	map.map_type = GameMapClass.MAP_DUNGEON
	for y in range(map.height):
		for x in range(map.width):
			map.tiles[y][x] = GameMapClass.TILE_WALL

	for y in range(2, map.height - 2):
		for x in range(2, map.width - 2):
			map.tiles[y][x] = GameMapClass.TILE_FLOOR

	for x in range(40, 42):
		for y in range(2, 20):
			map.tiles[y][x] = GameMapClass.TILE_WALL
	for x in range(40, 42):
		for y in range(24, map.height - 2):
			map.tiles[y][x] = GameMapClass.TILE_WALL

	for x in range(78, 80):
		for y in range(2, map.height - 2):
			map.tiles[y][x] = GameMapClass.TILE_WALL

	# Open doorways between the test bays.
	for pos in [Vector2i(40, 22), Vector2i(41, 22), Vector2i(78, 22), Vector2i(79, 22)]:
		map.tiles[pos.y][pos.x] = GameMapClass.TILE_FLOOR

	# Quartermaster room fixtures and supplies.
	_place_light_fixture(map, 16, 12, "brazier")
	_place_light_fixture(map, 16, 31, "brazier")
	_place_furniture(map, 14, 13, "=", Color(0.50, 0.33, 0.16), "counter")
	_place_furniture(map, 15, 13, "=", Color(0.50, 0.33, 0.16), "counter")
	_place_furniture(map, 16, 13, "=", Color(0.50, 0.33, 0.16), "counter")

	var merchant_data: Dictionary = NpcDataClass.get_npc("merchant")
	var quartermaster := NpcClass.new(Vector2i(16, 11), "merchant", merchant_data)
	quartermaster.trade_stock = _debug_quartermaster_stock()
	quartermaster.gold = 9999
	map.add_entity(quartermaster)

	# Armory / sample items.
	var sample_items: Array[String] = [
		ItemClass.TYPE_SHORT_SWORD, ItemClass.TYPE_SPEAR, ItemClass.TYPE_LEATHER_VEST,
		ItemClass.TYPE_BRONZE_HELMET, ItemClass.TYPE_TORCH, ItemClass.TYPE_HEALTH_POTION,
		ItemClass.TYPE_HEALING_DRAUGHT, "tablet_traders_ledger", ItemClass.TYPE_TIN_INGOT,
		ItemClass.TYPE_BRONZE_INGOT,
	]
	var sx: int = 10
	for item_type: String in sample_items:
		var item = ItemClass.new(Vector2i(sx, 31), item_type, 0)
		map.add_entity(item)
		sx += 2

	# Central fixtures.
	_place_light_fixture(map, 58, 22, "brazier")
	_add_debug_fixture(map, Vector2i(55, 18), "T", Color(0.86, 0.74, 0.30), "training obelisk")
	_add_debug_fixture(map, Vector2i(55, 22), "~", Color(0.28, 0.58, 0.92), "healing spring")
	_add_debug_fixture(map, Vector2i(55, 26), "!", Color(0.78, 0.32, 0.16), "trial brazier")
	_add_debug_fixture(map, Vector2i(63, 22), "<", Color(0.90, 0.85, 0.60), "return waystone")
	_add_debug_fixture(map, Vector2i(47, 18), "=", Color(0.88, 0.78, 0.42), "speed marker")
	var debug_mount_data: Dictionary = NpcDataClass.get_npc("donkey")
	var debug_mount := NpcClass.new(Vector2i(47, 22), "donkey", debug_mount_data)
	debug_mount.ai = null
	map.add_entity(debug_mount)

	# Combat arena fixtures.
	_place_light_fixture(map, 98, 12, "brazier")
	_place_light_fixture(map, 98, 31, "brazier")
	_add_debug_fixture(map, Vector2i(90, 14), "b", Color(0.72, 0.32, 0.20), "bandit marker")
	_add_debug_fixture(map, Vector2i(90, 22), "r", Color(0.78, 0.22, 0.10), "raider marker")
	_add_debug_fixture(map, Vector2i(90, 30), "B", Color(0.48, 0.32, 0.12), "beast marker")


static func _add_debug_fixture(map, pos: Vector2i, ch: String, col: Color, nm: String) -> void:
	var fixture = EntityClass.new(pos, ch, col, nm, false)
	map.add_entity(fixture)


static func _debug_quartermaster_stock() -> Array:
	var item_types: Array[String] = [
		ItemClass.TYPE_HEALTH_POTION,
		ItemClass.TYPE_HEALING_DRAUGHT,
		ItemClass.TYPE_DAGGER,
		ItemClass.TYPE_SHORT_SWORD,
		ItemClass.TYPE_SPEAR,
		ItemClass.TYPE_LINEN_TUNIC,
		ItemClass.TYPE_LEATHER_VEST,
		ItemClass.TYPE_SANDALS,
		ItemClass.TYPE_LEATHER_BOOTS,
		ItemClass.TYPE_LEATHER_CAP,
		ItemClass.TYPE_BRONZE_HELMET,
		ItemClass.TYPE_TORCH,
		ItemClass.TYPE_TIN_INGOT,
		ItemClass.TYPE_COPPER_INGOT,
		ItemClass.TYPE_BRONZE_INGOT,
		ItemClass.TYPE_LAPIS_LAZULI,
		ItemClass.TYPE_PURPLE_DYE,
		"tablet_traders_ledger",
		"tablet_caravan_letter",
	]
	var stock: Array = []
	for item_type: String in item_types:
		var item_data: Dictionary = ItemDataClass.get_item(item_type)
		stock.append({
			"item_type": item_type,
			"qty": 99,
			"price": int(item_data.get("base_value", 1)),
		})
	return stock


# ---------------------------------------------------------------------------
# Village generation
# ---------------------------------------------------------------------------

static func generate_villages(world_w: int, world_h: int, biomes: Array, world_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 999

	var cx_center: int = world_w >> 1
	var cy_center: int = world_h >> 1
	var result: Array  = []
	var target: int    = maxi(10, int(round(float(world_w * world_h) / 120.0)))
	var min_dist: int  = 7   # minimum Chebyshev distance between villages

	for _attempt in range(300):
		if result.size() >= target:
			break
		var cx: int = rng.randi_range(1, world_w - 2)
		var cy: int = rng.randi_range(1, world_h - 2)

		# Keep away from world centre (dungeon area).
		if maxi(absi(cx - cx_center), absi(cy - cy_center)) < 5:
			continue
		# Avoid mountain biomes (impassable terrain — villages shouldn't be there).
		if biomes[cy][cx] == GameMapClass.BIOME_MOUNTAINS:
			continue
		# Enforce minimum spacing.
		var too_close := false
		for v in result:
			if maxi(absi(cx - int(v.cx)), absi(cy - int(v.cy))) < min_dist:
				too_close = true
				break
		if too_close:
			continue

		result.append({cx = cx, cy = cy, name = VILLAGE_NAMES[result.size() % VILLAGE_NAMES.size()]})

	return result


# ---------------------------------------------------------------------------
# Road generation (Prim's MST connecting villages to world centre)
# ---------------------------------------------------------------------------

static func generate_roads(villages: Array, world_w: int, world_h: int) -> Dictionary:
	var road_set: Dictionary = {}

	if villages.is_empty():
		return road_set

	var center := Vector2i(world_w >> 1, world_h >> 1)
	var points: Array  = [center]
	for v in villages:
		points.append(Vector2i(int(v.cx), int(v.cy)))

	# Prim's MST: start from centre, greedily connect nearest unvisited point.
	var connected: Array   = [center]
	var remaining: Array   = points.slice(1)

	while remaining.size() > 0:
		var best_dist: int  = 999999
		var best_a: Vector2i = connected[0]
		var best_b: Vector2i = remaining[0]

		for a: Vector2i in connected:
			for b: Vector2i in remaining:
				var d: int = absi(a.x - b.x) + absi(a.y - b.y)
				if d < best_dist:
					best_dist = d
					best_a    = a
					best_b    = b

		_road_bresenham(road_set, best_a, best_b)
		connected.append(best_b)
		remaining.erase(best_b)

	return road_set


static func _road_bresenham(road_set: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var x0 := from.x;  var y0 := from.y
	var x1 := to.x;    var y1 := to.y
	var dx := absi(x1 - x0);  var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		road_set["%d,%d" % [x0, y0]] = true
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy and e2 < dx:
			# Diagonal step — mark the intermediate axis-aligned cell first so
			# every road chunk always has a cardinally-adjacent road neighbour.
			# Without this, get_road_dirs() finds no neighbours for diagonal
			# chunks and _carve_roads() is never called → phantom world-map roads.
			err -= dy;  x0 += sx
			road_set["%d,%d" % [x0, y0]] = true   # intermediate
			err += dx;  y0 += sy
		elif e2 > -dy:
			err -= dy;  x0 += sx
		else:
			err += dx;  y0 += sy


# ---------------------------------------------------------------------------
# Road carving inside an overworld chunk
# ---------------------------------------------------------------------------

static func _carve_roads(map, road_dirs: Array, world_seed: int, world_x: int, world_y: int) -> void:
	var cx: int = map.width  >> 1
	var cy: int = map.height >> 1
	var center := Vector2i(cx, cy)

	# Deterministic per-chunk RNG for organic bends.
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + world_x * 31337 + world_y * 13579

	# Entry points per cardinal direction.
	var edge_pts: Array = []
	for d: Vector2i in road_dirs:
		if   d == Vector2i( 0, -1): edge_pts.append(Vector2i(cx,              0))
		elif d == Vector2i( 0,  1): edge_pts.append(Vector2i(cx, map.height - 1))
		elif d == Vector2i(-1,  0): edge_pts.append(Vector2i(0,              cy))
		elif d == Vector2i( 1,  0): edge_pts.append(Vector2i(map.width - 1,  cy))

	if edge_pts.is_empty():
		return

	for ep: Vector2i in edge_pts:
		# Insert a waypoint near the midpoint, offset perpendicular to the road's
		# main axis, creating organic bends instead of ruler-straight roads.
		var mid_x: int = (ep.x + center.x) >> 1
		var mid_y: int = (ep.y + center.y) >> 1
		var is_v: bool = absi(ep.y - center.y) >= absi(ep.x - center.x)
		if is_v:
			mid_x = clampi(mid_x + rng.randi_range(-10, 10), 4, map.width  - 5)
		else:
			mid_y = clampi(mid_y + rng.randi_range(-10, 10), 4, map.height - 5)
		var waypoint := Vector2i(mid_x, mid_y)

		_road_line_in_chunk(map, ep, waypoint)
		_road_line_in_chunk(map, waypoint, center)


static func _road_line_in_chunk(map, from: Vector2i, to: Vector2i) -> void:
	# Direction-aware 3-tile-wide road. Overwrites any terrain tile (including
	# uninitialised TILE_WALL from map init) to prevent road gaps. Buildings
	# placed afterward will detect road overlap and reposition.
	var tdx: int = absi(to.x - from.x)
	var tdy: int = absi(to.y - from.y)
	var is_h: bool = tdx >= tdy  # mostly horizontal → widen in Y

	var x0 := from.x;  var y0 := from.y
	var x1 := to.x;    var y1 := to.y
	var dx := absi(x1 - x0);  var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		if is_h:
			for ry in range(-1, 2):
				if map.is_in_bounds(x0, y0 + ry):
					map.tiles[y0 + ry][x0] = GameMapClass.TILE_ROAD
		else:
			for rx in range(-1, 2):
				if map.is_in_bounds(x0 + rx, y0):
					map.tiles[y0][x0 + rx] = GameMapClass.TILE_ROAD
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy;  x0 += sx
		if e2 < dx:
			err += dx;  y0 += sy


# ---------------------------------------------------------------------------
# Village structure placement inside an overworld chunk
# ---------------------------------------------------------------------------

# Building type constants used only within village generation.
const _BT_HOME       := 0   # small dwelling
const _BT_ADMIN      := 1   # civic / temple / administrative
const _BT_COMMERCIAL := 2   # market stall, smithy, workshop


static func _place_village(map, world_seed: int, world_x: int, world_y: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ (world_x * 73856093) ^ (world_y * 19349663)
	var home_chunk := Vector2i(world_x / map.width, world_y / map.height)

	var cx: int = map.width  >> 1
	var cy: int = map.height >> 1

	# Central sand plaza — roads are already carved; preserve them.
	for y in range(maxi(0, cy - 7), mini(map.height, cy + 8)):
		for x in range(maxi(0, cx - 7), mini(map.width, cx + 8)):
			if map.tiles[y][x] != GameMapClass.TILE_ROAD:
				map.tiles[y][x] = GameMapClass.TILE_SAND

	# Building composition: 1 admin, 2–3 commercial, rest homes.
	var n_commercial: int   = rng.randi_range(2, 3)
	var n_homes: int        = rng.randi_range(3, 5)
	var target_buildings: int = 1 + n_commercial + n_homes

	# Build the type sequence: admin first, then commercial, then homes.
	var btype_seq: Array = [_BT_ADMIN]
	for _i in range(n_commercial): btype_seq.append(_BT_COMMERCIAL)
	for _i in range(n_homes):      btype_seq.append(_BT_HOME)

	var placed_rects: Array      = []   # [{bx, by, bw, bh}]
	var all_interior_tiles: Array = []

	for _attempt in range(target_buildings * 20):
		if placed_rects.size() >= target_buildings:
			break

		var bidx: int   = placed_rects.size()
		var btype: int  = btype_seq[bidx] if bidx < btype_seq.size() else _BT_HOME
		var angle: float = TAU * float(bidx) / float(target_buildings) \
				+ rng.randf_range(-0.4, 0.4)

		# Size and ring radius vary by type.
		var bw: int
		var bh: int
		var ring_r: float
		match btype:
			_BT_ADMIN:
				bw = rng.randi_range(10, 16); bh = rng.randi_range(7, 10); ring_r = 15.0
			_BT_COMMERCIAL:
				bw = rng.randi_range(7, 12);  bh = rng.randi_range(5, 8);  ring_r = 13.0
			_:  # HOME
				bw = rng.randi_range(5, 8);   bh = rng.randi_range(4, 6);  ring_r = 12.0

		var dist: float = ring_r + rng.randf_range(-2.0, 4.0)
		var bx: int  = cx + int(cos(angle) * dist) - (bw >> 1)
		var by_: int = cy + int(sin(angle) * dist) - (bh >> 1)

		# Reject if footprint goes outside map bounds.
		if bx < 1 or by_ < 1 or bx + bw > map.width - 1 or by_ + bh > map.height - 1:
			continue

		# Reject if too many road tiles in the footprint (road bisects building).
		var road_count: int = 0
		for dy in range(bh):
			for dx in range(bw):
				if map.tiles[by_ + dy][bx + dx] == GameMapClass.TILE_ROAD:
					road_count += 1
		if road_count * 100 > bw * bh * 20:
			continue

		# Reject if footprint overlaps any already-placed building (1-tile padding).
		var overlaps: bool = false
		for r: Dictionary in placed_rects:
			if bx   <= int(r.bx) + int(r.bw) and bx + bw >= int(r.bx) \
			and by_ <= int(r.by) + int(r.bh) and by_ + bh >= int(r.by):
				overlaps = true
				break
		if overlaps:
			continue

		# Stamp the building — walls on perimeter, floor inside.
		var interior_tiles: Array = []
		for dy in range(bh):
			for dx in range(bw):
				var px: int = bx + dx
				var py: int = by_ + dy
				var on_wall: bool = (dx == 0 or dx == bw - 1 or dy == 0 or dy == bh - 1)
				if on_wall:
					map.tiles[py][px] = GameMapClass.TILE_WALL
				else:
					map.tiles[py][px] = GameMapClass.TILE_FLOOR
					interior_tiles.append(Vector2i(px, py))

		# Doorway on the wall facing the plaza.
		var face: float = angle + PI
		var door_x: int
		var door_y: int
		if absf(cos(face)) >= absf(sin(face)):
			door_x = bx if cos(face) < 0.0 else bx + bw - 1
			door_y = by_ + (bh >> 1)
		else:
			door_x = bx + (bw >> 1)
			door_y = by_ if sin(face) < 0.0 else by_ + bh - 1
		if map.is_in_bounds(door_x, door_y):
			map.tiles[door_y][door_x] = GameMapClass.TILE_SAND

		# Furnish the building based on its type.
		match btype:
			_BT_ADMIN:      _furnish_admin(map, rng, bx, by_, bw, bh)
			_BT_COMMERCIAL: _furnish_commercial(map, rng, bx, by_, bw, bh)
			_:              _furnish_home(map, rng, bx, by_, bw, bh)

		placed_rects.append({bx = bx, by = by_, bw = bw + 1, bh = bh + 1})
		all_interior_tiles.append_array(interior_tiles)

	# Spawn 2–4 NPCs at unoccupied interior floor positions.
	if all_interior_tiles.size() > 0:
		var npc_pool: Array   = NpcDataClass.weighted_types()
		var npc_count: int    = rng.randi_range(2, 4)
		var used_npc: Dictionary = {}
		var spawned_npc: int  = 0
		for _npi in range(npc_count * 10):
			if spawned_npc >= npc_count:
				break
			var ni: int = rng.randi_range(0, all_interior_tiles.size() - 1)
			var npc_pos: Vector2i = all_interior_tiles[ni]
			if used_npc.has(npc_pos):
				continue
			# Skip tile if furniture is already blocking it.
			var occupied := false
			for e in map.entities:
				if e.pos == npc_pos and e.blocks_movement:
					occupied = true
					break
			if occupied:
				continue
			used_npc[npc_pos] = true
			var npc_type: String     = str(npc_pool[rng.randi_range(0, npc_pool.size() - 1)])
			var npc_data: Dictionary = NpcDataClass.get_npc(npc_type)
			var npc := NpcClass.new(npc_pos, npc_type, npc_data)
			npc.home_chunk = home_chunk
			# Non-merchant NPCs wander (diurnal — rest at night); merchants stay put.
			if not npc.is_merchant:
				npc.ai = DocileAIClass.new(npc, 0.35, true)
			map.add_entity(npc)
			spawned_npc += 1


# ---------------------------------------------------------------------------
# Furniture helpers
# Each function places decorative Entity objects on TILE_FLOOR tiles only.
# Furniture is non-blocking so the player can walk through it.
# ---------------------------------------------------------------------------

# Shared — place a single furniture piece; skips non-floor or already-occupied tiles.
static func _place_furniture(map, x: int, y: int, ch: String, col: Color, nm: String) -> void:
	if not map.is_in_bounds(x, y) or map.tiles[y][x] != GameMapClass.TILE_FLOOR:
		return
	for e in map.entities:
		if e.pos == Vector2i(x, y) and not (e is ActorClass):
			return   # don't stack furniture
	map.add_entity(EntityClass.new(Vector2i(x, y), ch, col, nm, false))


# Home — hearth, beds, storage jars.
static func _furnish_home(map, rng: RandomNumberGenerator, bx: int, by_: int, bw: int, bh: int) -> void:
	var cx: int = bx + (bw >> 1)
	var cy: int = by_ + (bh >> 1)

	# Hearth near the centre.
	_place_furniture(map, cx, cy, "*", Color(0.88, 0.42, 0.10), "hearth")

	# 1–2 beds against the back wall.
	var bed_wall_y: int = by_ + 1
	for i in range(rng.randi_range(1, 2)):
		var bx_f: int = bx + 1 + rng.randi_range(0, maxi(0, bw - 3))
		_place_furniture(map, bx_f, bed_wall_y, "\u2261", Color(0.68, 0.52, 0.35), "bed")

	# 1–3 storage jars in the corners.
	var corners: Array = [
		Vector2i(bx + 1,      by_ + bh - 2),
		Vector2i(bx + bw - 2, by_ + bh - 2),
		Vector2i(bx + 1,      by_ + 1),
	]
	var jar_count: int = rng.randi_range(1, mini(3, corners.size()))
	for i in range(jar_count):
		var ci: int = rng.randi_range(0, corners.size() - 1)
		_place_furniture(map, corners[ci].x, corners[ci].y, "o", Color(0.72, 0.40, 0.22), "storage jar")


# Readable tablets that can appear in admin/scribe buildings.
const READABLE_TABLETS: Array = [
	"tablet_traders_ledger",
	"tablet_hymn_shamash",
	"tablet_law_fragment",
	"tablet_caravan_letter",
	"tablet_mythic_fragment",
]

# Admin — central table cluster, clay tablet racks along walls, offering stand.
static func _furnish_admin(map, rng: RandomNumberGenerator, bx: int, by_: int, bw: int, bh: int) -> void:
	var cx: int = bx + (bw >> 1)
	var cy: int = by_ + (bh >> 1)

	# Central table cluster (2×2 or 3×2).
	var tw: int = rng.randi_range(2, 3)
	for dy in range(2):
		for dx in range(tw):
			_place_furniture(map, cx - 1 + dx, cy - 1 + dy, "+", Color(0.42, 0.28, 0.14), "table")

	# Offering / incense stand near the back wall, centred.
	_place_furniture(map, cx, by_ + 1, "^", Color(0.88, 0.72, 0.25), "offering stand")

	# Clay tablet racks along the left wall.
	var rack_count: int = rng.randi_range(2, maxi(2, bh - 3))
	for i in range(rack_count):
		_place_furniture(map, bx + 1, by_ + 2 + i, "-", Color(0.82, 0.72, 0.55), "clay tablet rack")

	# Clay tablet racks along the right wall.
	rack_count = rng.randi_range(1, maxi(1, bh - 3))
	for i in range(rack_count):
		_place_furniture(map, bx + bw - 2, by_ + 2 + i, "-", Color(0.82, 0.72, 0.55), "clay tablet rack")

	# A shelf unit in a rear corner.
	_place_furniture(map, bx + bw - 2, by_ + 1, "#", Color(0.45, 0.30, 0.18), "shelf")

	# Place 1–2 readable tablets on floor tiles — something to find and read.
	var tablet_count: int = rng.randi_range(1, 2)
	var placed_tablets: int = 0
	for _attempt in range(30):
		if placed_tablets >= tablet_count:
			break
		var tx: int = rng.randi_range(bx + 1, bx + bw - 2)
		var ty: int = rng.randi_range(by_ + 1, by_ + bh - 2)
		if map.tiles[ty][tx] != GameMapClass.TILE_FLOOR:
			continue
		var occupied := false
		for e in map.entities:
			if e.pos == Vector2i(tx, ty):
				occupied = true
				break
		if occupied:
			continue
		var ttype: String = READABLE_TABLETS[rng.randi_range(0, READABLE_TABLETS.size() - 1)]
		var tablet = ItemClass.new(Vector2i(tx, ty), ttype, 0)
		map.add_entity(tablet)
		placed_tablets += 1


# Commercial — counter facing the door, storage jars at the back, work surface.
static func _furnish_commercial(map, rng: RandomNumberGenerator, bx: int, by_: int, bw: int, bh: int) -> void:
	var cx: int = bx + (bw >> 1)
	var cy: int = by_ + (bh >> 1)

	# Counter runs across the near side of the room (facing plaza/door).
	var counter_len: int = rng.randi_range(2, maxi(2, bw - 3))
	var counter_y: int   = by_ + 2
	for i in range(counter_len):
		_place_furniture(map, bx + 1 + i, counter_y, "=", Color(0.50, 0.33, 0.16), "counter")

	# Storage jars lined up at the back wall.
	var jar_count: int = rng.randi_range(2, maxi(2, bw - 3))
	for i in range(jar_count):
		_place_furniture(map, bx + 1 + i, by_ + bh - 2, "o", Color(0.72, 0.40, 0.22), "storage jar")

	# Work surface (anvil, loom, mill) in the centre-back.
	_place_furniture(map, cx, cy, "+", Color(0.48, 0.32, 0.16), "work surface")

	# 1–2 extra jars or tools on the side wall.
	var side_count: int = rng.randi_range(1, 2)
	for i in range(side_count):
		_place_furniture(map, bx + bw - 2, by_ + 2 + i, "o", Color(0.65, 0.38, 0.20), "storage jar")


# ---------------------------------------------------------------------------
# Light fixture placement
# ---------------------------------------------------------------------------

# Helper: create a brazier/torch Entity with light_radius set.
static func _place_light_fixture(map, x: int, y: int, nm: String) -> void:
	if not map.is_in_bounds(x, y):
		return
	# Don't stack on top of actors or other fixtures.
	for e in map.entities:
		if e.pos == Vector2i(x, y):
			return
	var fixture = EntityClass.new(Vector2i(x, y), "*", Color(1.0, 0.65, 0.10), nm, false)
	fixture.light_radius = 6
	map.add_entity(fixture)


# Place braziers in the village central plaza — permanent light sources.
static func _place_village_lights(map, rng: RandomNumberGenerator) -> void:
	var cx: int = map.width  >> 1
	var cy: int = map.height >> 1
	# Four braziers in a loose square around the plaza centre.
	var offsets: Array = [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]
	for off: Vector2i in offsets:
		var px: int = cx + off.x
		var py: int = cy + off.y
		if map.is_in_bounds(px, py) and map.tiles[py][px] == GameMapClass.TILE_SAND:
			_place_light_fixture(map, px, py, "brazier")
	# One central brazier in the plaza.
	if map.is_in_bounds(cx, cy) and map.tiles[cy][cx] != GameMapClass.TILE_WALL:
		_place_light_fixture(map, cx, cy, "brazier")


# Place 1–2 road torches per chunk, on non-road tiles immediately beside the road.
static func _place_road_lights(map, rng: RandomNumberGenerator) -> void:
	# Collect all road tiles, then pick a small number of anchor points.
	var road_tiles: Array = []
	for y in range(map.height):
		for x in range(map.width):
			if map.tiles[y][x] == GameMapClass.TILE_ROAD:
				road_tiles.append(Vector2i(x, y))
	if road_tiles.is_empty():
		return

	var count: int = rng.randi_range(1, 2)
	for _i in range(count):
		# Pick a random road tile as the anchor.
		var anchor: Vector2i = road_tiles[rng.randi_range(0, road_tiles.size() - 1)]
		# Find an adjacent non-road walkable tile to place the torch beside the road.
		var dirs: Array = [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]
		for _attempt in range(8):
			var d: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
			var fx: int = anchor.x + d.x
			var fy: int = anchor.y + d.y
			if not map.is_in_bounds(fx, fy):
				continue
			var t: int = map.tiles[fy][fx]
			if t == GameMapClass.TILE_ROAD or t == GameMapClass.TILE_WALL:
				continue
			_place_light_fixture(map, fx, fy, "road torch")
			break


# ---------------------------------------------------------------------------
# Wildlife spawning
# Spawned on overworld chunks only; skipped for village chunks.
# Each species has a biome affinity and an allowed tile list.
# ---------------------------------------------------------------------------

static func _spawn_wildlife(map, biome: int, world_seed: int, world_x: int, world_y: int, safe_center: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ (world_x * 56789013) ^ (world_y * 23456791)
	var home_chunk := Vector2i(world_x / map.width, world_y / map.height)

	# Per-biome table: [npc_type, allowed_tiles, max_count]
	var table: Array = []
	match biome:
		GameMapClass.BIOME_DESERT:
			table = [
				["gazelle", [GameMapClass.TILE_SAND, GameMapClass.TILE_DUNE], 4],
				["hyena",   [GameMapClass.TILE_SAND, GameMapClass.TILE_DUNE], 2],
			]
		GameMapClass.BIOME_STEPPES:
			table = [
				["gazelle", [GameMapClass.TILE_GRASS, GameMapClass.TILE_SAND], 5],
				["onager",  [GameMapClass.TILE_GRASS, GameMapClass.TILE_SAND], 4],
			]
		GameMapClass.BIOME_MOUNTAINS:
			table = [
				["ibex",  [GameMapClass.TILE_SAND, GameMapClass.TILE_DUNE], 4],
				["hyena", [GameMapClass.TILE_SAND, GameMapClass.TILE_DUNE], 2],
			]
		GameMapClass.BIOME_BADLANDS:
			table = [
				["hyena", [GameMapClass.TILE_SAND, GameMapClass.TILE_DUNE], 3],
				["ibex",  [GameMapClass.TILE_SAND, GameMapClass.TILE_DUNE], 2],
			]
		GameMapClass.BIOME_OASIS:
			table = [
				["gazelle", [GameMapClass.TILE_GRASS, GameMapClass.TILE_SAND], 5],
				["onager",  [GameMapClass.TILE_GRASS, GameMapClass.TILE_SAND], 3],
			]

	# Safe-center exclusion zone (player spawn area).
	var safe_x1: int = 0;  var safe_x2: int = 0
	var safe_y1: int = 0;  var safe_y2: int = 0
	if safe_center:
		var cx: int = map.width  >> 1
		var cy: int = map.height >> 1
		safe_x1 = cx - 14;  safe_x2 = cx + 14
		safe_y1 = cy - 14;  safe_y2 = cy + 14

	for entry in table:
		var npc_type: String  = entry[0]
		var tiles: Array      = entry[1]
		var count: int        = rng.randi_range(1, entry[2])
		var npc_data: Dictionary = NpcDataClass.get_npc(npc_type)
		var placed: int = 0
		for _attempt in range(count * 20):
			if placed >= count:
				break
			var tx: int = rng.randi_range(2, map.width  - 3)
			var ty: int = rng.randi_range(2, map.height - 3)
			if safe_center and tx >= safe_x1 and tx <= safe_x2 and ty >= safe_y1 and ty <= safe_y2:
				continue
			if not (map.tiles[ty][tx] in tiles):
				continue
			if map.get_blocking_entity_at(tx, ty) != null:
				continue
			var npc := NpcClass.new(Vector2i(tx, ty), npc_type, npc_data)
			npc.home_chunk = home_chunk
			var mc: float = float(npc_data.get("move_chance", 0.35))
			npc.ai       = DocileAIClass.new(npc, mc, false)  # diurnal=false: active day & night
			map.add_entity(npc)
			placed += 1
