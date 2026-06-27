extends Node2D

signal encounter_finished(result: Dictionary)

const GameMapClass = preload("res://scripts/map/game_map.gd")

const UI_FONT_SIZE := 13
const UI_CELL_W := 11.0
const UI_CELL_H := 20.0
const MAP_FONT_SIZE := 34
const MAP_CELL_W := 40.0
const MAP_CELL_H := 43.0
const GRID_W := 18
const GRID_H := 12
const GRID_X := 3
const GRID_Y := 5
const PANEL_GAP := 4
const LOG_Y := 42
const MOVE_POINTS_PLAYER := 4
const MOVE_POINTS_ENEMY := 5
const ENEMY_STEP_DELAY_SEC := 0.08

const C_BG := Color(0.04, 0.03, 0.02)
const C_FRAME := Color(0.34, 0.22, 0.10)
const C_TITLE := Color(0.88, 0.62, 0.24)
const C_SUBTITLE := Color(0.62, 0.46, 0.24)
const C_TEXT := Color(0.84, 0.78, 0.66)
const C_DIM := Color(0.42, 0.35, 0.26)
const C_HILITE := Color(0.94, 0.86, 0.58)
const C_PLAYER := Color(0.86, 0.78, 0.64)
const C_ENEMY := Color(0.95, 0.42, 0.26)

enum Phase { PLAYER_COMMAND, PLAYER_MOVE, ENEMY_TURN, RESOLVED }

var _font: Font
var _encounter: Dictionary = {}
var _grid_tiles: Array = []
var _player = null
var _enemy = null
var _player_pos: Vector2i = Vector2i.ZERO
var _enemy_pos: Vector2i = Vector2i.ZERO
var _phase: Phase = Phase.PLAYER_COMMAND
var _player_move_remaining: int = 0
var _turn_number: int = 1
var _initiative_text: String = ""
var _status_text: String = ""
var _log: Array[String] = []
var _pending_result: Dictionary = {}
var _result_popup_lines: Array[String] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = _load_font()
	queue_redraw()


func setup(encounter: Dictionary) -> void:
	_encounter = encounter
	_grid_tiles = encounter.get("tiles", [])
	_player = encounter.get("player")
	_enemy = encounter.get("enemy")
	_player_pos = encounter.get("player_pos", Vector2i(2, GRID_H / 2))
	_enemy_pos = encounter.get("enemy_pos", Vector2i(GRID_W - 3, GRID_H / 2))
	_log.clear()
	_turn_number = 1
	_status_text = "A tactical engagement begins."
	_begin_encounter()
	queue_redraw()


func _load_font() -> Font:
	var path := GameState.current_font_path()
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console"])
	return sf


func _begin_encounter() -> void:
	var player_init: int = randi_range(1, 20) + int(_player.dex_mod if _player != null else 0)
	var enemy_init: int = randi_range(1, 20) + int(_enemy.dex_mod if _enemy != null else 0)
	_initiative_text = "Initiative  You %d  |  %s %d" % [
		player_init,
		_enemy.name.capitalize() if _enemy != null else "Enemy",
		enemy_init,
	]
	if player_init >= enemy_init:
		_phase = Phase.PLAYER_COMMAND
		_status_text = "You seize the initiative."
	else:
		_phase = Phase.ENEMY_TURN
		_status_text = "%s acts first." % (_enemy.name.capitalize() if _enemy != null else "The enemy")
		call_deferred("_run_enemy_turn")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if _phase == Phase.RESOLVED:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE:
				_emit_pending_result()
		return
	match _phase:
		Phase.PLAYER_COMMAND:
			_handle_player_command(event)
		Phase.PLAYER_MOVE:
			_handle_player_move(event)
		Phase.ENEMY_TURN:
			return


func _handle_player_command(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_M:
			_phase = Phase.PLAYER_MOVE
			_player_move_remaining = MOVE_POINTS_PLAYER
			_status_text = "Move with arrows. Enter to end movement."
			queue_redraw()
		KEY_A:
			_player_attack()
		KEY_W, KEY_KP_5, KEY_PERIOD:
			_end_player_turn("You hold your ground.")
		KEY_F:
			_finish("fled", true, ["You disengage before blades properly cross."])
		KEY_ESCAPE:
			_finish("aborted", false, ["You break off the experimental combat view."])


func _handle_player_move(event: InputEventKey) -> void:
	if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER or event.physical_keycode == KEY_SPACE:
		_end_player_turn("You stop moving.")
		return
	if event.physical_keycode == KEY_A:
		_player_attack()
		return
	var dir := _dir_from_key(event)
	if dir == Vector2i.ZERO:
		return
	var next: Vector2i = _player_pos + dir
	if not _can_occupy(next) or next == _enemy_pos:
		_status_text = "You can't move there."
		queue_redraw()
		return
	_player_pos = next
	_player_move_remaining -= 1
	if _player_move_remaining <= 0:
		_end_player_turn("You finish maneuvering.")
	else:
		_status_text = "Move %d remaining." % _player_move_remaining
		queue_redraw()


func _player_attack() -> void:
	if _enemy == null:
		return
	if not _adjacent(_player_pos, _enemy_pos):
		_status_text = "No enemy is in reach."
		queue_redraw()
		return
	var line: String = _player.attack(_enemy)
	_push_log(line)
	if not _enemy.is_alive:
		_push_log(_enemy.die())
		_finish("victory", true, [])
		return
	_end_player_turn("You press the attack.")


func _end_player_turn(status_line: String) -> void:
	_phase = Phase.ENEMY_TURN
	_status_text = status_line
	queue_redraw()
	call_deferred("_run_enemy_turn")


func _run_enemy_turn() -> void:
	if _phase != Phase.ENEMY_TURN or _enemy == null or _player == null:
		return
	if not _enemy.is_alive:
		_finish("victory", true, [])
		return
	var moves_left: int = MOVE_POINTS_ENEMY
	while moves_left > 0 and not _adjacent(_enemy_pos, _player_pos):
		var step: Vector2i = _best_enemy_step_toward_player()
		if step == Vector2i.ZERO:
			break
		_enemy_pos += step
		moves_left -= 1
		_status_text = "The %s advances." % _enemy.name
		queue_redraw()
		await get_tree().create_timer(ENEMY_STEP_DELAY_SEC).timeout
		if _phase != Phase.ENEMY_TURN or _enemy == null or _player == null:
			return
	if _adjacent(_enemy_pos, _player_pos):
		var line: String = _enemy.attack(_player)
		_push_log(line)
		if not _player.is_alive:
			_push_log(_player.die())
			_finish("defeat", true, [])
			return
	else:
		_status_text = "The %s repositions." % _enemy.name
	_phase = Phase.PLAYER_COMMAND
	_turn_number += 1
	if _adjacent(_enemy_pos, _player_pos):
		_status_text = "Your turn."
	queue_redraw()


func _best_enemy_step_toward_player() -> Vector2i:
	var path_step := _path_step_to_player_adjacency()
	if path_step != Vector2i.ZERO:
		return path_step
	var best_dir := Vector2i.ZERO
	var best_dist := 999999
	var dirs := [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]
	for dir in dirs:
		var next: Vector2i = _enemy_pos + dir
		if not _can_occupy(next) or next == _player_pos:
			continue
		var dist := maxi(absi(_player_pos.x - next.x), absi(_player_pos.y - next.y))
		if dist < best_dist:
			best_dist = dist
			best_dir = dir
	return best_dir


func _path_step_to_player_adjacency() -> Vector2i:
	var frontier: Array[Vector2i] = [_enemy_pos]
	var came_from: Dictionary = {_enemy_pos: _enemy_pos}
	var target := Vector2i.ZERO
	var found := false
	var dirs := [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]
	var head := 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		if current != _enemy_pos and _adjacent(current, _player_pos):
			target = current
			found = true
			break
		for dir in dirs:
			var next: Vector2i = current + dir
			if came_from.has(next) or next == _player_pos or not _can_occupy(next):
				continue
			came_from[next] = current
			frontier.append(next)
	if not found:
		return Vector2i.ZERO
	var step: Vector2i = target
	while came_from.get(step, _enemy_pos) != _enemy_pos:
		step = came_from[step]
	return step - _enemy_pos


func _can_occupy(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= GRID_W or pos.y >= GRID_H:
		return false
	if _grid_tiles.is_empty():
		return true
	var tile: int = int(_grid_tiles[pos.y][pos.x])
	return tile == GameMapClass.TILE_FLOOR \
		or tile == GameMapClass.TILE_SAND \
		or tile == GameMapClass.TILE_DUNE \
		or tile == GameMapClass.TILE_GRASS \
		or tile == GameMapClass.TILE_ROAD \
		or tile == GameMapClass.TILE_CAVE_FLOOR


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1


func _dir_from_key(event: InputEventKey) -> Vector2i:
	if event.shift_pressed:
		match event.physical_keycode:
			KEY_UP: return Vector2i(-1, -1)
			KEY_RIGHT: return Vector2i(1, -1)
			KEY_DOWN: return Vector2i(1, 1)
			KEY_LEFT: return Vector2i(-1, 1)
	match event.physical_keycode:
		KEY_UP, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_RIGHT, KEY_KP_6:
			return Vector2i(1, 0)
		KEY_DOWN, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_KP_7:
			return Vector2i(-1, -1)
		KEY_KP_9:
			return Vector2i(1, -1)
		KEY_KP_1:
			return Vector2i(-1, 1)
		KEY_KP_3:
			return Vector2i(1, 1)
		_:
			return Vector2i.ZERO


func _push_log(line: String) -> void:
	if line.is_empty():
		return
	_log.append(line)
	while _log.size() > 6:
		_log.pop_front()
	queue_redraw()


func _finish(outcome: String, consume_turn: bool, extra_log: Array) -> void:
	if _phase == Phase.RESOLVED:
		return
	_phase = Phase.RESOLVED
	for line in extra_log:
		_push_log(str(line))
	var result := {
		"outcome": outcome,
		"consume_turn": consume_turn,
		"log": _log.duplicate(),
		"player": _player,
		"enemy": _enemy,
	}
	if _encounter.has("xp_reward"):
		result["xp_reward"] = int(_encounter.get("xp_reward", 0))
	if outcome == "victory":
		_pending_result = result
		_result_popup_lines = [
			"VICTORY",
			"%s is defeated." % (_enemy.name.capitalize() if _enemy != null else "The foe"),
			"+%d XP" % int(_encounter.get("xp_reward", 0)),
			"Enter to continue",
		]
		queue_redraw()
		return
	encounter_finished.emit(result)
	queue_free()


func _emit_pending_result() -> void:
	if _pending_result.is_empty():
		return
	var result := _pending_result.duplicate(true)
	_pending_result.clear()
	encounter_finished.emit(result)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_BG)
	_draw_frame()
	_draw_battlefield()
	_draw_sidebar()
	_draw_log()
	_draw_result_popup()


func _draw_frame() -> void:
	for x in range(_view_cols()):
		_put_ui(x, 0, "-", C_FRAME)
		_put_ui(x, _view_rows() - 1, "-", C_FRAME)
	for y in range(1, _view_rows() - 1):
		_put_ui(0, y, "|", C_FRAME)
		_put_ui(_view_cols() - 1, y, "|", C_FRAME)
	_put_ui(0, 0, "+", C_FRAME)
	_put_ui(_view_cols() - 1, 0, "+", C_FRAME)
	_put_ui(0, _view_rows() - 1, "+", C_FRAME)
	_put_ui(_view_cols() - 1, _view_rows() - 1, "+", C_FRAME)
	_puts_ui(3, 1, _encounter.get("title", "TACTICAL COMBAT"), C_TITLE)
	_puts_ui(3, 2, _encounter.get("subtitle", ""), C_SUBTITLE)


func _draw_battlefield() -> void:
	var map_origin := _map_origin()
	var map_w := GRID_W * _map_cell_w()
	var map_h := GRID_H * _map_cell_h()
	draw_rect(Rect2(map_origin - Vector2(8, 8), Vector2(map_w + 16, map_h + 16)), C_FRAME, false, 3.0)
	for y in range(GRID_H):
		for x in range(GRID_W):
			var tile: int = int(_grid_tiles[y][x]) if not _grid_tiles.is_empty() else GameMapClass.TILE_FLOOR
			var visual := _tile_visual(tile)
			var rect := Rect2(map_origin + Vector2(x * _map_cell_w(), y * _map_cell_h()), Vector2(_map_cell_w(), _map_cell_h()))
			draw_rect(rect, visual.bg)
			_put_map(x, y, visual.ch, visual.fg)
	if _player != null:
		_draw_combatant(_player_pos, "@", C_PLAYER)
	if _enemy != null and _enemy.is_alive:
		_draw_combatant(_enemy_pos, str(_enemy.char), C_ENEMY)


func _draw_combatant(pos: Vector2i, glyph: String, color: Color) -> void:
	var rect := Rect2(_map_origin() + Vector2(pos.x * _map_cell_w(), pos.y * _map_cell_h()), Vector2(_map_cell_w(), _map_cell_h()))
	draw_rect(rect, Color(0, 0, 0, 1))
	_put_map(pos.x, pos.y, glyph, color)


func _draw_sidebar() -> void:
	var panel_x: int = _panel_x()
	_put_ui(panel_x - 2, GRID_Y - 1, "+", C_FRAME)
	for y in range(GRID_Y, LOG_Y - 1):
		_put_ui(panel_x - 2, y, "|", C_FRAME)
	_put_ui(panel_x, 5, "STATUS", C_SUBTITLE)
	_puts_ui(panel_x, 7, _short_initiative_text(), C_TEXT)
	_puts_ui(panel_x, 9, "Turn %d" % _turn_number, C_HILITE)
	_puts_ui(panel_x, 10, _status_text, C_TEXT)
	if _player != null:
		_puts_ui(panel_x, 13, "YOU", C_HILITE)
		_puts_ui(panel_x, 14, "HP %d/%d  AC %d" % [_player.hp, _player.max_hp, _player.ac], C_TEXT)
		_puts_ui(panel_x, 15, "DMG %s" % _player.melee_damage_label(), C_TEXT)
	if _enemy != null:
		_puts_ui(panel_x, 18, _enemy.name.to_upper(), C_ENEMY)
		_puts_ui(panel_x, 19, "HP %d/%d  AC %d" % [_enemy.hp, _enemy.max_hp, _enemy.ac], C_TEXT)
	if _phase == Phase.PLAYER_COMMAND:
		_puts_ui(panel_x, 22, "M move   A attack", C_TEXT)
		_puts_ui(panel_x, 23, "W wait   F flee", C_TEXT)
	elif _phase == Phase.PLAYER_MOVE:
		_puts_ui(panel_x, 22, "Arrows/numpad move", C_TEXT)
		_puts_ui(panel_x, 23, "Shift+arrow diagonal", C_TEXT)
		_puts_ui(panel_x, 24, "A attack  Enter done", C_TEXT)
		_puts_ui(panel_x, 25, "%d move left" % _player_move_remaining, C_HILITE)
	else:
		_puts_ui(panel_x, 22, "Enemy turn...", C_DIM)


func _draw_log() -> void:
	_puts_ui(3, LOG_Y, "Combat log", C_SUBTITLE)
	var start := maxi(0, _log.size() - 4)
	for i in range(start, _log.size()):
		var line: String = _log[i]
		_puts_ui(3, LOG_Y + 2 + (i - start), line, C_TEXT)


func _draw_result_popup() -> void:
	if _result_popup_lines.is_empty():
		return
	var popup_w := 24
	var popup_h := _result_popup_lines.size() + 4
	var x0 := maxi(2, (_view_cols() - popup_w) / 2)
	var y0 := maxi(2, (_view_rows() - popup_h) / 2)
	var rect := Rect2(float(x0 * _ui_cell_w()), float(y0 * _ui_cell_h()), float(popup_w * _ui_cell_w()), float(popup_h * _ui_cell_h()))
	draw_rect(rect, Color(0.02, 0.015, 0.01, 0.96))
	for x in range(popup_w):
		_put_ui(x0 + x, y0, "-", C_FRAME)
		_put_ui(x0 + x, y0 + popup_h - 1, "-", C_FRAME)
	for y in range(1, popup_h - 1):
		_put_ui(x0, y0 + y, "|", C_FRAME)
		_put_ui(x0 + popup_w - 1, y0 + y, "|", C_FRAME)
	_put_ui(x0, y0, "+", C_FRAME)
	_put_ui(x0 + popup_w - 1, y0, "+", C_FRAME)
	_put_ui(x0, y0 + popup_h - 1, "+", C_FRAME)
	_put_ui(x0 + popup_w - 1, y0 + popup_h - 1, "+", C_FRAME)
	for i in range(_result_popup_lines.size()):
		var color := C_TITLE if i == 0 else (C_HILITE if i == 2 else C_TEXT)
		_puts_ui(x0 + 2, y0 + 2 + i, _result_popup_lines[i], color)


func _short_initiative_text() -> String:
	var enemy_name: String = _enemy.name.capitalize() if _enemy != null else "Enemy"
	return "Init: You / %s" % enemy_name


func _tile_visual(tile: int) -> Dictionary:
	match tile:
		GameMapClass.TILE_WALL:
			return {"ch": "#", "fg": Color(0.54, 0.34, 0.18), "bg": Color(0.18, 0.09, 0.05)}
		GameMapClass.TILE_FLOOR:
			return {"ch": ".", "fg": Color(0.56, 0.50, 0.40), "bg": Color(0.14, 0.12, 0.10)}
		GameMapClass.TILE_SAND:
			return {"ch": ".", "fg": Color(0.96, 0.88, 0.56), "bg": Color(0.34, 0.26, 0.10)}
		GameMapClass.TILE_DUNE:
			return {"ch": "^", "fg": Color(0.95, 0.72, 0.28), "bg": Color(0.38, 0.20, 0.08)}
		GameMapClass.TILE_ROCK:
			return {"ch": "#", "fg": Color(0.80, 0.48, 0.24), "bg": Color(0.22, 0.10, 0.06)}
		GameMapClass.TILE_WATER:
			return {"ch": "~", "fg": Color(0.38, 0.70, 0.95), "bg": Color(0.08, 0.18, 0.28)}
		GameMapClass.TILE_GRASS:
			return {"ch": "\"", "fg": Color(0.58, 0.86, 0.34), "bg": Color(0.12, 0.22, 0.08)}
		GameMapClass.TILE_ROAD:
			return {"ch": "\u2591", "fg": Color(0.86, 0.72, 0.48), "bg": Color(0.24, 0.18, 0.10)}
		GameMapClass.TILE_CAVE_WALL:
			return {"ch": "%", "fg": Color(0.62, 0.60, 0.58), "bg": Color(0.12, 0.12, 0.12)}
		GameMapClass.TILE_CAVE_FLOOR:
			return {"ch": ".", "fg": Color(0.52, 0.50, 0.46), "bg": Color(0.10, 0.09, 0.09)}
		_:
			return {"ch": "?", "fg": C_TEXT, "bg": C_BG}


func _view_cols() -> int:
	return maxi(_panel_x() + 34, int(floor(get_viewport_rect().size.x / _ui_cell_w())))


func _view_rows() -> int:
	return maxi(LOG_Y + 9, int(floor(get_viewport_rect().size.y / _ui_cell_h())))


func _panel_x() -> int:
	var map_right_px: float = _map_origin().x + GRID_W * _map_cell_w()
	return int(ceil(map_right_px / _ui_cell_w())) + PANEL_GAP


func _ui_cell_w() -> float:
	if _font == null:
		return UI_CELL_W
	return maxf(1.0, ceil(_font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE).x))


func _ui_cell_h() -> float:
	if _font == null:
		return UI_CELL_H
	return maxf(1.0, ceil(_font.get_height(UI_FONT_SIZE)))


func _map_cell_w() -> float:
	return MAP_CELL_W


func _map_cell_h() -> float:
	return MAP_CELL_H


func _map_origin() -> Vector2:
	return Vector2(GRID_X * _ui_cell_w(), GRID_Y * _ui_cell_h())


func _put_ui(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * _ui_cell_w(), y * _ui_cell_h() + UI_FONT_SIZE), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE, color)


func _puts_ui(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * _ui_cell_w(), y * _ui_cell_h() + UI_FONT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE, color)


func _put_map(x: int, y: int, ch: String, color: Color) -> void:
	var pos := _map_origin() + Vector2(x * _map_cell_w(), y * _map_cell_h() + MAP_FONT_SIZE)
	var glyph_w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, MAP_FONT_SIZE).x if _font != null else 0.0
	pos.x += maxf(0.0, (_map_cell_w() - glyph_w) * 0.5)
	draw_string(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, MAP_FONT_SIZE, color)
