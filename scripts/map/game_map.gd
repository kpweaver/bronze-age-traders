class_name GameMap
extends RefCounted

const EntityClass = preload("res://scripts/entities/entity.gd")
const DevProfilerClass = preload("res://scripts/dev_profiler.gd")

const TILE_WALL  := 0  # dungeon wall
const TILE_FLOOR := 1  # dungeon floor
const TILE_SAND  := 2  # open desert (walkable)
const TILE_DUNE  := 3  # rolling dune (walkable)
const TILE_ROCK  := 4  # rocky outcropping (blocks movement + LOS)
const TILE_WATER := 5  # oasis water (blocks movement, transparent)
const TILE_GRASS := 6  # lush grassland (walkable, transparent)
const TILE_ROAD      := 7  # packed-dirt trade road (walkable, transparent)
const TILE_CAVE_WALL := 8  # natural cave wall (blocks movement + LOS)
const TILE_CAVE_FLOOR := 9 # natural cave floor (walkable, transparent)

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
var _permanent_light_regions: Array = []
var _permanent_light_regions_dirty: bool = true
var _visible_cells: Array[int] = []

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
	_permanent_light_regions = []
	_permanent_light_regions_dirty = true
	_visible_cells = []
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


func _cell_key(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


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


func get_entities_view_at(x: int, y: int) -> Array:
	return _entities_by_cell.get(_cell_key(x, y), [])


func is_walkable(x: int, y: int) -> bool:
	if not is_in_bounds(x, y):
		return false
	var t: int = tiles[y][x]
	return t == TILE_FLOOR or t == TILE_SAND or t == TILE_DUNE or t == TILE_GRASS or t == TILE_ROAD or t == TILE_CAVE_FLOOR


func is_transparent(x: int, y: int) -> bool:
	if not is_in_bounds(x, y):
		return false
	var t: int = tiles[y][x]
	# Water blocks movement but you can see across it (flat, open surface).
	return t == TILE_FLOOR or t == TILE_SAND or t == TILE_DUNE or t == TILE_GRASS or t == TILE_WATER or t == TILE_ROAD or t == TILE_CAVE_FLOOR


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
	_visible_cells.clear()
	for y in range(height):
		for x in range(width):
			visible[y][x] = true
			explored[y][x] = true
			_visible_cells.append(y * width + x)


func compute_fov(ox: int, oy: int, radius: int) -> void:
	var clear_started_at: int = DevProfilerClass.start("game_map.compute_fov.clear_visible")
	for cell_id in _visible_cells:
		var y: int = cell_id / width
		var x: int = cell_id - y * width
		visible[y][x] = false
	_visible_cells.clear()
	DevProfilerClass.stop("game_map.compute_fov.clear_visible", clear_started_at)
	var cast_started_at: int = DevProfilerClass.start("game_map.compute_fov.shadowcast")
	_shadowcast_fov(ox, oy, radius)
	DevProfilerClass.stop("game_map.compute_fov.shadowcast", cast_started_at)
	var reveal_started_at: int = DevProfilerClass.start("game_map.compute_fov.reveal_permanent")
	_reveal_permanently_lit_regions()
	DevProfilerClass.stop("game_map.compute_fov.reveal_permanent", reveal_started_at)


# Like compute_fov but does NOT clear the visible array first.
# Used to add light from static sources (braziers, road torches) on top of the
# player's own FOV without erasing what they can already see.
func compute_fov_additive(ox: int, oy: int, radius: int) -> void:
	var cast_started_at: int = DevProfilerClass.start("game_map.compute_fov_additive.shadowcast")
	_shadowcast_fov(ox, oy, radius)
	DevProfilerClass.stop("game_map.compute_fov_additive.shadowcast", cast_started_at)
	var reveal_started_at: int = DevProfilerClass.start("game_map.compute_fov_additive.reveal_permanent")
	_reveal_permanently_lit_regions()
	DevProfilerClass.stop("game_map.compute_fov_additive.reveal_permanent", reveal_started_at)


func _shadowcast_fov(ox: int, oy: int, radius: int) -> void:
	if not is_in_bounds(ox, oy):
		return

	_reveal_cell(ox, oy)

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
			if map_x < 0 or map_x >= width or map_y < 0 or map_y >= height:
				continue

			var cell_tile: int = tiles[map_y][map_x]
			var transparent: bool = (
				cell_tile == TILE_FLOOR
				or cell_tile == TILE_SAND
				or cell_tile == TILE_DUNE
				or cell_tile == TILE_GRASS
				or cell_tile == TILE_WATER
				or cell_tile == TILE_ROAD
				or cell_tile == TILE_CAVE_FLOOR
			)
			var dist_sq: int = delta_x * delta_x + delta_y * delta_y
			if dist_sq <= radius_sq:
				if not visible[map_y][map_x]:
					visible[map_y][map_x] = true
					_visible_cells.append(map_y * width + map_x)
				if not explored[map_y][map_x]:
					explored[map_y][map_x] = true

			if blocked:
				if not transparent:
					next_start = right_slope
					continue
				blocked = false
				current_start = next_start
			elif not transparent and distance < radius:
				blocked = true
				_cast_light(cx, cy, distance + 1, current_start, left_slope,
						radius, radius_sq, xx, xy, yx, yy)
				next_start = right_slope

		if blocked:
			break


func _reveal_permanently_lit_regions() -> void:
	_rebuild_permanent_light_regions_if_needed()
	for region in _permanent_light_regions:
		var cells: Array = region
		var should_reveal: bool = false
		for pos in cells:
			if visible[pos.y][pos.x]:
				should_reveal = true
				break
		if not should_reveal:
			continue
		for pos in cells:
			_reveal_cell(pos.x, pos.y)


func _reveal_cell(x: int, y: int) -> void:
	if not visible[y][x]:
		visible[y][x] = true
		_visible_cells.append(y * width + x)
	if not explored[y][x]:
		explored[y][x] = true


func _rebuild_permanent_light_regions_if_needed() -> void:
	if not _permanent_light_regions_dirty:
		return
	_permanent_light_regions.clear()
	var visited: Dictionary = {}
	for y in range(height):
		for x in range(width):
			if not permanent_light[y][x]:
				continue
			var key := _cell_key(x, y)
			if visited.has(key):
				continue
			_permanent_light_regions.append(_collect_permanent_light_region(x, y, visited))
	_permanent_light_regions_dirty = false


func _collect_permanent_light_region(start_x: int, start_y: int, visited: Dictionary) -> Array:
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var queue_idx: int = 0
	var cells: Array = []
	visited[_cell_key(start_x, start_y)] = true

	while queue_idx < queue.size():
		var pos: Vector2i = queue[queue_idx]
		queue_idx += 1
		cells.append(pos)

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
	return cells


func _flood_permanent_light(start_x: int, start_y: int, visited: Dictionary) -> void:
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	visited[_cell_key(start_x, start_y)] = true
	var queue_idx: int = 0

	while queue_idx < queue.size():
		var pos: Vector2i = queue[queue_idx]
		queue_idx += 1
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
