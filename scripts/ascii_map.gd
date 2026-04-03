extends Node2D

const GameMapClass = preload("res://scripts/map/game_map.gd")
const ActorClass   = preload("res://scripts/entities/actor.gd")
const ProcgenClass = preload("res://scripts/map/procgen.gd")

# ---------------------------------------------------------------------------
# Display constants
# ---------------------------------------------------------------------------
const COLS: int = 80
const ROWS: int = 25
const FONT_SIZE: int = 16
const CELL_W: float = 9.0
const CELL_H: float = 18.0

# Layout: 20 map rows, then divider, status, and 3 message rows
const MAP_ROWS: int    = 20
const DIVIDER_ROW: int = 20
const STATUS_ROW: int  = 21
const MSG_START_ROW: int = 22
const MSG_LINES: int   = 3

const FOV_RADIUS: int = 8

# ---------------------------------------------------------------------------
# Bronze Age colour palette
# ---------------------------------------------------------------------------
const C_BG         := Color(0.05, 0.04, 0.03)
const C_WALL_LIT   := Color(0.55, 0.38, 0.22)  # sandstone, lit
const C_WALL_DIM   := Color(0.22, 0.15, 0.09)  # sandstone, remembered
const C_FLOOR_LIT  := Color(0.28, 0.24, 0.16)  # arid dirt, lit
const C_FLOOR_DIM  := Color(0.10, 0.09, 0.06)  # arid dirt, remembered
const C_DIVIDER    := Color(0.30, 0.20, 0.10)
const C_STATUS     := Color(0.80, 0.50, 0.20)  # bronze
const C_MSG_RECENT := Color(0.78, 0.68, 0.52)
const C_MSG_OLD    := Color(0.45, 0.38, 0.28)

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
	_new_game()


func _make_font() -> Font:
	var path := "res://assets/fonts/Px437_IBM_VGA_9x16.ttf"
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	# Fallback if font file is missing
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "Courier New"])
	return sf


func _new_game() -> void:
	_game_over = false
	_messages.clear()
	_map = GameMapClass.new(COLS, MAP_ROWS)
	_player = ActorClass.new(Vector2i(0, 0), "@", Color(0.80, 0.50, 0.20), "You", 30, 2, 5)
	_player.game_map = _map
	_map.entities.append(_player)
	ProcgenClass.generate_dungeon(_map, 30, 5, 10, 2, _player)
	_map.compute_fov(_player.pos.x, _player.pos.y, FOV_RADIUS)
	_log("The ruins swallow you whole. Steel yourself.")
	queue_redraw()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
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
		KEY_KP_5:            pass  # wait in place — still ends turn
		_:                   return

	get_viewport().set_input_as_handled()
	_do_player_turn(dir)


# ---------------------------------------------------------------------------
# Turn logic
# ---------------------------------------------------------------------------
func _do_player_turn(dir: Vector2i) -> void:
	if dir != Vector2i.ZERO:
		var next: Vector2i = _player.pos + dir

		if not _map.is_in_bounds(next.x, next.y):
			return  # edge of map — no turn consumed

		var target = _map.get_blocking_entity_at(next.x, next.y)
		if target != null:
			if target is ActorClass and target.is_alive:
				_log(_player.attack(target))
				if not target.is_alive:
					_log(target.die())
			# bumping a dead entity or non-actor: turn consumed, no move
		elif _map.is_walkable(next.x, next.y):
			_player.pos = next
		else:
			return  # solid wall — no turn consumed

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
	# Only one entity is drawn per cell — highest priority wins.
	# Priority: living actors > corpses > other entities.
	# Build a dict of pos -> entity so the last write (highest priority) wins,
	# then draw each cell once.
	var cell_map: Dictionary = {}

	# Pass 1: corpses (lowest priority — may be overwritten)
	for e in _map.entities:
		if (e is ActorClass) and not e.is_alive and _map.visible[e.pos.y][e.pos.x]:
			cell_map[e.pos] = e

	# Pass 2: living actors (highest priority — always overwrite)
	for e in _map.entities:
		if (e is ActorClass) and e.is_alive and _map.visible[e.pos.y][e.pos.x]:
			cell_map[e.pos] = e

	for e in cell_map.values():
		# Clear the map tile behind the entity so chars don't bleed through
		draw_rect(Rect2(e.pos.x * CELL_W, e.pos.y * CELL_H, CELL_W, CELL_H), C_BG)
		_put(e.pos.x, e.pos.y, e.char, e.color)


func _draw_ui() -> void:
	# Divider row
	for x in range(COLS):
		_put(x, DIVIDER_ROW, "-", C_DIVIDER)

	# Status bar — HP colour shifts red as health drops
	var hp_frac: float = float(_player.hp) / float(_player.max_hp)
	var hp_color := C_STATUS.lerp(Color(0.8, 0.15, 0.05), 1.0 - hp_frac)
	var status := "HP: %d/%d    ATK: %d  DEF: %d" % [
		_player.hp, _player.max_hp, _player.power, _player.defense
	]
	_puts(0, STATUS_ROW, status, hp_color)

	# Message log — most recent is brightest
	for i in range(_messages.size()):
		var is_last := i == _messages.size() - 1
		_puts(0, MSG_START_ROW + i, _messages[i], C_MSG_RECENT if is_last else C_MSG_OLD)


# ---------------------------------------------------------------------------
# Draw helpers
# ---------------------------------------------------------------------------
func _put(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
