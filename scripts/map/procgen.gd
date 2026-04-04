class_name Procgen

const GameMapClass   = preload("res://scripts/map/game_map.gd")
const EntityClass    = preload("res://scripts/entities/entity.gd")
const ActorClass     = preload("res://scripts/entities/actor.gd")
const ItemClass      = preload("res://scripts/entities/item.gd")
const HostileAIClass = preload("res://scripts/components/hostile_ai.gd")


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

		_carve_room(map, new_room)

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
		stairs.game_map = map
		map.entities.append(stairs)


static func _carve_room(map, room: RectRoom) -> void:
	for y in range(room.y1, room.y2):
		for x in range(room.x1, room.x2):
			map.tiles[y][x] = GameMapClass.TILE_FLOOR


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
		monster.game_map = map
		map.entities.append(monster)


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
		item.game_map = map
		map.entities.append(item)


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


static func generate_overworld(map, world_x: int, world_y: int, world_seed: int, biome: int = GameMapClass.BIOME_DESERT, safe_center: bool = false) -> void:
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
