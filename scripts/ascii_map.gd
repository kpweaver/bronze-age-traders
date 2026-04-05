extends Node2D

const GameMapClass     = preload("res://scripts/map/game_map.gd")
const EntityClass      = preload("res://scripts/entities/entity.gd")
const ActorClass       = preload("res://scripts/entities/actor.gd")
const ItemClass        = preload("res://scripts/entities/item.gd")
const NpcClass         = preload("res://scripts/entities/npc.gd")
const ProcgenClass     = preload("res://scripts/map/procgen.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")

# ---------------------------------------------------------------------------
# Display constants  (viewport: 1080×720, cell: 9×18 → 120×40 tiles)
# ---------------------------------------------------------------------------
const COLS: int = 120      # visible columns
const ROWS: int = 40       # total rows including UI
const FONT_SIZE: int = 16
const CELL_W: float = 9.0
const CELL_H: float = 18.0

const MAP_ROWS: int      = 35  # visible map rows
const DIVIDER_ROW: int   = 35
const STATUS_ROW: int    = 36
const MSG_START_ROW: int = 37
const MSG_LINES: int     = 3

const FOV_RADIUS: int      = 8
const FOV_OVERWORLD: int   = 24  # wide sight lines in open desert

# Internal map dimensions — larger than the viewport, enabling scrolling.
const DUNGEON_W: int   = 160
const DUNGEON_H: int   = 70
const OVERWORLD_W: int = 200
const OVERWORLD_H: int = 100

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
const C_BG         := Color(0.05, 0.04, 0.03)
const C_WALL_LIT   := Color(0.55, 0.38, 0.22)
const C_WALL_DIM   := Color(0.22, 0.15, 0.09)
const C_FLOOR_LIT  := Color(0.28, 0.24, 0.16)
const C_FLOOR_DIM  := Color(0.10, 0.09, 0.06)
const C_DIVIDER    := Color(0.30, 0.20, 0.10)
const C_STATUS     := Color(0.80, 0.50, 0.20)
const C_GOLD       := Color(0.90, 0.78, 0.15)
const C_MSG_RECENT := Color(0.78, 0.68, 0.52)
const C_MSG_OLD    := Color(0.45, 0.38, 0.28)

# Overworld tile palette — biome-tuned, sun-baked
const C_SAND_LIT   := Color(0.98, 0.88, 0.48)  # bright sunlit sand
const C_SAND_DIM   := Color(0.55, 0.46, 0.22)  # shadow sand
const C_DUNE_LIT   := Color(0.94, 0.68, 0.22)  # warm amber dune crest
const C_DUNE_DIM   := Color(0.50, 0.34, 0.10)  # dune shadow
const C_ROCK_LIT   := Color(0.78, 0.38, 0.18)  # terracotta rock face
const C_ROCK_DIM   := Color(0.40, 0.18, 0.08)  # rock in shadow
const C_WATER_LIT  := Color(0.22, 0.55, 0.88)  # oasis water, sunlit
const C_WATER_DIM  := Color(0.10, 0.26, 0.44)  # oasis water, shadow
const C_GRASS_LIT  := Color(0.40, 0.75, 0.22)  # lush grass, sunlit
const C_GRASS_DIM  := Color(0.18, 0.38, 0.10)  # grass in shadow
const C_ROAD_LIT   := Color(0.78, 0.62, 0.38)  # packed-dirt road, sunlit
const C_ROAD_DIM   := Color(0.42, 0.32, 0.18)  # road in shadow
const C_VILLAGE_WM := Color(0.95, 0.90, 0.70)  # village marker on world map

# ---------------------------------------------------------------------------
# Escape menu
# ---------------------------------------------------------------------------
const ESCAPE_OPTIONS := ["Resume", "Settings", "Save & Quit to Title", "Quit Game"]
var _escape_cursor: int = 0

# ---------------------------------------------------------------------------
# Overlay screens
# ---------------------------------------------------------------------------
enum Screen { NONE, ESCAPE, INVENTORY, CHARACTER, SETTINGS, LOOK, WORLD_MAP, TRADE, DISAMBIGUATE, HELP }
var _screen: Screen          = Screen.NONE
var _world_look_mode: bool   = false
var _world_look_cursor: Vector2i = Vector2i.ZERO
var _world_entry_chunk: Vector2i = Vector2i.ZERO  # chunk when world map was opened

# NPC interaction
var _nearby_npc = null   # last NPC bumped (cleared when player moves away)

# Trade screen state
var _trade_npc  = null   # merchant currently being traded with
var _trade_buy_cursor:  int = 0   # cursor in merchant's stock list
var _trade_sell_cursor: int = 0   # cursor in player's sellable inventory
var _trade_panel: int = 0         # 0 = buy panel active, 1 = sell panel active

# Disambiguation overlay — used whenever a key press has multiple valid targets.
# Each option: {label: String, key: int (physical_keycode), callback: Callable}
var _disambig_prompt:  String = ""
var _disambig_options: Array  = []

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------
var _map        # GameMap
var _player     # Actor
var _floor: int = 0
var _floors: Dictionary = {}  # dungeon floor number (1+) -> GameMap
var _chunk: Vector2i     = Vector2i.ZERO  # current overworld chunk coords
var _chunks: Dictionary  = {}             # Vector2i -> GameMap for visited overworld chunks
var _cam_x: int = 0  # top-left map column currently visible
var _cam_y: int = 0  # top-left map row currently visible
var _look_pos: Vector2i = Vector2i.ZERO
var _messages: Array[String] = []
var _game_over: bool = false
var _font: Font


func _ready() -> void:
	_font = _make_font()
	if GameState.load_save:
		_load_from_save()
		GameState.load_save = false
	else:
		_new_game()


func _make_font() -> Font:
	var path := "res://assets/fonts/Px437_IBM_VGA_9x16.ttf"
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "Courier New"])
	return sf


func _new_game() -> void:
	_floor  = 0
	_chunk  = Vector2i.ZERO
	_floors.clear()
	_chunks.clear()
	_game_over = false
	_screen    = Screen.NONE
	_messages.clear()

	# Roll the world seed once — all overworld chunks use this for seamless borders.
	GameState.world_seed   = randi()
	GameState.world_biomes = ProcgenClass.generate_world_biomes(GameState.WORLD_W, GameState.WORLD_H, GameState.world_seed)
	GameState.villages     = ProcgenClass.generate_villages(GameState.WORLD_W, GameState.WORLD_H, GameState.world_biomes, GameState.world_seed)
	GameState.road_chunks  = ProcgenClass.generate_roads(GameState.villages, GameState.WORLD_W, GameState.WORLD_H)

	# Player starts at the centre of the world map (always forced to BIOME_DESERT).
	_chunk = Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1)

	# Build the starting overworld chunk.
	var ow_map = GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
	ProcgenClass.generate_overworld(ow_map, _chunk.x * OVERWORLD_W, _chunk.y * OVERWORLD_H,
			GameState.world_seed, GameMapClass.BIOME_DESERT, true, _get_road_dirs(_chunk), false)

	# Find a natural cave mouth: a walkable tile beside rocky outcroppings.
	var entrance_pos: Vector2i = ProcgenClass.find_cave_entrance(ow_map)
	var dungeon_entry := EntityClass.new(entrance_pos, ">", Color(0.90, 0.85, 0.60), "dungeon entrance", false)
	dungeon_entry.game_map = ow_map
	ow_map.entities.append(dungeon_entry)

	# Spawn the player a few steps away from the entrance, toward the centre.
	var spawn_pos: Vector2i = _walk_toward_center(ow_map, entrance_pos, 6)
	_player = ActorClass.new(spawn_pos, "@", Color(0.80, 0.72, 0.55), "you", 30, 2, 5)
	_player.game_map = ow_map
	ow_map.entities.append(_player)
	_map = ow_map

	_update_camera()
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_OVERWORLD)
	_log("You stand beneath a merciless sun. The dungeon entrance lies nearby. Press < for the world map.")
	queue_redraw()


# Walk up to `steps` tiles from `from` toward the map centre, avoiding rocks.
# Each step picks the walkable neighbour that is closest to the centre.
func _walk_toward_center(map, from: Vector2i, steps: int) -> Vector2i:
	var cx: int = map.width  >> 1
	var cy: int = map.height >> 1
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
				if not map.is_walkable(nx, ny):
					continue
				var d: int = (nx - cx) * (nx - cx) + (ny - cy) * (ny - cy)
				if d < best_dist:
					best_dist = d
					best_next = Vector2i(nx, ny)
		if best_next == pos:
			break  # no walkable neighbour closer to centre — stop here
		pos = best_next
	return pos


func _chunk_transition(dir: Vector2i) -> void:
	# Work out which axis (or axes) crossed the boundary.
	var next: Vector2i  = _player.pos + dir
	var dc   := Vector2i.ZERO
	var new_x: int      = next.x
	var new_y: int      = next.y

	if next.x < 0:
		dc.x  = -1
		new_x = OVERWORLD_W - 2
	elif next.x >= OVERWORLD_W:
		dc.x  = 1
		new_x = 1

	if next.y < 0:
		dc.y  = -1
		new_y = OVERWORLD_H - 2
	elif next.y >= OVERWORLD_H:
		dc.y  = 1
		new_y = 1

	# Save current chunk, move to the new one.
	_map.entities.erase(_player)
	_chunks[_chunk] = _map
	_chunk += dc

	if _chunks.has(_chunk):
		_map = _chunks[_chunk]
	else:
		var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
		var wx: int = _chunk.x * OVERWORLD_W
		var wy: int = _chunk.y * OVERWORLD_H
		ProcgenClass.generate_overworld(new_map, wx, wy, GameState.world_seed,
				_get_chunk_biome(_chunk), false, _get_road_dirs(_chunk), _is_village_chunk(_chunk.x, _chunk.y))
		_map = new_map

	_player.pos      = Vector2i(new_x, new_y)
	_player.game_map = _map
	_map.entities.append(_player)

	_update_camera()
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_OVERWORLD)
	var arrival_v: Variant = _get_village_at_chunk(_chunk.x, _chunk.y)
	if arrival_v != null:
		_log("You enter %s." % arrival_v.name)
	else:
		_log("You enter the %s." % _biome_name(_get_chunk_biome(_chunk)))
	queue_redraw()


func _load_from_save() -> void:
	var data := SaveManagerClass.load_game()
	if data.is_empty():
		_new_game()
		return
	_game_over = false
	_screen    = Screen.NONE
	_messages.clear()
	var result := SaveManagerClass.restore(data, FOV_RADIUS)
	_map    = result[0]
	_player = result[1]
	_floor  = result[2]
	_floors = result[3]
	_chunk  = result[4]
	_chunks = result[5]
	# Regenerate world data deterministically from the saved seed.
	GameState.world_biomes = ProcgenClass.generate_world_biomes(GameState.WORLD_W, GameState.WORLD_H, GameState.world_seed)
	GameState.villages     = ProcgenClass.generate_villages(GameState.WORLD_W, GameState.WORLD_H, GameState.world_biomes, GameState.world_seed)
	GameState.road_chunks  = ProcgenClass.generate_roads(GameState.villages, GameState.WORLD_W, GameState.WORLD_H)
	_update_camera()
	_log("You return to where you left off...")
	queue_redraw()


func _stairs_pos(map, ch: String) -> Vector2i:
	for e in map.entities:
		if not (e is ActorClass) and e.char == ch:
			return e.pos
	return Vector2i(0, 0)


func _descend() -> void:
	_map.entities.erase(_player)
	if _floor == 0:
		# Descending from the overworld — save current chunk, not _floors.
		_chunks[_chunk] = _map
		_floor = 1
	else:
		_floors[_floor] = _map
		_floor += 1

	if _floors.has(_floor):
		_map = _floors[_floor]
		_player.pos      = _stairs_pos(_map, "<")
		_player.game_map = _map
		_map.entities.append(_player)
	else:
		var new_map = GameMapClass.new(DUNGEON_W, DUNGEON_H)
		_player.game_map = new_map
		_player.pos      = Vector2i(0, 0)
		new_map.entities.append(_player)
		_map = new_map
		var monsters := mini(2 + (_floor - 1) >> 1, 4)
		ProcgenClass.generate_dungeon(_map, 50, 5, 14, monsters, _player, _floor)
		var up_stairs := EntityClass.new(_player.pos, "<", Color(0.55, 0.80, 0.95), "stairs up", false)
		up_stairs.game_map = _map
		_map.entities.append(up_stairs)

	_update_camera()
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_RADIUS)
	_log("You descend to floor %d. The air grows heavier." % _floor)
	queue_redraw()


func _ascend() -> void:
	if _floor <= 0:
		_log("There is nothing above.")
		return
	_map.entities.erase(_player)
	_floors[_floor] = _map
	_floor -= 1

	if _floor == 0:
		# Return to the overworld — restore the chunk we descended from.
		if _chunks.has(_chunk):
			_map = _chunks[_chunk]
			_player.pos      = _stairs_pos(_map, ">")
			_player.game_map = _map
			_map.entities.append(_player)
		else:
			# Fallback: regenerate the chunk (shouldn't normally happen).
			var new_map = GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
			var is_center: bool = (_chunk == Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1))
			ProcgenClass.generate_overworld(new_map, _chunk.x * OVERWORLD_W, _chunk.y * OVERWORLD_H,
					GameState.world_seed, _get_chunk_biome(_chunk), is_center,
					_get_road_dirs(_chunk), _is_village_chunk(_chunk.x, _chunk.y))
			var entrance_pos: Vector2i = ProcgenClass.find_cave_entrance(new_map)
			var dungeon_entry := EntityClass.new(entrance_pos, ">", Color(0.90, 0.85, 0.60), "dungeon entrance", false)
			dungeon_entry.game_map = new_map
			new_map.entities.append(dungeon_entry)
			_player.pos      = entrance_pos
			_player.game_map = new_map
			new_map.entities.append(_player)
			_map = new_map
	else:
		if _floors.has(_floor):
			_map = _floors[_floor]
			_player.pos      = _stairs_pos(_map, ">")
			_player.game_map = _map
			_map.entities.append(_player)

	_update_camera()
	var fov := FOV_OVERWORLD if _map.map_type == GameMapClass.MAP_OVERWORLD else FOV_RADIUS
	_map.compute_fov(_player.pos.x, _player.pos.y, fov)
	if _floor == 0:
		_log("You emerge into the blinding light of the open desert.")
	else:
		_log("You ascend to floor %d." % _floor)
	queue_redraw()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match _screen:
		Screen.ESCAPE:
			_handle_escape_input(event)
			return
		Screen.INVENTORY:
			_handle_inventory_input(event)
			return
		Screen.CHARACTER:
			_handle_character_input(event)
			return
		Screen.SETTINGS:
			_handle_settings_input(event)
			return
		Screen.LOOK:
			_handle_look_input(event)
			return
		Screen.WORLD_MAP:
			_handle_world_map_input(event)
			return
		Screen.TRADE:
			_handle_trade_input(event)
			return
		Screen.DISAMBIGUATE:
			_handle_disambig_input(event)
			return
		Screen.HELP:
			get_viewport().set_input_as_handled()
			_screen = Screen.NONE
			queue_redraw()
			return

	# Escape — always valid regardless of shift.
	if event.physical_keycode == KEY_ESCAPE:
		_screen = Screen.ESCAPE
		_escape_cursor = 0
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	# ? (shift+/) — help screen.
	if event.shift_pressed and event.physical_keycode == KEY_SLASH:
		_screen = Screen.HELP
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	# Unshifted letter overlay toggles — explicitly guard against shift so that
	# e.g. shift+i does not accidentally open the inventory.
	if not event.shift_pressed:
		match event.physical_keycode:
			KEY_I:
				_screen = Screen.INVENTORY
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			KEY_C:
				_screen = Screen.CHARACTER
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			KEY_L:
				_look_pos = _player.pos
				_screen   = Screen.LOOK
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			KEY_T:
				get_viewport().set_input_as_handled()
				var merchants: Array = _get_adjacent_merchants()
				if merchants.is_empty():
					return
				var options: Array = []
				for m: Dictionary in merchants:
					var npc_ref = m.npc
					var dir_key: int = _dir_to_key(m.dir as Vector2i)
					options.append({
						"label":    "%s (%s)" % [(npc_ref as NpcClass).name.capitalize(), _dir_name(m.dir as Vector2i)],
						"key":      dir_key,
						"callback": func(): _open_trade(npc_ref),
					})
				_disambiguate("Trade with which merchant?", options)
				return

	if _game_over:
		if event.physical_keycode == KEY_R and not event.shift_pressed:
			_new_game()
		return

	# > and < are shifted keys — check modifier explicitly before the match.
	if event.shift_pressed and event.physical_keycode == KEY_PERIOD:
		get_viewport().set_input_as_handled()
		_try_descend()
		return
	if event.shift_pressed and event.physical_keycode == KEY_COMMA:
		get_viewport().set_input_as_handled()
		if _floor == 0:
			_world_look_mode   = false
			_world_look_cursor = _chunk
			_world_entry_chunk = _chunk
			_screen = Screen.WORLD_MAP
			queue_redraw()
		else:
			_try_ascend()
		return

	var dir := Vector2i.ZERO
	match event.physical_keycode:
		KEY_KP_8, KEY_UP:    dir = Vector2i(0, -1)
		KEY_KP_2, KEY_DOWN:  dir = Vector2i(0, 1)
		KEY_KP_4, KEY_LEFT:  dir = Vector2i(-1, 0)
		KEY_KP_6, KEY_RIGHT: dir = Vector2i(1, 0)
		KEY_KP_7:            dir = Vector2i(-1, -1)
		KEY_KP_9:            dir = Vector2i(1, -1)
		KEY_KP_1:            dir = Vector2i(-1, 1)
		KEY_KP_3:            dir = Vector2i(1, 1)
		KEY_KP_5, KEY_PERIOD: pass  # wait
		KEY_G:
			if not event.shift_pressed:
				_auto_pickup(); _do_enemy_turns(); _end_turn()
			return
		_:      return

	get_viewport().set_input_as_handled()
	_do_player_turn(dir)


func _handle_escape_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_ESCAPE:
			_screen = Screen.NONE
			queue_redraw()
		KEY_UP, KEY_KP_8:
			_escape_cursor = wrapi(_escape_cursor - 1, 0, ESCAPE_OPTIONS.size())
			queue_redraw()
		KEY_DOWN, KEY_KP_2:
			_escape_cursor = wrapi(_escape_cursor + 1, 0, ESCAPE_OPTIONS.size())
			queue_redraw()
		KEY_ENTER, KEY_KP_ENTER:
			_confirm_escape()


func _confirm_escape() -> void:
	match _escape_cursor:
		0:  # Resume
			_screen = Screen.NONE
			queue_redraw()
		1:  # Settings
			_screen = Screen.SETTINGS
			queue_redraw()
		2:  # Save & Quit to Title
			if not _game_over:
				SaveManagerClass.save_game(_map, _player, _floor, _floors, _chunk, _chunks)
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		3:  # Quit Game
			get_tree().quit()


func _handle_inventory_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE or (key == KEY_I and not event.shift_pressed):
		_screen = Screen.NONE
		queue_redraw()
		return

	# w/b/f/h — unequip from weapon/body/feet/head slot (unshifted only).
	if not event.shift_pressed:
		var unequip_slot := ""
		match key:
			KEY_W: unequip_slot = ItemClass.SLOT_WEAPON
			KEY_B: unequip_slot = ItemClass.SLOT_BODY
			KEY_F: unequip_slot = ItemClass.SLOT_FEET
			KEY_H: unequip_slot = ItemClass.SLOT_HEAD
		if unequip_slot != "":
			var msg: String = _player.unequip(unequip_slot)
			if msg != "":
				_log(msg)
				queue_redraw()
			return

	# a–t — use usable items, equip equipment items (unshifted only).
	if not event.shift_pressed and key >= KEY_A and key <= KEY_T:
		var idx: int = key - KEY_A
		if idx < _player.inventory.size():
			var item = _player.inventory[idx]
			if item.category == ItemClass.CATEGORY_EQUIPMENT:
				var msg: String = _player.equip(item)
				_log(msg)
				_screen = Screen.NONE
				_do_enemy_turns()
				_end_turn()
			elif item.category == ItemClass.CATEGORY_USABLE:
				var msg: String = item.use(_player)
				if msg != "":
					_log(msg)
					_player.inventory.remove_at(idx)
					_screen = Screen.NONE
					_do_enemy_turns()
					_end_turn()
			else:
				queue_redraw()


func _handle_character_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE or \
			(event.physical_keycode == KEY_C and not event.shift_pressed):
		_screen = Screen.NONE
		queue_redraw()


func _handle_settings_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		_screen = Screen.ESCAPE
		queue_redraw()
	elif not event.shift_pressed:
		match event.physical_keycode:
			KEY_A:
				GameState.auto_pickup = not GameState.auto_pickup
				queue_redraw()
			KEY_G:
				GameState.god_mode = not GameState.god_mode
				queue_redraw()


func _handle_look_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var moved := true
	match event.physical_keycode:
		KEY_ESCAPE, KEY_L, KEY_ENTER, KEY_KP_ENTER:
			_screen = Screen.NONE
			queue_redraw()
			return
		KEY_KP_8, KEY_UP:    _look_pos += Vector2i(0, -1)
		KEY_KP_2, KEY_DOWN:  _look_pos += Vector2i(0, 1)
		KEY_KP_4, KEY_LEFT:  _look_pos += Vector2i(-1, 0)
		KEY_KP_6, KEY_RIGHT: _look_pos += Vector2i(1, 0)
		KEY_KP_7:            _look_pos += Vector2i(-1, -1)
		KEY_KP_9:            _look_pos += Vector2i(1, -1)
		KEY_KP_1:            _look_pos += Vector2i(-1, 1)
		KEY_KP_3:            _look_pos += Vector2i(1, 1)
		_:                   moved = false
	if moved:
		_look_pos.x = clampi(_look_pos.x, 0, _map.width - 1)
		_look_pos.y = clampi(_look_pos.y, 0, _map.height - 1)
		# Pan camera to keep look cursor centred on screen.
		_cam_x = clampi(_look_pos.x - (COLS >> 1), 0, _map.width  - COLS)
		_cam_y = clampi(_look_pos.y - (MAP_ROWS >> 1), 0, _map.height - MAP_ROWS)
		queue_redraw()


func _look_description() -> String:
	var x := _look_pos.x
	var y := _look_pos.y
	if not _map.is_in_bounds(x, y) or not _map.explored[y][x]:
		return "Unexplored."

	var tile_type: int = _map.tiles[y][x]
	var tile: String
	match tile_type:
		GameMapClass.TILE_WALL:  tile = "stone wall"
		GameMapClass.TILE_FLOOR: tile = "stone floor"
		GameMapClass.TILE_SAND:  tile = "open desert"
		GameMapClass.TILE_DUNE:  tile = "sandy dune"
		GameMapClass.TILE_ROCK:  tile = "rocky outcropping"
		GameMapClass.TILE_WATER: tile = "shimmering water"
		GameMapClass.TILE_GRASS: tile = "lush grassland"
		GameMapClass.TILE_ROAD:  tile = "packed-dirt trade road"
		_:                       tile = "unknown terrain"

	if not _map.visible[y][x]:
		return "You remember: %s." % tile

	# Collect visible entities at this tile (highest draw priority last = most important first).
	var names: Array[String] = []
	for e in _map.entities:
		if e.pos == Vector2i(x, y):
			names.append(e.name as String)
	if names.is_empty():
		return "You see: %s." % tile
	return "You see: %s." % ", ".join(names)


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
func _update_camera() -> void:
	_cam_x = clampi(_player.pos.x - (COLS >> 1), 0, _map.width  - COLS)
	_cam_y = clampi(_player.pos.y - (MAP_ROWS >> 1), 0, _map.height - MAP_ROWS)


func _to_screen(mx: int, my: int) -> Vector2i:
	return Vector2i(mx - _cam_x, my - _cam_y)


func _on_screen(mx: int, my: int) -> bool:
	return mx >= _cam_x and mx < _cam_x + COLS \
	   and my >= _cam_y and my < _cam_y + MAP_ROWS


# ---------------------------------------------------------------------------
# Turn logic
# ---------------------------------------------------------------------------
func _do_player_turn(dir: Vector2i) -> void:
	if dir != Vector2i.ZERO:
		var next: Vector2i = _player.pos + dir
		if not _map.is_in_bounds(next.x, next.y):
			if _map.map_type == GameMapClass.MAP_OVERWORLD:
				_chunk_transition(dir)
			return

		var target = _map.get_blocking_entity_at(next.x, next.y)
		if target != null:
			if target is NpcClass and (target as NpcClass).is_alive:
				# Bump NPC: show greeting; offer trade hint if merchant.
				_nearby_npc = target
				var npc: NpcClass = target as NpcClass
				_log("%s says: \"%s\"" % [npc.name.capitalize(), npc.greet()])
			elif target is ActorClass and (target as ActorClass).is_alive:
				_log(_player.attack(target as ActorClass))
				if GameState.god_mode and (target as ActorClass).is_alive:
					(target as ActorClass).take_damage((target as ActorClass).hp)
				if not (target as ActorClass).is_alive:
					_log((target as ActorClass).die())
		elif _map.is_walkable(next.x, next.y):
			_player.pos = next
			_nearby_npc = null   # moved away — clear NPC context
			if GameState.auto_pickup:
				_auto_pickup()
			_check_stairs()
		else:
			return  # wall — no turn consumed

	_do_enemy_turns()
	_end_turn()


func _auto_pickup() -> void:
	for e in _map.entities.duplicate():
		if not (e is ItemClass) or e.pos != _player.pos:
			continue
		if e.item_type == ItemClass.TYPE_GOLD:
			_player.gold += e.value
			_log("You collect %d gold." % e.value)
			_map.entities.erase(e)
		elif _player.inventory.size() < ActorClass.MAX_INVENTORY:
			_player.inventory.append(e)
			var slot := char(ord("a") + _player.inventory.size() - 1)
			_log("You pick up the %s. [%s]" % [e.name, slot])
			_map.entities.erase(e)
		else:
			_log("Your pack is full!")


func _check_stairs() -> void:
	for e in _map.entities:
		if (e is ActorClass) or e.pos != _player.pos:
			continue
		if e.char == ">":
			if (e.name as String) == "dungeon entrance":
				_log("A dungeon entrance yawns in the earth. > to enter.")
			else:
				_log("Stairs lead down. > to descend.")
			return
		if e.char == "<":
			var hint := "< to ascend." if _floor > 1 else "< to surface."
			_log("Stairs lead up. %s" % hint)
			return


func _try_descend() -> void:
	for e in _map.entities:
		if not (e is ActorClass) and e.char == ">" and e.pos == _player.pos:
			get_viewport().set_input_as_handled()
			_descend()
			return


func _try_ascend() -> void:
	for e in _map.entities:
		if not (e is ActorClass) and e.char == "<" and e.pos == _player.pos:
			get_viewport().set_input_as_handled()
			_ascend()
			return


func _do_enemy_turns() -> void:
	for e in _map.entities:
		if not (e is ActorClass):
			continue
		if e == _player or not e.is_alive or e.ai == null:
			continue
		var msg: String = e.ai.take_turn(_player, _map)
		if msg != "":
			_log(msg)
		if not _player.is_alive:
			if GameState.god_mode:
				_player.hp = _player.max_hp
			else:
				_log(_player.die())
				_log("You are dead.  Press r to try again.")
				_game_over = true
				return


func _end_turn() -> void:
	_update_camera()
	var fov := FOV_OVERWORLD if _map.map_type == GameMapClass.MAP_OVERWORLD else FOV_RADIUS
	_map.compute_fov(_player.pos.x, _player.pos.y, fov)
	queue_redraw()


# ---------------------------------------------------------------------------
# Message log
# ---------------------------------------------------------------------------
func _log(text: String) -> void:
	_messages.append(text)
	if _messages.size() > MSG_LINES:
		_messages = _messages.slice(_messages.size() - MSG_LINES)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), C_BG)
	if _screen == Screen.WORLD_MAP:
		_draw_world_map()
		_draw_ui()
		return
	_draw_map()
	_draw_entities()
	_draw_ui()
	match _screen:
		Screen.ESCAPE:    _draw_escape_menu()
		Screen.INVENTORY: _draw_inventory()
		Screen.CHARACTER: _draw_character_sheet()
		Screen.SETTINGS:  _draw_settings()
		Screen.LOOK:         _draw_look_cursor()
		Screen.TRADE:        _draw_trade_screen()
		Screen.DISAMBIGUATE: _draw_disambig_overlay()
		Screen.HELP:         _draw_help_screen()


func _draw_map() -> void:
	for vy in range(MAP_ROWS):
		for vx in range(COLS):
			var mx := vx + _cam_x
			var my := vy + _cam_y
			if not _map.is_in_bounds(mx, my) or not _map.explored[my][mx]:
				continue
			var tile: int = _map.tiles[my][mx]
			var lit: bool = _map.visible[my][mx]
			var ch: String
			var color: Color
			match tile:
				GameMapClass.TILE_WALL:
					ch = "#"; color = C_WALL_LIT if lit else C_WALL_DIM
				GameMapClass.TILE_FLOOR:
					ch = "."; color = C_FLOOR_LIT if lit else C_FLOOR_DIM
				GameMapClass.TILE_SAND:
					ch = "."; color = C_SAND_LIT if lit else C_SAND_DIM
				GameMapClass.TILE_DUNE:
					ch = "^"; color = C_DUNE_LIT if lit else C_DUNE_DIM
				GameMapClass.TILE_ROCK:
					ch = "#"; color = C_ROCK_LIT if lit else C_ROCK_DIM
				GameMapClass.TILE_WATER:
					ch = "~"; color = C_WATER_LIT if lit else C_WATER_DIM
				GameMapClass.TILE_GRASS:
					ch = "."; color = C_GRASS_LIT if lit else C_GRASS_DIM
				GameMapClass.TILE_ROAD:
					ch = "\u2591"; color = C_ROAD_LIT if lit else C_ROAD_DIM
				_:
					ch = "?"; color = Color.WHITE
			_put(vx, vy, ch, color)


func _draw_entities() -> void:
	# key: screen-space Vector2i; value: entity. Three passes for priority.
	var cell_map: Dictionary = {}

	for e in _map.entities:
		if not (e is ActorClass) and _on_screen(e.pos.x, e.pos.y) \
				and _map.visible[e.pos.y][e.pos.x]:
			cell_map[_to_screen(e.pos.x, e.pos.y)] = e
	for e in _map.entities:
		if (e is ActorClass) and not e.is_alive and _on_screen(e.pos.x, e.pos.y) \
				and _map.visible[e.pos.y][e.pos.x]:
			cell_map[_to_screen(e.pos.x, e.pos.y)] = e
	for e in _map.entities:
		if (e is ActorClass) and e.is_alive and _on_screen(e.pos.x, e.pos.y) \
				and _map.visible[e.pos.y][e.pos.x]:
			cell_map[_to_screen(e.pos.x, e.pos.y)] = e

	for sp in cell_map:
		var e = cell_map[sp]
		draw_rect(Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H), C_BG)
		_put(sp.x, sp.y, e.char as String, e.color)


func _draw_ui() -> void:
	for x in range(COLS):
		_put(x, DIVIDER_ROW, "-", C_DIVIDER)

	var hp_frac: float = float(_player.hp) / float(_player.max_hp)
	var hp_color       := C_STATUS.lerp(Color(0.8, 0.15, 0.05), 1.0 - hp_frac)
	var wpn     = _player.equipped.get(ItemClass.SLOT_WEAPON)
	var wpn_str := ("  WPN: %s" % (wpn as ItemClass).name) if wpn != null else ""
	var status := "HP: %d/%d   ATK: 1d6+%d  AC: %d   Gold: %d   Floor: %d%s" % [
		_player.hp, _player.max_hp, _player.power + _player.total_attack_bonus,
		_player.ac, _player.gold, _floor, wpn_str
	]
	_puts(0, STATUS_ROW, status, hp_color)

	for i in range(_messages.size()):
		var is_last := i == _messages.size() - 1
		_puts(0, MSG_START_ROW + i, _messages[i], C_MSG_RECENT if is_last else C_MSG_OLD)


# ---------------------------------------------------------------------------
# Overlay: escape menu
# ---------------------------------------------------------------------------
func _draw_escape_menu() -> void:
	const BOX_W := 52
	const BOX_H := 12
	const BOX_X := (COLS - BOX_W) >> 1
	const BOX_Y := (MAP_ROWS - BOX_H) >> 1

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ PAUSED ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y + 1, title, C_STATUS)

	for i in range(ESCAPE_OPTIONS.size()):
		var color  := C_STATUS if i == _escape_cursor else C_MSG_OLD
		var prefix := "> " if i == _escape_cursor else "  "
		_puts(BOX_X + 2, BOX_Y + 3 + i, prefix + ESCAPE_OPTIONS[i], color)

	var hint := "enter: select   esc: resume"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: settings
# ---------------------------------------------------------------------------
func _draw_settings() -> void:
	const BOX_W := 54
	const BOX_H := 12
	const BOX_X := (COLS - BOX_W) >> 1
	const BOX_Y := (MAP_ROWS - BOX_H) >> 1

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ SETTINGS ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y + 1, title, C_STATUS)

	var ap_val  := "ON " if GameState.auto_pickup else "OFF"
	var god_val := "ON " if GameState.god_mode    else "OFF"
	_puts(BOX_X + 2, BOX_Y + 3, "a) Auto-pickup items:  %s" % ap_val,  C_MSG_RECENT)
	_puts(BOX_X + 2, BOX_Y + 4, "g) God mode:           %s" % god_val,
		Color(1.0, 0.85, 0.2) if GameState.god_mode else C_MSG_RECENT)

	var hint := "esc: back"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: inventory
# ---------------------------------------------------------------------------
func _draw_inventory() -> void:
	const BOX_X := 2
	const BOX_Y := 1
	const BOX_W := 116
	const BOX_H := 32
	const PACK_X  := BOX_X + 2
	const EQUIP_X := BOX_X + 64

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ INVENTORY ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	# ── Left panel: pack ──────────────────────────────────────────────────
	_puts(PACK_X, BOX_Y + 2, "PACK  (%d/%d)" % [_player.inventory.size(), ActorClass.MAX_INVENTORY], C_STATUS)
	if _player.inventory.is_empty():
		_puts(PACK_X, BOX_Y + 4, "Your pack is empty.", C_MSG_OLD)
	else:
		for i in range(_player.inventory.size()):
			var item = _player.inventory[i]
			var sl   := char(ord("a") + i)
			var tag  := ""
			if item.category == ItemClass.CATEGORY_EQUIPMENT:
				tag = "  [equip]"
			elif item.category == ItemClass.CATEGORY_USABLE:
				tag = "  (%s HP)" % item.dice_label()
			elif item.category == ItemClass.CATEGORY_TRADE and item.base_value > 0:
				tag = "  (%dg)" % item.base_value
			_puts(PACK_X, BOX_Y + 4 + i,
				"%s) %-28s%s" % [sl, item.name, tag], C_MSG_RECENT)

	_puts(PACK_X, BOX_Y + BOX_H - 4, "Gold: %d" % _player.gold, C_GOLD)

	# ── Right panel: equipped gear ────────────────────────────────────────
	_puts(EQUIP_X, BOX_Y + 2, "EQUIPPED", C_STATUS)
	var slot_rows: Array = [
		[ItemClass.SLOT_WEAPON, "w) WEAPON"],
		[ItemClass.SLOT_BODY,   "b) BODY  "],
		[ItemClass.SLOT_FEET,   "f) FEET  "],
		[ItemClass.SLOT_HEAD,   "h) HEAD  "],
	]
	for si in range(slot_rows.size()):
		var sdata: Array  = slot_rows[si]
		var s_key: String = str(sdata[0])
		var s_lbl: String = str(sdata[1])
		var eq    = _player.equipped.get(s_key)
		if eq != null:
			var eq_item: ItemClass = eq as ItemClass
			var bonus_str := ""
			if eq_item.attack_bonus  > 0: bonus_str = "  (+%d atk)" % eq_item.attack_bonus
			if eq_item.defense_bonus > 0: bonus_str = "  (+%d def)" % eq_item.defense_bonus
			_puts(EQUIP_X, BOX_Y + 4 + si * 2,
				"%s: %-20s%s" % [s_lbl, eq_item.name, bonus_str], C_MSG_RECENT)
		else:
			_puts(EQUIP_X, BOX_Y + 4 + si * 2, "%s: -" % s_lbl, C_MSG_OLD)

	var hint := "[a-t] use/equip   [w/b/f/h] unequip   [Esc] close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# NPC / direction helpers
# ---------------------------------------------------------------------------
func _get_adjacent_merchants() -> Array:
	var result: Array = []
	for d: Vector2i in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
		var e = _map.get_blocking_entity_at(_player.pos.x + d.x, _player.pos.y + d.y)
		if e != null and e is NpcClass and (e as NpcClass).is_merchant and (e as NpcClass).is_alive:
			result.append({"npc": e, "dir": d})
	return result


func _open_trade(npc) -> void:
	_trade_npc         = npc
	_trade_buy_cursor  = 0
	_trade_sell_cursor = 0
	_trade_panel       = 0
	_screen            = Screen.TRADE
	queue_redraw()


func _dir_name(d: Vector2i) -> String:
	match d:
		Vector2i( 0, -1): return "north"
		Vector2i( 0,  1): return "south"
		Vector2i(-1,  0): return "west"
		Vector2i( 1,  0): return "east"
		_:                return "?"


func _dir_to_key(d: Vector2i) -> int:
	match d:
		Vector2i( 0, -1): return KEY_UP
		Vector2i( 0,  1): return KEY_DOWN
		Vector2i(-1,  0): return KEY_LEFT
		Vector2i( 1,  0): return KEY_RIGHT
		_:                return KEY_NONE


func _dir_to_arrow(d: Vector2i) -> String:
	match d:
		Vector2i( 0, -1): return "^"
		Vector2i( 0,  1): return "v"
		Vector2i(-1,  0): return "<"
		Vector2i( 1,  0): return ">"
		_:                return "?"


# ---------------------------------------------------------------------------
# Disambiguation overlay
# Fires immediately when there is exactly one option; otherwise prompts player.
# options: Array of {label: String, key: int (physical_keycode), callback: Callable}
# ---------------------------------------------------------------------------
func _disambiguate(prompt: String, options: Array) -> void:
	if options.is_empty():
		return
	if options.size() == 1:
		(options[0].callback as Callable).call()
		return
	_disambig_prompt  = prompt
	_disambig_options = options
	_screen           = Screen.DISAMBIGUATE
	queue_redraw()


func _handle_disambig_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		_screen = Screen.NONE
		queue_redraw()
		return
	for opt: Dictionary in _disambig_options:
		if event.physical_keycode == int(opt.key):
			_screen = Screen.NONE
			(opt.callback as Callable).call()
			return


func _draw_disambig_overlay() -> void:
	const PAD := 3
	var box_w: int = 44
	# Size the box to the widest option label + padding.
	for opt: Dictionary in _disambig_options:
		var w: int = (opt.label as String).length() + 10
		if w > box_w:
			box_w = w
	var box_h: int = _disambig_options.size() + 6
	var box_x: int = (COLS - box_w) >> 1
	var box_y: int = (MAP_ROWS - box_h) >> 1

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.70))
	draw_rect(Rect2(box_x * CELL_W, box_y * CELL_H, box_w * CELL_W, box_h * CELL_H), C_BG)
	_draw_box(box_x, box_y, box_w, box_h)

	_puts(box_x + ((box_w - _disambig_prompt.length()) >> 1), box_y + 1, _disambig_prompt, C_STATUS)

	for i in range(_disambig_options.size()):
		var opt: Dictionary = _disambig_options[i]
		# Reconstruct arrow glyph from the stored keycode.
		var arrow := "?"
		match int(opt.key):
			KEY_UP:    arrow = "^"
			KEY_DOWN:  arrow = "v"
			KEY_LEFT:  arrow = "<"
			KEY_RIGHT: arrow = ">"
			_:
				arrow = char(int(opt.key))
		_puts(box_x + PAD, box_y + 3 + i,
			"[%s]  %s" % [arrow, str(opt.label)], C_MSG_RECENT)

	_puts(box_x + ((box_w - 11) >> 1), box_y + box_h - 2, "[Esc] cancel", C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: help screen
# ---------------------------------------------------------------------------
func _draw_help_screen() -> void:
	const BOX_X := 4
	const BOX_Y := 1
	const BOX_W := 112
	const BOX_H := 33
	const COL1  := BOX_X + 3
	const COL2  := BOX_X + 38
	const COL3  := BOX_X + 74

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.88))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ KEYBINDS ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	var r := BOX_Y + 2

	# Column 1 — Movement
	_puts(COL1, r, "MOVEMENT", C_STATUS); r += 1
	_help_row(COL1, r, "arrows / numpad", "move");           r += 1
	_help_row(COL1, r, "numpad 7/9/1/3",  "diagonal move");  r += 1
	_help_row(COL1, r, "numpad 5 / .",    "wait one turn");   r += 1
	r += 1
	_puts(COL1, r, "ACTIONS", C_STATUS); r += 1
	_help_row(COL1, r, "g",  "pick up items");       r += 1
	_help_row(COL1, r, "t",  "trade (near merchant)"); r += 1
	_help_row(COL1, r, ">",  "descend / enter");     r += 1
	_help_row(COL1, r, "<",  "ascend / world map");  r += 1

	# Column 2 — Menus
	r = BOX_Y + 2
	_puts(COL2, r, "MENUS", C_STATUS); r += 1
	_help_row(COL2, r, "i",    "inventory");       r += 1
	_help_row(COL2, r, "c",    "character sheet"); r += 1
	_help_row(COL2, r, "l",    "look mode");       r += 1
	_help_row(COL2, r, "?",    "this help screen"); r += 1
	_help_row(COL2, r, "Esc",  "pause menu");      r += 1
	r += 1
	_puts(COL2, r, "INVENTORY", C_STATUS); r += 1
	_help_row(COL2, r, "a-t",    "use / equip item"); r += 1
	_help_row(COL2, r, "w/b/f/h","unequip slot");     r += 1
	r += 1
	_puts(COL2, r, "TRADE", C_STATUS); r += 1
	_help_row(COL2, r, "a-z",       "buy item");  r += 1
	_help_row(COL2, r, "Tab + A-Z", "sell item"); r += 1
	_help_row(COL2, r, "Esc",       "leave");     r += 1

	# Column 3 — World map
	r = BOX_Y + 2
	_puts(COL3, r, "WORLD MAP", C_STATUS); r += 1
	_help_row(COL3, r, "arrows", "travel between chunks"); r += 1
	_help_row(COL3, r, "l",      "toggle look cursor");    r += 1
	_help_row(COL3, r, ">",      "enter chunk view");      r += 1
	_help_row(COL3, r, "Esc",    "close silently");        r += 1

	_puts(BOX_X + ((BOX_W - 20) >> 1), BOX_Y + BOX_H - 2, "any key to close", C_DIVIDER)


func _help_row(x: int, y: int, key: String, desc: String) -> void:
	_puts(x,      y, "%-16s" % key,  C_STATUS)
	_puts(x + 16, y, desc,           C_MSG_RECENT)


# ---------------------------------------------------------------------------
# Overlay: trade screen
# ---------------------------------------------------------------------------
func _draw_trade_screen() -> void:
	if _trade_npc == null:
		return
	var npc: NpcClass = _trade_npc as NpcClass

	const BOX_X := 2
	const BOX_Y := 1
	const BOX_W := 116
	const BOX_H := 32
	const BUY_X  := BOX_X + 2
	const SELL_X := BOX_X + 60

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ TRADE: %s ]=-" % npc.name.capitalize()
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	# Vertical divider between panels
	for dy in range(2, BOX_H - 1):
		_puts(BOX_X + 57, BOX_Y + dy, "|", C_DIVIDER)

	# ── Left panel: merchant sells ────────────────────────────────────────
	_puts(BUY_X, BOX_Y + 2, "MERCHANT SELLS", C_STATUS)
	if npc.trade_stock.is_empty():
		_puts(BUY_X, BOX_Y + 4, "Nothing for sale.", C_MSG_OLD)
	else:
		for i in range(npc.trade_stock.size()):
			var entry: Dictionary = npc.trade_stock[i]
			var sl    := char(ord("a") + i)
			var itype := str(entry.get("item_type", ""))
			var qty   := int(entry.get("qty", 0))
			var price := int(entry.get("price", 0))
			var color := C_STATUS if (_trade_panel == 0 and i == _trade_buy_cursor) else C_MSG_RECENT
			_puts(BUY_X, BOX_Y + 4 + i,
				"%s) %-24s %3dg  (x%d)" % [sl, itype.replace("_", " "), price, qty], color)

	# ── Right panel: player sells ─────────────────────────────────────────
	_puts(SELL_X, BOX_Y + 2, "YOUR PACK", C_STATUS)
	var sellable: Array = _build_sellable()
	if sellable.is_empty():
		_puts(SELL_X, BOX_Y + 4, "Nothing to sell.", C_MSG_OLD)
	else:
		for i in range(sellable.size()):
			var item = sellable[i]
			var sl   := char(ord("A") + i)
			var offer: int = npc.buy_price(item)
			var color := C_STATUS if (_trade_panel == 1 and i == _trade_sell_cursor) else C_MSG_RECENT
			_puts(SELL_X, BOX_Y + 4 + i,
				"%s) %-24s %3dg" % [sl, (item as ItemClass).name, offer], color)

	_puts(BUY_X, BOX_Y + BOX_H - 4, "Gold: %d" % _player.gold, C_GOLD)

	var hint: String
	if _trade_panel == 0:
		hint = "[a-z] buy   [Tab] sell panel   [Esc] leave"
	else:
		hint = "[A-Z] sell   [Tab] buy panel   [Esc] leave"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


func _build_sellable() -> Array:
	var result: Array = []
	for item in _player.inventory:
		if item.category != ItemClass.CATEGORY_GOLD and item.base_value > 0:
			result.append(item)
	return result


func _handle_trade_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _trade_npc == null:
		_screen = Screen.NONE
		queue_redraw()
		return
	var npc: NpcClass = _trade_npc as NpcClass
	var key: int = event.physical_keycode

	if key == KEY_ESCAPE:
		_screen = Screen.NONE
		queue_redraw()
		return

	if key == KEY_TAB:
		_trade_panel = 1 - _trade_panel
		queue_redraw()
		return

	# Buy panel: lowercase a-z
	if _trade_panel == 0 and key >= KEY_A and key <= KEY_Z:
		var idx: int = key - KEY_A
		if idx < npc.trade_stock.size():
			var entry: Dictionary = npc.trade_stock[idx]
			var price: int  = int(entry.get("price", 0))
			var qty: int    = int(entry.get("qty",   0))
			var itype: String = str(entry.get("item_type", ""))
			if qty <= 0:
				_log("The %s has no more %s." % [npc.name, itype.replace("_", " ")])
			elif _player.gold < price:
				_log("You cannot afford that. (need %dg)" % price)
			elif _player.inventory.size() >= ActorClass.MAX_INVENTORY:
				_log("Your pack is full.")
			else:
				_player.gold -= price
				entry["qty"] = qty - 1
				_player.inventory.append(ItemClass.new(Vector2i(0, 0), itype, 0))
				_log("You buy %s for %dg." % [itype.replace("_", " "), price])
				queue_redraw()
		return

	# Sell panel: shift+letter (uppercase key codes same as lowercase in physical_keycode)
	# We distinguish via event.shift_pressed + panel state.
	if _trade_panel == 1 and event.shift_pressed and key >= KEY_A and key <= KEY_Z:
		var idx: int = key - KEY_A
		var sellable: Array = _build_sellable()
		if idx < sellable.size():
			var item = sellable[idx]
			var offer: int = npc.buy_price(item)
			_player.gold += offer
			_player.inventory.erase(item)
			_log("You sell the %s for %dg." % [(item as ItemClass).name, offer])
			queue_redraw()
		return


# ---------------------------------------------------------------------------
# Overlay: character sheet
# ---------------------------------------------------------------------------
func _draw_character_sheet() -> void:
	const BOX_X := 35
	const BOX_Y := 4
	const BOX_W := 50
	const BOX_H := 18

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.80))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ CHARACTER ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	var r := BOX_Y + 2
	_stat_line(BOX_X + 4, r, "Name",    GameState.player_name);    r += 1
	_stat_line(BOX_X + 4, r, "Class",   GameState.player_class.capitalize()); r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "Floor",   str(_floor));              r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "HP",      "%d / %d" % [_player.hp, _player.max_hp]); r += 1
	var atk_total: int = _player.power + _player.total_attack_bonus
	var atk_str := "1d6+%d" % atk_total
	if _player.total_attack_bonus > 0:
		atk_str += "  (+%d from gear)" % _player.total_attack_bonus
	_stat_line(BOX_X + 4, r, "Attack", atk_str); r += 1
	var ac_str := str(_player.ac)
	if _player.total_defense_bonus > 0:
		ac_str += "  (+%d from gear)" % _player.total_defense_bonus
	_stat_line(BOX_X + 4, r, "AC", ac_str); r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "Gold",    str(_player.gold), C_GOLD); r += 1
	_stat_line(BOX_X + 4, r, "Pack",
		"%d / %d items" % [_player.inventory.size(), ActorClass.MAX_INVENTORY]); r += 1

	var hint := "[Esc] close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: look mode
# ---------------------------------------------------------------------------
func _draw_look_cursor() -> void:
	# Highlight cursor tile (camera already panned to keep it on-screen).
	var sp := _to_screen(_look_pos.x, _look_pos.y)
	draw_rect(
		Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H),
		Color(0.20, 0.75, 0.90, 0.40)
	)

	# Overdraw message rows with description + exit hint.
	draw_rect(
		Rect2(0, MSG_START_ROW * CELL_H, COLS * CELL_W, MSG_LINES * CELL_H),
		C_BG
	)
	_puts(0, MSG_START_ROW,     _look_description(),              C_MSG_RECENT)
	_puts(0, MSG_START_ROW + 1, "l / Esc / Enter to exit look mode", C_DIVIDER)


# ---------------------------------------------------------------------------
# World map helpers
# ---------------------------------------------------------------------------
func _get_chunk_biome(c: Vector2i) -> int:
	if c.y >= 0 and c.y < GameState.world_biomes.size() and \
	   c.x >= 0 and c.x < GameState.world_biomes[c.y].size():
		return int(GameState.world_biomes[c.y][c.x])
	return GameMapClass.BIOME_DESERT


func _is_road_chunk(cx: int, cy: int) -> bool:
	return GameState.road_chunks.has("%d,%d" % [cx, cy])


func _is_village_chunk(cx: int, cy: int) -> bool:
	for v in GameState.villages:
		if int(v.cx) == cx and int(v.cy) == cy:
			return true
	return false


func _get_village_at_chunk(cx: int, cy: int) -> Variant:
	for v in GameState.villages:
		if int(v.cx) == cx and int(v.cy) == cy:
			return v
	return null


func _get_road_dirs(chunk: Vector2i) -> Array:
	var dirs: Array = []
	for d: Vector2i in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
		var nc := chunk + d
		if GameState.road_chunks.has("%d,%d" % [nc.x, nc.y]):
			dirs.append(d)
	return dirs


func _biome_name(biome: int) -> String:
	match biome:
		GameMapClass.BIOME_DESERT:    return "arid desert"
		GameMapClass.BIOME_OASIS:     return "lush oasis"
		GameMapClass.BIOME_STEPPES:   return "open steppes"
		GameMapClass.BIOME_MOUNTAINS: return "rocky mountains"
		GameMapClass.BIOME_BADLANDS:  return "rugged badlands"
		_:                            return "unknown lands"


func _biome_char(biome: int) -> String:
	match biome:
		GameMapClass.BIOME_DESERT:    return "."
		GameMapClass.BIOME_OASIS:     return "~"
		GameMapClass.BIOME_STEPPES:   return "\""
		GameMapClass.BIOME_MOUNTAINS: return "^"
		GameMapClass.BIOME_BADLANDS:  return "%"
		_:                            return "?"


func _biome_color(biome: int) -> Color:
	match biome:
		GameMapClass.BIOME_DESERT:    return Color(0.85, 0.70, 0.35)
		GameMapClass.BIOME_OASIS:     return Color(0.22, 0.72, 0.50)
		GameMapClass.BIOME_STEPPES:   return Color(0.42, 0.72, 0.20)
		GameMapClass.BIOME_MOUNTAINS: return Color(0.62, 0.56, 0.48)
		GameMapClass.BIOME_BADLANDS:  return Color(0.72, 0.44, 0.18)
		_:                            return Color(0.4, 0.4, 0.4)


# ---------------------------------------------------------------------------
# Overlay: world map
# ---------------------------------------------------------------------------
func _draw_world_map() -> void:
	# Full-view world map. Each tile = 2 chars wide (compensates 9×18 font aspect ratio).
	# Layout (MAP_ROWS = 35):
	#   row 0        : title
	#   row 2        : top border
	#   rows 3–26    : 24-row world grid (WORLD_H=24)
	#   row 27       : bottom border
	#   row 29       : info line
	#   row 31       : legend
	#   row 33       : hint
	var wm_cell: int = 2
	var wm_left: int = (COLS - GameState.WORLD_W * wm_cell) >> 1
	var wm_top:  int = 3

	var title_str := "-=[ WORLD MAP - LOOK ]=-" if _world_look_mode else "-=[ WORLD MAP ]=-"
	_puts_centered(0, title_str, C_STATUS)
	_draw_box(wm_left - 1, wm_top - 1, GameState.WORLD_W * wm_cell + 2, GameState.WORLD_H + 2)

	for cy in range(GameState.WORLD_H):
		for cx in range(GameState.WORLD_W):
			var this_chunk := Vector2i(cx, cy)
			var sx: int = wm_left + cx * wm_cell
			var sy: int = wm_top  + cy
			var is_current  := this_chunk == _chunk
			var is_lk_curs  := _world_look_mode and this_chunk == _world_look_cursor
			var is_visited  := _chunks.has(this_chunk) or is_current

			var ch: String
			var color: Color
			var village: Variant = _get_village_at_chunk(cx, cy)

			if village != null:
				ch    = "*"
				color = C_VILLAGE_WM
			elif _is_road_chunk(cx, cy):
				ch    = "="
				color = Color(0.70, 0.55, 0.32)
			else:
				var biome: int = _get_chunk_biome(this_chunk)
				ch    = _biome_char(biome)
				color = _biome_color(biome)  # fully visible — world map shows all terrain

			if is_current:
				ch    = "@"
				color = Color(0.95, 0.80, 0.40) if is_lk_curs else Color(0.80, 0.72, 0.55)

			_put(sx, sy, ch, color)

			if is_lk_curs:
				_put(sx - 1, sy, "[", C_STATUS)
				_put(sx + 1, sy, "]", C_STATUS)

	# Info rows
	var info_y: int = wm_top + GameState.WORLD_H + 2
	var info_c := _world_look_cursor if _world_look_mode else _chunk
	var info_biome := _get_chunk_biome(info_c)
	var info_vill: Variant = _get_village_at_chunk(info_c.x, info_c.y)

	var info_str: String
	if info_vill != null:
		info_str = "VILLAGE: %s  [%s]" % [str(info_vill.name), _biome_name(info_biome).to_upper()]
	else:
		info_str = _biome_name(info_biome).to_upper()
	if _is_road_chunk(info_c.x, info_c.y) and info_vill == null:
		info_str += "  [road]"
	var loc: String = "  (here)" if info_c == _chunk \
					else ("  (visited)" if _chunks.has(info_c) else "")
	_puts_centered(info_y, info_str + loc, C_MSG_RECENT)

	_puts_centered(info_y + 2,
		". desert  ~ oasis  \" steppes  ^ mountains  %% badlands  = road  * village", C_DIVIDER)

	var hint_str: String
	if _world_look_mode:
		hint_str = "arrows: move look cursor     l/esc: exit look"
	else:
		hint_str = "arrows: travel     l: look mode     >: enter view     esc: close"
	_puts_centered(info_y + 4, hint_str, C_DIVIDER)


func _handle_world_map_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var dc := Vector2i.ZERO

	# Look-mode sub-handler: arrows move cursor, L/Esc exits.
	if _world_look_mode:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_L:
				_world_look_mode = false
				queue_redraw()
			KEY_UP,    KEY_KP_8: dc = Vector2i(0, -1)
			KEY_DOWN,  KEY_KP_2: dc = Vector2i(0,  1)
			KEY_LEFT,  KEY_KP_4: dc = Vector2i(-1, 0)
			KEY_RIGHT, KEY_KP_6: dc = Vector2i(1,  0)
			KEY_KP_7:            dc = Vector2i(-1, -1)
			KEY_KP_9:            dc = Vector2i( 1, -1)
			KEY_KP_1:            dc = Vector2i(-1,  1)
			KEY_KP_3:            dc = Vector2i( 1,  1)
			_: pass
		if dc != Vector2i.ZERO:
			_world_look_cursor = Vector2i(
				clampi(_world_look_cursor.x + dc.x, 0, GameState.WORLD_W - 1),
				clampi(_world_look_cursor.y + dc.y, 0, GameState.WORLD_H - 1))
			queue_redraw()
		return

	# Normal navigation mode: arrows move the player across the world.
	# > (shift+period) enters chunk view; ESC closes without message.
	if event.shift_pressed and event.physical_keycode == KEY_PERIOD:
		_screen = Screen.NONE
		_update_camera()
		_map.compute_fov(_player.pos.x, _player.pos.y, FOV_OVERWORLD)
		if _chunk != _world_entry_chunk:
			var wv: Variant = _get_village_at_chunk(_chunk.x, _chunk.y)
			if wv != null:
				_log("You arrive at %s." % wv.name)
			else:
				_log("You arrive in the %s." % _biome_name(_get_chunk_biome(_chunk)))
		queue_redraw()
		return

	match event.physical_keycode:
		KEY_ESCAPE:
			# Close map silently.
			_screen = Screen.NONE
			_update_camera()
			_map.compute_fov(_player.pos.x, _player.pos.y, FOV_OVERWORLD)
			queue_redraw()
			return
		KEY_L:
			_world_look_mode   = true
			_world_look_cursor = _chunk
			queue_redraw()
			return
		KEY_UP,    KEY_KP_8: dc = Vector2i(0, -1)
		KEY_DOWN,  KEY_KP_2: dc = Vector2i(0,  1)
		KEY_LEFT,  KEY_KP_4: dc = Vector2i(-1, 0)
		KEY_RIGHT, KEY_KP_6: dc = Vector2i(1,  0)
		KEY_KP_7:            dc = Vector2i(-1, -1)
		KEY_KP_9:            dc = Vector2i( 1, -1)
		KEY_KP_1:            dc = Vector2i(-1,  1)
		KEY_KP_3:            dc = Vector2i( 1,  1)
		_: return

	if dc != Vector2i.ZERO:
		_world_map_navigate(dc)


func _world_map_navigate(dir: Vector2i) -> void:
	var dest := Vector2i(
		clampi(_chunk.x + dir.x, 0, GameState.WORLD_W - 1),
		clampi(_chunk.y + dir.y, 0, GameState.WORLD_H - 1))
	if dest == _chunk:
		return

	_map.entities.erase(_player)
	_chunks[_chunk] = _map
	_chunk = dest

	if _chunks.has(_chunk):
		_map = _chunks[_chunk]
	else:
		var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
		var wx: int = _chunk.x * OVERWORLD_W
		var wy: int = _chunk.y * OVERWORLD_H
		ProcgenClass.generate_overworld(new_map, wx, wy, GameState.world_seed,
				_get_chunk_biome(_chunk), false, _get_road_dirs(_chunk), _is_village_chunk(_chunk.x, _chunk.y))
		_map = new_map

	_player.pos      = Vector2i(OVERWORLD_W >> 1, OVERWORLD_H >> 1)
	_player.game_map = _map
	_map.entities.append(_player)
	queue_redraw()


# ---------------------------------------------------------------------------
# Draw helpers
# ---------------------------------------------------------------------------
func _draw_box(bx: int, by: int, bw: int, bh: int) -> void:
	for x in range(bx, bx + bw):
		_put(x, by, "-", C_DIVIDER)
		_put(x, by + bh - 1, "-", C_DIVIDER)
	for y in range(by, by + bh):
		_put(bx, y, "|", C_DIVIDER)
		_put(bx + bw - 1, y, "|", C_DIVIDER)
	_put(bx, by, "+", C_DIVIDER)
	_put(bx + bw - 1, by, "+", C_DIVIDER)
	_put(bx, by + bh - 1, "+", C_DIVIDER)
	_put(bx + bw - 1, by + bh - 1, "+", C_DIVIDER)


func _stat_line(x: int, y: int, label: String, value: String, color: Color = C_MSG_RECENT) -> void:
	_puts(x, y, "%-10s: %s" % [label, value], color)


func _put(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts_centered(row: int, text: String, color: Color) -> void:
	_puts((COLS - text.length()) >> 1, row, text, color)
