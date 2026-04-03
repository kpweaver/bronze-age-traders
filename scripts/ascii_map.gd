extends Node2D

const GameMapClass     = preload("res://scripts/map/game_map.gd")
const ActorClass       = preload("res://scripts/entities/actor.gd")
const ItemClass        = preload("res://scripts/entities/item.gd")
const ProcgenClass     = preload("res://scripts/map/procgen.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")

# ---------------------------------------------------------------------------
# Display constants
# ---------------------------------------------------------------------------
const COLS: int = 80
const ROWS: int = 25
const FONT_SIZE: int = 16
const CELL_W: float = 9.0
const CELL_H: float = 18.0

const MAP_ROWS: int      = 20
const DIVIDER_ROW: int   = 20
const STATUS_ROW: int    = 21
const MSG_START_ROW: int = 22
const MSG_LINES: int     = 3

const FOV_RADIUS: int = 8

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

# ---------------------------------------------------------------------------
# Escape menu
# ---------------------------------------------------------------------------
const ESCAPE_OPTIONS := ["Resume", "Settings", "Save & Quit to Title", "Quit Game"]
var _escape_open: bool  = false
var _escape_cursor: int = 0

# ---------------------------------------------------------------------------
# Overlay screens
# ---------------------------------------------------------------------------
enum Screen { NONE, ESCAPE, INVENTORY, CHARACTER, SETTINGS }
var _screen: Screen = Screen.NONE

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------
var _map        # GameMap
var _player     # Actor
var _floor: int = 1
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
	_floor     = 1
	_game_over = false
	_screen    = Screen.NONE
	_messages.clear()
	_map    = GameMapClass.new(COLS, MAP_ROWS)
	_player = ActorClass.new(Vector2i(0, 0), "@", Color(0.80, 0.50, 0.20), "You", 30, 2, 5)
	_player.game_map = _map
	_map.entities.append(_player)
	ProcgenClass.generate_dungeon(_map, 30, 5, 10, 2, _player, _floor)
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_RADIUS)
	_log("The ruins swallow you whole. Steel yourself.")
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
	_log("You return to where you left off...")
	queue_redraw()


func _descend() -> void:
	_floor += 1
	var new_map = GameMapClass.new(COLS, MAP_ROWS)
	_player.game_map = new_map
	_player.pos      = Vector2i(0, 0)  # procgen will set the real spawn
	new_map.entities.append(_player)
	_map = new_map
	var monsters := mini(2 + (_floor - 1) / 2, 4)
	ProcgenClass.generate_dungeon(_map, 30, 5, 10, monsters, _player, _floor)
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_RADIUS)
	_log("You descend to floor %d. The air grows heavier." % _floor)
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

	if _game_over:
		if event.physical_keycode == KEY_R:
			_new_game()
		return

	# Shift+Period (>) uses keycode, not physical_keycode, so check it first.
	if event.keycode == KEY_GREATER:
		get_viewport().set_input_as_handled()
		_try_descend()
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
				SaveManagerClass.save_game(_map, _player, _floor)
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
		KEY_A:  # auto-pickup toggle
			GameState.auto_pickup = not GameState.auto_pickup
			queue_redraw()


# ---------------------------------------------------------------------------
# Turn logic
# ---------------------------------------------------------------------------
func _do_player_turn(dir: Vector2i) -> void:
	if dir != Vector2i.ZERO:
		var next: Vector2i = _player.pos + dir
		if not _map.is_in_bounds(next.x, next.y):
			return

		var target = _map.get_blocking_entity_at(next.x, next.y)
		if target != null:
			if target is ActorClass and target.is_alive:
				_log(_player.attack(target))
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
		if not (e is ActorClass) and e.char == ">" and e.pos == _player.pos:
			_log("Stairs lead down. [>] to descend.")
			return


func _try_descend() -> void:
	for e in _map.entities:
		if not (e is ActorClass) and e.char == ">" and e.pos == _player.pos:
			get_viewport().set_input_as_handled()
			_descend()
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
			_log(_player.die())
			_log("You are dead.  Press r to try again.")
			_game_over = true
			return


func _end_turn() -> void:
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_RADIUS)
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


func _draw_map() -> void:
	for y in range(MAP_ROWS):
		for x in range(COLS):
			if not _map.explored[y][x]:
				continue
			var is_wall: bool = _map.tiles[y][x] == GameMapClass.TILE_WALL
			var lit: bool     = _map.visible[y][x]
			var color: Color
			if is_wall:
				color = C_WALL_LIT if lit else C_WALL_DIM
			else:
				color = C_FLOOR_LIT if lit else C_FLOOR_DIM
			_put(x, y, "#" if is_wall else ".", color)


func _draw_entities() -> void:
	var cell_map: Dictionary = {}

	# Priority (lowest to highest): items/stairs → corpses → living actors
	for e in _map.entities:
		if not (e is ActorClass) and _map.is_in_bounds(e.pos.x, e.pos.y) \
				and _map.visible[e.pos.y][e.pos.x]:
			cell_map[e.pos] = e
	for e in _map.entities:
		if (e is ActorClass) and not e.is_alive and _map.visible[e.pos.y][e.pos.x]:
			cell_map[e.pos] = e
	for e in _map.entities:
		if (e is ActorClass) and e.is_alive and _map.visible[e.pos.y][e.pos.x]:
			cell_map[e.pos] = e

	for e in cell_map.values():
		draw_rect(Rect2(e.pos.x * CELL_W, e.pos.y * CELL_H, CELL_W, CELL_H), C_BG)
		_put(e.pos.x, e.pos.y, e.char, e.color)


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
	const BOX_W := 36
	const BOX_H := 9
	const BOX_X := (COLS - BOX_W) / 2
	const BOX_Y := (MAP_ROWS - BOX_H) / 2

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ PAUSED ]=-"
	_puts(BOX_X + (BOX_W - title.length()) / 2, BOX_Y + 1, title, C_STATUS)

	for i in range(ESCAPE_OPTIONS.size()):
		var color  := C_STATUS if i == _escape_cursor else C_MSG_OLD
		var prefix := "> " if i == _escape_cursor else "  "
		_puts(BOX_X + 2, BOX_Y + 3 + i, prefix + ESCAPE_OPTIONS[i], color)

	var hint := "enter: select   esc: resume"
	_puts(BOX_X + (BOX_W - hint.length()) / 2, BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: settings
# ---------------------------------------------------------------------------
func _draw_settings() -> void:
	const BOX_W := 40
	const BOX_H := 9
	const BOX_X := (COLS - BOX_W) / 2
	const BOX_Y := (MAP_ROWS - BOX_H) / 2

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ SETTINGS ]=-"
	_puts(BOX_X + (BOX_W - title.length()) / 2, BOX_Y + 1, title, C_STATUS)

	var ap_val := "ON " if GameState.auto_pickup else "OFF"
	_puts(BOX_X + 2, BOX_Y + 3,
		"[a] Auto-pickup items:  %s" % ap_val,
		C_MSG_RECENT)

	var hint := "esc: back"
	_puts(BOX_X + (BOX_W - hint.length()) / 2, BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: inventory
# ---------------------------------------------------------------------------
func _draw_inventory() -> void:
	const BOX_X := 3
	const BOX_Y := 0
	const BOX_W := 50
	const BOX_H := 25

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.80))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ INVENTORY ]=-"
	_puts(BOX_X + (BOX_W - title.length()) / 2, BOX_Y, title, C_STATUS)

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
	_puts(BOX_X + (BOX_W - hint.length()) / 2, BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: character sheet
# ---------------------------------------------------------------------------
func _draw_character_sheet() -> void:
	const BOX_X := 20
	const BOX_Y := 4
	const BOX_W := 40
	const BOX_H := 15

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.80))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ CHARACTER ]=-"
	_puts(BOX_X + (BOX_W - title.length()) / 2, BOX_Y, title, C_STATUS)

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
	_puts(BOX_X + (BOX_W - hint.length()) / 2, BOX_Y + BOX_H - 2, hint, C_DIVIDER)


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
