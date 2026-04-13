class_name GameMap
extends RefCounted

const EntityClass = preload("res://scripts/entities/entity.gd")

const TILE_WALL  := 0  # dungeon wall
const TILE_FLOOR := 1  # dungeon floor
const TILE_SAND  := 2  # open desert (walkable)
const TILE_DUNE  := 3  # rolling dune (walkable)
const TILE_ROCK  := 4  # rocky outcropping (blocks movement + LOS)
const TILE_WATER := 5  # oasis water (blocks movement, transparent)
const TILE_GRASS := 6  # lush grassland (walkable, transparent)
const TILE_ROAD  := 7  # packed-dirt trade road (walkable, transparent)

const MAP_DUNGEON   := 0
const MAP_OVERWORLD := 1

# Biome types — used by the world map to determine overworld chunk generation.
const BIOME_DESERT    := 0  # arid waste: sand, dunes, rocky outcroppings
const BIOME_OASIS     := 1  # fertile depression: water, grass, sparse rock
const BIOME_STEPPES   := 2  # open grassland: grass dominant, light rocks
const BIOME_MOUNTAINS := 3  # highland: rock dominant, narrow passages
const BIOME_BADLANDS  := 4  # eroded: heavy dunes, moderate rock

var width: int
var height: int
var map_type: int = MAP_DUNGEON
var tiles: Array    # Array[Array[int]]  — tiles[y][x]
var visible: Array  # Array[Array[bool]] — currently in FOV
var explored: Array # Array[Array[bool]] — ever seen
var permanent_light: Array # Array[Array[bool]] — permanently lit tiles (Angband-style rooms)
var glyph_overrides: Array # Array[Array[String]] — optional per-cell display glyphs
var entities: Array # Array[Entity]
var _entities_by_cell: Dictionary
var _blocking_by_cell: Dictionary

const _OCTANT_TRANSFORMS := [
	[1, 0, 0, 1],
	[0, 1, 1, 0],
	[0, 1, -1, 0],
	[1, 0, 0, -1],
	[-1, 0, 0, -1],
	[0, -1, -1, 0],
	[0, -1, 1, 0],
	[-1, 0, 0, 1],
]


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	tiles = []
	visible = []
	explored = []
	permanent_light = []
	glyph_overrides = []
	entities = []
	_entities_by_cell = {}
	_blocking_by_cell = {}
	for y in range(height):
		tiles.append([])
		visible.append([])
		explored.append([])
		permanent_light.append([])
		glyph_overrides.append([])
		for x in range(width):
			tiles[y].append(TILE_WALL)
			visible[y].append(false)
			explored[y].append(false)
			permanent_light[y].append(false)
			glyph_overrides[y].append("")


func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func add_entity(entity) -> void:
	entities.append(entity)
	var key := _cell_key(entity.pos.x, entity.pos.y)
	if not _entities_by_cell.has(key):
		_entities_by_cell[key] = []
	(_entities_by_cell[key] as Array).append(entity)
	if entity.blocks_movement:
		_blocking_by_cell[key] = entity


func remove_entity(entity) -> void:
	var key := _cell_key(entity.pos.x, entity.pos.y)
	if _entities_by_cell.has(key):
		var cell_entities: Array = _entities_by_cell[key]
		cell_entities.erase(entity)
		if cell_entities.is_empty():
			_entities_by_cell.erase(key)
	if _blocking_by_cell.get(key) == entity:
		_blocking_by_cell.erase(key)
		if _entities_by_cell.has(key):
			for other in _entities_by_cell[key]:
				if other.blocks_movement:
					_blocking_by_cell[key] = other
					break
	entities.erase(entity)


func move_entity(entity, new_pos: Vector2i) -> void:
	if entity.pos == new_pos:
		return
	var old_key := _cell_key(entity.pos.x, entity.pos.y)
	if _entities_by_cell.has(old_key):
		var old_entities: Array = _entities_by_cell[old_key]
		old_entities.erase(entity)
		if old_entities.is_empty():
			_entities_by_cell.erase(old_key)
	if _blocking_by_cell.get(old_key) == entity:
		_blocking_by_cell.erase(old_key)
		if _entities_by_cell.has(old_key):
			for other in _entities_by_cell[old_key]:
				if other.blocks_movement:
					_blocking_by_cell[old_key] = other
					break

	entity.pos = new_pos
	var new_key := _cell_key(new_pos.x, new_pos.y)
	if not _entities_by_cell.has(new_key):
		_entities_by_cell[new_key] = []
	(_entities_by_cell[new_key] as Array).append(entity)
	if entity.blocks_movement:
		_blocking_by_cell[new_key] = entity


func refresh_entity(entity) -> void:
	var key := _cell_key(entity.pos.x, entity.pos.y)
	if entity.blocks_movement:
		_blocking_by_cell[key] = entity
	elif _blocking_by_cell.get(key) == entity:
		_blocking_by_cell.erase(key)
		if _entities_by_cell.has(key):
			for other in _entities_by_cell[key]:
				if other != entity and other.blocks_movement:
					_blocking_by_cell[key] = other
					break


func get_entities_at(x: int, y: int) -> Array:
	var key := _cell_key(x, y)
	return (_entities_by_cell.get(key, []) as Array).duplicate()


func is_walkable(x: int, y: int) -> bool:
	if not is_in_bounds(x, y):
		return false
	var t: int = tiles[y][x]
	return t == TILE_FLOOR or t == TILE_SAND or t == TILE_DUNE or t == TILE_GRASS or t == TILE_ROAD


func is_transparent(x: int, y: int) -> bool:
	if not is_in_bounds(x, y):
		return false
	var t: int = tiles[y][x]
	# Water blocks movement but you can see across it (flat, open surface).
	return t == TILE_FLOOR or t == TILE_SAND or t == TILE_DUNE or t == TILE_GRASS or t == TILE_WATER or t == TILE_ROAD


# Returns the first blocking entity at (x, y), or null.
func get_blocking_entity_at(x: int, y: int):
	return _blocking_by_cell.get(_cell_key(x, y), null)


func set_glyph_override(x: int, y: int, glyph: String) -> void:
	if not is_in_bounds(x, y):
		return
	glyph_overrides[y][x] = glyph


func clear_glyph_override(x: int, y: int) -> void:
	if not is_in_bounds(x, y):
		return
	glyph_overrides[y][x] = ""


func get_glyph_override(x: int, y: int) -> String:
	if not is_in_bounds(x, y):
		return ""
	return str(glyph_overrides[y][x])


func reveal_all() -> void:
	for y in range(height):
		for x in range(width):
			visible[y][x] = true
			explored[y][x] = true


func compute_fov(ox: int, oy: int, radius: int) -> void:
	for y in range(height):
		for x in range(width):
			visible[y][x] = false
	_shadowcast_fov(ox, oy, radius)
	_reveal_permanently_lit_regions()


# Like compute_fov but does NOT clear the visible array first.
# Used to add light from static sources (braziers, road torches) on top of the
# player's own FOV without erasing what they can already see.
func compute_fov_additive(ox: int, oy: int, radius: int) -> void:
	_shadowcast_fov(ox, oy, radius)
	_reveal_permanently_lit_regions()


func _shadowcast_fov(ox: int, oy: int, radius: int) -> void:
	if not is_in_bounds(ox, oy):
		return

	visible[oy][ox] = true
	explored[oy][ox] = true

	var radius_sq: int = radius * radius
	for transform: Array in _OCTANT_TRANSFORMS:
		_cast_light(ox, oy, 1, 1.0, 0.0, radius, radius_sq,
				int(transform[0]), int(transform[1]), int(transform[2]), int(transform[3]))


func _cast_light(cx: int, cy: int, row: int, start_slope: float, end_slope: float,
		radius: int, radius_sq: int, xx: int, xy: int, yx: int, yy: int) -> void:
	if start_slope < end_slope:
		return

	var current_start: float = start_slope
	for distance in range(row, radius + 1):
		var blocked: bool = false
		var next_start: float = current_start
		var delta_y: int = -distance

		for delta_x in range(-distance, 1):
			var left_slope: float = (delta_x - 0.5) / (delta_y + 0.5)
			var right_slope: float = (delta_x + 0.5) / (delta_y - 0.5)

			if current_start < right_slope:
				continue
			if end_slope > left_slope:
				break

			var map_x: int = cx + delta_x * xx + delta_y * xy
			var map_y: int = cy + delta_x * yx + delta_y * yy
			if not is_in_bounds(map_x, map_y):
				continue

			var dist_sq: int = delta_x * delta_x + delta_y * delta_y
			if dist_sq <= radius_sq:
				visible[map_y][map_x] = true
				explored[map_y][map_x] = true

			if blocked:
				if not is_transparent(map_x, map_y):
					next_start = right_slope
					continue
				blocked = false
				current_start = next_start
			elif not is_transparent(map_x, map_y) and distance < radius:
				blocked = true
				_cast_light(cx, cy, distance + 1, current_start, left_slope,
						radius, radius_sq, xx, xy, yx, yy)
				next_start = right_slope

		if blocked:
			break


func _reveal_permanently_lit_regions() -> void:
	var visited: Dictionary = {}
	for y in range(height):
		for x in range(width):
			if not visible[y][x] or not permanent_light[y][x]:
				continue
			var key := _cell_key(x, y)
			if visited.has(key):
				continue
			_flood_permanent_light(x, y, visited)


func _flood_permanent_light(start_x: int, start_y: int, visited: Dictionary) -> void:
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	visited[_cell_key(start_x, start_y)] = true

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		visible[pos.y][pos.x] = true
		explored[pos.y][pos.x] = true

		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			if not is_in_bounds(nx, ny) or not permanent_light[ny][nx]:
				continue
			var key := _cell_key(nx, ny)
			if visited.has(key):
				continue
			visited[key] = true
			queue.append(Vector2i(nx, ny))
