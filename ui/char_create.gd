extends Node2D

const COLS      := 120
const ROWS      := 40
const FONT_SIZE := 16
const CELL_W    := 9.0
const CELL_H    := 18.0

const C_BG       := Color(0.05, 0.04, 0.03)
const C_BORDER   := Color(0.30, 0.20, 0.10)
const C_TITLE    := Color(0.80, 0.50, 0.20)
const C_LABEL    := Color(0.55, 0.42, 0.28)
const C_INPUT    := Color(0.92, 0.82, 0.60)
const C_CURSOR   := Color(0.80, 0.50, 0.20)
const C_SELECTED := Color(0.80, 0.50, 0.20)
const C_NORMAL   := Color(0.55, 0.42, 0.28)
const C_DISABLED := Color(0.22, 0.17, 0.10)
const C_HINT     := Color(0.30, 0.20, 0.10)

# Classes available at character creation — add entries here when new classes are ready.
# Format: [id_string, display_name, description]
const CLASSES := [
	["wanderer", "Wanderer",  "A rootless traveller. Balanced stats, no allegiances."],
]

const NAME_MAX := 24

var _font: Font
var _name: String = ""
var _class_cursor: int = 0
var _blink: float  = 0.0   # cursor blink timer

enum Phase { NAME, CLASS, CONFIRM }
var _phase: Phase = Phase.NAME


func _ready() -> void:
	_font = _load_font()
	_name = ""
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


func _process(delta: float) -> void:
	_blink += delta
	if _blink >= 0.55:
		_blink = 0.0
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()

	match _phase:
		Phase.NAME:   _handle_name_input(event)
		Phase.CLASS:  _handle_class_input(event)
		Phase.CONFIRM: _handle_confirm_input(event)


func _handle_name_input(event: InputEvent) -> void:
	match event.physical_keycode:
		KEY_BACKSPACE:
			if _name.length() > 0:
				_name = _name.left(_name.length() - 1)
				queue_redraw()
		KEY_ENTER, KEY_KP_ENTER:
			if _name.strip_edges().length() > 0:
				_phase = Phase.CLASS
				queue_redraw()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		_:
			# event.unicode is the final codepoint accounting for Shift, etc.
			var code: int = event.unicode
			if code >= 32 and code <= 126 and _name.length() < NAME_MAX:
				_name += char(code)
				queue_redraw()


func _handle_class_input(event: InputEvent) -> void:
	match event.physical_keycode:
		KEY_UP, KEY_KP_8:
			_class_cursor = wrapi(_class_cursor - 1, 0, CLASSES.size())
			queue_redraw()
		KEY_DOWN, KEY_KP_2:
			_class_cursor = wrapi(_class_cursor + 1, 0, CLASSES.size())
			queue_redraw()
		KEY_ENTER, KEY_KP_ENTER:
			_phase = Phase.CONFIRM
			queue_redraw()
		KEY_ESCAPE:
			_phase = Phase.NAME
			queue_redraw()


func _handle_confirm_input(event: InputEvent) -> void:
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_Y:
			_start_game()
		KEY_ESCAPE, KEY_N:
			_phase = Phase.NAME
			queue_redraw()


func _start_game() -> void:
	GameState.player_name  = _name.strip_edges()
	GameState.player_class = CLASSES[_class_cursor][0]
	GameState.load_save    = false
	get_tree().change_scene_to_file("res://main.tscn")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), C_BG)
	_draw_border()
	_draw_title()
	match _phase:
		Phase.NAME:    _draw_name_phase()
		Phase.CLASS:   _draw_class_phase()
		Phase.CONFIRM: _draw_confirm_phase()
	_draw_hint()


func _draw_border() -> void:
	for x in range(COLS):
		_put(x, 0,        "-", C_BORDER)
		_put(x, ROWS - 1, "-", C_BORDER)
	for y in range(1, ROWS - 1):
		_put(0,        y, "|", C_BORDER)
		_put(COLS - 1, y, "|", C_BORDER)
	_put(0,        0,        "+", C_BORDER)
	_put(COLS - 1, 0,        "+", C_BORDER)
	_put(0,        ROWS - 1, "+", C_BORDER)
	_put(COLS - 1, ROWS - 1, "+", C_BORDER)


func _draw_title() -> void:
	_puts_centered(6,  "B R O N Z E  A G E  T R A D E R S", C_TITLE)
	_puts_centered(8,  "Character Creation", C_LABEL)
	_puts_centered(9,  "- - - - - - - - - - - - - - - - -", C_BORDER)


func _draw_name_phase() -> void:
	_puts_centered(14, "What is your name, traveller?", C_LABEL)

	# Name input box
	const BOX_W := 32
	const BOX_X := (COLS - BOX_W) >> 1
	var display := _name
	var show_cursor := _blink < 0.28
	if show_cursor:
		display += "_"
	else:
		display += " "
	_puts_centered(17, display.lpad(BOX_W >> 1).rpad(BOX_W), C_INPUT)

	# Underline
	var ul := ""
	for _i in range(BOX_W):
		ul += "-"
	_puts(BOX_X, 18, ul, C_BORDER)

	if _name.strip_edges().length() == 0:
		_puts_centered(21, "enter a name to continue", C_DISABLED)


func _draw_class_phase() -> void:
	_puts_centered(12, "Choose your calling:", C_LABEL)

	var name_display := "Name: " + _name.strip_edges()
	_puts_centered(14, name_display, C_INPUT)

	for i in range(CLASSES.size()):
		var cls: Array = CLASSES[i]
		var is_sel     := i == _class_cursor
		var color      := C_SELECTED if is_sel else C_NORMAL
		var prefix     := "> " if is_sel else "  "
		_puts_centered(17 + i * 3, prefix + cls[1], color)
		if is_sel:
			_puts_centered(18 + i * 3, cls[2], C_LABEL)

	_puts_centered(32, "enter: confirm class    esc: back to name", C_HINT)


func _draw_confirm_phase() -> void:
	var cls_name: String = CLASSES[_class_cursor][1]
	_puts_centered(14, "Ready to begin?", C_LABEL)
	_puts_centered(17, "Name:  " + _name.strip_edges(), C_INPUT)
	_puts_centered(19, "Class: " + cls_name, C_INPUT)
	_puts_centered(23, "[ Enter / Y ] to start      [ Esc / N ] to go back", C_HINT)


func _draw_hint() -> void:
	match _phase:
		Phase.NAME:
			_puts_centered(ROWS - 2, "type your name    enter: next    esc: main menu", C_HINT)
		Phase.CLASS:
			_puts_centered(ROWS - 2, "arrows: choose class    enter: next    esc: back", C_HINT)
		Phase.CONFIRM:
			_puts_centered(ROWS - 2, "enter/Y: start game    esc/N: go back", C_HINT)


func _puts_centered(row: int, text: String, color: Color) -> void:
	_puts((COLS - text.length()) >> 1, row, text, color)


func _put(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
