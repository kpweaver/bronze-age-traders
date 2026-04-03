extends Node2D

const SaveManagerClass = preload("res://scripts/save_manager.gd")

const COLS := 80
const ROWS := 25
const FONT_SIZE := 16
const CELL_W := 9.0
const CELL_H := 18.0

const C_BG       := Color(0.05, 0.04, 0.03)
const C_BORDER   := Color(0.30, 0.20, 0.10)
const C_TITLE    := Color(0.80, 0.50, 0.20)  # bronze
const C_TAGLINE  := Color(0.40, 0.28, 0.14)
const C_SELECTED := Color(0.80, 0.50, 0.20)
const C_NORMAL   := Color(0.55, 0.42, 0.28)
const C_DISABLED := Color(0.22, 0.17, 0.10)

const OPTIONS := ["Continue", "New Game", "Quit"]

var _font: Font
var _cursor: int = 0
var _save_exists: bool = false


func _ready() -> void:
	_font = _load_font()
	_save_exists = SaveManagerClass.save_exists()
	_cursor = 0 if _save_exists else 1
	queue_redraw()


func _load_font() -> Font:
	var path := "res://assets/fonts/Px437_IBM_VGA_9x16.ttf"
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console"])
	return sf


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_UP, KEY_KP_8:
			_move_cursor(-1)
		KEY_DOWN, KEY_KP_2:
			_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm()


func _move_cursor(dir: int) -> void:
	var next := wrapi(_cursor + dir, 0, OPTIONS.size())
	# Skip "Continue" if no save exists
	if next == 0 and not _save_exists:
		next = wrapi(next + dir, 0, OPTIONS.size())
	_cursor = next
	queue_redraw()


func _confirm() -> void:
	match _cursor:
		0:  # Continue
			if _save_exists:
				GameState.load_save = true
				get_tree().change_scene_to_file("res://main.tscn")
		1:  # New Game
			SaveManagerClass.delete_save()
			GameState.load_save = false
			get_tree().change_scene_to_file("res://main.tscn")
		2:  # Quit
			get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), C_BG)
	_draw_border()
	_draw_title()
	_draw_options()
	_draw_hint()


func _draw_border() -> void:
	for x in range(COLS):
		_put(x, 0, "-", C_BORDER)
		_put(x, ROWS - 1, "-", C_BORDER)
	for y in range(1, ROWS - 1):
		_put(0, y, "|", C_BORDER)
		_put(COLS - 1, y, "|", C_BORDER)
	_put(0, 0, "+", C_BORDER)
	_put(COLS - 1, 0, "+", C_BORDER)
	_put(0, ROWS - 1, "+", C_BORDER)
	_put(COLS - 1, ROWS - 1, "+", C_BORDER)


func _draw_title() -> void:
	_puts_centered(7, "B R O N Z E  A G E  T R A D E R S", C_TITLE)
	_puts_centered(9, "survive . trade . ascend", C_TAGLINE)


func _draw_options() -> void:
	for i in range(OPTIONS.size()):
		var is_disabled := i == 0 and not _save_exists
		var is_selected := i == _cursor and not is_disabled
		var color: Color
		if is_disabled:
			color = C_DISABLED
		elif is_selected:
			color = C_SELECTED
		else:
			color = C_NORMAL
		var prefix := "> " if is_selected else "  "
		_puts_centered(14 + i * 2, prefix + OPTIONS[i], color)


func _draw_hint() -> void:
	_puts_centered(ROWS - 2, "arrows: navigate    enter: select", C_BORDER)


func _puts_centered(row: int, text: String, color: Color) -> void:
	_puts(int((COLS - text.length()) / 2), row, text, color)


func _put(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
