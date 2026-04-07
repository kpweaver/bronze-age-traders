extends Node2D

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
const GameMapClass = preload("res://scripts/map/game_map.gd")
const ActorClass   = preload("res://scripts/entities/actor.gd")
const ItemClass    = preload("res://scripts/entities/item.gd")
const NpcClass     = preload("res://scripts/entities/npc.gd")
const GameWorldClass = preload("res://scripts/game_world.gd")

# ---------------------------------------------------------------------------
# Display constants  (viewport: 1080×720, cell: 9×14 → 120×51 tiles)
# ---------------------------------------------------------------------------
const COLS: int = 120
const ROWS: int = 51
const FONT_SIZE: int    = 14   # map tile glyphs
const UI_FONT_SIZE: int = 16   # overlay / status bar text
const CELL_W: float = 9.0
const CELL_H: float = 14.0

const MAP_ROWS: int      = 46
const DIVIDER_ROW: int   = 46
const STATUS_ROW: int    = 47
const MSG_START_ROW: int = 48
const MSG_LINES: int     = 3

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
const C_SAND_LIT   := Color(0.98, 0.88, 0.48)
const C_SAND_DIM   := Color(0.55, 0.46, 0.22)
const C_DUNE_LIT   := Color(0.94, 0.68, 0.22)
const C_DUNE_DIM   := Color(0.50, 0.34, 0.10)
const C_ROCK_LIT   := Color(0.78, 0.38, 0.18)
const C_ROCK_DIM   := Color(0.40, 0.18, 0.08)
const C_WATER_LIT  := Color(0.22, 0.55, 0.88)
const C_WATER_DIM  := Color(0.10, 0.26, 0.44)
const C_GRASS_LIT  := Color(0.40, 0.75, 0.22)
const C_GRASS_DIM  := Color(0.18, 0.38, 0.10)
const C_ROAD_LIT   := Color(0.78, 0.62, 0.38)
const C_ROAD_DIM   := Color(0.42, 0.32, 0.18)
const C_VILLAGE_WM := Color(0.95, 0.90, 0.70)

# ---------------------------------------------------------------------------
# Escape menu
# ---------------------------------------------------------------------------
const ESCAPE_OPTIONS := ["Resume", "Settings", "Save & Quit to Title", "Quit Game"]
var _escape_cursor: int = 0

# ---------------------------------------------------------------------------
# Overlay screens
# ---------------------------------------------------------------------------
enum Screen { NONE, ESCAPE, INVENTORY, CHARACTER, SETTINGS, LOOK, WORLD_MAP, TRAVEL_EVENT, TRADE, DISAMBIGUATE, HELP, READER, DIALOGUE }
var _screen: Screen              = Screen.NONE
var _world_look_mode: bool       = false
var _world_look_cursor: Vector2i = Vector2i.ZERO
var _world_entry_chunk: Vector2i = Vector2i.ZERO

# Readable item state
var _reader_item                  = null
var _reader_lines: Array[String]  = []
var _reader_scroll: int           = 0

# Dialogue state
var _dialogue_npc                 = null
var _dialogue_line: String        = ""

# NPC trade state
var _trade_npc        = null
var _trade_buy_cursor:  int = 0
var _trade_sell_cursor: int = 0
var _trade_panel:       int = 0   # 0 = buy, 1 = sell

# Disambiguation overlay
var _disambig_prompt:  String = ""
var _disambig_options: Array  = []

# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
var _cam_x: int = 0
var _cam_y: int = 0
var _look_pos: Vector2i = Vector2i.ZERO

# ---------------------------------------------------------------------------
# Day/night tint — applied to map tiles and entities only (UI stays lit).
# Updated every turn via _on_turn_ended.
# ---------------------------------------------------------------------------
var _day_tint: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Game world + rendering
# ---------------------------------------------------------------------------
var _world  # GameWorld — untyped to avoid class_name scope issues
var _font: Font

# Convenience aliases — read-only proxies into _world.
# These let the rendering/input code below read _map, _player etc. unchanged.
var _map:
	get: return _world.map
var _player:
	get: return _world.player
var _floor:
	get: return _world.depth
var _chunk:
	get: return _world.chunk
var _chunks:
	get: return _world.chunks
var _messages:
	get: return _world.messages
var _game_over:
	get: return _world.game_over


# ===========================================================================
# Setup
# ===========================================================================

func _ready() -> void:
	_font  = _make_font()
	_world = GameWorldClass.new()
	add_child(_world)
	_world.turn_ended.connect(_on_turn_ended)
	_world.map_changed.connect(_on_map_changed)
	if GameState.load_save:
		_world.load_from_save()
		GameState.load_save = false
	else:
		_world.new_game()
	# map_changed fires during new_game/load, but compute tint explicitly here
	# in case _ready runs before the signal handler is wired (belt-and-suspenders).
	_day_tint = _compute_day_tint()


func _make_font() -> Font:
	var path := "res://assets/fonts/Px437_IBM_VGA_9x14.ttf"
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "Courier New"])
	return sf


func _on_turn_ended(_n: int) -> void:
	_day_tint = _compute_day_tint()
	_update_camera()
	queue_redraw()


func _on_map_changed() -> void:
	_day_tint = _compute_day_tint()
	_update_camera()
	queue_redraw()


# ---------------------------------------------------------------------------
# Day/night tint computation
# Anchor colours:                  time_of_day value
#   Midnight  (0.00) — deep blue   0.00
#   Pre-dawn  (0.17) — dark indigo 0.17  (04:00)
#   Dawn      (0.25) — warm amber  0.25  (06:00)
#   Morning   (0.33) — soft gold   0.33  (08:00)
#   Midday    (0.50) — full white  0.50  (12:00)
#   Afternoon (0.67) — soft gold   0.67  (16:00)
#   Dusk      (0.75) — warm amber  0.75  (18:00)
#   Night     (0.83) — dark indigo 0.83  (20:00)
#   Midnight  (1.00) — deep blue   (wraps)
# ---------------------------------------------------------------------------
func _compute_day_tint() -> Color:
	# Only the overworld is lit by the sun.  Underground is always the same dim.
	if _world.depth > 0:
		return Color(0.55, 0.50, 0.45)  # dungeon — torchlight amber-dim

	var t: float = _world.time_of_day   # 0.0 = midnight, 0.5 = noon

	# Four anchor points that repeat symmetrically (dawn ↔ dusk).
	# Each anchor: [time, Color].
	const ANCHORS: Array = [
		[0.00, Color(0.18, 0.20, 0.40)],  # midnight  — deep blue-black
		[0.17, Color(0.22, 0.22, 0.48)],  # pre-dawn  — indigo dark
		[0.25, Color(0.88, 0.60, 0.35)],  # dawn      — warm amber
		[0.33, Color(0.95, 0.85, 0.65)],  # morning   — golden
		[0.50, Color(1.00, 1.00, 1.00)],  # midday    — full white
		[0.67, Color(0.95, 0.85, 0.65)],  # afternoon — golden
		[0.75, Color(0.88, 0.58, 0.32)],  # dusk      — amber
		[0.83, Color(0.22, 0.22, 0.48)],  # nightfall — indigo dark
		[1.00, Color(0.18, 0.20, 0.40)],  # midnight  — wraps back
	]

	# Linear interpolation between the two surrounding anchors.
	for i in range(ANCHORS.size() - 1):
		var t0: float  = float(ANCHORS[i][0])
		var t1: float  = float(ANCHORS[i + 1][0])
		if t >= t0 and t <= t1:
			var f: float = (t - t0) / (t1 - t0)
			return (ANCHORS[i][1] as Color).lerp(ANCHORS[i + 1][1] as Color, f)
	return Color.WHITE


# ===========================================================================
# Input
# ===========================================================================

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
		Screen.TRAVEL_EVENT:
			_handle_travel_event_input(event)
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
		Screen.READER:
			_handle_reader_input(event)
			return
		Screen.DIALOGUE:
			_handle_dialogue_input(event)
			return

	# Escape — always valid.
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

	# Unshifted letter overlay toggles.
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
			KEY_S:
				get_viewport().set_input_as_handled()
				_world.try_skin()
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
			_world.new_game()
		return

	# > descend / enter dungeon.
	if event.shift_pressed and event.physical_keycode == KEY_PERIOD:
		get_viewport().set_input_as_handled()
		_world.try_descend()
		return

	# < ascend / world map.
	if event.shift_pressed and event.physical_keycode == KEY_COMMA:
		get_viewport().set_input_as_handled()
		if _floor == 0:
			_world_look_mode   = false
			_world_look_cursor = _chunk
			_world_entry_chunk = _chunk
			_screen = Screen.WORLD_MAP
			queue_redraw()
		else:
			_world.try_ascend()
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
				_world.auto_pickup()
				_world.do_enemy_turns()
				_world.end_turn()
			return
		_: return

	get_viewport().set_input_as_handled()
	_world.do_player_turn(dir, event.shift_pressed and dir != Vector2i.ZERO)
	# Open dialogue panel when the player bumps a non-wildlife NPC.
	if _world.nearby_npc != null and not (_world.nearby_npc as NpcClass).is_wildlife:
		_open_dialogue(_world.nearby_npc)


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
				_world.save()
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

	# w/b/f/h/l — unequip slot (unshifted only).
	if not event.shift_pressed:
		var unequip_slot := ""
		match key:
			KEY_W: unequip_slot = ItemClass.SLOT_WEAPON
			KEY_B: unequip_slot = ItemClass.SLOT_BODY
			KEY_F: unequip_slot = ItemClass.SLOT_FEET
			KEY_H: unequip_slot = ItemClass.SLOT_HEAD
			KEY_U: unequip_slot = ItemClass.SLOT_LIGHT
		if unequip_slot != "":
			var msg: String = _player.unequip(unequip_slot)
			if msg != "":
				_world.add_msg(msg)
				queue_redraw()
			return

	# a–t — use / equip / read depending on item category (unshifted only).
	if not event.shift_pressed and key >= KEY_A and key <= KEY_T:
		var idx: int = key - KEY_A
		if idx < _player.inventory.size():
			var item = _player.inventory[idx]
			if item.category == ItemClass.CATEGORY_EQUIPMENT:
				var msg: String = _player.equip(item)
				_world.add_msg(msg)
				_screen = Screen.NONE
				_world.do_enemy_turns()
				_world.end_turn()
			elif item.category == ItemClass.CATEGORY_USABLE:
				var msg: String = item.use(_player)
				if msg != "":
					_world.add_msg(msg)
					_player.inventory.remove_at(idx)
					_screen = Screen.NONE
					_world.do_enemy_turns()
					_world.end_turn()
			elif item.category == ItemClass.CATEGORY_READABLE:
				_open_reader(item)
			else:
				queue_redraw()


# ---------------------------------------------------------------------------
# Reader (readable items)
# ---------------------------------------------------------------------------
func _open_reader(item) -> void:
	_reader_item  = item
	_reader_scroll = 0
	_reader_lines  = _word_wrap(item.text, 96)
	_screen        = Screen.READER
	queue_redraw()


func _word_wrap(text: String, max_width: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		if paragraph.strip_edges().is_empty():
			lines.append("")
			continue
		var words: PackedStringArray = paragraph.split(" ")
		var current: String = ""
		for word in words:
			if current.is_empty():
				current = word
			elif current.length() + 1 + word.length() <= max_width:
				current += " " + word
			else:
				lines.append(current)
				current = word
		lines.append(current)
	return lines


func _handle_reader_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_screen = Screen.NONE
			_reader_item = null
			queue_redraw()
		KEY_UP, KEY_KP_8:
			_reader_scroll = maxi(0, _reader_scroll - 1)
			queue_redraw()
		KEY_DOWN, KEY_KP_2:
			var max_scroll: int = maxi(0, _reader_lines.size() - 14)
			_reader_scroll = mini(_reader_scroll + 1, max_scroll)
			queue_redraw()


# ---------------------------------------------------------------------------
# Dialogue
# ---------------------------------------------------------------------------
func _open_dialogue(npc) -> void:
	_dialogue_npc  = npc
	_dialogue_line = (npc as NpcClass).greet()
	_screen        = Screen.DIALOGUE
	queue_redraw()


func _handle_dialogue_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_ESCAPE:
			_screen = Screen.NONE
			_dialogue_npc = null
			queue_redraw()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			# Advance to the next dialogue line.
			_dialogue_line = (_dialogue_npc as NpcClass).greet()
			queue_redraw()
		KEY_T:
			if (_dialogue_npc as NpcClass).is_merchant:
				_open_trade(_dialogue_npc)


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
			moved   = false
			queue_redraw()
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

	var names: Array[String] = []
	for e in _map.entities:
		if e.pos == Vector2i(x, y):
			names.append(e.name as String)
	if names.is_empty():
		return "You see: %s." % tile
	return "You see: %s." % ", ".join(names)


# ===========================================================================
# Camera
# ===========================================================================

func _update_camera() -> void:
	_cam_x = clampi(_player.pos.x - (COLS >> 1), 0, _map.width  - COLS)
	_cam_y = clampi(_player.pos.y - (MAP_ROWS >> 1), 0, _map.height - MAP_ROWS)


func _to_screen(mx: int, my: int) -> Vector2i:
	return Vector2i(mx - _cam_x, my - _cam_y)


func _on_screen(mx: int, my: int) -> bool:
	return mx >= _cam_x and mx < _cam_x + COLS \
	   and my >= _cam_y and my < _cam_y + MAP_ROWS


# ===========================================================================
# NPC / direction helpers
# ===========================================================================

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


# ===========================================================================
# Disambiguation overlay
# ===========================================================================

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


func _handle_travel_event_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if not _world.has_pending_travel_event():
		_screen = Screen.WORLD_MAP
		queue_redraw()
		return

	var event_data: Dictionary = _world.pending_travel_event
	match event.physical_keycode:
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_world.enter_pending_travel_event()
			_screen = Screen.NONE
			queue_redraw()
		KEY_I:
			if bool(event_data.get("can_ignore", false)):
				_world.ignore_pending_travel_event()
				_screen = Screen.WORLD_MAP
				queue_redraw()
		KEY_F:
			if bool(event_data.get("can_flee", false)):
				var result: Dictionary = _world.attempt_pending_travel_flee()
				_screen = Screen.NONE if bool(result.get("entered", false)) else Screen.WORLD_MAP
				queue_redraw()


# ===========================================================================
# Rendering
# ===========================================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), C_BG)
	if _screen == Screen.WORLD_MAP or _screen == Screen.TRAVEL_EVENT:
		_draw_world_map()
		_draw_ui()
		if _screen == Screen.TRAVEL_EVENT:
			_draw_travel_event_overlay()
		return
	_draw_map()
	_draw_entities()
	_draw_ui()
	match _screen:
		Screen.ESCAPE:       _draw_escape_menu()
		Screen.INVENTORY:    _draw_inventory()
		Screen.CHARACTER:    _draw_character_sheet()
		Screen.SETTINGS:     _draw_settings()
		Screen.LOOK:         _draw_look_cursor()
		Screen.TRADE:        _draw_trade_screen()
		Screen.DISAMBIGUATE: _draw_disambig_overlay()
		Screen.HELP:         _draw_help_screen()
		Screen.READER:       _draw_reader_screen()
		Screen.DIALOGUE:     _draw_dialogue_screen()


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
			_put(vx, vy, ch, color * _day_tint)


func _draw_entities() -> void:
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
		_put(sp.x, sp.y, e.char as String, e.color * _day_tint)


func _draw_ui() -> void:
	for x in range(COLS):
		_put(x, DIVIDER_ROW, "-", C_DIVIDER)

	var hp_frac: float = float(_player.hp) / float(_player.max_hp)
	var hp_color       := C_STATUS.lerp(Color(0.8, 0.15, 0.05), 1.0 - hp_frac)
	var wpn     = _player.equipped.get(ItemClass.SLOT_WEAPON)
	var wpn_str := ("  WPN: %s" % (wpn as ItemClass).name) if wpn != null else ""
	var lit     = _player.equipped.get(ItemClass.SLOT_LIGHT)
	var lit_str := ""
	if lit != null:
		var lt := lit as ItemClass
		lit_str = "  LIT: %dt" % lt.value if lt.burn_turns > 0 else "  LIT"
	var cal_str: String   = _world.get_calendar_string()
	var phase_str: String = _world.get_day_phase()
	var thr_pct: int      = int(float(_player.thirst)  / float(ActorClass.THIRST_MAX)  * 100.0)
	var fat_pct: int      = int(float(_player.fatigue) / float(ActorClass.FATIGUE_MAX) * 100.0)
	var thr_str: String   = ("  THR: %d%%" % thr_pct) if _floor == 0 else ""
	var fat_str: String   = "  FAT: %d%%" % fat_pct
	var status := "HP: %d/%d   ATK: 1d6+%d  AC: %d   Gold: %d   Floor: %d   %s  %s%s%s%s%s" % [
		_player.hp, _player.max_hp, _player.power + _player.total_attack_bonus,
		_player.ac, _player.gold, _floor, cal_str, phase_str, thr_str, fat_str, wpn_str, lit_str
	]
	_puts(0, STATUS_ROW, status, hp_color)

	for i in range(_messages.size()):
		var is_last: bool = i == _messages.size() - 1
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

	# Left panel: pack
	_puts(PACK_X, BOX_Y + 2, "PACK  (%d/%d)" % [_player.inventory.size(), _player.max_inventory], C_STATUS)
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
			elif item.category == ItemClass.CATEGORY_READABLE:
				tag = "  [read]"
			elif item.category == ItemClass.CATEGORY_TRADE and item.base_value > 0:
				tag = "  (%dg)" % item.base_value
			_puts(PACK_X, BOX_Y + 4 + i,
				"%s) %-28s%s" % [sl, item.name, tag], C_MSG_RECENT)

	_puts(PACK_X, BOX_Y + BOX_H - 4, "Gold: %d" % _player.gold, C_GOLD)

	# Right panel: equipped gear
	_puts(EQUIP_X, BOX_Y + 2, "EQUIPPED", C_STATUS)
	var slot_rows: Array = [
		[ItemClass.SLOT_WEAPON, "w) WEAPON"],
		[ItemClass.SLOT_BODY,   "b) BODY  "],
		[ItemClass.SLOT_FEET,   "f) FEET  "],
		[ItemClass.SLOT_HEAD,   "h) HEAD  "],
		[ItemClass.SLOT_LIGHT,  "u) LIGHT "],
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
			if s_key == ItemClass.SLOT_LIGHT and eq_item.burn_turns > 0:
				bonus_str = "  (%dt left)" % eq_item.value
			_puts(EQUIP_X, BOX_Y + 4 + si * 2,
				"%s: %-20s%s" % [s_lbl, eq_item.name, bonus_str], C_MSG_RECENT)
		else:
			_puts(EQUIP_X, BOX_Y + 4 + si * 2, "%s: -" % s_lbl, C_MSG_OLD)

	var hint := "[a-t] use / equip / read   [w/b/f/h/u] unequip   [Esc] close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


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
	_stat_line(BOX_X + 4, r, "Name",  GameState.player_name);                       r += 1
	_stat_line(BOX_X + 4, r, "Class", GameState.player_class.capitalize());          r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "Floor", str(_floor));                                  r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "HP",    "%d / %d" % [_player.hp, _player.max_hp]);    r += 1
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
	_stat_line(BOX_X + 4, r, "Gold", str(_player.gold), C_GOLD); r += 1
	_stat_line(BOX_X + 4, r, "Pack",
		"%d / %d items" % [_player.inventory.size(), _player.max_inventory]); r += 1

	var hint := "[Esc] close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: look mode
# ---------------------------------------------------------------------------
func _draw_look_cursor() -> void:
	var sp := _to_screen(_look_pos.x, _look_pos.y)
	draw_rect(
		Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H),
		Color(0.20, 0.75, 0.90, 0.40)
	)
	draw_rect(
		Rect2(0, MSG_START_ROW * CELL_H, COLS * CELL_W, MSG_LINES * CELL_H),
		C_BG
	)
	_puts(0, MSG_START_ROW,     _look_description(),                  C_MSG_RECENT)
	_puts(0, MSG_START_ROW + 1, "l / Esc / Enter to exit look mode",  C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: reader screen (clay tablets, scrolls, etc.)
# ---------------------------------------------------------------------------
func _draw_reader_screen() -> void:
	if _reader_item == null:
		return
	const BOX_X := 6
	const BOX_Y := 3
	const BOX_W := 108
	const BOX_H := 24
	const TEXT_X := BOX_X + 4
	const TEXT_W := BOX_W - 8
	const VISIBLE_LINES := 18

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.88))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H),
			Color(0.12, 0.09, 0.05))
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ %s ]=-" % _reader_item.name.to_upper()
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	var visible := _reader_lines.slice(_reader_scroll, _reader_scroll + VISIBLE_LINES)
	for i in range(visible.size()):
		_puts(TEXT_X, BOX_Y + 2 + i, str(visible[i]), C_MSG_RECENT)

	# Scroll indicators
	if _reader_scroll > 0:
		_puts(BOX_X + BOX_W - 4, BOX_Y + 2, "/\\", C_DIVIDER)
	if _reader_scroll + VISIBLE_LINES < _reader_lines.size():
		_puts(BOX_X + BOX_W - 4, BOX_Y + BOX_H - 3, "\\/", C_DIVIDER)

	var hint := "[Esc / Space] close   [Up / Down] scroll"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: disambiguation
# ---------------------------------------------------------------------------
func _draw_disambig_overlay() -> void:
	const PAD := 3
	var box_w: int = 44
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
		var arrow := "?"
		match int(opt.key):
			KEY_UP:    arrow = "^"
			KEY_DOWN:  arrow = "v"
			KEY_LEFT:  arrow = "<"
			KEY_RIGHT: arrow = ">"
			_:         arrow = char(int(opt.key))
		_puts(box_x + PAD, box_y + 3 + i,
			"[%s]  %s" % [arrow, str(opt.label)], C_MSG_RECENT)

	_puts(box_x + ((box_w - 11) >> 1), box_y + box_h - 2, "[Esc] cancel", C_DIVIDER)


func _draw_travel_event_overlay() -> void:
	if not _world.has_pending_travel_event():
		return
	var event_data: Dictionary = _world.pending_travel_event
	var desc_lines: Array[String] = _word_wrap(str(event_data.get("desc", "")), 48)
	var options: Array[String] = ["[E] Enter the chunk"]
	if bool(event_data.get("can_ignore", false)):
		options.append("[I] Ignore and continue")
	if bool(event_data.get("can_flee", false)):
		options.append("[F] Attempt to flee")

	const BOX_W := 58
	var box_h: int = 8 + desc_lines.size() + options.size()
	var box_x: int = (COLS - BOX_W) >> 1
	var box_y: int = (MAP_ROWS - box_h) >> 1

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(box_x * CELL_W, box_y * CELL_H, BOX_W * CELL_W, box_h * CELL_H), C_BG)
	_draw_box(box_x, box_y, BOX_W, box_h)

	var title := "-=[ %s ]=-" % str(event_data.get("title", "TRAVEL EVENT"))
	_puts(box_x + ((BOX_W - title.length()) >> 1), box_y + 1, title, C_STATUS)

	for i in range(desc_lines.size()):
		_puts(box_x + 4, box_y + 3 + i, desc_lines[i], C_MSG_RECENT)
	for i in range(options.size()):
		_puts(box_x + 4, box_y + 5 + desc_lines.size() + i, options[i], C_STATUS)


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
	_help_row(COL1, r, "g",           "pick up items");           r += 1
	_help_row(COL1, r, "s",           "skin/butcher carcass");    r += 1
	_help_row(COL1, r, "t",           "trade (near merchant)");   r += 1
	_help_row(COL1, r, "Shift+dir",   "force attack (any NPC)");  r += 1
	_help_row(COL1, r, ">",           "descend / enter");         r += 1
	_help_row(COL1, r, "<",           "ascend / world map");      r += 1

	# Column 2 — Menus
	r = BOX_Y + 2
	_puts(COL2, r, "MENUS", C_STATUS); r += 1
	_help_row(COL2, r, "i",    "inventory");        r += 1
	_help_row(COL2, r, "c",    "character sheet");  r += 1
	_help_row(COL2, r, "l",    "look mode");        r += 1
	_help_row(COL2, r, "?",    "this help screen"); r += 1
	_help_row(COL2, r, "Esc",  "pause menu");       r += 1
	r += 1
	_puts(COL2, r, "INVENTORY", C_STATUS); r += 1
	_help_row(COL2, r, "a-t",    "use / equip item"); r += 1
	_help_row(COL2, r, "w/b/f/h/u","unequip slot");   r += 1
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
	_puts(x,      y, "%-16s" % key, C_STATUS)
	_puts(x + 16, y, desc,          C_MSG_RECENT)


# ---------------------------------------------------------------------------
# Overlay: trade screen
# ---------------------------------------------------------------------------
# Overlay: dialogue panel
# ---------------------------------------------------------------------------
func _draw_dialogue_screen() -> void:
	if _dialogue_npc == null:
		return
	const BOX_X := 2
	const BOX_Y := 30
	const BOX_W := 116
	const BOX_H := 9
	const TEXT_X := BOX_X + 4
	const TEXT_W := BOX_W - 8

	# Dim only the bottom portion so the map stays readable above.
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H),
			Color(0.08, 0.05, 0.03, 0.96))
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var npc: NpcClass = _dialogue_npc as NpcClass
	var title := "-=[ %s ]=-" % npc.name.to_upper()
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	# Word-wrap the dialogue line into the box.
	var wrapped: Array[String] = _word_wrap(_dialogue_line, TEXT_W)
	for i in range(mini(wrapped.size(), 4)):
		_puts(TEXT_X, BOX_Y + 2 + i, str(wrapped[i]), C_MSG_RECENT)

	var hint := "[Space] Next   [T] Trade   [Esc] Close"
	if not npc.is_merchant:
		hint = "[Space] Next   [Esc] Close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


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

	for dy in range(2, BOX_H - 1):
		_puts(BOX_X + 57, BOX_Y + dy, "|", C_DIVIDER)

	# Left panel: merchant sells
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

	# Right panel: player sells
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
			var price: int    = int(entry.get("price", 0))
			var qty: int      = int(entry.get("qty",   0))
			var itype: String = str(entry.get("item_type", ""))
			if qty <= 0:
				_world.add_msg("The %s has no more %s." % [npc.name, itype.replace("_", " ")])
			elif _player.gold < price:
				_world.add_msg("You cannot afford that. (need %dg)" % price)
			elif _player.inventory.size() >= _player.max_inventory:
				_world.add_msg("Your pack is full.")
			else:
				_player.gold -= price
				entry["qty"] = qty - 1
				_player.inventory.append(ItemClass.new(Vector2i(0, 0), itype, 0))
				_world.add_msg("You buy %s for %dg." % [itype.replace("_", " "), price])
				queue_redraw()
		return

	# Sell panel: Tab is active, shift+letter
	if _trade_panel == 1 and event.shift_pressed and key >= KEY_A and key <= KEY_Z:
		var idx: int = key - KEY_A
		var sellable: Array = _build_sellable()
		if idx < sellable.size():
			var item = sellable[idx]
			var offer: int = npc.buy_price(item)
			_player.gold += offer
			_player.inventory.erase(item)
			_world.add_msg("You sell the %s for %dg." % [(item as ItemClass).name, offer])
			queue_redraw()
		return


# ---------------------------------------------------------------------------
# World map
# ---------------------------------------------------------------------------
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


func _draw_world_map() -> void:
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
			var is_current: bool = this_chunk == _chunk
			var is_lk_curs: bool = _world_look_mode and this_chunk == _world_look_cursor

			var ch: String
			var color: Color
			var village: Variant = _world.get_village_at_chunk(cx, cy)

			if village != null:
				ch    = "*"
				color = C_VILLAGE_WM
			elif _world.is_road_chunk(cx, cy):
				ch    = "="
				color = Color(0.70, 0.55, 0.32)
			else:
				var biome: int = _world.get_chunk_biome(this_chunk)
				ch    = _biome_char(biome)
				color = _biome_color(biome)

			if is_current:
				ch    = "@"
				color = Color(0.95, 0.80, 0.40) if is_lk_curs else Color(0.80, 0.72, 0.55)

			_put(sx, sy, ch, color)

			if is_lk_curs:
				_put(sx - 1, sy, "[", C_STATUS)
				_put(sx + 1, sy, "]", C_STATUS)

	var info_y: int = wm_top + GameState.WORLD_H + 2
	var info_c: Vector2i = _world_look_cursor if _world_look_mode else _chunk
	var info_biome: int = _world.get_chunk_biome(info_c)
	var info_vill: Variant = _world.get_village_at_chunk(info_c.x, info_c.y)

	var info_str: String
	if info_vill != null:
		info_str = "VILLAGE: %s  [%s]" % [str(info_vill.name), _biome_name(info_biome).to_upper()]
	else:
		info_str = _biome_name(info_biome).to_upper()
	if _world.is_road_chunk(info_c.x, info_c.y) and info_vill == null:
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

	if event.shift_pressed and event.physical_keycode == KEY_PERIOD:
		_screen = Screen.NONE
		_update_camera()
		_map.compute_fov(_player.pos.x, _player.pos.y, GameWorldClass.FOV_OVERWORLD)
		if _chunk != _world_entry_chunk:
			var wv: Variant = _world.get_village_at_chunk(_chunk.x, _chunk.y)
			if wv != null:
				_world.add_msg("You arrive at %s." % wv.name)
			else:
				_world.add_msg("You arrive in the %s." % _biome_name(_world.get_chunk_biome(_chunk)))
		queue_redraw()
		return

	match event.physical_keycode:
		KEY_ESCAPE:
			_screen = Screen.NONE
			_update_camera()
			_map.compute_fov(_player.pos.x, _player.pos.y, GameWorldClass.FOV_OVERWORLD)
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
		_world.world_map_navigate(dc)
		if _world.has_pending_travel_event():
			_screen = Screen.TRAVEL_EVENT
		queue_redraw()


# ===========================================================================
# Draw helpers
# ===========================================================================

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
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + UI_FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE, color)


func _puts_centered(row: int, text: String, color: Color) -> void:
	_puts((COLS - text.length()) >> 1, row, text, color)
