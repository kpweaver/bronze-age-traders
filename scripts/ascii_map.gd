extends Node2D

const GameMapClass    = preload("res://scripts/map/game_map.gd")
const ActorClass      = preload("res://scripts/entities/actor.gd")
const ProcgenClass    = preload("res://scripts/map/procgen.gd")
const SaveManagerClass = preload("res://scripts/save_manager.gd")

# ---------------------------------------------------------------------------
# Display constants
# ---------------------------------------------------------------------------
const COLS: int = 80
const ROWS: int = 25
const FONT_SIZE: int = 16
const CELL_W: float = 9.0
const CELL_H: float = 18.0

# Layout: 20 map rows, then divider, status, and 3 message rows
const MAP_ROWS: int      = 20
const DIVIDER_ROW: int   = 20
const STATUS_ROW: int    = 21
const MSG_START_ROW: int = 22
const MSG_LINES: int     = 3

const FOV_RADIUS: int = 8

# ---------------------------------------------------------------------------
# Bronze Age colour palette
# ---------------------------------------------------------------------------
const C_BG         := Color(0.05, 0.04, 0.03)
const C_WALL_LIT   := Color(0.55, 0.38, 0.22)
const C_WALL_DIM   := Color(0.22, 0.15, 0.09)
const C_FLOOR_LIT  := Color(0.28, 0.24, 0.16)
const C_FLOOR_DIM  := Color(0.10, 0.09, 0.06)
const C_DIVIDER    := Color(0.30, 0.20, 0.10)
const C_STATUS     := Color(0.80, 0.50, 0.20)
const C_MSG_RECENT := Color(0.78, 0.68, 0.52)
const C_MSG_OLD    := Color(0.45, 0.38, 0.28)

# ---------------------------------------------------------------------------
# Escape menu
# ---------------------------------------------------------------------------
const ESCAPE_OPTIONS := ["Resume", "Save & Quit to Title", "Quit Game"]
var _escape_open: bool   = false
var _escape_cursor: int  = 0

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------
var _map           # GameMap
var _player        # Actor
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
	_game_over = false
	_escape_open = false
	_messages.clear()
	_map = GameMapClass.new(COLS, MAP_ROWS)
	_player = ActorClass.new(Vector2i(0, 0), "@", Color(0.80, 0.50, 0.20), "You", 30, 2, 5)
	_player.game_map = _map
	_map.entities.append(_player)
	ProcgenClass.generate_dungeon(_map, 30, 5, 10, 2, _player)
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_RADIUS)
	_log("The ruins swallow you whole. Steel yourself.")
	queue_redraw()


func _load_from_save() -> void:
	var data := SaveManagerClass.load_game()
	if data.is_empty():
		_new_game()
		return
	_game_over = false
	_escape_open = false
	_messages.clear()
	var result := SaveManagerClass.restore(data, FOV_RADIUS)
	_map    = result[0]
	_player = result[1]
	_log("You return to where you left off...")
	queue_redraw()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# Escape menu takes full priority when open
	if _escape_open:
		_handle_escape_input(event)
		return

	if event.physical_keycode == KEY_ESCAPE:
		_escape_open = true
		_escape_cursor = 0
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	if _game_over:
		if event.physical_keycode == KEY_R:
			_new_game()
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
		KEY_KP_5:            pass  # wait in place
		_:                   return

	get_viewport().set_input_as_handled()
	_do_player_turn(dir)


func _handle_escape_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_ESCAPE:
			_escape_open = false
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
			_escape_open = false
			queue_redraw()
		1:  # Save & Quit to Title
			if not _game_over:
				SaveManagerClass.save_game(_map, _player)
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		2:  # Quit Game
			get_tree().quit()


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
		else:
			return  # wall — no turn consumed

	_do_enemy_turns()
	_end_turn()


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
			_log("You are dead.  Press R to try again.")
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
	if _escape_open:
		_draw_escape_menu()


func _draw_map() -> void:
	for y in range(MAP_ROWS):
		for x in range(COLS):
			if not _map.explored[y][x]:
				continue
			var is_wall: bool = _map.tiles[y][x] == GameMapClass.TILE_WALL
			var lit: bool = _map.visible[y][x]
			var color: Color
			if is_wall:
				color = C_WALL_LIT if lit else C_WALL_DIM
			else:
				color = C_FLOOR_LIT if lit else C_FLOOR_DIM
			_put(x, y, "#" if is_wall else ".", color)


func _draw_entities() -> void:
	var cell_map: Dictionary = {}

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
	var hp_color := C_STATUS.lerp(Color(0.8, 0.15, 0.05), 1.0 - hp_frac)
	var status := "HP: %d/%d    ATK: %d  DEF: %d" % [
		_player.hp, _player.max_hp, _player.power, _player.defense
	]
	_puts(0, STATUS_ROW, status, hp_color)

	for i in range(_messages.size()):
		var is_last := i == _messages.size() - 1
		_puts(0, MSG_START_ROW + i, _messages[i], C_MSG_RECENT if is_last else C_MSG_OLD)


func _draw_escape_menu() -> void:
	const BOX_W := 36
	const BOX_H := 9
	const BOX_X := (COLS - BOX_W) / 2   # 22
	const BOX_Y := (MAP_ROWS - BOX_H) / 2  # 5

	# Darken everything behind the menu
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.65))

	# Box background
	draw_rect(
		Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H),
		C_BG
	)

	# Border
	for x in range(BOX_X, BOX_X + BOX_W):
		_put(x, BOX_Y, "-", C_DIVIDER)
		_put(x, BOX_Y + BOX_H - 1, "-", C_DIVIDER)
	for y in range(BOX_Y, BOX_Y + BOX_H):
		_put(BOX_X, y, "|", C_DIVIDER)
		_put(BOX_X + BOX_W - 1, y, "|", C_DIVIDER)
	_put(BOX_X, BOX_Y, "+", C_DIVIDER)
	_put(BOX_X + BOX_W - 1, BOX_Y, "+", C_DIVIDER)
	_put(BOX_X, BOX_Y + BOX_H - 1, "+", C_DIVIDER)
	_put(BOX_X + BOX_W - 1, BOX_Y + BOX_H - 1, "+", C_DIVIDER)

	# Title
	var title := "-=[ PAUSED ]=-"
	_puts(BOX_X + (BOX_W - title.length()) / 2, BOX_Y + 1, title, C_STATUS)

	# Options
	for i in range(ESCAPE_OPTIONS.size()):
		var is_selected := i == _escape_cursor
		var color := C_STATUS if is_selected else C_MSG_OLD
		var prefix := "> " if is_selected else "  "
		_puts(BOX_X + 2, BOX_Y + 3 + i, prefix + ESCAPE_OPTIONS[i], color)

	# Hint
	var hint := "enter: select   esc: resume"
	_puts(BOX_X + (BOX_W - hint.length()) / 2, BOX_Y + BOX_H - 2, hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Draw helpers
# ---------------------------------------------------------------------------
func _put(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
