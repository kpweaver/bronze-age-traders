extends Node2D

const GameMapClass     = preload("res://scripts/map/game_map.gd")
const EntityClass      = preload("res://scripts/entities/entity.gd")
const ActorClass       = preload("res://scripts/entities/actor.gd")
const ItemClass        = preload("res://scripts/entities/item.gd")
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

# ---------------------------------------------------------------------------
# Escape menu
# ---------------------------------------------------------------------------
const ESCAPE_OPTIONS := ["Resume", "Settings", "Save & Quit to Title", "Quit Game"]
var _escape_cursor: int = 0

# ---------------------------------------------------------------------------
# Overlay screens
# ---------------------------------------------------------------------------
enum Screen { NONE, ESCAPE, INVENTORY, CHARACTER, SETTINGS, LOOK, WORLD_MAP }
var _screen: Screen     = Screen.NONE
var _world_cursor: Vector2i = Vector2i.ZERO

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

	# Player starts at the centre of the world map (always forced to BIOME_DESERT).
	_chunk = Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1)

	# Build the starting overworld chunk.
	var ow_map = GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
	ProcgenClass.generate_overworld(ow_map, _chunk.x * OVERWORLD_W, _chunk.y * OVERWORLD_H, GameState.world_seed, GameMapClass.BIOME_DESERT, true)

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
		ProcgenClass.generate_overworld(new_map, wx, wy, GameState.world_seed, _get_chunk_biome(_chunk))
		_map = new_map

	_player.pos      = Vector2i(new_x, new_y)
	_player.game_map = _map
	_map.entities.append(_player)

	_update_camera()
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_OVERWORLD)
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
	# Regenerate biome grid deterministically from the saved world seed.
	GameState.world_biomes = ProcgenClass.generate_world_biomes(GameState.WORLD_W, GameState.WORLD_H, GameState.world_seed)
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
			ProcgenClass.generate_overworld(new_map, _chunk.x * OVERWORLD_W, _chunk.y * OVERWORLD_H, GameState.world_seed, _get_chunk_biome(_chunk), _chunk == Vector2i(GameState.WORLD_W >> 1, GameState.WORLD_H >> 1))
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

	# Global overlay toggles
	match event.physical_keycode:
		KEY_ESCAPE:
			_screen = Screen.ESCAPE
			_escape_cursor = 0
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
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

	if _game_over:
		if event.physical_keycode == KEY_R:
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
			_world_cursor = _chunk
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
		KEY_G:  _auto_pickup(); _do_enemy_turns(); _end_turn(); return
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
	if key == KEY_ESCAPE or key == KEY_I:
		_screen = Screen.NONE
		queue_redraw()
		return
	# a–t maps to inventory slots 0–19
	if key >= KEY_A and key <= KEY_T:
		var idx: int = key - KEY_A
		if idx < _player.inventory.size():
			var item = _player.inventory[idx]
			var msg: String = item.use(_player)
			if msg != "":
				_log(msg)
				_player.inventory.remove_at(idx)
				_screen = Screen.NONE
				_do_enemy_turns()
				_end_turn()


func _handle_character_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_C:
		_screen = Screen.NONE
		queue_redraw()


func _handle_settings_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_ESCAPE:
			_screen = Screen.ESCAPE
			queue_redraw()
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
			if target is ActorClass and target.is_alive:
				_log(_player.attack(target))
				if GameState.god_mode and target.is_alive:
					target.take_damage(target.hp)  # instakill
				if not target.is_alive:
					_log(target.die())
		elif _map.is_walkable(next.x, next.y):
			_player.pos = next
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
	_draw_map()
	_draw_entities()
	_draw_ui()
	match _screen:
		Screen.ESCAPE:    _draw_escape_menu()
		Screen.INVENTORY: _draw_inventory()
		Screen.CHARACTER: _draw_character_sheet()
		Screen.SETTINGS:  _draw_settings()
		Screen.LOOK:      _draw_look_cursor()
		Screen.WORLD_MAP: _draw_world_map()


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
	var status := "HP: %d/%d   ATK: 1d6+%d  AC: %d   Gold: %d   Floor: %d" % [
		_player.hp, _player.max_hp, _player.power, _player.ac,
		_player.gold, _floor
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
	const BOX_X := 4
	const BOX_Y := 1
	const BOX_W := 60
	const BOX_H := 28

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.80))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ INVENTORY ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	if _player.inventory.is_empty():
		_puts(BOX_X + 2, BOX_Y + 2, "Your pack is empty.", C_MSG_OLD)
	else:
		for i in range(_player.inventory.size()):
			var item   = _player.inventory[i]
			var slot   := char(ord("a") + i)
			var detail := ""
			if item.item_type in [ItemClass.TYPE_HEALTH_POTION, ItemClass.TYPE_HEALING_DRAUGHT]:
				detail = "  (%s HP)" % item.dice_label()
			_puts(BOX_X + 2, BOX_Y + 2 + i, "%s) %s%s" % [slot, item.name, detail], C_MSG_RECENT)

	# Gold summary
	_puts(BOX_X + 2, BOX_Y + BOX_H - 4, "Gold: %d" % _player.gold, C_GOLD)
	_puts(BOX_X + 2, BOX_Y + BOX_H - 3,
		"%d / %d items" % [_player.inventory.size(), ActorClass.MAX_INVENTORY], C_MSG_OLD)

	var hint := "[a-t] use item     [Esc] close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: character sheet
# ---------------------------------------------------------------------------
func _draw_character_sheet() -> void:
	const BOX_X := 35
	const BOX_Y := 6
	const BOX_W := 50
	const BOX_H := 16

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.80))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ CHARACTER ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	var r := BOX_Y + 2
	_stat_line(BOX_X + 4, r, "Floor",   str(_floor));              r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "HP",      "%d / %d" % [_player.hp, _player.max_hp]); r += 1
	_stat_line(BOX_X + 4, r, "Attack",  "1d6+%d" % _player.power); r += 1
	_stat_line(BOX_X + 4, r, "AC",      str(_player.ac));          r += 1
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
	# Each world tile renders as 2 chars wide × 1 char tall, making tiles
	# visually square given the 9×18 font (2:1 height-to-width ratio).
	const WM_CELL  := 2
	const WM_LEFT  := (COLS - GameState.WORLD_W * WM_CELL) >> 1  # ≈ 28
	const WM_TOP   := 3

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.82))

	_puts_centered(1, "-=[ WORLD MAP ]=-", C_STATUS)

	for cy in range(GameState.WORLD_H):
		for cx in range(GameState.WORLD_W):
			var this_chunk := Vector2i(cx, cy)
			var biome: int   = _get_chunk_biome(this_chunk)
			var sx: int      = WM_LEFT + cx * WM_CELL
			var sy: int      = WM_TOP  + cy

			var is_current := this_chunk == _chunk
			var is_cursor  := this_chunk == _world_cursor
			var is_visited := _chunks.has(this_chunk) or is_current

			var ch: String   = _biome_char(biome)
			var color: Color = _biome_color(biome)

			if not is_visited:
				color = color * 0.38  # fog-of-war dim

			if is_current:
				ch    = "@"
				color = Color(0.95, 0.80, 0.40) if is_cursor else Color(0.80, 0.72, 0.55)
			elif is_cursor:
				color = C_STATUS  # bronze highlight for cursor

			_put(sx, sy, ch, color)

			# Cursor brackets — drawn on top of whatever char is there.
			if is_cursor:
				_put(sx - 1, sy, "[", C_STATUS)
				_put(sx + 1, sy, "]", C_STATUS)

	# Biome name of cursor tile
	var cursor_biome: int   = _get_chunk_biome(_world_cursor)
	var cursor_label: String = _biome_name(cursor_biome)
	if _world_cursor == _chunk:
		cursor_label += " (here)"
	var visited_label := "visited" if (_chunks.has(_world_cursor) or _world_cursor == _chunk) else "unexplored"

	var bottom: int = WM_TOP + GameState.WORLD_H + 1
	_puts_centered(bottom,     "%s — %s" % [cursor_label, visited_label],                C_MSG_RECENT)
	_puts_centered(bottom + 1, ". desert  ~ oasis  \" steppes  ^ mountains  %% badlands", C_DIVIDER)
	_puts_centered(bottom + 2, "arrows/numpad: move   enter: travel here   esc: close",  C_DIVIDER)


func _handle_world_map_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var dc := Vector2i.ZERO
	match event.physical_keycode:
		KEY_ESCAPE:
			_screen = Screen.NONE
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
		KEY_ENTER, KEY_KP_ENTER:
			if _world_cursor != _chunk:
				_world_map_travel(_world_cursor)
			else:
				_screen = Screen.NONE
				queue_redraw()
			return
		_:
			return
	_world_cursor = Vector2i(
		clampi(_world_cursor.x + dc.x, 0, GameState.WORLD_W - 1),
		clampi(_world_cursor.y + dc.y, 0, GameState.WORLD_H - 1)
	)
	queue_redraw()


func _world_map_travel(dest: Vector2i) -> void:
	# Save current chunk, then load or generate the destination.
	_map.entities.erase(_player)
	_chunks[_chunk] = _map
	_chunk = dest

	if _chunks.has(_chunk):
		_map = _chunks[_chunk]
	else:
		var new_map := GameMapClass.new(OVERWORLD_W, OVERWORLD_H)
		var wx: int = _chunk.x * OVERWORLD_W
		var wy: int = _chunk.y * OVERWORLD_H
		ProcgenClass.generate_overworld(new_map, wx, wy, GameState.world_seed, _get_chunk_biome(_chunk))
		_map = new_map

	_player.pos      = Vector2i(OVERWORLD_W >> 1, OVERWORLD_H >> 1)
	_player.game_map = _map
	_map.entities.append(_player)
	_screen = Screen.NONE

	_update_camera()
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_OVERWORLD)
	_log("You arrive in the %s." % _biome_name(_get_chunk_biome(_chunk)))
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
