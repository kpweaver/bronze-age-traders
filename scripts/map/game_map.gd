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
var entities: Array # Array[Entity]


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	tiles = []
	visible = []
	explored = []
	entities = []
	for y in range(height):
		tiles.append([])
		visible.append([])
		explored.append([])
		for x in range(width):
			tiles[y].append(TILE_WALL)
			visible[y].append(false)
			explored[y].append(false)


func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


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
	for e in entities:
		if e.pos.x == x and e.pos.y == y and e.blocks_movement:
			return e
	return null


func compute_fov(ox: int, oy: int, radius: int) -> void:
	for y in range(height):
		for x in range(width):
			visible[y][x] = false

	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var tx := ox + dx
			var ty := oy + dy
			if not is_in_bounds(tx, ty):
				continue
			if _has_los(ox, oy, tx, ty):
				visible[ty][tx] = true
				explored[ty][tx] = true


# Like compute_fov but does NOT clear the visible array first.
# Used to add light from static sources (braziers, road torches) on top of the
# player's own FOV without erasing what they can already see.
func compute_fov_additive(ox: int, oy: int, radius: int) -> void:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var tx := ox + dx
			var ty := oy + dy
			if not is_in_bounds(tx, ty):
				continue
			if _has_los(ox, oy, tx, ty):
				visible[ty][tx] = true
				explored[ty][tx] = true


# Bresenham LOS — transparent intermediate tiles only.
# Destination is always reachable (you can see the wall that blocks you).
func _has_los(x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x1 > x0 else -1
	var sy := 1 if y1 > y0 else -1
	var err := dx - dy
	var x := x0
	var y := y0

	while true:
		if x == x1 and y == y1:
			return true
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		# Block on opaque intermediate tiles (not the destination itself)
		if not (x == x1 and y == y1) and not is_transparent(x, y):
			return false

	return false  # unreachable
