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

const MAP_ROWS: int      = 44
const DIVIDER_ROW: int   = 44
const STATUS_ROW: int    = 46
const STATUS_ROW_2: int  = 47
const MSG_START_ROW: int = 49
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
enum Screen { NONE, ESCAPE, INVENTORY, CHARACTER, SETTINGS, LOOK, TARGET, WORLD_MAP, TRAVEL_EVENT, ATTRIBUTE_PICK, TRADE, DISAMBIGUATE, HELP, READER, DIALOGUE }
enum AutoMoveMode { NONE, EXPLORE, TRAVEL }
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

const ATTRIBUTE_OPTIONS := [
	{"key": KEY_S, "code": "str", "label": "Strength"},
	{"key": KEY_D, "code": "dex", "label": "Dexterity"},
	{"key": KEY_C, "code": "con", "label": "Constitution"},
	{"key": KEY_I, "code": "int", "label": "Intelligence"},
	{"key": KEY_W, "code": "wis", "label": "Wisdom"},
	{"key": KEY_H, "code": "cha", "label": "Charisma"},
]

# NPC trade state
var _trade_npc        = null
var _trade_buy_cursor:  int = 0
var _trade_sell_cursor: int = 0
var _trade_panel:       int = 0   # 0 = buy, 1 = sell

# Disambiguation overlay
var _disambig_prompt:  String = ""
var _disambig_options: Array  = []
var _disambig_cursor: int     = 0

# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
var _cam_x: int = 0
var _cam_y: int = 0
var _look_pos: Vector2i = Vector2i.ZERO
var _target_pos: Vector2i = Vector2i.ZERO
var _target_candidates: Array = []
var _target_candidate_index: int = 0
var _hover_pos: Vector2i = Vector2i.ZERO
var _hover_active: bool = false
var _auto_move_mode: AutoMoveMode = AutoMoveMode.NONE
var _auto_move_target: Vector2i = Vector2i.ZERO
var _auto_move_accum: float = 0.0
var _auto_move_steps_taken: int = 0
const AUTO_MOVE_STEP_SECONDS: float = 0.05
const MOUNT_GLYPH_CYCLE_MS: int = 700
var _mount_cycle_bucket: int = -1

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
var _ui_theme: Theme
var _ui_layer
var _inventory_ui_root: Control
var _inventory_shell: PanelContainer
var _inventory_pack_list
var _inventory_summary_box
var _inventory_loadout_box
var _inventory_title_label
var _inventory_left_hint_label
var _inventory_right_hint_label
var _menu_ui_root: Control
var _menu_shell: PanelContainer
var _menu_title_label
var _menu_body_text
var _menu_footer_label
var _trade_ui_root: Control
var _trade_shell: PanelContainer
var _trade_title_label
var _trade_buy_text
var _trade_sell_text
var _trade_footer_label
var _hud_ui_root: Control
var _hud_bg: ColorRect
var _hud_status_top: Label
var _hud_status_bottom: Label
var _hud_message_labels: Array = []

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
	_ui_theme = _make_ui_theme()
	_world = GameWorldClass.new()
	add_child(_world)
	_attach_ui_layer()
	_build_hud_ui()
	_build_inventory_ui()
	_build_menu_ui()
	_build_trade_ui()
	set_process(true)
	_world.turn_ended.connect(_on_turn_ended)
	_world.map_changed.connect(_on_map_changed)
	_world.attribute_points_changed.connect(_on_attribute_points_changed)
	if GameState.load_save:
		_world.load_from_save()
		GameState.load_save = false
	else:
		_world.new_game()
	# map_changed fires during new_game/load, but compute tint explicitly here
	# in case _ready runs before the signal handler is wired (belt-and-suspenders).
	_day_tint = _compute_day_tint()
	_open_attribute_overlay_if_needed()


func _exit_tree() -> void:
	if _world != null:
		_world.cleanup()


func _process(delta: float) -> void:
	_refresh_hud_ui()
	_sync_inventory_ui_visibility()
	_sync_menu_ui_visibility()
	_sync_trade_ui_visibility()
	if _world != null and _world.get_player_mount() != null:
		var bucket: int = int(Time.get_ticks_msec() / MOUNT_GLYPH_CYCLE_MS)
		if bucket != _mount_cycle_bucket:
			_mount_cycle_bucket = bucket
			queue_redraw()
	if _auto_move_mode == AutoMoveMode.NONE:
		return
	if _screen != Screen.NONE or _game_over:
		_stop_auto_move()
		return
	_auto_move_accum += delta
	while _auto_move_mode != AutoMoveMode.NONE and _auto_move_accum >= AUTO_MOVE_STEP_SECONDS:
		_auto_move_accum -= AUTO_MOVE_STEP_SECONDS
		_tick_auto_move()


func _make_font() -> Font:
	var path := "res://assets/fonts/Px437_IBM_VGA_9x14.ttf"
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "Courier New"])
	return sf


func _make_ui_theme() -> Theme:
	var theme := Theme.new()
	theme.set_font("font", "Label", _font)
	theme.set_font("font", "Button", _font)
	theme.set_font("font", "PanelContainer", _font)
	theme.set_font("font", "ScrollContainer", _font)
	theme.set_font("normal_font", "RichTextLabel", _font)
	theme.set_font("bold_font", "RichTextLabel", _font)
	theme.set_font("italics_font", "RichTextLabel", _font)
	theme.set_font("mono_font", "RichTextLabel", _font)
	theme.set_font_size("font_size", "Label", UI_FONT_SIZE)
	theme.set_font_size("font_size", "Button", UI_FONT_SIZE)
	theme.set_font_size("normal_font_size", "RichTextLabel", UI_FONT_SIZE)
	theme.set_font_size("bold_font_size", "RichTextLabel", UI_FONT_SIZE)
	theme.set_font_size("italics_font_size", "RichTextLabel", UI_FONT_SIZE)
	theme.set_font_size("mono_font_size", "RichTextLabel", UI_FONT_SIZE)
	theme.set_color("font_color", "Label", C_MSG_RECENT)
	theme.set_color("font_focus_color", "Button", C_STATUS)
	theme.set_color("font_hover_color", "Button", C_STATUS)
	theme.set_color("font_pressed_color", "Button", C_GOLD)
	theme.set_color("font_color", "Button", C_MSG_RECENT)
	theme.set_color("default_color", "RichTextLabel", C_MSG_RECENT)

	theme.set_stylebox("panel", "PanelContainer", _make_panel_style(C_DIVIDER, 10, 2))

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0, 0, 0, 0)
	button_normal.content_margin_left = 2
	button_normal.content_margin_right = 2
	button_normal.content_margin_top = 1
	button_normal.content_margin_bottom = 1
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("pressed", "Button", button_normal)
	theme.set_stylebox("focus", "Button", button_normal)
	theme.set_stylebox("disabled", "Button", button_normal)

	var button_hover := StyleBoxFlat.new()
	button_hover.bg_color = Color(0.30, 0.20, 0.10, 0.45)
	button_hover.content_margin_left = 2
	button_hover.content_margin_right = 2
	button_hover.content_margin_top = 1
	button_hover.content_margin_bottom = 1
	theme.set_stylebox("hover", "Button", button_hover)

	return theme


func _make_panel_style(border_color: Color, content_margin: int, border_width: int = 2) -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.04, 0.03, 0.97)
	panel_style.border_color = border_color
	panel_style.border_width_left = border_width
	panel_style.border_width_top = border_width
	panel_style.border_width_right = border_width
	panel_style.border_width_bottom = border_width
	panel_style.content_margin_left = content_margin
	panel_style.content_margin_top = content_margin
	panel_style.content_margin_right = content_margin
	panel_style.content_margin_bottom = content_margin
	panel_style.shadow_color = Color(0, 0, 0, 0.30)
	panel_style.shadow_size = 6
	return panel_style


func _apply_shell_style(shell: PanelContainer, border_color: Color, content_margin: int, border_width: int = 2) -> void:
	if shell == null:
		return
	shell.add_theme_stylebox_override("panel", _make_panel_style(border_color, content_margin, border_width))


func _attach_ui_layer() -> void:
	_ui_layer = get_parent().get_node_or_null("UI")
	if _ui_layer == null:
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "UI"
		get_parent().add_child(_ui_layer)


func _build_hud_ui() -> void:
	_hud_ui_root = Control.new()
	_hud_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_ui_root.theme = _ui_theme
	_ui_layer.add_child(_hud_ui_root)

	_hud_bg = ColorRect.new()
	_hud_bg.color = C_BG
	_hud_bg.position = Vector2(0, DIVIDER_ROW * CELL_H)
	_hud_bg.size = Vector2(COLS * CELL_W, (ROWS - DIVIDER_ROW) * CELL_H)
	_hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_bg)

	var divider := ColorRect.new()
	divider.color = C_DIVIDER
	divider.position = Vector2(0, DIVIDER_ROW * CELL_H)
	divider.size = Vector2(COLS * CELL_W, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(divider)

	_hud_status_top = Label.new()
	_hud_status_top.position = Vector2(0, STATUS_ROW * CELL_H - 2)
	_hud_status_top.custom_minimum_size = Vector2(COLS * CELL_W, CELL_H)
	_hud_status_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_status_top)

	_hud_status_bottom = Label.new()
	_hud_status_bottom.position = Vector2(0, STATUS_ROW_2 * CELL_H - 2)
	_hud_status_bottom.custom_minimum_size = Vector2(COLS * CELL_W, CELL_H)
	_hud_status_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_status_bottom.add_theme_color_override("font_color", C_STATUS)
	_hud_ui_root.add_child(_hud_status_bottom)

	for i in range(MSG_LINES):
		var msg := Label.new()
		msg.position = Vector2(0, (MSG_START_ROW + i) * CELL_H - 4)
		msg.custom_minimum_size = Vector2(COLS * CELL_W, CELL_H + 4)
		msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_ui_root.add_child(msg)
		_hud_message_labels.append(msg)


func _on_turn_ended(_n: int) -> void:
	_day_tint = _compute_day_tint()
	_update_camera()
	if _screen == Screen.INVENTORY:
		_refresh_inventory_ui()
	queue_redraw()


func _on_map_changed() -> void:
	_day_tint = _compute_day_tint()
	_update_camera()
	_open_attribute_overlay_if_needed()
	if _screen == Screen.INVENTORY:
		_refresh_inventory_ui()
	queue_redraw()


func _on_attribute_points_changed(_n: int) -> void:
	_stop_auto_move()
	_open_attribute_overlay_if_needed()
	queue_redraw()


func _open_attribute_overlay_if_needed() -> void:
	if _world != null and _world.has_unspent_attribute_points():
		_stop_auto_move()
		_screen = Screen.ATTRIBUTE_PICK
	elif _screen == Screen.ATTRIBUTE_PICK:
		_screen = Screen.NONE


func _build_inventory_ui() -> void:
	_inventory_ui_root = Control.new()
	_inventory_ui_root.visible = false
	_inventory_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory_ui_root.theme = _ui_theme
	_ui_layer.add_child(_inventory_ui_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory_ui_root.add_child(dim)

	_inventory_shell = PanelContainer.new()
	_inventory_shell.position = Vector2(52, 34)
	_inventory_shell.size = Vector2(976, 412)
	_inventory_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_ui_root.add_child(_inventory_shell)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 12)
	outer.add_theme_constant_override("margin_top", 10)
	outer.add_theme_constant_override("margin_right", 12)
	outer.add_theme_constant_override("margin_bottom", 10)
	_inventory_shell.add_child(outer)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	outer.add_child(root_v)

	_inventory_title_label = Label.new()
	_inventory_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_title_label.add_theme_color_override("font_color", C_STATUS)
	root_v.add_child(_inventory_title_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root_v.add_child(body)

	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.2
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 10)
	left_margin.add_theme_constant_override("margin_top", 10)
	left_margin.add_theme_constant_override("margin_right", 10)
	left_margin.add_theme_constant_override("margin_bottom", 10)
	left_panel.add_child(left_margin)

	var left_v := VBoxContainer.new()
	left_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_v)

	var left_header := Label.new()
	left_header.text = "PACK"
	left_header.add_theme_color_override("font_color", C_STATUS)
	left_v.add_child(left_header)

	var pack_scroll := ScrollContainer.new()
	pack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_v.add_child(pack_scroll)

	_inventory_pack_list = VBoxContainer.new()
	_inventory_pack_list.add_theme_constant_override("separation", 4)
	_inventory_pack_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_scroll.add_child(_inventory_pack_list)

	_inventory_summary_box = VBoxContainer.new()
	_inventory_summary_box.add_theme_constant_override("separation", 2)
	left_v.add_child(_inventory_summary_box)

	_inventory_left_hint_label = Label.new()
	_inventory_left_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_left_hint_label.add_theme_color_override("font_color", C_DIVIDER)
	left_v.add_child(_inventory_left_hint_label)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(280, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_panel.add_child(right_margin)

	var right_v := VBoxContainer.new()
	right_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_v)

	var right_header := Label.new()
	right_header.text = "LOADOUT"
	right_header.add_theme_color_override("font_color", C_STATUS)
	right_v.add_child(right_header)

	_inventory_loadout_box = VBoxContainer.new()
	_inventory_loadout_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_loadout_box.add_theme_constant_override("separation", 6)
	right_v.add_child(_inventory_loadout_box)

	_inventory_right_hint_label = Label.new()
	_inventory_right_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_right_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_right_hint_label.add_theme_color_override("font_color", C_DIVIDER)
	right_v.add_child(_inventory_right_hint_label)


func _sync_inventory_ui_visibility() -> void:
	if _inventory_ui_root == null:
		return
	var should_show: bool = _screen == Screen.INVENTORY
	if _inventory_ui_root.visible == should_show:
		return
	_inventory_ui_root.visible = should_show
	if should_show:
		_apply_inventory_shell_layout()
		_refresh_inventory_ui()


func _clear_control_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _refresh_inventory_ui() -> void:
	if _inventory_ui_root == null or _world == null or _player == null:
		return
	_inventory_title_label.text = "-=[ INVENTORY ]=-"
	_inventory_left_hint_label.text = "[a-z] use / equip / read"
	_inventory_right_hint_label.text = "[w/r/b/f/h/u] unequip    [Esc] close"
	_clear_control_children(_inventory_pack_list)
	_clear_control_children(_inventory_summary_box)
	_clear_control_children(_inventory_loadout_box)

	var load_line := Label.new()
	load_line.text = "%s / %s" % [_format_lbs(_player.total_carry_weight), _format_lbs(_player.max_carry_weight)]
	load_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	load_line.add_theme_color_override("font_color", C_STATUS)
	_inventory_pack_list.add_child(load_line)

	var section_order := ["weapons", "ammo", "armor", "lights", "consumables", "goods", "tablets", "other"]
	var next_letter_ord: int = ord("a")
	var display_items: Array = _inventory_display_items()
	if display_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Your pack is empty."
		empty_label.add_theme_color_override("font_color", C_MSG_OLD)
		_inventory_pack_list.add_child(empty_label)
	else:
		for section_key in section_order:
			var items: Array = []
			for item in display_items:
				if _inventory_section_key(item) == section_key:
					items.append(item)
			if items.is_empty():
				continue
			var section_row := HBoxContainer.new()
			var section_label := Label.new()
			section_label.text = "[-] %s" % _inventory_section_title(section_key)
			section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			section_label.add_theme_color_override("font_color", C_STATUS)
			section_row.add_child(section_label)
			var section_weight: int = 0
			for item in items:
				section_weight += int(item.total_weight())
			var section_value := Label.new()
			section_value.text = "[%s]" % _format_lbs(section_weight)
			section_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			section_value.add_theme_color_override("font_color", C_STATUS)
			section_row.add_child(section_value)
			_inventory_pack_list.add_child(section_row)

			for item in items:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				var key_button := Button.new()
				key_button.text = "%s)" % char(next_letter_ord)
				key_button.flat = true
				key_button.custom_minimum_size = Vector2(36, 0)
				key_button.pressed.connect(func(): _activate_inventory_item(item))
				row.add_child(key_button)

				var name_button := Button.new()
				var item_name: String = item.name
				if item.stack_label() != "":
					item_name += " %s" % item.stack_label()
				name_button.text = item_name
				name_button.flat = true
				name_button.clip_text = true
				name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				name_button.pressed.connect(func(): _activate_inventory_item(item))
				row.add_child(name_button)

				var detail_label := Label.new()
				detail_label.text = _inventory_item_detail(item)
				detail_label.clip_text = true
				detail_label.custom_minimum_size = Vector2(140, 0)
				row.add_child(detail_label)

				var weight_label := Label.new()
				weight_label.text = "[%s]" % item.weight_label()
				weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				weight_label.custom_minimum_size = Vector2(86, 0)
				row.add_child(weight_label)

				_inventory_pack_list.add_child(row)
				next_letter_ord += 1

	var carry_label := Label.new()
	carry_label.text = "Carry: %s / %s" % [_format_lbs(_player.total_carry_weight), _format_lbs(_player.max_carry_weight)]
	_inventory_summary_box.add_child(carry_label)
	var str_label := Label.new()
	str_label.text = "STR bonus: %+d lbs." % (_player.max_carry_weight - ActorClass.BASE_CARRY_WEIGHT)
	_inventory_summary_box.add_child(str_label)
	var gold_label := Label.new()
	gold_label.text = "Gold: %d" % _player.gold
	gold_label.add_theme_color_override("font_color", C_GOLD)
	_inventory_summary_box.add_child(gold_label)

	var equipped_title := Label.new()
	equipped_title.text = "EQUIPPED"
	equipped_title.add_theme_color_override("font_color", C_STATUS)
	_inventory_loadout_box.add_child(equipped_title)

	var slot_rows: Array = [
		[ItemClass.SLOT_WEAPON, "w) WEAPON"],
		[ItemClass.SLOT_RANGED, "r) RANGED"],
		[ItemClass.SLOT_BODY,   "b) BODY"],
		[ItemClass.SLOT_FEET,   "f) FEET"],
		[ItemClass.SLOT_HEAD,   "h) HEAD"],
		[ItemClass.SLOT_LIGHT,  "u) LIGHT"],
	]
	for sdata in slot_rows:
		var slot_key: String = str(sdata[0])
		var slot_button := Button.new()
		slot_button.text = str(sdata[1])
		slot_button.flat = true
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.pressed.connect(func():
			var msg: String = _player.unequip(slot_key)
			if msg != "":
				_world.add_msg(msg)
				_refresh_inventory_ui()
				queue_redraw()
		)
		_inventory_loadout_box.add_child(slot_button)

		var eq_item = _player.equipped.get(slot_key)
		if eq_item == null:
			var dash := Label.new()
			dash.text = "  -"
			dash.add_theme_color_override("font_color", C_MSG_OLD)
			_inventory_loadout_box.add_child(dash)
			continue

		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 6)
		var item_name := Label.new()
		item_name.text = (eq_item as ItemClass).name
		item_name.clip_text = true
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_row.add_child(item_name)
		var item_weight := Label.new()
		item_weight.text = "[%s]" % (eq_item as ItemClass).weight_label()
		item_weight.custom_minimum_size = Vector2(86, 0)
		item_weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		item_row.add_child(item_weight)
		_inventory_loadout_box.add_child(item_row)

		var detail := _inventory_item_detail(eq_item)
		if not detail.is_empty():
			var detail_label := Label.new()
			detail_label.text = "  %s" % detail
			detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_label.add_theme_color_override("font_color", C_MSG_OLD)
			_inventory_loadout_box.add_child(detail_label)


func _build_menu_ui() -> void:
	_menu_ui_root = Control.new()
	_menu_ui_root.visible = false
	_menu_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_ui_root.theme = _ui_theme
	_ui_layer.add_child(_menu_ui_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_ui_root.add_child(dim)

	_menu_shell = PanelContainer.new()
	_menu_shell.position = Vector2(184, 78)
	_menu_shell.size = Vector2(712, 368)
	_menu_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_ui_root.add_child(_menu_shell)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_menu_shell.add_child(margin)

	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	_menu_title_label = Label.new()
	_menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_title_label.add_theme_color_override("font_color", C_STATUS)
	v.add_child(_menu_title_label)

	_menu_body_text = RichTextLabel.new()
	_menu_body_text.bbcode_enabled = false
	_menu_body_text.fit_content = false
	_menu_body_text.scroll_active = true
	_menu_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_body_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_menu_body_text)

	_menu_footer_label = Label.new()
	_menu_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_footer_label.add_theme_color_override("font_color", C_DIVIDER)
	v.add_child(_menu_footer_label)


func _build_trade_ui() -> void:
	_trade_ui_root = Control.new()
	_trade_ui_root.visible = false
	_trade_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trade_ui_root.theme = _ui_theme
	_ui_layer.add_child(_trade_ui_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trade_ui_root.add_child(dim)

	_trade_shell = PanelContainer.new()
	_trade_shell.position = Vector2(52, 34)
	_trade_shell.size = Vector2(976, 412)
	_trade_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_ui_root.add_child(_trade_shell)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_trade_shell.add_child(margin)

	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	_trade_title_label = Label.new()
	_trade_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_title_label.add_theme_color_override("font_color", C_STATUS)
	v.add_child(_trade_title_label)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	v.add_child(split)

	_trade_buy_text = RichTextLabel.new()
	_trade_buy_text.fit_content = false
	_trade_buy_text.scroll_active = true
	_trade_buy_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_buy_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_buy_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(_trade_buy_text)

	_trade_sell_text = RichTextLabel.new()
	_trade_sell_text.fit_content = false
	_trade_sell_text.scroll_active = true
	_trade_sell_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_sell_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_sell_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(_trade_sell_text)

	_trade_footer_label = Label.new()
	_trade_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_footer_label.add_theme_color_override("font_color", C_DIVIDER)
	v.add_child(_trade_footer_label)


func _screen_uses_menu_ui() -> bool:
	return _screen in [Screen.ESCAPE, Screen.CHARACTER, Screen.SETTINGS, Screen.ATTRIBUTE_PICK,
		Screen.DISAMBIGUATE, Screen.HELP, Screen.READER, Screen.DIALOGUE, Screen.TRAVEL_EVENT]


func _sync_menu_ui_visibility() -> void:
	if _menu_ui_root == null:
		return
	var should_show: bool = _screen_uses_menu_ui()
	_menu_ui_root.visible = should_show
	if should_show:
		_apply_menu_shell_layout()
		_refresh_menu_ui()


func _sync_trade_ui_visibility() -> void:
	if _trade_ui_root == null:
		return
	var should_show: bool = _screen == Screen.TRADE
	_trade_ui_root.visible = should_show
	if should_show:
		_apply_trade_shell_layout()
		_refresh_trade_ui()


func _apply_inventory_shell_layout() -> void:
	if _inventory_shell == null:
		return
	_inventory_shell.size = Vector2(976, 412)
	_inventory_shell.position = _centered_shell_pos(_inventory_shell.size)
	_apply_shell_style(_inventory_shell, C_DIVIDER, 10, 2)


func _apply_trade_shell_layout() -> void:
	if _trade_shell == null:
		return
	_trade_shell.size = Vector2(976, 412)
	_trade_shell.position = _centered_shell_pos(_trade_shell.size)
	_apply_shell_style(_trade_shell, C_DIVIDER, 10, 2)


func _apply_menu_shell_layout() -> void:
	if _menu_shell == null:
		return
	match _screen:
		Screen.ESCAPE:
			_menu_shell.size = Vector2(376, 238)
			_apply_shell_style(_menu_shell, C_STATUS, 8, 2)
		Screen.TRAVEL_EVENT, Screen.DISAMBIGUATE, Screen.ATTRIBUTE_PICK:
			_menu_shell.size = Vector2(472, 268)
			_apply_shell_style(_menu_shell, C_STATUS, 8, 2)
		Screen.SETTINGS:
			_menu_shell.size = Vector2(440, 250)
			_apply_shell_style(_menu_shell, C_STATUS, 8, 2)
		Screen.DIALOGUE:
			_menu_shell.size = Vector2(856, 146)
			_apply_shell_style(_menu_shell, C_DIVIDER, 8, 2)
		Screen.CHARACTER:
			_menu_shell.size = Vector2(424, 388)
			_apply_shell_style(_menu_shell, C_DIVIDER, 10, 2)
		Screen.HELP, Screen.READER:
			_menu_shell.size = Vector2(872, 416)
			_apply_shell_style(_menu_shell, C_DIVIDER, 10, 2)
		_:
			_menu_shell.size = Vector2(712, 368)
			_apply_shell_style(_menu_shell, C_DIVIDER, 10, 2)
	_menu_shell.position = _centered_shell_pos(_menu_shell.size)


func _centered_shell_pos(shell_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		floor((viewport_size.x - shell_size.x) * 0.5),
		floor((viewport_size.y - shell_size.y) * 0.5)
	)


func _refresh_menu_ui() -> void:
	if _menu_ui_root == null:
		return
	match _screen:
		Screen.ESCAPE:
			_menu_title_label.text = "-=[ PAUSED ]=-"
			var body := ""
			for i in range(ESCAPE_OPTIONS.size()):
				body += ("%s %s\n" % [">" if i == _escape_cursor else " ", ESCAPE_OPTIONS[i]])
			_menu_body_text.text = body
			_menu_footer_label.text = "Enter: select    Esc: resume"
		Screen.SETTINGS:
			_menu_title_label.text = "-=[ SETTINGS ]=-"
			_menu_body_text.text = "a) Auto-pickup items:  %s\nd) Debug tools:        %s\ng) God mode:           %s" % [
				"ON" if GameState.auto_pickup else "OFF",
				"ON" if GameState.debug_tools_enabled else "OFF",
				"ON" if GameState.god_mode else "OFF",
			]
			_menu_footer_label.text = "Esc: back"
		Screen.CHARACTER:
			_menu_title_label.text = "-=[ CHARACTER ]=-"
			var mount = _world.get_player_mount()
			var ranged_weapon = _player.equipped.get(ItemClass.SLOT_RANGED)
			var ranged_str := "none"
			if ranged_weapon != null:
				var ammo = _world.get_matching_ammo(ranged_weapon)
				ranged_str = (ranged_weapon as ItemClass).name
				if ammo != null:
					ranged_str += " [%d]" % (ammo as ItemClass).stack_count()
			_menu_body_text.text = "Name       %s\nClass      %s\nLevel      %d\nXP         %d / %d\nMount      %s\n\nHP         %d / %d\nAttack     1d6+%d\nRanged     %s\nAC         %d\nGold       %d\nCarry      %s / %s\nSTR Carry  %+d lbs.\n\nSTR        %d (%+d)\nDEX        %d (%+d)\nCON        %d (%+d)\nINT        %d (%+d)\nWIS        %d (%+d)\nCHA        %d (%+d)" % [
				GameState.player_name,
				GameState.player_class.capitalize(),
				_player.level,
				_player.xp, _player.xp_to_next,
				mount.name.capitalize() if mount != null else "None",
				_player.hp, _player.max_hp,
				_player.power + _player.total_attack_bonus,
				ranged_str,
				_player.ac,
				_player.gold,
				_format_lbs(_player.total_carry_weight), _format_lbs(_player.max_carry_weight),
				(_player.max_carry_weight - ActorClass.BASE_CARRY_WEIGHT),
				_player.str_score, _player.str_mod,
				_player.dex_score, _player.dex_mod,
				_player.con_score, _player.con_mod,
				_player.int_score, _player.int_mod,
				_player.wis_score, _player.wis_mod,
				_player.cha_score, _player.cha_mod,
			]
			_menu_footer_label.text = "Esc: close"
		Screen.ATTRIBUTE_PICK:
			_menu_title_label.text = "-=[ ATTRIBUTE INCREASE ]=-"
			var attr_body := "Choose an attribute to raise by 1.\nUnspent points: %d\n\n" % _player.unspent_attribute_points
			for opt in ATTRIBUTE_OPTIONS:
				var score: int = int(_player.get("%s_score" % str(opt.code)))
				attr_body += "[%s] %-12s %2d -> %2d\n" % [char(int(opt.key)), str(opt.label), score, score + 1]
			_menu_body_text.text = attr_body
			_menu_footer_label.text = "Press the matching key"
		Screen.DISAMBIGUATE:
			_menu_title_label.text = _disambig_prompt
			var disambig_body := ""
			for i in range(_disambig_options.size()):
				var opt: Dictionary = _disambig_options[i]
				disambig_body += "%s [%s] %s\n" % [
					">" if i == _disambig_cursor else " ",
					char(int(opt.key)) if int(opt.key) >= KEY_A and int(opt.key) <= KEY_Z else "•",
					str(opt.label)
				]
			_menu_body_text.text = disambig_body
			_menu_footer_label.text = "Enter: confirm    Esc: cancel"
		Screen.HELP:
			_menu_title_label.text = "-=[ KEYBINDS ]=-"
			_menu_body_text.text = "MOVEMENT\narrows / numpad  move\nnumpad 7/9/1/3   diagonal move\nnumpad 5 / .     wait one turn\n\nACTIONS\nm  mount / dismount\ng  pick up items\ns  skin/butcher carcass\nt  trade (near merchant)\nf  fire ranged weapon\nShift+dir  force attack\n>  descend / enter\n<  ascend / world map\n\nMENUS\ni  inventory\nc  character sheet\nl  look mode\n?  this help screen\nEsc  pause menu\n\nINVENTORY\n[a-z] use / equip item\n[w/r/b/f/h/u] unequip slot\n\nTRADE\n[a-z] buy item\n[Tab + A-Z] sell item\n\nWORLD MAP\narrows  travel between chunks\nl  toggle look cursor\n>  enter chunk view"
			_menu_footer_label.text = "Any key to close"
		Screen.READER:
			_menu_title_label.text = "-=[ %s ]=-" % (_reader_item.name.to_upper() if _reader_item != null else "READER")
			var visible := _reader_lines.slice(_reader_scroll, _reader_scroll + 18)
			_menu_body_text.text = "\n".join(visible)
			_menu_footer_label.text = "Esc / Space close    Up / Down scroll"
		Screen.DIALOGUE:
			var npc: NpcClass = _dialogue_npc as NpcClass
			_menu_title_label.text = "-=[ %s ]=-" % npc.name.to_upper()
			_menu_body_text.text = _dialogue_line
			_menu_footer_label.text = "[T] Trade    [Any other key] Close" if npc.is_merchant else "[Any key] Close"
		Screen.TRAVEL_EVENT:
			var event_data: Dictionary = _world.pending_travel_event
			_menu_title_label.text = "-=[ %s ]=-" % str(event_data.get("title", "TRAVEL EVENT"))
			var options: Array[String] = ["[E] Enter the chunk"]
			if bool(event_data.get("can_ignore", false)):
				options.append("[I] Ignore and continue")
			if bool(event_data.get("can_flee", false)):
				options.append("[F] Attempt to flee")
			_menu_body_text.text = "%s\n\n%s" % [str(event_data.get("desc", "")), "\n".join(options)]
			_menu_footer_label.text = "Choose an option"


func _refresh_trade_ui() -> void:
	if _trade_ui_root == null or _trade_npc == null:
		return
	var npc: NpcClass = _trade_npc as NpcClass
	_trade_title_label.text = "-=[ TRADE: %s ]=-" % npc.name.capitalize()
	var buy_text := "MERCHANT SELLS\n\n"
	if npc.trade_stock.is_empty():
		buy_text += "Nothing for sale."
	else:
		for i in range(npc.trade_stock.size()):
			var entry: Dictionary = npc.trade_stock[i]
			var sl := char(ord("a") + i)
			var itype := str(entry.get("item_type", ""))
			var qty := int(entry.get("qty", 0))
			var price := int(entry.get("price", 0))
			var marker := ">" if _trade_panel == 0 and i == _trade_buy_cursor else " "
			buy_text += "%s %s) %-18s %3dg  %8s  x%d\n" % [marker, sl, itype.replace("_", " "), price, _format_lbs(_item_weight_for_type(itype)), qty]
	buy_text += "\nGold: %d" % _player.gold
	_trade_buy_text.text = buy_text

	var sell_text := "YOUR PACK\n\n"
	var sellable: Array = _build_sellable()
	if sellable.is_empty():
		sell_text += "Nothing to sell."
	else:
		for i in range(sellable.size()):
			var item = sellable[i]
			var sl := char(ord("A") + i)
			var offer: int = npc.buy_price(item)
			var marker := ">" if _trade_panel == 1 and i == _trade_sell_cursor else " "
			sell_text += "%s %s) %-18s %3dg  %8s\n" % [marker, sl, (item as ItemClass).name, offer, _format_lbs(int((item as ItemClass).total_weight()))]
	_trade_sell_text.text = sell_text

	var hint: String = "[a-z] buy   [Tab] sell panel   [Esc] leave" if _trade_panel == 0 else "[A-Z] sell   [Tab] buy panel   [Esc] leave"
	_trade_footer_label.text = hint


func _refresh_hud_ui() -> void:
	if _hud_ui_root == null or _world == null or _player == null:
		return
	var hp_frac: float = float(_player.hp) / float(_player.max_hp)
	var hp_color := C_STATUS.lerp(Color(0.8, 0.15, 0.05), 1.0 - hp_frac)
	var wpn = _player.equipped.get(ItemClass.SLOT_WEAPON)
	var wpn_str := ("  WPN: %s" % (wpn as ItemClass).name) if wpn != null else ""
	var lit = _player.equipped.get(ItemClass.SLOT_LIGHT)
	var lit_str := ""
	if lit != null:
		var lt := lit as ItemClass
		lit_str = "  LIT: %dt" % lt.value if lt.burn_turns > 0 else "  LIT"
	var mount = _world.get_player_mount()
	var mount_str := ""
	if mount != null:
		mount_str = "  MOUNT: %s" % mount.name
	var move_cost_str := "  MOVE: %s" % _world.get_move_cost_label()
	var cal_str: String = _world.get_calendar_string()
	var sky_str: String = _sky_track()
	var thr_pct: int = int(float(_player.thirst) / float(ActorClass.THIRST_MAX) * 100.0)
	var fat_pct: int = int(float(_player.fatigue) / float(ActorClass.FATIGUE_MAX) * 100.0)
	var thr_str: String = ("  THR: %d%%" % thr_pct) if _floor == 0 else ""
	var fat_str: String = "  FAT: %d%%" % fat_pct
	var floor_label: String = "HUB" if _world.debug_hub_active else str(_floor)
	_hud_status_top.text = "Lvl: %d   HP: %d/%d   ATK: 1d6+%d  AC: %d   Gold: %d   Floor: %s   %s  %s" % [
		_player.level, _player.hp, _player.max_hp, _player.power + _player.total_attack_bonus,
		_player.ac, _player.gold, floor_label, cal_str, sky_str
	]
	_hud_status_top.add_theme_color_override("font_color", hp_color)
	_hud_status_bottom.text = ("%s%s%s%s%s" % [thr_str, fat_str, wpn_str, lit_str, mount_str + move_cost_str]).strip_edges()

	for label in _hud_message_labels:
		label.text = ""
		label.add_theme_color_override("font_color", C_MSG_OLD)

	var hud_lines: Array = []
	if _screen == Screen.LOOK:
		hud_lines = [_look_description(), "l / Esc / Enter to exit look mode"]
	elif _screen == Screen.TARGET:
		hud_lines = [_target_description(), "f / Esc: cancel   arrows: aim   Tab: cycle targets   Enter/click: fire"]
	elif _screen == Screen.WORLD_MAP and _world_look_mode:
		hud_lines = ["%s  [travel %d]" % [_world_map_look_label(), _world.get_world_map_travel_cost(_world_look_cursor)],
			"arrows: move look cursor    l/esc: exit look"]
	else:
		hud_lines = _messages.duplicate()

	for i in range(mini(MSG_LINES, hud_lines.size())):
		var label: Label = _hud_message_labels[i]
		label.text = str(hud_lines[i])
		if _screen == Screen.LOOK or _screen == Screen.TARGET or (_screen == Screen.WORLD_MAP and _world_look_mode):
			label.add_theme_color_override("font_color", C_MSG_RECENT if i == 0 else C_DIVIDER)
		else:
			var is_last: bool = i == hud_lines.size() - 1
			label.add_theme_color_override("font_color", C_MSG_RECENT if is_last else C_MSG_OLD)


func _handle_post_player_action() -> void:
	_open_attribute_overlay_if_needed()
	if _screen == Screen.NONE and _world.nearby_npc != null and not (_world.nearby_npc as NpcClass).is_wildlife:
		_open_dialogue(_world.nearby_npc)


func _wildlife_at_bump(dir: Vector2i):
	if dir == Vector2i.ZERO or _map == null:
		return null
	var next: Vector2i = _player.pos + dir
	if not _map.is_in_bounds(next.x, next.y):
		return null
	var target = _map.get_blocking_entity_at(next.x, next.y)
	if target is NpcClass:
		var npc: NpcClass = target as NpcClass
		if npc.is_alive and npc.is_wildlife and not npc.is_angered:
			return npc
	return null


func _maybe_prompt_wildlife_attack(dir: Vector2i, force_attack: bool) -> bool:
	if force_attack or _screen != Screen.NONE:
		return false
	var npc = _wildlife_at_bump(dir)
	if npc == null:
		return false
	_world.nearby_npc = null
	_disambiguate(
		"Attack %s?" % str((npc as NpcClass).name),
		[
			{"key": KEY_A, "label": "Attack", "callback": Callable(self, "_confirm_wildlife_attack").bind(dir)},
			{"key": KEY_L, "label": "Leave it be", "callback": Callable(self, "_close_disambig_overlay")},
		]
	)
	return true


func _confirm_wildlife_attack(dir: Vector2i) -> void:
	_close_disambig_overlay()
	_world.do_player_turn(dir, true)
	_handle_post_player_action()
	queue_redraw()


func _close_disambig_overlay() -> void:
	_screen = Screen.NONE
	_disambig_prompt = ""
	_disambig_options.clear()
	_disambig_cursor = 0
	queue_redraw()


func _stop_auto_move(message: String = "") -> void:
	_auto_move_mode = AutoMoveMode.NONE
	_auto_move_target = Vector2i.ZERO
	_auto_move_accum = 0.0
	_auto_move_steps_taken = 0
	if not message.is_empty():
		_world.add_msg(message)
	queue_redraw()


func _start_autoexplore() -> void:
	if _screen != Screen.NONE or _game_over:
		return
	if _auto_move_mode != AutoMoveMode.NONE:
		_stop_auto_move("Autoexplore stops.")
		return
	if _world._visible_hostile_exists():
		_world.add_msg("Autoexplore stops: danger is already in sight.")
		queue_redraw()
		return
	if _world._next_autoexplore_step() == Vector2i.ZERO:
		_world.add_msg("There is nothing left to explore.")
		queue_redraw()
		return
	_auto_move_mode = AutoMoveMode.EXPLORE
	_auto_move_accum = 0.0
	_auto_move_steps_taken = 0
	_tick_auto_move()


func _start_travel_to(target: Vector2i) -> void:
	if _screen != Screen.NONE or _game_over:
		return
	if _auto_move_mode != AutoMoveMode.NONE:
		_stop_auto_move()
	if not _map.is_in_bounds(target.x, target.y) or target == _player.pos:
		return
	if _world._visible_hostile_exists():
		_world.add_msg("Travel stops: danger is already in sight.")
		queue_redraw()
		return
	var path: Array = _world._path_to(target, true)
	if path.is_empty():
		_world.add_msg("You cannot find a clear path there.")
		queue_redraw()
		return
	_auto_move_mode = AutoMoveMode.TRAVEL
	_auto_move_target = target
	_auto_move_accum = 0.0
	_auto_move_steps_taken = 0
	_tick_auto_move()


func _tick_auto_move() -> void:
	match _auto_move_mode:
		AutoMoveMode.EXPLORE:
			_tick_autoexplore_step()
		AutoMoveMode.TRAVEL:
			_tick_travel_step()


func _tick_autoexplore_step() -> void:
	if _world._visible_hostile_exists():
		_stop_auto_move("Autoexplore stops: danger is already in sight.")
		return
	var dir: Vector2i = _world._next_autoexplore_step()
	if dir == Vector2i.ZERO:
		_stop_auto_move("Autoexplore complete." if _auto_move_steps_taken > 0 else "There is nothing left to explore.")
		return
	_world.do_player_turn(dir)
	_auto_move_steps_taken += 1
	_after_auto_move_step("Autoexplore")


func _tick_travel_step() -> void:
	if _player.pos == _auto_move_target:
		_stop_auto_move()
		return
	if _world._visible_hostile_exists():
		_stop_auto_move("Travel stops: danger is already in sight.")
		return
	var path: Array = _world._path_to(_auto_move_target, true)
	if path.is_empty():
		_stop_auto_move("You cannot find a clear path there.")
		return
	var next_pos: Vector2i = path[0]
	var dir: Vector2i = next_pos - _player.pos
	if maxi(absi(dir.x), absi(dir.y)) > 1:
		_stop_auto_move("You cannot find a clear path there.")
		return
	_world.do_player_turn(dir)
	_auto_move_steps_taken += 1
	_after_auto_move_step("Travel")
	if _auto_move_mode == AutoMoveMode.TRAVEL and _player.pos == _auto_move_target:
		_stop_auto_move()


func _after_auto_move_step(label: String) -> void:
	_open_attribute_overlay_if_needed()
	if _auto_move_mode == AutoMoveMode.NONE or _screen != Screen.NONE or _game_over:
		return
	if _world._visible_hostile_exists():
		_stop_auto_move("%s stops: danger spotted." % label)
		return


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
	if _world.debug_hub_active or _world.depth > 0:
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
	var should_interrupt_auto_move: bool = false
	if event is InputEventKey:
		should_interrupt_auto_move = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		should_interrupt_auto_move = event.pressed
	if _auto_move_mode != AutoMoveMode.NONE and should_interrupt_auto_move:
		_stop_auto_move()
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return
	if event is InputEventMouseButton and event.pressed:
		_handle_mouse_button(event)
		return
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
		Screen.TARGET:
			_handle_target_input(event)
			return
		Screen.WORLD_MAP:
			_handle_world_map_input(event)
			return
		Screen.TRAVEL_EVENT:
			_handle_travel_event_input(event)
			return
		Screen.ATTRIBUTE_PICK:
			_handle_attribute_pick_input(event)
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

	if event.shift_pressed and event.physical_keycode == KEY_D:
		get_viewport().set_input_as_handled()
		_world.toggle_debug_hub()
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
			KEY_F:
				get_viewport().set_input_as_handled()
				_open_ranged_targeting()
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
			KEY_M:
				get_viewport().set_input_as_handled()
				_world.toggle_mount()
				queue_redraw()
				return
			KEY_X:
				get_viewport().set_input_as_handled()
				_start_autoexplore()
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
				_world.resolve_action()
			return
		_: return

	get_viewport().set_input_as_handled()
	var force_attack: bool = event.shift_pressed and dir != Vector2i.ZERO
	if _maybe_prompt_wildlife_attack(dir, force_attack):
		return
	_world.do_player_turn(dir, force_attack)
	_handle_post_player_action()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var cell := _mouse_cell(event.position)
	var map_pos := Vector2i(cell.x + _cam_x, cell.y + _cam_y)
	var should_highlight: bool = cell.y >= 0 and cell.y < MAP_ROWS and _map != null and _map.is_in_bounds(map_pos.x, map_pos.y)
	if _screen == Screen.NONE:
		_hover_active = should_highlight and _map.explored[map_pos.y][map_pos.x]
		if _hover_active:
			_hover_pos = map_pos
	elif _screen == Screen.WORLD_MAP:
		var chunk := _world_map_chunk_at_pos(event.position)
		if chunk.x >= 0:
			_world_look_cursor = chunk
			queue_redraw()
	elif _screen == Screen.LOOK:
		_hover_active = false
		if should_highlight and _map.explored[map_pos.y][map_pos.x]:
			_look_pos = map_pos
	elif _screen == Screen.TARGET:
		_hover_active = false
		if should_highlight and _map.explored[map_pos.y][map_pos.x]:
			_target_pos = map_pos
	else:
		_hover_active = false
	if _screen == Screen.NONE or _screen == Screen.LOOK or _screen == Screen.TARGET:
		queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		match _screen:
			Screen.TARGET:
				_close_targeting()
				queue_redraw()
				get_viewport().set_input_as_handled()
			Screen.LOOK, Screen.INVENTORY, Screen.CHARACTER, Screen.SETTINGS, Screen.TRADE, Screen.HELP, Screen.READER, Screen.DIALOGUE:
				_screen = Screen.NONE
				queue_redraw()
				get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	match _screen:
		Screen.NONE:
			_handle_map_mouse_click(event.position)
		Screen.LOOK:
			_handle_look_mouse_click(event.position)
		Screen.TARGET:
			_handle_target_mouse_click(event.position)
		Screen.ESCAPE:
			_handle_escape_mouse_click(event.position)
		Screen.SETTINGS:
			_handle_settings_mouse_click(event.position)
		Screen.INVENTORY:
			_handle_inventory_mouse_click(event.position)
		Screen.TRADE:
			_handle_trade_mouse_click(event.position)
		Screen.CHARACTER:
			_handle_character_mouse_click(event.position)
		Screen.HELP:
			_handle_help_mouse_click(event.position)
		Screen.READER:
			_handle_reader_mouse_click(event.position)
		Screen.DIALOGUE:
			_handle_dialogue_mouse_click(event.position)
		Screen.ATTRIBUTE_PICK:
			_handle_attribute_pick_mouse_click(event.position)
		Screen.DISAMBIGUATE:
			_handle_disambig_mouse_click(event.position)
		Screen.WORLD_MAP:
			_handle_world_map_mouse_click(event.position)


func _mouse_cell(mouse_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(mouse_pos.x / CELL_W)), int(floor(mouse_pos.y / CELL_H)))


func _screen_to_map(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x + _cam_x, cell.y + _cam_y)


func _handle_map_mouse_click(mouse_pos: Vector2) -> void:
	var cell := _mouse_cell(mouse_pos)
	if cell.y < 0 or cell.y >= MAP_ROWS:
		return
	var map_pos := _screen_to_map(cell)
	if not _map.is_in_bounds(map_pos.x, map_pos.y) or not _map.explored[map_pos.y][map_pos.x]:
		return

	var delta: Vector2i = map_pos - _player.pos
	if maxi(absi(delta.x), absi(delta.y)) <= 1 and delta != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		var step := Vector2i(clampi(delta.x, -1, 1), clampi(delta.y, -1, 1))
		if _maybe_prompt_wildlife_attack(step, false):
			return
		_world.do_player_turn(step, false)
		_handle_post_player_action()
		return
	get_viewport().set_input_as_handled()
	_start_travel_to(map_pos)
	if _screen == Screen.NONE and _world.nearby_npc != null and not (_world.nearby_npc as NpcClass).is_wildlife:
		_open_dialogue(_world.nearby_npc)
	queue_redraw()


func _handle_look_mouse_click(mouse_pos: Vector2) -> void:
	var cell := _mouse_cell(mouse_pos)
	if cell.y < 0 or cell.y >= MAP_ROWS:
		return
	var map_pos := _screen_to_map(cell)
	if not _map.is_in_bounds(map_pos.x, map_pos.y) or not _map.explored[map_pos.y][map_pos.x]:
		return
	_look_pos = map_pos
	get_viewport().set_input_as_handled()
	queue_redraw()


func _open_ranged_targeting() -> void:
	var weapon = _world.get_equipped_ranged_weapon()
	if weapon == null:
		_world.add_msg("You have no ranged weapon readied.")
		queue_redraw()
		return
	var ammo = _world.get_matching_ammo(weapon)
	if ammo == null:
		_world.add_msg("You have no ammunition for the %s." % (weapon as ItemClass).name)
		queue_redraw()
		return
	_refresh_target_candidates()
	if not _target_candidates.is_empty():
		_target_candidate_index = 0
		_target_pos = (_target_candidates[0] as ActorClass).pos
	else:
		_target_pos = _player.pos + Vector2i(0, -1)
		if _map != null:
			_target_pos.x = clampi(_target_pos.x, 0, _map.width - 1)
			_target_pos.y = clampi(_target_pos.y, 0, _map.height - 1)
	_screen = Screen.TARGET
	_hover_active = false
	_cam_x = clampi(_target_pos.x - (COLS >> 1), 0, _map.width - COLS)
	_cam_y = clampi(_target_pos.y - (MAP_ROWS >> 1), 0, _map.height - MAP_ROWS)
	queue_redraw()


func _refresh_target_candidates() -> void:
	_target_candidates = _world.get_ranged_targets()
	if _target_candidates.is_empty():
		_target_candidate_index = 0
		return
	_target_candidate_index = clampi(_target_candidate_index, 0, _target_candidates.size() - 1)


func _close_targeting() -> void:
	_screen = Screen.NONE
	_target_candidates.clear()
	_target_candidate_index = 0
	_target_pos = Vector2i.ZERO
	_update_camera()
	queue_redraw()


func _cycle_target_candidate(step: int) -> void:
	_refresh_target_candidates()
	if _target_candidates.is_empty():
		return
	_target_candidate_index = wrapi(_target_candidate_index + step, 0, _target_candidates.size())
	_target_pos = (_target_candidates[_target_candidate_index] as ActorClass).pos
	_cam_x = clampi(_target_pos.x - (COLS >> 1), 0, _map.width - COLS)
	_cam_y = clampi(_target_pos.y - (MAP_ROWS >> 1), 0, _map.height - MAP_ROWS)
	queue_redraw()


func _handle_target_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	match event.physical_keycode:
		KEY_ESCAPE, KEY_F:
			_close_targeting()
			return
		KEY_ENTER, KEY_KP_ENTER:
			_world.fire_ranged_at(_target_pos)
			_close_targeting()
			_handle_post_player_action()
			return
		KEY_TAB:
			_cycle_target_candidate(-1 if event.shift_pressed else 1)
			return

	var delta := Vector2i.ZERO
	match event.physical_keycode:
		KEY_KP_8, KEY_UP:    delta = Vector2i(0, -1)
		KEY_KP_2, KEY_DOWN:  delta = Vector2i(0, 1)
		KEY_KP_4, KEY_LEFT:  delta = Vector2i(-1, 0)
		KEY_KP_6, KEY_RIGHT: delta = Vector2i(1, 0)
		KEY_KP_7:            delta = Vector2i(-1, -1)
		KEY_KP_9:            delta = Vector2i(1, -1)
		KEY_KP_1:            delta = Vector2i(-1, 1)
		KEY_KP_3:            delta = Vector2i(1, 1)
		_: return
	_target_pos += delta
	_target_pos.x = clampi(_target_pos.x, 0, _map.width - 1)
	_target_pos.y = clampi(_target_pos.y, 0, _map.height - 1)
	_cam_x = clampi(_target_pos.x - (COLS >> 1), 0, _map.width - COLS)
	_cam_y = clampi(_target_pos.y - (MAP_ROWS >> 1), 0, _map.height - MAP_ROWS)
	queue_redraw()


func _handle_target_mouse_click(mouse_pos: Vector2) -> void:
	var cell := _mouse_cell(mouse_pos)
	if cell.y < 0 or cell.y >= MAP_ROWS:
		return
	var map_pos := _screen_to_map(cell)
	if not _map.is_in_bounds(map_pos.x, map_pos.y) or not _map.explored[map_pos.y][map_pos.x]:
		return
	_target_pos = map_pos
	get_viewport().set_input_as_handled()
	_world.fire_ranged_at(_target_pos)
	_close_targeting()
	_handle_post_player_action()


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


func _handle_escape_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_W := 52
	const BOX_H := 12
	const BOX_X := (COLS - BOX_W) >> 1
	const BOX_Y := (MAP_ROWS - BOX_H) >> 1
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	var idx: int = cell.y - (BOX_Y + 3)
	if idx >= 0 and idx < ESCAPE_OPTIONS.size():
		_escape_cursor = idx
		_confirm_escape()


func _handle_character_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_X := 35
	const BOX_Y := 4
	const BOX_W := 50
	const BOX_H := 24
	var cell := _mouse_cell(mouse_pos)
	if cell.x >= BOX_X and cell.x < BOX_X + BOX_W and cell.y == BOX_Y + BOX_H - 2:
		_screen = Screen.NONE
		queue_redraw()


func _handle_help_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_X := 4
	const BOX_Y := 1
	const BOX_W := 112
	const BOX_H := 33
	var cell := _mouse_cell(mouse_pos)
	if cell.x >= BOX_X and cell.x < BOX_X + BOX_W and cell.y >= BOX_Y and cell.y < BOX_Y + BOX_H:
		_screen = Screen.NONE
		queue_redraw()


func _handle_reader_mouse_click(mouse_pos: Vector2) -> void:
	if _reader_item == null:
		return
	const BOX_X := 6
	const BOX_Y := 3
	const BOX_W := 108
	const BOX_H := 24
	const VISIBLE_LINES := 18
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	if cell.y == BOX_Y + BOX_H - 2:
		_screen = Screen.NONE
		_reader_item = null
		queue_redraw()
		return
	if cell.x >= BOX_X + BOX_W - 4 and cell.y <= BOX_Y + 2 and _reader_scroll > 0:
		_reader_scroll = maxi(0, _reader_scroll - 1)
		queue_redraw()
		return
	var max_scroll: int = maxi(0, _reader_lines.size() - VISIBLE_LINES)
	if cell.x >= BOX_X + BOX_W - 4 and cell.y >= BOX_Y + BOX_H - 3 and _reader_scroll < max_scroll:
		_reader_scroll = mini(_reader_scroll + 1, max_scroll)
		queue_redraw()
		return


func _handle_dialogue_mouse_click(mouse_pos: Vector2) -> void:
	if _dialogue_npc == null:
		return
	const BOX_X := 2
	const BOX_Y := 30
	const BOX_W := 116
	const BOX_H := 9
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	if cell.y == BOX_Y + BOX_H - 2:
		var npc: NpcClass = _dialogue_npc as NpcClass
		if npc.is_merchant and cell.x >= BOX_X + 48 and cell.x <= BOX_X + 58:
			_open_trade(_dialogue_npc)
			return
		if cell.x >= BOX_X + 84 and cell.x <= BOX_X + 96:
			_screen = Screen.NONE
			_dialogue_npc = null
			queue_redraw()
			return
	_dialogue_line = (_dialogue_npc as NpcClass).greet()
	queue_redraw()


func _activate_inventory_item(item) -> void:
	if item.category == ItemClass.CATEGORY_EQUIPMENT:
		var msg: String = _player.equip(item)
		_world.add_msg(msg)
		_screen = Screen.NONE
		_sync_inventory_ui_visibility()
		_world.resolve_action()
	elif item.category == ItemClass.CATEGORY_USABLE:
		var msg: String = item.use(_player)
		if msg != "":
			_world.add_msg(msg)
			_player.inventory.erase(item)
			_screen = Screen.NONE
			_sync_inventory_ui_visibility()
			_world.resolve_action()
	elif item.category == ItemClass.CATEGORY_READABLE:
		_open_reader(item)
	else:
		_refresh_inventory_ui()
		queue_redraw()


func _inventory_item_at_row(row: int):
	var current_row: int = 5
	var section_order := ["weapons", "ammo", "armor", "lights", "consumables", "goods", "tablets", "other"]
	for section_key in section_order:
		var section_items: Array = []
		for item in _player.inventory:
			if _inventory_section_key(item) == section_key:
				section_items.append(item)
		if section_items.is_empty():
			continue
		if row == current_row:
			return null
		current_row += 1
		for item in section_items:
			if row == current_row:
				return item
			current_row += 1
		current_row += 1
	return null


func _handle_inventory_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_X := 2
	const BOX_Y := 1
	const BOX_W := 116
	const BOX_H := 32
	const LEFT_X := BOX_X + 2
	const RIGHT_X := BOX_X + 77
	const RIGHT_W := 35
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	if cell.x >= LEFT_X and cell.x < 73:
		var item = _inventory_item_at_row(cell.y)
		if item != null:
			_activate_inventory_item(item)
			return
	for si in range(6):
		var label_row: int = BOX_Y + 6 + si * 2
		if cell.x >= RIGHT_X and cell.x < RIGHT_X + RIGHT_W and cell.y >= label_row and cell.y <= label_row + 2:
			var slot_key: String = [ItemClass.SLOT_WEAPON, ItemClass.SLOT_RANGED, ItemClass.SLOT_BODY, ItemClass.SLOT_FEET, ItemClass.SLOT_HEAD, ItemClass.SLOT_LIGHT][si]
			var msg: String = _player.unequip(slot_key)
			if msg != "":
				_world.add_msg(msg)
				queue_redraw()
			return


func _handle_inventory_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE or (key == KEY_I and not event.shift_pressed):
		_screen = Screen.NONE
		_sync_inventory_ui_visibility()
		queue_redraw()
		return

	# w/b/f/h/l — unequip slot (unshifted only).
	if not event.shift_pressed:
		var unequip_slot := ""
		match key:
			KEY_W: unequip_slot = ItemClass.SLOT_WEAPON
			KEY_R: unequip_slot = ItemClass.SLOT_RANGED
			KEY_B: unequip_slot = ItemClass.SLOT_BODY
			KEY_F: unequip_slot = ItemClass.SLOT_FEET
			KEY_H: unequip_slot = ItemClass.SLOT_HEAD
			KEY_U: unequip_slot = ItemClass.SLOT_LIGHT
		if unequip_slot != "":
			var msg: String = _player.unequip(unequip_slot)
			if msg != "":
				_world.add_msg(msg)
				_refresh_inventory_ui()
				queue_redraw()
			return

	# a–t — use / equip / read depending on item category (unshifted only).
	if not event.shift_pressed and key >= KEY_A and key <= KEY_Z:
		var idx: int = key - KEY_A
		var display_items: Array = _inventory_display_items()
		if idx < display_items.size():
			_activate_inventory_item(display_items[idx])


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
	if _dialogue_npc == null:
		_screen = Screen.NONE
		queue_redraw()
		return
	if event.physical_keycode == KEY_T and (_dialogue_npc as NpcClass).is_merchant:
		_open_trade(_dialogue_npc)
		return
	_screen = Screen.NONE
	_dialogue_npc = null
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
			KEY_D:
				GameState.debug_tools_enabled = not GameState.debug_tools_enabled
				queue_redraw()
			KEY_G:
				GameState.god_mode = not GameState.god_mode
				queue_redraw()


func _handle_settings_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_W := 54
	const BOX_H := 13
	const BOX_X := (COLS - BOX_W) >> 1
	const BOX_Y := (MAP_ROWS - BOX_H) >> 1
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	match cell.y:
		BOX_Y + 3:
			GameState.auto_pickup = not GameState.auto_pickup
		BOX_Y + 4:
			GameState.debug_tools_enabled = not GameState.debug_tools_enabled
		BOX_Y + 5:
			GameState.god_mode = not GameState.god_mode
		_:
			return
	queue_redraw()


func _handle_attribute_pick_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_X := 34
	const BOX_Y := 13
	const BOX_W := 52
	const BOX_H := 14
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	for i in range(ATTRIBUTE_OPTIONS.size()):
		if cell.y == BOX_Y + 5 + i:
			var opt: Dictionary = ATTRIBUTE_OPTIONS[i]
			if _world.apply_attribute_increase(str(opt.code)):
				_open_attribute_overlay_if_needed()
				queue_redraw()
			return


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
	for e in _map.get_entities_at(x, y):
		if e == _player:
			names.append("you")
		elif e is ActorClass and e.is_mounted:
			names.append("%s (mounted)" % e.name)
		else:
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
	_disambig_prompt  = prompt
	_disambig_options = options
	_disambig_cursor  = 0
	_screen           = Screen.DISAMBIGUATE
	queue_redraw()


func _handle_disambig_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		_close_disambig_overlay()
		return
	match event.physical_keycode:
		KEY_UP, KEY_LEFT:
			_disambig_cursor = wrapi(_disambig_cursor - 1, 0, _disambig_options.size())
			queue_redraw()
			return
		KEY_DOWN, KEY_RIGHT, KEY_TAB:
			_disambig_cursor = wrapi(_disambig_cursor + 1, 0, _disambig_options.size())
			queue_redraw()
			return
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _disambig_options.is_empty():
				var selected: Dictionary = _disambig_options[_disambig_cursor]
				(selected.callback as Callable).call()
			return
	for opt: Dictionary in _disambig_options:
		if event.physical_keycode == int(opt.key):
			(opt.callback as Callable).call()
			return


func _handle_disambig_mouse_click(mouse_pos: Vector2) -> void:
	const PAD := 3
	var box_w: int = 44
	for opt: Dictionary in _disambig_options:
		var w: int = (opt.label as String).length() + 10
		if w > box_w:
			box_w = w
	var box_h: int = _disambig_options.size() + 6
	var box_x: int = (COLS - box_w) >> 1
	var box_y: int = (MAP_ROWS - box_h) >> 1
	var cell := _mouse_cell(mouse_pos)
	if cell.x < box_x or cell.x >= box_x + box_w or cell.y < box_y or cell.y >= box_y + box_h:
		return
	for i in range(_disambig_options.size()):
		if cell.y == box_y + 3 + i:
			_disambig_cursor = i
			var selected: Dictionary = _disambig_options[i]
			(selected.callback as Callable).call()
			return
	if cell.y == box_y + box_h - 2:
		_close_disambig_overlay()


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


func _handle_attribute_pick_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	for opt: Dictionary in ATTRIBUTE_OPTIONS:
		if event.physical_keycode == int(opt.key):
			if _world.apply_attribute_increase(str(opt.code)):
				_open_attribute_overlay_if_needed()
				queue_redraw()
			return


# ===========================================================================
# Rendering
# ===========================================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_BG)
	if _screen == Screen.WORLD_MAP or _screen == Screen.TRAVEL_EVENT:
		_draw_world_map()
		_draw_ui()
		return
	_draw_map()
	_draw_entities()
	if _screen == Screen.NONE:
		_draw_hover_cursor()
	_draw_ui()
	match _screen:
		Screen.ESCAPE:       pass
		Screen.INVENTORY:    pass
		Screen.CHARACTER:    pass
		Screen.SETTINGS:     pass
		Screen.LOOK:         _draw_look_cursor()
		Screen.TARGET:       _draw_target_cursor()
		Screen.ATTRIBUTE_PICK: pass
		Screen.TRADE:        pass
		Screen.DISAMBIGUATE: pass
		Screen.HELP:         pass
		Screen.READER:       pass
		Screen.DIALOGUE:     pass


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
		if not _on_screen(e.pos.x, e.pos.y) or not _map.visible[e.pos.y][e.pos.x]:
			continue
		var sp := _to_screen(e.pos.x, e.pos.y)
		if not cell_map.has(sp):
			cell_map[sp] = []
		(cell_map[sp] as Array).append(e)

	for sp in cell_map:
		var e = _display_entity_for_cell(cell_map[sp] as Array)
		if e == null:
			continue
		draw_rect(Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H), C_BG)
		_put(sp.x, sp.y, e.char as String, e.color * _day_tint)


func _display_entity_for_cell(entities_on_cell: Array):
	var mounted_player_stack: Array = []
	for e in entities_on_cell:
		if e == _player or (e is ActorClass and e.is_mounted):
			mounted_player_stack.append(e)
	if mounted_player_stack.size() >= 2:
		for e in mounted_player_stack:
			if e != _player and e is ActorClass and e.is_mounted:
				return e if (_mount_cycle_bucket % 2 == 0) else _player

	var best = null
	var best_priority: int = -1
	for e in entities_on_cell:
		var priority: int = 0
		if e is ActorClass:
			priority = 2 if e.is_alive else 1
		if priority >= best_priority:
			best_priority = priority
			best = e
	return best


func _draw_ui() -> void:
	return


func _sky_track() -> String:
	const TRACK_LEN: int = 19
	var t: float = _world.time_of_day
	var is_night: bool = _world.is_night
	var body: String = "o" if is_night else "*"
	var travel_t: float
	if is_night:
		travel_t = t / 0.20 if t < 0.20 else (t - 0.80) / 0.20
	else:
		travel_t = (t - 0.20) / 0.60
	travel_t = clampf(travel_t, 0.0, 1.0)
	var pos: int = int(round(travel_t * float(TRACK_LEN - 1)))
	var track := ""
	for i in range(TRACK_LEN):
		track += body if i == pos else "-"
	return "[%s]" % track


func _target_description() -> String:
	var weapon = _world.get_equipped_ranged_weapon()
	if weapon == null:
		return "No ranged weapon readied."
	var ammo = _world.get_matching_ammo(weapon)
	var range_str := "range %d" % int((weapon as ItemClass).ranged_range)
	var ammo_str := "no ammo"
	if ammo != null:
		ammo_str = "%s %s" % [(ammo as ItemClass).name, (ammo as ItemClass).stack_label()]
		ammo_str = ammo_str.strip_edges()
	var target = _world._first_actor_on_line(_player.pos, _target_pos)
	var target_str := "empty ground"
	if target != null:
		target_str = "%s (%d/%d HP)" % [target.name, target.hp, target.max_hp]
	return "Aim %s using %s [%s, %s]." % [target_str, (weapon as ItemClass).name, ammo_str, range_str]


func _world_map_look_label() -> String:
	var village: Variant = _world.get_village_at_chunk(_world_look_cursor.x, _world_look_cursor.y)
	if village != null:
		return str(village.name)
	return _biome_name(_world.get_chunk_biome(_world_look_cursor))


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
	const BOX_H := 13
	const BOX_X := (COLS - BOX_W) >> 1
	const BOX_Y := (MAP_ROWS - BOX_H) >> 1

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ SETTINGS ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y + 1, title, C_STATUS)

	var ap_val  := "ON " if GameState.auto_pickup else "OFF"
	var dbg_val := "ON " if GameState.debug_tools_enabled else "OFF"
	var god_val := "ON " if GameState.god_mode    else "OFF"
	_puts(BOX_X + 2, BOX_Y + 3, "a) Auto-pickup items:  %s" % ap_val,  C_MSG_RECENT)
	_puts(BOX_X + 2, BOX_Y + 4, "d) Debug tools:        %s" % dbg_val,
		Color(0.72, 0.88, 1.0) if GameState.debug_tools_enabled else C_MSG_RECENT)
	_puts(BOX_X + 2, BOX_Y + 5, "g) God mode:           %s" % god_val,
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
	const LEFT_X := BOX_X + 2
	const RIGHT_X := BOX_X + 77
	const LEFT_W := 70
	const RIGHT_W := 35

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ INVENTORY ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)
	for dy in range(2, BOX_H - 1):
		_puts(BOX_X + 73, BOX_Y + dy, "|", C_DIVIDER)

	# Left panel: grouped inventory list, closer to a classic roguelike gear view.
	var load_header := "PACK"
	var load_value := "[%s / %s]" % [_format_lbs(_player.total_carry_weight), _format_lbs(_player.max_carry_weight)]
	_puts(LEFT_X, BOX_Y + 2, load_header, C_STATUS)
	_puts(LEFT_X + LEFT_W - load_value.length(), BOX_Y + 2, load_value, C_STATUS)

	var section_order := ["weapons", "ammo", "armor", "lights", "consumables", "goods", "tablets", "other"]
	var section_items: Dictionary = {}
	for section_key in section_order:
		section_items[section_key] = []
	for item in _player.inventory:
		var section_key := _inventory_section_key(item)
		(section_items[section_key] as Array).append(item)

	var row: int = BOX_Y + 4
	var next_letter_ord: int = ord("a")
	for section_key in section_order:
		var items: Array = section_items[section_key]
		if items.is_empty():
			continue
		var section_weight: int = 0
		for item in items:
			section_weight += int(item.total_weight())
		var section_label := "[-] %s" % _inventory_section_title(section_key)
		var section_value := "[%s]" % _format_lbs(section_weight)
		_puts(LEFT_X, row, section_label, C_STATUS)
		_puts(LEFT_X + LEFT_W - section_value.length(), row, section_value, C_STATUS)
		row += 1

		for item in items:
			if row >= BOX_Y + BOX_H - 3:
				break
			var letter := "?"
			if next_letter_ord <= ord("z"):
				letter = char(next_letter_ord)
			var detail: String = _inventory_item_detail(item)
			var item_name: String = item.name
			if item.stack_label() != "":
				item_name += " %s" % item.stack_label()
			var detail_col: String = "%-16s" % detail if not detail.is_empty() else "                "
			var weight_col := "[%s]" % item.weight_label()
			_puts(LEFT_X + 2, row,
				"%s) %-24s %s %s" % [letter, item_name.left(24), detail_col, weight_col],
				C_MSG_RECENT)
			next_letter_ord += 1
			row += 1
		row += 1

	if _player.inventory.is_empty():
		_puts(LEFT_X, BOX_Y + 5, "Your pack is empty.", C_MSG_OLD)

	# Bottom-left summary block.
	_puts(LEFT_X, BOX_Y + BOX_H - 6, "Carry: %s / %s" %
		[_format_lbs(_player.total_carry_weight), _format_lbs(_player.max_carry_weight)], C_MSG_RECENT)
	_puts(LEFT_X, BOX_Y + BOX_H - 5, "STR bonus: %+d lbs." %
		(_player.max_carry_weight - ActorClass.BASE_CARRY_WEIGHT), C_MSG_RECENT)
	_puts(LEFT_X, BOX_Y + BOX_H - 4, "Gold: %d" % _player.gold, C_GOLD)

	# Right panel: equipment only.
	_puts(RIGHT_X, BOX_Y + 2, "LOADOUT", C_STATUS)
	_puts(RIGHT_X, BOX_Y + 4, "EQUIPPED", C_STATUS)
	var slot_rows: Array = [
		[ItemClass.SLOT_WEAPON, "w) WEAPON"],
		[ItemClass.SLOT_RANGED, "r) RANGED"],
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
			var bonus_str := _inventory_item_detail(eq_item)
			var weight_str := "[%s]" % eq_item.weight_label()
			_puts(RIGHT_X, BOX_Y + 6 + si * 2,
				"%s" % s_lbl, C_STATUS)
			_puts(RIGHT_X + 2, BOX_Y + 7 + si * 2, eq_item.name.left(18), C_MSG_RECENT)
			_puts(RIGHT_X + RIGHT_W - weight_str.length(), BOX_Y + 7 + si * 2, weight_str, C_MSG_RECENT)
			if not bonus_str.is_empty():
				_puts(RIGHT_X + 2, BOX_Y + 8 + si * 2, bonus_str.left(RIGHT_W - 4), C_MSG_OLD)
		else:
			_puts(RIGHT_X, BOX_Y + 6 + si * 2, "%s" % s_lbl, C_STATUS)
			_puts(RIGHT_X + 2, BOX_Y + 7 + si * 2, "-", C_MSG_OLD)

	var left_hint := "[a-z] use / equip / read"
	var right_hint := "[w/r/b/f/h/u] unequip  [Esc] close"
	_puts(LEFT_X + ((LEFT_W - left_hint.length()) >> 1), BOX_Y + BOX_H - 2, left_hint, C_DIVIDER)
	_puts(RIGHT_X + ((RIGHT_W - right_hint.length()) >> 1), BOX_Y + BOX_H - 2, right_hint, C_DIVIDER)


# ---------------------------------------------------------------------------
# Overlay: character sheet
# ---------------------------------------------------------------------------
func _draw_character_sheet() -> void:
	const BOX_X := 35
	const BOX_Y := 4
	const BOX_W := 50
	const BOX_H := 24

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.80))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ CHARACTER ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)

	var r := BOX_Y + 2
	_stat_line(BOX_X + 4, r, "Name",  GameState.player_name);                       r += 1
	_stat_line(BOX_X + 4, r, "Class", GameState.player_class.capitalize());          r += 1
	_stat_line(BOX_X + 4, r, "Level", str(_player.level));                           r += 1
	_stat_line(BOX_X + 4, r, "XP",    "%d / %d" % [_player.xp, _player.xp_to_next]); r += 1
	var mount = _world.get_player_mount()
	_stat_line(BOX_X + 4, r, "Mount", mount.name.capitalize() if mount != null else "None"); r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "Floor", "HUB" if _world.debug_hub_active else str(_floor)); r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "HP",    "%d / %d" % [_player.hp, _player.max_hp]);    r += 1
	var atk_total: int = _player.power + _player.total_attack_bonus
	var atk_str := "1d6+%d" % atk_total
	if _player.total_attack_bonus > 0:
		atk_str += "  (+%d from gear)" % _player.total_attack_bonus
	_stat_line(BOX_X + 4, r, "Attack", atk_str); r += 1
	var ranged_weapon = _player.equipped.get(ItemClass.SLOT_RANGED)
	var ranged_str := "none"
	if ranged_weapon != null:
		var ammo = _world.get_matching_ammo(ranged_weapon)
		var ammo_suffix := ""
		if ammo != null:
			ammo_suffix = "  [%d]" % (ammo as ItemClass).stack_count()
		ranged_str = "%s  1d6+%d%s" % [(ranged_weapon as ItemClass).name, _player.dex_mod + _player.total_ranged_bonus, ammo_suffix]
	_stat_line(BOX_X + 4, r, "Ranged", ranged_str); r += 1
	var ac_str := str(_player.ac)
	if _player.total_defense_bonus > 0:
		ac_str += "  (+%d from gear)" % _player.total_defense_bonus
	_stat_line(BOX_X + 4, r, "AC", ac_str); r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "Gold", str(_player.gold), C_GOLD); r += 1
	_stat_line(BOX_X + 4, r, "Carry",
		"%s / %s" % [_format_lbs(_player.total_carry_weight), _format_lbs(_player.max_carry_weight)]); r += 1
	_stat_line(BOX_X + 4, r, "STR Carry",
		"%+d lbs." % (_player.max_carry_weight - ActorClass.BASE_CARRY_WEIGHT)); r += 1
	r += 1
	_stat_line(BOX_X + 4, r, "STR", "%d (%+d)" % [_player.str_score, _player.str_mod]); r += 1
	_stat_line(BOX_X + 4, r, "DEX", "%d (%+d)" % [_player.dex_score, _player.dex_mod]); r += 1
	_stat_line(BOX_X + 4, r, "CON", "%d (%+d)" % [_player.con_score, _player.con_mod]); r += 1
	_stat_line(BOX_X + 4, r, "INT", "%d (%+d)" % [_player.int_score, _player.int_mod]); r += 1
	_stat_line(BOX_X + 4, r, "WIS", "%d (%+d)" % [_player.wis_score, _player.wis_mod]); r += 1
	_stat_line(BOX_X + 4, r, "CHA", "%d (%+d)" % [_player.cha_score, _player.cha_mod]); r += 1

	var hint := "[Esc] close"
	_puts(BOX_X + ((BOX_W - hint.length()) >> 1), BOX_Y + BOX_H - 2, hint, C_DIVIDER)


func _draw_attribute_pick_overlay() -> void:
	const BOX_X := 34
	const BOX_Y := 13
	const BOX_W := 52
	const BOX_H := 14

	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W, ROWS * CELL_H)), Color(0, 0, 0, 0.84))
	draw_rect(Rect2(BOX_X * CELL_W, BOX_Y * CELL_H, BOX_W * CELL_W, BOX_H * CELL_H), C_BG)
	_draw_box(BOX_X, BOX_Y, BOX_W, BOX_H)

	var title := "-=[ ATTRIBUTE INCREASE ]=-"
	_puts(BOX_X + ((BOX_W - title.length()) >> 1), BOX_Y, title, C_STATUS)
	_puts(BOX_X + 4, BOX_Y + 2, "Choose an attribute to raise by 1.", C_MSG_RECENT)
	_puts(BOX_X + 4, BOX_Y + 3, "Unspent points: %d" % _player.unspent_attribute_points, C_STATUS)

	for i in range(ATTRIBUTE_OPTIONS.size()):
		var opt: Dictionary = ATTRIBUTE_OPTIONS[i]
		var score: int = int(_player.get("%s_score" % str(opt.code)))
		_puts(BOX_X + 4, BOX_Y + 5 + i,
			"[%s] %-12s %2d -> %2d" % [char(int(opt.key)), str(opt.label), score, score + 1],
			C_MSG_RECENT)


# ---------------------------------------------------------------------------
# Overlay: look mode
# ---------------------------------------------------------------------------
func _draw_look_cursor() -> void:
	var sp := _to_screen(_look_pos.x, _look_pos.y)
	draw_rect(
		Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H),
		Color(0.20, 0.75, 0.90, 0.40)
	)


func _draw_target_cursor() -> void:
	if not _on_screen(_target_pos.x, _target_pos.y):
		return
	for point in _world._bresenham_line(_player.pos, _target_pos):
		if point == _player.pos or not _on_screen(point.x, point.y):
			continue
		var line_sp := _to_screen(point.x, point.y)
		draw_rect(
			Rect2(line_sp.x * CELL_W, line_sp.y * CELL_H, CELL_W, CELL_H),
			Color(0.80, 0.20, 0.10, 0.14)
		)
	var sp := _to_screen(_target_pos.x, _target_pos.y)
	draw_rect(
		Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H),
		Color(0.92, 0.28, 0.12, 0.42)
	)


func _draw_hover_cursor() -> void:
	if not _hover_active or not _on_screen(_hover_pos.x, _hover_pos.y):
		return
	var sp := _to_screen(_hover_pos.x, _hover_pos.y)
	draw_rect(
		Rect2(sp.x * CELL_W, sp.y * CELL_H, CELL_W, CELL_H),
		Color(0.85, 0.72, 0.20, 0.24)
	)


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
		var prefix: String = "> " if i == _disambig_cursor else "  "
		var color: Color = C_STATUS if i == _disambig_cursor else C_MSG_RECENT
		_puts(box_x + PAD, box_y + 3 + i,
			"%s[%s]  %s" % [prefix, arrow, str(opt.label)], color)

	_puts(box_x + ((box_w - 25) >> 1), box_y + box_h - 2, "[Enter] confirm  [Esc] cancel", C_DIVIDER)


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
	_help_row(COL1, r, "m",           "mount / dismount");       r += 1
	_help_row(COL1, r, "g",           "pick up items");           r += 1
	_help_row(COL1, r, "s",           "skin/butcher carcass");    r += 1
	_help_row(COL1, r, "t",           "trade (near merchant)");   r += 1
	_help_row(COL1, r, "f",           "fire ranged weapon");      r += 1
	_help_row(COL1, r, "Shift+dir",   "force attack (any NPC)");  r += 1
	_help_row(COL1, r, ">",           "descend / enter");         r += 1
	_help_row(COL1, r, "<",           "ascend / world map");      r += 1

	# Column 2 — Menus
	r = BOX_Y + 2
	_puts(COL2, r, "MENUS", C_STATUS); r += 1
	_help_row(COL2, r, "i",    "inventory");        r += 1
	_help_row(COL2, r, "c",    "character sheet");  r += 1
	_help_row(COL2, r, "l",    "look mode");        r += 1
	_help_row(COL2, r, "Shift+D", "debug hub");     r += 1
	_help_row(COL2, r, "?",    "this help screen"); r += 1
	_help_row(COL2, r, "Esc",  "pause menu");       r += 1
	r += 1
	_puts(COL2, r, "INVENTORY", C_STATUS); r += 1
	_help_row(COL2, r, "a-z",    "use / equip item"); r += 1
	_help_row(COL2, r, "w/r/b/f/h/u","unequip slot");   r += 1
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
		hint = "[Any key] Close"
	else:
		hint = "[T] Trade   [Any other key] Close"
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
			var weight := _item_weight_for_type(itype)
			var color := C_STATUS if (_trade_panel == 0 and i == _trade_buy_cursor) else C_MSG_RECENT
			_puts(BUY_X, BOX_Y + 4 + i,
				"%s) %-16s %3dg %8s (x%d)" % [sl, itype.replace("_", " "), price, _format_lbs(weight), qty], color)

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
				"%s) %-16s %3dg %8s" % [sl, (item as ItemClass).name, offer, _format_lbs(int((item as ItemClass).total_weight()))], color)

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


func _item_weight_for_type(item_type: String) -> int:
	return int(ItemClass.new(Vector2i.ZERO, item_type, 0).total_weight())


func _format_lbs(weight: int) -> String:
	return "%d lbs." % weight


func _inventory_section_key(item) -> String:
	if item.category == ItemClass.CATEGORY_EQUIPMENT:
		match item.slot:
			ItemClass.SLOT_WEAPON, ItemClass.SLOT_RANGED:
				return "weapons"
			ItemClass.SLOT_BODY, ItemClass.SLOT_FEET, ItemClass.SLOT_HEAD:
				return "armor"
			ItemClass.SLOT_LIGHT:
				return "lights"
	if item.category == ItemClass.CATEGORY_AMMO:
		return "ammo"
	if item.category == ItemClass.CATEGORY_USABLE:
		return "consumables"
	if item.category == ItemClass.CATEGORY_TRADE:
		return "goods"
	if item.category == ItemClass.CATEGORY_READABLE:
		return "tablets"
	return "other"


func _inventory_section_title(section_key: String) -> String:
	match section_key:
		"weapons": return "WEAPONS"
		"ammo": return "AMMUNITION"
		"armor": return "ARMOR"
		"lights": return "LIGHT SOURCES"
		"consumables": return "CONSUMABLES"
		"goods": return "TRADE GOODS"
		"tablets": return "TABLETS"
		_: return "OTHER"


func _inventory_item_detail(item) -> String:
	if item.category == ItemClass.CATEGORY_EQUIPMENT:
		if item.slot == ItemClass.SLOT_RANGED:
			return "%+d atk  %s  rng %d" % [item.attack_bonus, item.ammo_type.replace("_", " "), item.ranged_range]
		if item.attack_bonus > 0:
			return "+%d atk" % item.attack_bonus
		if item.defense_bonus > 0:
			return "+%d def" % item.defense_bonus
		if item.slot == ItemClass.SLOT_LIGHT and item.burn_turns > 0:
			return "%dt left" % item.value
		return "equip"
	if item.category == ItemClass.CATEGORY_USABLE:
		return item.dice_label()
	if item.category == ItemClass.CATEGORY_AMMO:
		return "ammo"
	if item.category == ItemClass.CATEGORY_READABLE:
		return "read"
	if item.category == ItemClass.CATEGORY_TRADE and item.base_value > 0:
		return "%dg" % item.base_value
	return ""


func _inventory_display_items() -> Array:
	var ordered: Array = []
	var section_order := ["weapons", "ammo", "armor", "lights", "consumables", "goods", "tablets", "other"]
	for section_key in section_order:
		for item in _player.inventory:
			if _inventory_section_key(item) == section_key:
				ordered.append(item)
	return ordered


func _trade_buy(idx: int) -> void:
	if _trade_npc == null:
		return
	var npc: NpcClass = _trade_npc as NpcClass
	if idx < 0 or idx >= npc.trade_stock.size():
		return
	var entry: Dictionary = npc.trade_stock[idx]
	var price: int = int(entry.get("price", 0))
	var qty: int = int(entry.get("qty", 0))
	var itype: String = str(entry.get("item_type", ""))
	if qty <= 0:
		_world.add_msg("The %s has no more %s." % [npc.name, itype.replace("_", " ")])
	elif _player.gold < price:
		_world.add_msg("You cannot afford that. (need %dg)" % price)
	else:
		var new_item := ItemClass.new(Vector2i(0, 0), itype, 0)
		if not _player.can_carry(new_item):
			_world.add_msg("That %s is too heavy for your current load." % new_item.name)
			return
		_player.gold -= price
		entry["qty"] = qty - 1
		_player.inventory.append(new_item)
		_world.add_msg("You buy %s for %dg." % [itype.replace("_", " "), price])
	queue_redraw()


func _trade_sell(idx: int) -> void:
	if _trade_npc == null:
		return
	var npc: NpcClass = _trade_npc as NpcClass
	var sellable: Array = _build_sellable()
	if idx < 0 or idx >= sellable.size():
		return
	var item = sellable[idx]
	var offer: int = npc.buy_price(item)
	_player.gold += offer
	_player.inventory.erase(item)
	_world.add_msg("You sell the %s for %dg." % [(item as ItemClass).name, offer])
	queue_redraw()


func _handle_trade_mouse_click(mouse_pos: Vector2) -> void:
	const BOX_X := 2
	const BOX_Y := 1
	const BOX_W := 116
	const BOX_H := 32
	const BUY_X := BOX_X + 2
	const SELL_X := BOX_X + 60
	var cell := _mouse_cell(mouse_pos)
	if cell.x < BOX_X or cell.x >= BOX_X + BOX_W or cell.y < BOX_Y or cell.y >= BOX_Y + BOX_H:
		return
	if cell.x < BOX_X + 57:
		var buy_idx: int = cell.y - (BOX_Y + 4)
		if buy_idx >= 0:
			_trade_panel = 0
			_trade_buy_cursor = buy_idx
			_trade_buy(buy_idx)
			return
	elif cell.x >= SELL_X:
		var sell_idx: int = cell.y - (BOX_Y + 4)
		if sell_idx >= 0:
			_trade_panel = 1
			_trade_sell_cursor = sell_idx
			_trade_sell(sell_idx)
			return


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
		_trade_buy(idx)
		return

	# Sell panel: Tab is active, shift+letter
	if _trade_panel == 1 and event.shift_pressed and key >= KEY_A and key <= KEY_Z:
		var idx: int = key - KEY_A
		_trade_sell(idx)
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
	var title_str := "-=[ WORLD MAP - LOOK ]=-" if _world_look_mode else "-=[ WORLD MAP ]=-"
	_puts_centered(0, title_str, C_STATUS)
	var world_move_hint := "Chunk Travel: %d" % _world.get_world_map_travel_cost(_chunk)
	_puts(COLS - world_move_hint.length() - 2, 0, world_move_hint, C_DIVIDER)
	var mount = _world.get_player_mount()
	var current_chunk_char: String = "@"
	var current_chunk_color: Color = Color(0.80, 0.72, 0.55)
	if mount != null and (_mount_cycle_bucket % 2 == 0):
		current_chunk_char = mount.char as String
		current_chunk_color = mount.color
	elif mount != null:
		current_chunk_color = Color(0.95, 0.80, 0.40)

	var map_px_w: float = COLS * CELL_W
	var map_px_y: float = CELL_H * 2.0
	var map_px_h: float = MAP_ROWS * CELL_H - map_px_y
	var cell_w: float = map_px_w / float(GameState.WORLD_W)
	var cell_h: float = map_px_h / float(GameState.WORLD_H)

	for cy in range(GameState.WORLD_H):
		for cx in range(GameState.WORLD_W):
			var this_chunk := Vector2i(cx, cy)
			var px: float = cx * cell_w
			var py: float = map_px_y + cy * cell_h
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
				ch    = current_chunk_char
				color = Color(0.95, 0.80, 0.40) if is_lk_curs else current_chunk_color

			var cell_bg: Color = color.lerp(C_BG, 0.70)
			if is_lk_curs:
				cell_bg = Color(0.20, 0.16, 0.10, 0.96)
			elif is_current:
				cell_bg = Color(0.17, 0.13, 0.08, 0.92)

			var cell_rect := Rect2(px, py, cell_w, cell_h)
			draw_rect(cell_rect, cell_bg)
			if is_lk_curs:
				draw_rect(cell_rect, Color(0.85, 0.70, 0.32, 0.18), false, 2.0)
			elif is_current:
				draw_rect(cell_rect, Color(0.78, 0.62, 0.22, 0.12), false, 1.0)
			var baseline_y: float = py + cell_h * 0.60
			draw_string(_font, Vector2(px, baseline_y), ch,
					HORIZONTAL_ALIGNMENT_CENTER, cell_w, UI_FONT_SIZE, color)


func _world_map_chunk_at_pos(mouse_pos: Vector2) -> Vector2i:
	var map_px_w: float = COLS * CELL_W
	var map_px_y: float = CELL_H * 2.0
	var map_px_h: float = MAP_ROWS * CELL_H - map_px_y
	if mouse_pos.y < map_px_y or mouse_pos.y >= map_px_y + map_px_h:
		return Vector2i(-1, -1)
	var cx: int = clampi(int(floor(mouse_pos.x / (map_px_w / float(GameState.WORLD_W)))), 0, GameState.WORLD_W - 1)
	var cy: int = clampi(int(floor((mouse_pos.y - map_px_y) / (map_px_h / float(GameState.WORLD_H)))), 0, GameState.WORLD_H - 1)
	return Vector2i(cx, cy)


func _handle_world_map_mouse_click(mouse_pos: Vector2) -> void:
	var chunk := _world_map_chunk_at_pos(mouse_pos)
	if chunk.x < 0:
		return
	_world_look_cursor = chunk
	if _world_look_mode:
		queue_redraw()
		return
	var delta: Vector2i = chunk - _chunk
	if delta == Vector2i.ZERO:
		_screen = Screen.NONE
		_update_camera()
		_map.compute_fov(_player.pos.x, _player.pos.y, GameWorldClass.FOV_OVERWORLD)
		queue_redraw()
		return
	delta.x = clampi(delta.x, -1, 1)
	delta.y = clampi(delta.y, -1, 1)
	_world.world_map_navigate(delta)
	if _world.has_pending_travel_event():
		_screen = Screen.TRAVEL_EVENT
	queue_redraw()



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
