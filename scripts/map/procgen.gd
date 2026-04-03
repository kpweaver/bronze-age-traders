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
		var stairs_pos := rooms.back().center()
		var stairs := EntityClass.new(stairs_pos, ">", Color(0.90, 0.85, 0.60), "Stairs Down", false)
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
			monster = ActorClass.new(Vector2i(x, y), "B", Color(0.48, 0.32, 0.12), "Desert Beast", hp, 2, power)
		else:
			var hp    := 10 + (floor - 1) * 2
			var power := 3  + (floor - 1)
			monster = ActorClass.new(Vector2i(x, y), "r", Color(0.72, 0.22, 0.10), "Raider", hp, 0, power)
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
		var item: Item
		if randf() < 0.6:
			# From floor 3 onward, Healing Draughts (~25 HP) can appear alongside
			# basic Health Potions (~8 HP). Chance grows with depth, capped at 50%.
			var draught_chance := clampf((floor - 2) * 0.15, 0.0, 0.5)
			if floor >= 3 and randf() < draught_chance:
				item = ItemClass.new(Vector2i(x, y), ItemClass.TYPE_HEALING_DRAUGHT, randi_range(20, 30))
			else:
				item = ItemClass.new(Vector2i(x, y), ItemClass.TYPE_HEALTH_POTION, randi_range(6, 10))
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
