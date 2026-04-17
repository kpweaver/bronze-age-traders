extends Node2D

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
const GameMapClass = preload("res://scripts/map/game_map.gd")
const ActorClass   = preload("res://scripts/entities/actor.gd")
const ItemClass    = preload("res://scripts/entities/item.gd")
const NpcClass     = preload("res://scripts/entities/npc.gd")
const GameWorldClass = preload("res://scripts/game_world.gd")
const ModulateTileMapLayerClass = preload("res://scripts/render/modulate_tile_map_layer.gd")

# ---------------------------------------------------------------------------
# Display constants  (viewport: 1080Ã—720, cell: 9Ã—14 â†’ 120Ã—51 tiles)
# ---------------------------------------------------------------------------
const COLS: int = 120
const ROWS: int = 51
const FONT_SIZE: int    = 14   # map tile glyphs
const UI_FONT_SIZE: int = 16   # overlay / status bar text
const CELL_W: float = 9.0
const CELL_H: float = 14.0
const TILESET_ENABLED := true
const TILESET_PATH := "res://assets/tilesets/CGA8x8thick_mask_centered.png"
const ASCII_ATLAS_PATH := "res://assets/fonts/Px437_IBM_BIOS_cp437_8x8_atlas.png"
const TILESET_COLS := 16
const TILESET_ROWS := 16
const TILESET_TILE_W := 8
const TILESET_TILE_H := 8
const TILESET_BG_OVERDRAW := 1.0
const ASCII_BG_OVERDRAW_X := 0.5
const ASCII_BG_OVERDRAW_Y := 0.5
const HUD_SIDEBAR_W := 320.0
const TILE_SOURCE_ID := 0
const FILL_SOURCE_ID := 1

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

# Overworld tile palette â€” biome-tuned, sun-baked
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
const C_ROAD_LIT        := Color(0.78, 0.62, 0.38)
const C_ROAD_DIM        := Color(0.42, 0.32, 0.18)
const C_CAVE_WALL_LIT   := Color(0.50, 0.46, 0.44)   # cool slate grey
const C_CAVE_WALL_DIM   := Color(0.18, 0.16, 0.15)
const C_CAVE_FLOOR_LIT  := Color(0.34, 0.30, 0.28)   # dark stone, slightly cool
const C_CAVE_FLOOR_DIM  := Color(0.12, 0.11, 0.10)
const C_VILLAGE_WM      := Color(0.95, 0.90, 0.70)

const C_WALL_DIM_TILESET      := Color(0.08, 0.05, 0.03)
const C_FLOOR_DIM_TILESET     := Color(0.03, 0.025, 0.02)
const C_SAND_DIM_TILESET      := Color(0.08, 0.06, 0.03)
const C_DUNE_DIM_TILESET      := Color(0.10, 0.05, 0.02)
const C_ROCK_DIM_TILESET      := Color(0.08, 0.035, 0.02)
const C_WATER_DIM_TILESET     := Color(0.03, 0.08, 0.14)
const C_GRASS_DIM_TILESET     := Color(0.04, 0.08, 0.03)
const C_ROAD_DIM_TILESET      := Color(0.08, 0.06, 0.03)
const C_CAVE_WALL_DIM_TILESET  := Color(0.05, 0.05, 0.05)
const C_CAVE_FLOOR_DIM_TILESET := Color(0.03, 0.03, 0.03)
const C_UNEXPLORED_TILESET    := Color(0.0, 0.0, 0.0)

const C_WALL_BG_TILESET_LIT  := Color(0.46, 0.24, 0.14)
const C_WALL_BG_TILESET_DIM  := Color(0.18, 0.10, 0.06)
const C_FLOOR_BG_TILESET_LIT := Color(0.42, 0.32, 0.18)
const C_FLOOR_BG_TILESET_DIM := Color(0.14, 0.10, 0.06)
const C_SAND_BG_TILESET_LIT  := Color(0.66, 0.54, 0.28)
const C_SAND_BG_TILESET_DIM  := Color(0.22, 0.18, 0.08)
const C_DUNE_BG_TILESET_LIT  := Color(0.72, 0.46, 0.16)
const C_DUNE_BG_TILESET_DIM  := Color(0.24, 0.14, 0.05)
const C_ROCK_BG_TILESET_LIT  := Color(0.48, 0.22, 0.12)
const C_ROCK_BG_TILESET_DIM  := Color(0.16, 0.08, 0.05)
const C_WATER_BG_TILESET_LIT := Color(0.16, 0.34, 0.54)
const C_WATER_BG_TILESET_DIM := Color(0.06, 0.12, 0.20)
const C_GRASS_BG_TILESET_LIT := Color(0.22, 0.46, 0.14)
const C_GRASS_BG_TILESET_DIM := Color(0.08, 0.16, 0.05)
const C_ROAD_BG_TILESET_LIT       := Color(0.50, 0.40, 0.24)
const C_ROAD_BG_TILESET_DIM       := Color(0.18, 0.14, 0.08)
const C_CAVE_WALL_BG_TILESET_LIT  := Color(0.32, 0.30, 0.28)
const C_CAVE_WALL_BG_TILESET_DIM  := Color(0.10, 0.10, 0.09)
const C_CAVE_FLOOR_BG_TILESET_LIT := Color(0.22, 0.20, 0.18)
const C_CAVE_FLOOR_BG_TILESET_DIM := Color(0.08, 0.07, 0.07)

# -- TERRAIN VARIATION -------------------------------------------------------
# Set to false to revert all terrain tiles to single-char, single-colour glyphs.
const TERRAIN_VARIATION := true

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
var _hover_path: Array = []
var _auto_move_mode: AutoMoveMode = AutoMoveMode.NONE
var _auto_move_target: Vector2i = Vector2i.ZERO
var _auto_move_accum: float = 0.0
var _auto_move_steps_taken: int = 0
const AUTO_MOVE_STEP_SECONDS: float = 0.05
const MOUNT_GLYPH_CYCLE_MS: int = 700
var _mount_cycle_bucket: int = -1
var _map_zoom_idx: int = 2

# ---------------------------------------------------------------------------
# World-map incremental sync state — tracks what was last painted so only
# changed cells are repainted rather than the full 60×36 grid each redraw.
# ---------------------------------------------------------------------------
var _wm_last_scale: Vector2 = Vector2.ZERO  # detects viewport resize; reset forces full repaint
var _wm_prev_chunk: Vector2i = Vector2i(-99, -99)
var _wm_prev_look_cursor: Vector2i = Vector2i(-99, -99)
var _wm_prev_look_mode: bool = false

# ---------------------------------------------------------------------------
# Chunk-map entity layer incremental sync — tracks which screen cells had
# entities last frame so only those cells need to be cleared, not all cells.
# When the camera moves all screen-space positions shift, so we fall back to
# a full entity layer clear on camera-move turns.
# ---------------------------------------------------------------------------
var _prev_entity_cells: Array[Vector2i] = []
var _prev_cam_x: int = -9999
var _prev_cam_y: int = -9999

# ---------------------------------------------------------------------------
# Attack animation state — bump ghosts run sequentially via _anim_queue so
# the player animation always completes before the enemy animation begins.
# ---------------------------------------------------------------------------
var _bump_ghosts: Dictionary = {}         # Vector2i(screen_x, screen_y) → Label
var _bump_suppressed: Dictionary = {}     # screen cells whose entity tile is hidden during animation
var _anim_queue: Array = []              # pending Callables, played one at a time
var _anim_busy: bool = false             # true while a bump animation is in flight

# ---------------------------------------------------------------------------
# Day/night tint â€” applied to map tiles and entities only (UI stays lit).
# Updated every turn via _on_turn_ended.
# ---------------------------------------------------------------------------
var _day_tint: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Game world + rendering
# ---------------------------------------------------------------------------
var _world  # GameWorld â€” untyped to avoid class_name scope issues
var _font: Font
var _tileset: Texture2D
var _ascii_atlas: Texture2D
var _glyph_tileset: TileSet
var _fill_tileset: TileSet
var _chunk_tile_root: Node2D
var _chunk_bg_layer
var _chunk_fg_layer
var _chunk_entity_layer
var _chunk_overlay_bg_layer
var _chunk_overlay_fg_layer
var _world_tile_root: Node2D
var _world_bg_layer
var _world_fg_layer
var _world_overlay_layer
var _anim_layer: Node2D  # ephemeral bump/flash nodes live here; cleared each attack
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
var _menu_spacer_top
var _menu_body_text
var _menu_button_box
var _menu_spacer_bottom
var _menu_footer_label
var _trade_ui_root: Control
var _trade_shell: PanelContainer
var _trade_title_label
var _trade_buy_list
var _trade_sell_list
var _trade_footer_label
var _hud_ui_root: Control
var _hud_bg: ColorRect
var _hud_sidebar_bg: ColorRect
var _hud_log_divider: ColorRect
var _hud_status_top
var _hud_status_bottom
var _hud_status_third
var _hud_sky_label
var _hud_message_labels: Array = []

# Convenience aliases â€” read-only proxies into _world.
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font  = _make_font()
	_tileset = _load_tileset()
	_ascii_atlas = _load_ascii_atlas()
	_build_tilemap_tilesets()
	_ui_theme = _make_ui_theme()
	_world = GameWorldClass.new()
	add_child(_world)
	_build_tilemap_layers()
	_attach_ui_layer()
	_build_hud_ui()
	_build_inventory_ui()
	_build_menu_ui()
	_build_trade_ui()
	_layout_hud_ui()
	get_viewport().size_changed.connect(_layout_hud_ui)
	set_process(true)
	_world.turn_ended.connect(_on_turn_ended)
	_world.map_changed.connect(_on_map_changed)
	_world.attribute_points_changed.connect(_on_attribute_points_changed)
	_world.entity_attacked.connect(_on_entity_attacked)
	_world.entity_fired.connect(_on_entity_fired)
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
	var path := GameState.current_font_path()
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "Courier New"])
	return sf


func _load_tileset() -> Texture2D:
	if not TILESET_ENABLED or not FileAccess.file_exists(TILESET_PATH):
		return null
	var image := Image.load_from_file(TILESET_PATH)
	if image == null or image.is_empty():
		return null
	if not TILESET_PATH.ends_with("_mask.png"):
		_prepare_tileset_mask(image)
	return ImageTexture.create_from_image(image)


func _load_ascii_atlas() -> Texture2D:
	if not FileAccess.file_exists(ASCII_ATLAS_PATH):
		return null
	var image := Image.load_from_file(ASCII_ATLAS_PATH)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _build_tilemap_tilesets() -> void:
	_glyph_tileset = TileSet.new()
	_glyph_tileset.tile_size = Vector2i(TILESET_TILE_W, TILESET_TILE_H)
	var glyph_source := TileSetAtlasSource.new()
	glyph_source.texture = _tileset if _tileset != null else _ascii_atlas
	glyph_source.texture_region_size = Vector2i(TILESET_TILE_W, TILESET_TILE_H)
	for row in range(TILESET_ROWS):
		for col in range(TILESET_COLS):
			glyph_source.create_tile(Vector2i(col, row))
	_glyph_tileset.add_source(glyph_source, TILE_SOURCE_ID)

	_fill_tileset = TileSet.new()
	_fill_tileset.tile_size = Vector2i(TILESET_TILE_W, TILESET_TILE_H)
	var fill_image := Image.create(TILESET_TILE_W, TILESET_TILE_H, false, Image.FORMAT_RGBA8)
	fill_image.fill(Color.WHITE)
	var fill_texture := ImageTexture.create_from_image(fill_image)
	var fill_source := TileSetAtlasSource.new()
	fill_source.texture = fill_texture
	fill_source.texture_region_size = Vector2i(TILESET_TILE_W, TILESET_TILE_H)
	fill_source.create_tile(Vector2i.ZERO)
	_fill_tileset.add_source(fill_source, FILL_SOURCE_ID)


func _make_tile_layer(tile_set: TileSet, z_index: int) -> ModulateTileMapLayerClass:
	var layer = ModulateTileMapLayerClass.new()
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = z_index
	return layer


func _build_tilemap_layers() -> void:
	_chunk_tile_root = Node2D.new()
	_chunk_tile_root.name = "ChunkTileRoot"
	_chunk_tile_root.z_index = 1
	add_child(_chunk_tile_root)

	_chunk_bg_layer = _make_tile_layer(_fill_tileset, 0)
	_chunk_fg_layer = _make_tile_layer(_glyph_tileset, 1)
	_chunk_entity_layer = _make_tile_layer(_glyph_tileset, 2)
	_chunk_overlay_bg_layer = _make_tile_layer(_fill_tileset, 3)
	_chunk_overlay_fg_layer = _make_tile_layer(_glyph_tileset, 4)
	_chunk_tile_root.add_child(_chunk_bg_layer)
	_chunk_tile_root.add_child(_chunk_fg_layer)
	_chunk_tile_root.add_child(_chunk_entity_layer)
	_chunk_tile_root.add_child(_chunk_overlay_bg_layer)
	_chunk_tile_root.add_child(_chunk_overlay_fg_layer)

	_world_tile_root = Node2D.new()
	_world_tile_root.name = "WorldTileRoot"
	_world_tile_root.z_index = 1
	add_child(_world_tile_root)
	_world_bg_layer = _make_tile_layer(_fill_tileset, 0)
	_world_fg_layer = _make_tile_layer(_glyph_tileset, 1)
	_world_overlay_layer = _make_tile_layer(_fill_tileset, 2)
	_world_tile_root.add_child(_world_bg_layer)
	_world_tile_root.add_child(_world_fg_layer)
	_world_tile_root.add_child(_world_overlay_layer)

	_anim_layer = Node2D.new()
	_anim_layer.name = "AnimLayer"
	_anim_layer.z_index = 2  # above tile roots (z=1), below CanvasLayer UI
	add_child(_anim_layer)


func _prepare_tileset_mask(image: Image) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in range(h):
		for x in range(w):
			var px: Color = image.get_pixel(x, y)
			if _is_tileset_bg(px):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var alpha := _tileset_mask_alpha(px)
				image.set_pixel(x, y, Color(1, 1, 1, alpha))


func _is_tileset_bg(px: Color) -> bool:
	if px.a <= 0.01:
		return true
	if px.r >= 0.75 and px.g <= 0.25 and px.b >= 0.75:
		return true
	var brightness: float = (px.r + px.g + px.b) / 3.0
	return brightness <= 0.55


func _tileset_mask_alpha(px: Color) -> float:
	var brightness: float = (px.r + px.g + px.b) / 3.0
	return clampf((brightness - 0.55) / 0.45, 0.0, 1.0)


func _tileset_active() -> bool:
	return _tileset != null and GameState.use_tileset


func _ascii_atlas_active() -> bool:
	return not _tileset_active() and GameState.font_profile == GameState.FONT_PROFILE_BIOS and _ascii_atlas != null


func _use_tilemap_renderer() -> bool:
	return _glyph_tileset != null and _fill_tileset != null and GameState.use_tileset


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


func _bb_escape(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _bb_color(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), _bb_escape(text)]


func _set_rich_text_plain(label: RichTextLabel, text: String) -> void:
	label.clear()
	label.add_text(text)


func _set_rich_text_with_highlight(label: RichTextLabel, lines: Array[String], highlight_idx: int) -> void:
	label.clear()
	for i in range(lines.size()):
		if i == highlight_idx:
			label.push_color(C_STATUS)
			label.add_text(lines[i])
			label.pop()
		else:
			label.add_text(lines[i])
		if i < lines.size() - 1:
			label.add_text("\n")


func _set_hud_segments(label: RichTextLabel, segments: Array) -> void:
	label.clear()
	for segment in segments:
		var text: String = str(segment.get("text", ""))
		var color: Color = segment.get("color", C_STATUS)
		label.push_color(color)
		label.add_text(text)
		label.pop()


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

	_hud_sidebar_bg = ColorRect.new()
	_hud_sidebar_bg.color = C_BG
	_hud_sidebar_bg.position = Vector2(COLS * CELL_W - HUD_SIDEBAR_W, 0)
	_hud_sidebar_bg.size = Vector2(HUD_SIDEBAR_W, DIVIDER_ROW * CELL_H)
	_hud_sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_sidebar_bg)

	var divider := ColorRect.new()
	divider.color = C_DIVIDER
	divider.position = Vector2(0, DIVIDER_ROW * CELL_H)
	divider.size = Vector2(COLS * CELL_W, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(divider)

	var side_divider := ColorRect.new()
	side_divider.name = "HudSideDivider"
	side_divider.color = C_DIVIDER
	side_divider.position = Vector2(COLS * CELL_W - HUD_SIDEBAR_W, 0)
	side_divider.size = Vector2(1, DIVIDER_ROW * CELL_H)
	side_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(side_divider)

	_hud_status_top = RichTextLabel.new()
	_hud_status_top.bbcode_enabled = false
	_hud_status_top.fit_content = false
	_hud_status_top.scroll_active = false
	_hud_status_top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_status_top.position = Vector2(0, STATUS_ROW * CELL_H - 2)
	_hud_status_top.size = Vector2(COLS * CELL_W, _ui_line_height() + 6.0)
	_hud_status_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_status_top)

	_hud_status_bottom = RichTextLabel.new()
	_hud_status_bottom.bbcode_enabled = false
	_hud_status_bottom.fit_content = false
	_hud_status_bottom.scroll_active = false
	_hud_status_bottom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_status_bottom.position = Vector2(0, STATUS_ROW_2 * CELL_H - 2)
	_hud_status_bottom.size = Vector2(COLS * CELL_W, _ui_line_height() + 6.0)
	_hud_status_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_status_bottom)

	_hud_status_third = RichTextLabel.new()
	_hud_status_third.bbcode_enabled = false
	_hud_status_third.fit_content = false
	_hud_status_third.scroll_active = false
	_hud_status_third.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_status_third.position = Vector2(0, (STATUS_ROW_2 + 1) * CELL_H - 2)
	_hud_status_third.size = Vector2(COLS * CELL_W, _ui_line_height() + 6.0)
	_hud_status_third.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_status_third)

	_hud_sky_label = Label.new()
	_hud_sky_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_sky_label)

	_hud_log_divider = ColorRect.new()
	_hud_log_divider.color = C_DIVIDER
	_hud_log_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ui_root.add_child(_hud_log_divider)

	for i in range(MSG_LINES):
		var msg := Label.new()
		msg.position = Vector2(0, (MSG_START_ROW + i) * CELL_H - 4)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.clip_text = false
		msg.custom_minimum_size = Vector2(COLS * CELL_W, _ui_line_height() + 12.0)
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


func _on_entity_attacked(attacker_pos: Vector2i, target_pos: Vector2i, glyph: String, color: Color) -> void:
	if _anim_layer == null or not _on_screen(attacker_pos.x, attacker_pos.y):
		return
	_anim_queue.append(func(): _play_bump_anim(attacker_pos, target_pos, glyph, color))
	if not _anim_busy:
		_next_anim()


func _next_anim() -> void:
	if _anim_queue.is_empty():
		_anim_busy = false
		return
	_anim_busy = true
	(_anim_queue.pop_front() as Callable).call()


func _play_bump_anim(attacker_pos: Vector2i, target_pos: Vector2i, glyph: String, color: Color) -> void:
	var cell_px: float = float(_map_font_size())

	# Bump ghost — attacker glyph slides toward the target tile then springs back.
	var sp     := _to_screen(attacker_pos.x, attacker_pos.y)
	var sp_key := Vector2i(sp.x, sp.y)
	var origin_px := Vector2(float(sp.x), float(sp.y)) * cell_px
	var bump_dir  := Vector2(target_pos - attacker_pos).normalized()

	# Fast attacks cancel the previous ghost rather than stacking.
	if _bump_ghosts.has(sp_key):
		(_bump_ghosts[sp_key] as Label).queue_free()
		_bump_ghosts.erase(sp_key)
		_bump_suppressed.erase(sp_key)

	# Hide the real entity tile so only the sliding ghost is visible.
	_bump_suppressed[sp_key] = true
	if _use_tilemap_renderer():
		_chunk_entity_layer.erase_cell_with_modulate(sp_key)

	var ghost := Label.new()
	ghost.text = glyph
	ghost.add_theme_font_override("font", _font)
	ghost.add_theme_font_size_override("font_size", _map_font_size())
	ghost.add_theme_color_override("font_color", color)
	ghost.size = Vector2(cell_px, cell_px)
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.position = origin_px
	_anim_layer.add_child(ghost)
	_bump_ghosts[sp_key] = ghost

	var tw := ghost.create_tween()
	tw.tween_property(ghost, "position", origin_px + bump_dir * (cell_px * 0.50), 0.06)
	tw.tween_property(ghost, "position", origin_px, 0.06)
	tw.tween_callback(func():
		_bump_ghosts.erase(sp_key)
		_bump_suppressed.erase(sp_key)
		ghost.queue_free()
		queue_redraw()  # restore the entity tile
		_next_anim()    # advance the queue
	)

	# Hit flash — warm bloom on the target cell that fades out quickly.
	if _on_screen(target_pos.x, target_pos.y):
		var tsp      := _to_screen(target_pos.x, target_pos.y)
		var target_px := Vector2(float(tsp.x), float(tsp.y)) * cell_px
		var flash    := ColorRect.new()
		flash.size     = Vector2(cell_px, cell_px)
		flash.color    = Color(1.0, 0.80, 0.35, 0.50)
		flash.position = target_px
		_anim_layer.add_child(flash)
		var ftw := flash.create_tween()
		ftw.tween_property(flash, "color:a", 0.0, 0.10)
		ftw.tween_callback(flash.queue_free)


func _on_entity_fired(attacker_pos: Vector2i, target_pos: Vector2i, proj_char: String, proj_color: Color) -> void:
	if _anim_layer == null:
		return
	_anim_queue.append(func(): _play_projectile_anim(attacker_pos, target_pos, proj_char, proj_color))
	if not _anim_busy:
		_next_anim()


func _play_projectile_anim(attacker_pos: Vector2i, target_pos: Vector2i, proj_char: String, proj_color: Color) -> void:
	var cell_px := float(_map_font_size())

	# Map positions to screen positions; clamp to on-screen endpoints if needed.
	var sp_a := _to_screen(attacker_pos.x, attacker_pos.y)
	var sp_t := _to_screen(target_pos.x, target_pos.y)
	var start_px := Vector2(float(sp_a.x), float(sp_a.y)) * cell_px
	var end_px   := Vector2(float(sp_t.x), float(sp_t.y)) * cell_px

	# Quadratic bezier arc: control point is the midpoint raised upward in
	# screen space to simulate a ballistic trajectory.
	var mid_px: Vector2 = (start_px + end_px) * 0.5 + Vector2(0.0, -cell_px * 0.6)

	# Duration scales with distance — snappy over short range, readable over long.
	var dist_cells: float = (end_px - start_px).length() / cell_px
	var duration: float = clampf(dist_cells * 0.025, 0.10, 0.28)

	var proj := Label.new()
	proj.text = proj_char
	proj.add_theme_font_override("font", _font)
	proj.add_theme_font_size_override("font_size", _map_font_size())
	proj.add_theme_color_override("font_color", proj_color)
	proj.size = Vector2(cell_px, cell_px)
	proj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proj.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	proj.position = start_px
	_anim_layer.add_child(proj)

	var tw := proj.create_tween()
	tw.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		proj.position = u * u * start_px + 2.0 * u * t * mid_px + t * t * end_px
	, 0.0, 1.0, duration)
	tw.tween_callback(func() -> void:
		proj.queue_free()
		# Hit flash at the target cell.
		if _on_screen(target_pos.x, target_pos.y):
			var tsp := _to_screen(target_pos.x, target_pos.y)
			var target_px := Vector2(float(tsp.x), float(tsp.y)) * cell_px
			var flash := ColorRect.new()
			flash.size    = Vector2(cell_px, cell_px)
			flash.color   = Color(1.0, 0.80, 0.35, 0.65)
			flash.position = target_px
			_anim_layer.add_child(flash)
			var ftw := flash.create_tween()
			ftw.tween_property(flash, "color:a", 0.0, 0.12)
			ftw.tween_callback(flash.queue_free)
		_next_anim()
	)


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
	_inventory_shell.mouse_filter = Control.MOUSE_FILTER_PASS
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


func _make_menu_button(text: String, callback: Callable, selected: bool = false, centered: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if centered else Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", C_STATUS if selected else C_MSG_RECENT)
	button.pressed.connect(callback)
	return button


func _add_trade_entry_row(parent, text: String, callback: Callable, selected: bool = false) -> void:
	var button := _make_menu_button(text, callback, selected)
	parent.add_child(button)


func _add_menu_label(parent, text: String, color: Color = C_MSG_RECENT, centered: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


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
	_menu_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_menu_shell.mouse_filter = Control.MOUSE_FILTER_PASS
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

	_menu_spacer_top = Control.new()
	_menu_spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_menu_spacer_top)

	_menu_body_text = RichTextLabel.new()
	_menu_body_text.bbcode_enabled = false
	_menu_body_text.fit_content = false
	_menu_body_text.scroll_active = true
	_menu_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_body_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_menu_body_text)

	_menu_button_box = VBoxContainer.new()
	_menu_button_box.add_theme_constant_override("separation", 6)
	_menu_button_box.visible = false
	v.add_child(_menu_button_box)

	_menu_spacer_bottom = Control.new()
	_menu_spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_spacer_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_menu_spacer_bottom)

	_menu_footer_label = Label.new()
	_menu_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_footer_label.add_theme_color_override("font_color", C_DIVIDER)
	v.add_child(_menu_footer_label)


func _build_trade_ui() -> void:
	_trade_ui_root = Control.new()
	_trade_ui_root.visible = false
	_trade_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_trade_shell.mouse_filter = Control.MOUSE_FILTER_PASS
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

	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(buy_scroll)

	_trade_buy_list = VBoxContainer.new()
	_trade_buy_list.add_theme_constant_override("separation", 4)
	_trade_buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.add_child(_trade_buy_list)

	var sell_scroll := ScrollContainer.new()
	sell_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(sell_scroll)

	_trade_sell_list = VBoxContainer.new()
	_trade_sell_list.add_theme_constant_override("separation", 4)
	_trade_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_scroll.add_child(_trade_sell_list)

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


func _map_font_size() -> int:
	var zoom_sizes: Array = GameState.current_map_zoom_sizes()
	_map_zoom_idx = clampi(_map_zoom_idx, 0, zoom_sizes.size() - 1)
	return int(zoom_sizes[_map_zoom_idx])


func _divider_y_px() -> float:
	var ui_line_h: float = _ui_line_height()
	return get_viewport_rect().size.y - (ui_line_h * 5.0 + 46.0)


func _hud_sidebar_w_px() -> float:
	return minf(HUD_SIDEBAR_W, floor(get_viewport_rect().size.x * 0.32))


func _chunk_view_px_w() -> float:
	return get_viewport_rect().size.x - _hud_sidebar_w_px()


func _chunk_view_px_h() -> float:
	return _divider_y_px()


func _map_cell_w() -> float:
	if _tileset_active() or _ascii_atlas_active():
		return float(_map_font_size())
	return maxf(1.0, ceil(_font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, _map_font_size()).x))


func _map_cell_h() -> float:
	if _tileset_active() or _ascii_atlas_active():
		return float(_map_font_size())
	return maxf(1.0, ceil(_font.get_height(_map_font_size())))


func _map_visible_cols() -> int:
	return maxi(10, int(floor(_chunk_view_px_w() / _map_cell_w())))


func _map_visible_rows() -> int:
	return maxi(8, int(floor(_chunk_view_px_h() / _map_cell_h())))


func _map_px_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(_map_visible_cols()) * _map_cell_w(), float(_map_visible_rows()) * _map_cell_h())


func _set_chunk_zoom(step: int) -> void:
	var zoom_sizes: Array = GameState.current_map_zoom_sizes()
	var new_idx: int = clampi(_map_zoom_idx + step, 0, zoom_sizes.size() - 1)
	if new_idx == _map_zoom_idx:
		return
	_map_zoom_idx = new_idx
	_update_camera()
	_layout_hud_ui()
	queue_redraw()


func _layout_hud_ui() -> void:
	if _hud_ui_root == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var divider_y: float = _divider_y_px()
	var ui_line_h: float = _ui_line_height()
	var hud_pad_top: float = 10.0
	var hud_row_gap: float = 6.0
	var msg_gap: float = 6.0
	var msg_block_h: float = ui_line_h + 12.0
	var sidebar_w: float = _hud_sidebar_w_px()
	var sidebar_x: float = viewport_size.x - sidebar_w
	_hud_bg.position = Vector2(0, divider_y)
	_hud_bg.size = Vector2(viewport_size.x, viewport_size.y - divider_y)
	_hud_sidebar_bg.position = Vector2(sidebar_x, 0)
	_hud_sidebar_bg.size = Vector2(sidebar_w, divider_y)
	var divider := _hud_ui_root.get_child(2) as ColorRect
	if divider != null:
		divider.position = Vector2(0, divider_y)
		divider.size = Vector2(viewport_size.x, 1)
	var side_divider := _hud_ui_root.get_node_or_null("HudSideDivider") as ColorRect
	if side_divider != null:
		side_divider.position = Vector2(sidebar_x, 0)
		side_divider.size = Vector2(1, divider_y)
	var sidebar_inner_x: float = sidebar_x + 10.0
	var sidebar_inner_w: float = sidebar_w - 20.0
	var block_h: float = ui_line_h * 2.0 + 14.0
	_hud_status_top.position = Vector2(sidebar_inner_x, hud_pad_top)
	_hud_status_top.size = Vector2(sidebar_inner_w, block_h)
	_hud_status_bottom.position = Vector2(sidebar_inner_x, hud_pad_top + block_h + hud_row_gap)
	_hud_status_bottom.size = Vector2(sidebar_inner_w, block_h)
	var third_y: float = hud_pad_top + (block_h + hud_row_gap) * 2.0
	_hud_status_third.position = Vector2(sidebar_inner_x, third_y)
	_hud_status_third.size = Vector2(sidebar_inner_w, maxi(block_h + ui_line_h + 6.0, divider_y - third_y - 10.0))
	var sky_y: float = divider_y + 6.0
	_hud_sky_label.position = Vector2(0, sky_y)
	_hud_sky_label.custom_minimum_size = Vector2(viewport_size.x, ui_line_h + 8.0)
	_hud_log_divider.position = Vector2(0, sky_y + ui_line_h + 8.0)
	_hud_log_divider.size = Vector2(viewport_size.x, 1)
	var msg_start_y: float = sky_y + ui_line_h + 14.0
	for i in range(_hud_message_labels.size()):
		var msg: Label = _hud_message_labels[i]
		msg.position = Vector2(0, msg_start_y + float(i) * (msg_block_h + msg_gap))
		msg.custom_minimum_size = Vector2(viewport_size.x, msg_block_h)


func _set_menu_vertical_centering(enabled: bool) -> void:
	if _menu_spacer_top == null or _menu_spacer_bottom == null or _menu_body_text == null:
		return
	_menu_spacer_top.visible = enabled
	_menu_spacer_bottom.visible = enabled
	_menu_spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL if enabled else Control.SIZE_SHRINK_BEGIN
	_menu_spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL if enabled else Control.SIZE_SHRINK_BEGIN
	_menu_body_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER if enabled else Control.SIZE_EXPAND_FILL


func _ui_line_height() -> float:
	return maxf(1.0, ceil(_font.get_height(UI_FONT_SIZE)))


func _apply_font_profile() -> void:
	_font = _make_font()
	_ascii_atlas = _load_ascii_atlas()
	_ui_theme = _make_ui_theme()
	if _hud_ui_root != null:
		_hud_ui_root.theme = _ui_theme
	if _inventory_ui_root != null:
		_inventory_ui_root.theme = _ui_theme
	if _menu_ui_root != null:
		_menu_ui_root.theme = _ui_theme
	if _trade_ui_root != null:
		_trade_ui_root.theme = _ui_theme
	_map_zoom_idx = clampi(_map_zoom_idx, 0, GameState.current_map_zoom_sizes().size() - 1)
	_update_camera()
	_layout_hud_ui()
	if _screen == Screen.INVENTORY:
		_refresh_inventory_ui()
	if _screen in [Screen.ESCAPE, Screen.CHARACTER, Screen.SETTINGS, Screen.ATTRIBUTE_PICK, Screen.DISAMBIGUATE, Screen.HELP, Screen.READER, Screen.DIALOGUE, Screen.TRAVEL_EVENT]:
		_refresh_menu_ui()
	if _screen == Screen.TRADE:
		_refresh_trade_ui()
	queue_redraw()


func _refresh_menu_ui() -> void:
	if _menu_ui_root == null:
		return
	_clear_control_children(_menu_button_box)
	_menu_button_box.visible = false
	_menu_body_text.visible = true
	_set_menu_vertical_centering(false)
	match _screen:
		Screen.ESCAPE:
			_set_menu_vertical_centering(true)
			_menu_title_label.text = "-=[ PAUSED ]=-"
			_set_rich_text_plain(_menu_body_text, "")
			_menu_button_box.visible = true
			for i in range(ESCAPE_OPTIONS.size()):
				var idx: int = i
				var escape_callback := func():
					_escape_cursor = idx
					_confirm_escape()
				var escape_button := _make_menu_button(
					ESCAPE_OPTIONS[i],
					escape_callback,
					i == _escape_cursor,
					true
				)
				_menu_button_box.add_child(escape_button)
			_menu_footer_label.text = "Enter: select    Esc: resume"
		Screen.SETTINGS:
			_set_menu_vertical_centering(true)
			_menu_title_label.text = "-=[ SETTINGS ]=-"
			_set_rich_text_plain(_menu_body_text, "")
			_menu_button_box.visible = true
			_menu_button_box.add_child(_make_menu_button(
				"[A] Auto-pickup items:  %s" % ("ON" if GameState.auto_pickup else "OFF"),
				func():
					GameState.auto_pickup = not GameState.auto_pickup
					_refresh_menu_ui()
			, false, true))
			_menu_button_box.add_child(_make_menu_button(
				"[D] Debug tools:        %s" % ("ON" if GameState.debug_tools_enabled else "OFF"),
				func():
					GameState.debug_tools_enabled = not GameState.debug_tools_enabled
					_refresh_menu_ui()
			, false, true))
			_menu_button_box.add_child(_make_menu_button(
				"[G] God mode:           %s" % ("ON" if GameState.god_mode else "OFF"),
				func():
					GameState.god_mode = not GameState.god_mode
					_refresh_menu_ui()
			, false, true))
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
			_set_rich_text_plain(_menu_body_text, "Name       %s\nClass      %s\nLevel      %d\nXP         %d / %d\nMount      %s\n\nHP         %d / %d\nAttack     %s\nRanged     %s\nAC         %d\nGold       %d\nCarry      %s / %s\nSTR Carry  %+d lbs.\n\nSTR        %d (%+d)\nDEX        %d (%+d)\nCON        %d (%+d)\nINT        %d (%+d)\nWIS        %d (%+d)\nCHA        %d (%+d)" % [
				GameState.player_name,
				GameState.player_class.capitalize(),
				_player.level,
				_player.xp, _player.xp_to_next,
				mount.name.capitalize() if mount != null else "None",
				_player.hp, _player.max_hp,
				_player.melee_damage_label(),
				("%s  (%s)" % [ranged_str, _player.ranged_damage_label()]) if ranged_weapon != null else ranged_str,
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
			])
			_menu_button_box.visible = true
			_menu_button_box.add_child(_make_menu_button("Close", func():
				_screen = Screen.NONE
				queue_redraw()
			, false, true))
			_menu_footer_label.text = "Esc: close"
		Screen.ATTRIBUTE_PICK:
			_set_menu_vertical_centering(true)
			_menu_title_label.text = "-=[ ATTRIBUTE INCREASE ]=-"
			var attr_body := "Choose an attribute to raise by 1.\nUnspent points: %d" % _player.unspent_attribute_points
			_set_rich_text_plain(_menu_body_text, attr_body)
			_menu_button_box.visible = true
			for opt in ATTRIBUTE_OPTIONS:
				var score: int = int(_player.get("%s_score" % str(opt.code)))
				var attr_code: String = str(opt.code)
				var attr_callback := func():
					if _world.apply_attribute_increase(attr_code):
						_open_attribute_overlay_if_needed()
						queue_redraw()
				var attr_button := _make_menu_button(
					"[%s] %-12s %2d -> %2d" % [char(int(opt.key)), str(opt.label), score, score + 1],
					attr_callback,
					false,
					true
				)
				_menu_button_box.add_child(attr_button)
			_menu_footer_label.text = "Press the matching key"
		Screen.DISAMBIGUATE:
			_set_menu_vertical_centering(true)
			_menu_title_label.text = _disambig_prompt
			_set_rich_text_plain(_menu_body_text, "")
			_menu_button_box.visible = true
			for i in range(_disambig_options.size()):
				var opt_line: Dictionary = _disambig_options[i]
				var opt_key: int = int(opt_line.get("key", KEY_NONE))
				var key_label := char(opt_key) if opt_key >= KEY_A and opt_key <= KEY_Z else "*"
				var callback: Callable = opt_line.get("callback", Callable())
				var idx: int = i
				var disambig_callback := func():
					_disambig_cursor = idx
					if callback.is_valid():
						callback.call()
				var disambig_button := _make_menu_button(
					"[%s] %s" % [key_label, str(opt_line.get("label", ""))],
					disambig_callback,
					i == _disambig_cursor,
					true
				)
				_menu_button_box.add_child(disambig_button)
			_menu_footer_label.text = "Enter: confirm    Esc: cancel"
		Screen.HELP:
			_menu_title_label.text = "-=[ KEYBINDS ]=-"
			_set_rich_text_plain(_menu_body_text, "MOVEMENT\narrows / numpad  move\nnumpad 7/9/1/3   diagonal move\nnumpad 5 / .     wait one turn\nmouse wheel       zoom chunk view\n\nACTIONS\nm  mount / dismount\ng  pick up items\ns  skin/butcher carcass\nt  trade (near merchant)\nf  fire ranged weapon\nShift+dir  force attack\n>  descend / enter\n<  ascend / world map\n\nMENUS\ni  inventory\nc  character sheet\nl  look mode\n?  this help screen\nEsc  pause menu\n\nINVENTORY\n[a-z] use / equip item\n[w/r/b/f/h/u] unequip slot\n\nTRADE\n[a-z] buy item\n[Tab + A-Z] sell item\n\nWORLD MAP\narrows  travel between chunks\nl  toggle look cursor\n>  enter chunk view")
			_menu_button_box.visible = true
			_menu_button_box.add_child(_make_menu_button("Close", func():
				_screen = Screen.NONE
				queue_redraw()
			, false, true))
			_menu_footer_label.text = "Any key to close"
		Screen.READER:
			_menu_title_label.text = "-=[ %s ]=-" % (_reader_item.name.to_upper() if _reader_item != null else "READER")
			var visible := _reader_lines.slice(_reader_scroll, _reader_scroll + 18)
			_set_rich_text_plain(_menu_body_text, "\n".join(visible))
			_menu_button_box.visible = true
			var max_scroll: int = maxi(0, _reader_lines.size() - 18)
			var scroll_up_callback := func():
				_reader_scroll = maxi(0, _reader_scroll - 1)
				_refresh_menu_ui()
			var scroll_up_button := _make_menu_button(
				"Scroll Up",
				scroll_up_callback,
				_reader_scroll > 0,
				true
			)
			_menu_button_box.add_child(scroll_up_button)
			var scroll_down_callback := func():
				_reader_scroll = mini(_reader_scroll + 1, max_scroll)
				_refresh_menu_ui()
			var scroll_down_button := _make_menu_button(
				"Scroll Down",
				scroll_down_callback,
				_reader_scroll < max_scroll,
				true
			)
			_menu_button_box.add_child(scroll_down_button)
			_menu_button_box.add_child(_make_menu_button("Close", func():
				_screen = Screen.NONE
				_reader_item = null
				queue_redraw()
			, false, true))
			_menu_footer_label.text = "Esc / Space close    Up / Down scroll"
		Screen.DIALOGUE:
			_set_menu_vertical_centering(true)
			var npc: NpcClass = _dialogue_npc as NpcClass
			_menu_title_label.text = "-=[ %s ]=-" % npc.name.to_upper()
			_set_rich_text_plain(_menu_body_text, _dialogue_line)
			_menu_button_box.visible = true
			if npc.is_merchant:
				_menu_button_box.add_child(_make_menu_button("[T] Trade", func():
					_open_trade(_dialogue_npc)
				, false, true))
			_menu_button_box.add_child(_make_menu_button("Close", func():
				_screen = Screen.NONE
				_dialogue_npc = null
				queue_redraw()
			, false, true))
			_menu_footer_label.text = "[T] Trade    [Any other key] Close" if npc.is_merchant else "[Any key] Close"
		Screen.TRAVEL_EVENT:
			_set_menu_vertical_centering(true)
			var event_data: Dictionary = _world.pending_travel_event
			_menu_title_label.text = "-=[ %s ]=-" % str(event_data.get("title", "TRAVEL EVENT"))
			_set_rich_text_plain(_menu_body_text, str(event_data.get("desc", "")))
			_menu_button_box.visible = true
			_menu_button_box.add_child(_make_menu_button("[E] Enter the chunk", func():
				_world.resolve_travel_event("enter")
			, false, true))
			if bool(event_data.get("can_ignore", false)):
				_menu_button_box.add_child(_make_menu_button("[I] Ignore and continue", func():
					_world.resolve_travel_event("ignore")
				, false, true))
			if bool(event_data.get("can_flee", false)):
				_menu_button_box.add_child(_make_menu_button("[F] Attempt to flee", func():
					_world.resolve_travel_event("flee")
				, false, true))
			_menu_footer_label.text = "Choose an option"


func _refresh_trade_ui() -> void:
	if _trade_ui_root == null or _trade_npc == null:
		return
	var npc: NpcClass = _trade_npc as NpcClass
	_trade_title_label.text = "-=[ TRADE: %s ]=-" % npc.name.capitalize()
	_clear_control_children(_trade_buy_list)
	_clear_control_children(_trade_sell_list)
	_add_menu_label(_trade_buy_list, "MERCHANT SELLS", C_STATUS)
	if npc.trade_stock.is_empty():
		_add_menu_label(_trade_buy_list, "Nothing for sale.", C_MSG_OLD)
	else:
		for i in range(npc.trade_stock.size()):
			var entry: Dictionary = npc.trade_stock[i]
			var sl := char(ord("a") + i)
			var itype := str(entry.get("item_type", ""))
			var qty := int(entry.get("qty", 0))
			var price := int(entry.get("price", 0))
			var idx: int = i
			var buy_text := "%s) %-18s %3dg  %8s  x%d" % [sl, itype.replace("_", " "), price, _format_lbs(_item_weight_for_type(itype)), qty]
			var buy_callback := func():
				_trade_panel = 0
				_trade_buy_cursor = idx
				_trade_buy(idx)
			_add_trade_entry_row(_trade_buy_list, buy_text, buy_callback, _trade_panel == 0 and i == _trade_buy_cursor)
	_add_menu_label(_trade_buy_list, "")
	_add_menu_label(_trade_buy_list, "Gold: %d" % _player.gold, C_GOLD)

	_add_menu_label(_trade_sell_list, "YOUR PACK", C_STATUS)
	var sellable: Array = _build_sellable()
	if sellable.is_empty():
		_add_menu_label(_trade_sell_list, "Nothing to sell.", C_MSG_OLD)
	else:
		for i in range(sellable.size()):
			var item = sellable[i]
			var sl := char(ord("A") + i)
			var offer: int = npc.buy_price(item)
			var idx: int = i
			var sell_text := "%s) %-18s %3dg  %8s" % [sl, (item as ItemClass).name, offer, _format_lbs(int((item as ItemClass).total_weight()))]
			var sell_callback := func():
				_trade_panel = 1
				_trade_sell_cursor = idx
				_trade_sell(idx)
			_add_trade_entry_row(_trade_sell_list, sell_text, sell_callback, _trade_panel == 1 and i == _trade_sell_cursor)

	var hint: String = "[a-z] buy   [Tab] sell panel   [Esc] leave" if _trade_panel == 0 else "[A-Z] sell   [Tab] buy panel   [Esc] leave"
	_trade_footer_label.text = hint


func _refresh_hud_ui() -> void:
	if _hud_ui_root == null or _world == null or _player == null:
		return
	var hp_frac: float = float(_player.hp) / float(_player.max_hp)
	var wpn = _player.equipped.get(ItemClass.SLOT_WEAPON)
	var wpn_str := ("WPN %s" % (wpn as ItemClass).name) if wpn != null else ""
	var lit = _player.equipped.get(ItemClass.SLOT_LIGHT)
	var lit_str := ""
	if lit != null:
		var lt := lit as ItemClass
		lit_str = "LIT %dt" % lt.value if lt.burn_turns > 0 else "LIT"
	var mount = _world.get_player_mount()
	var mount_str := ""
	if mount != null:
		mount_str = "MOUNT %s" % mount.name
	var move_cost_str := "SPD %s" % _world.get_move_cost_label()
	var cal_str: String = _world.get_calendar_string()
	var sky_str: String = _sky_track()
	var target = _sidebar_target_enemy()
	var hostile_lines: Array[String] = _sidebar_nearby_hostiles()
	var thr_pct: int = int(float(_player.thirst) / float(ActorClass.THIRST_MAX) * 100.0)
	var fat_pct: int = int(float(_player.fatigue) / float(ActorClass.FATIGUE_MAX) * 100.0)
	var hp_color := C_STATUS.lerp(Color(0.8, 0.15, 0.05), clampf(1.0 - hp_frac, 0.0, 1.0))
	var fat_color := C_STATUS.lerp(Color(0.8, 0.15, 0.05), clampf(float(_player.fatigue) / float(ActorClass.FATIGUE_MAX), 0.0, 1.0))
	var thr_color := C_STATUS.lerp(Color(0.8, 0.15, 0.05), clampf(float(_player.thirst) / float(ActorClass.THIRST_MAX), 0.0, 1.0))
	_set_hud_segments(_hud_status_top, [
		{"text": "LVL %d" % _player.level, "color": C_STATUS},
		{"text": "    ", "color": C_STATUS},
		{"text": "HP %d/%d" % [_player.hp, _player.max_hp], "color": hp_color},
		{"text": "\nATK %s" % _player.melee_damage_label(), "color": C_STATUS},
		{"text": "   ", "color": C_STATUS},
		{"text": "AC %d" % _player.ac, "color": C_STATUS},
	])
	var bottom_segments: Array = []
	bottom_segments.append({"text": "GOLD %d" % _player.gold, "color": C_GOLD})
	if _floor == 0:
		bottom_segments.append({"text": "\nTHR %d%%" % thr_pct, "color": thr_color})
		bottom_segments.append({"text": "   ", "color": C_STATUS})
	bottom_segments.append({"text": "FAT %d%%" % fat_pct, "color": fat_color})
	bottom_segments.append({"text": "\n%s" % move_cost_str, "color": C_STATUS})
	_set_hud_segments(_hud_status_bottom, bottom_segments)
	var detail_lines: Array[String] = []
	if mount_str != "":
		detail_lines.append(mount_str)
	if lit_str != "":
		detail_lines.append(lit_str)
	if wpn_str != "":
		detail_lines.append(wpn_str)
	if target != null:
		detail_lines.append("")
		detail_lines.append("TARGET")
		detail_lines.append("%s %s" % [str(target.name).capitalize(), _sidebar_hp_bar(target)])
	if not hostile_lines.is_empty():
		detail_lines.append("")
		detail_lines.append("NEARBY")
		for line in hostile_lines:
			detail_lines.append(line)
	_set_hud_segments(_hud_status_third, [
		{"text": "\n".join(detail_lines), "color": C_STATUS},
	])
	_hud_sky_label.text = "%s  %s" % [cal_str, sky_str]
	_hud_sky_label.add_theme_color_override("font_color", C_STATUS)

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
	_hover_active = false
	_hover_path.clear()
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
	_hover_active = false
	_hover_path.clear()
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
#   Midnight  (0.00) â€” deep blue   0.00
#   Pre-dawn  (0.17) â€” dark indigo 0.17  (04:00)
#   Dawn      (0.25) â€” warm amber  0.25  (06:00)
#   Morning   (0.33) â€” soft gold   0.33  (08:00)
#   Midday    (0.50) â€” full white  0.50  (12:00)
#   Afternoon (0.67) â€” soft gold   0.67  (16:00)
#   Dusk      (0.75) â€” warm amber  0.75  (18:00)
#   Night     (0.83) â€” dark indigo 0.83  (20:00)
#   Midnight  (1.00) â€” deep blue   (wraps)
# ---------------------------------------------------------------------------
func _compute_day_tint() -> Color:
	# Only the overworld is lit by the sun.  Underground is always the same dim.
	if _world.debug_hub_active or _world.depth > 0:
		if _tileset_active():
			return Color(0.62, 0.64, 0.74)  # tileset dungeon â€” cooler, readable stone-dark
		return Color(0.55, 0.50, 0.45)  # dungeon â€” torchlight amber-dim

	var t: float = _world.time_of_day   # 0.0 = midnight, 0.5 = noon

	# Four anchor points that repeat symmetrically (dawn â†” dusk).
	# Each anchor: [time, Color].
	var anchors: Array
	if _tileset_active():
		anchors = [
			[0.00, Color(0.44, 0.58, 0.96)],  # midnight  â€” stronger moonlit blue
			[0.17, Color(0.50, 0.62, 1.00)],  # pre-dawn  â€” cold blue
			[0.25, Color(0.86, 0.66, 0.44)],  # dawn      â€” warm amber-blue transition
			[0.33, Color(0.95, 0.85, 0.65)],  # morning   â€” golden
			[0.50, Color(1.00, 1.00, 1.00)],  # midday    â€” full white
			[0.67, Color(0.95, 0.85, 0.65)],  # afternoon â€” golden
			[0.75, Color(0.82, 0.60, 0.40)],  # dusk      â€” amber-blue transition
			[0.83, Color(0.50, 0.62, 1.00)],  # nightfall â€” cold blue
			[1.00, Color(0.44, 0.58, 0.96)],  # midnight  â€” wraps back
		]
	else:
		anchors = [
			[0.00, Color(0.18, 0.20, 0.40)],  # midnight  â€” deep blue-black
			[0.17, Color(0.22, 0.22, 0.48)],  # pre-dawn  â€” indigo dark
			[0.25, Color(0.88, 0.60, 0.35)],  # dawn      â€” warm amber
			[0.33, Color(0.95, 0.85, 0.65)],  # morning   â€” golden
			[0.50, Color(1.00, 1.00, 1.00)],  # midday    â€” full white
			[0.67, Color(0.95, 0.85, 0.65)],  # afternoon â€” golden
			[0.75, Color(0.88, 0.58, 0.32)],  # dusk      â€” amber
			[0.83, Color(0.22, 0.22, 0.48)],  # nightfall â€” indigo dark
			[1.00, Color(0.18, 0.20, 0.40)],  # midnight  â€” wraps back
		]

	# Linear interpolation between the two surrounding anchors.
	for i in range(anchors.size() - 1):
		var t0: float  = float(anchors[i][0])
		var t1: float  = float(anchors[i + 1][0])
		if t >= t0 and t <= t1:
			var f: float = (t - t0) / (t1 - t0)
			return (anchors[i][1] as Color).lerp(anchors[i + 1][1] as Color, f)
	return Color.WHITE


func _tile_dim_color(tile: int) -> Color:
	var tileset_mode: bool = _tileset_active()
	match tile:
		GameMapClass.TILE_WALL:
			return C_WALL_DIM_TILESET if tileset_mode else C_WALL_DIM
		GameMapClass.TILE_FLOOR:
			return C_FLOOR_DIM_TILESET if tileset_mode else C_FLOOR_DIM
		GameMapClass.TILE_SAND:
			return C_SAND_DIM_TILESET if tileset_mode else C_SAND_DIM
		GameMapClass.TILE_DUNE:
			return C_DUNE_DIM_TILESET if tileset_mode else C_DUNE_DIM
		GameMapClass.TILE_ROCK:
			return C_ROCK_DIM_TILESET if tileset_mode else C_ROCK_DIM
		GameMapClass.TILE_WATER:
			return C_WATER_DIM_TILESET if tileset_mode else C_WATER_DIM
		GameMapClass.TILE_GRASS:
			return C_GRASS_DIM_TILESET if tileset_mode else C_GRASS_DIM
		GameMapClass.TILE_ROAD:
			return C_ROAD_DIM_TILESET if tileset_mode else C_ROAD_DIM
		GameMapClass.TILE_CAVE_WALL:
			return C_CAVE_WALL_DIM_TILESET if tileset_mode else C_CAVE_WALL_DIM
		GameMapClass.TILE_CAVE_FLOOR:
			return C_CAVE_FLOOR_DIM_TILESET if tileset_mode else C_CAVE_FLOOR_DIM
		_:
			return Color(0.05, 0.05, 0.05) if tileset_mode else Color(0.20, 0.20, 0.20)


func _tileset_fill_color(tile: int, base_color: Color, lit: bool) -> Color:
	var fill: Color
	match tile:
		GameMapClass.TILE_WALL:
			fill = C_WALL_BG_TILESET_LIT if lit else C_WALL_BG_TILESET_DIM
		GameMapClass.TILE_FLOOR:
			fill = C_FLOOR_BG_TILESET_LIT if lit else C_FLOOR_BG_TILESET_DIM
		GameMapClass.TILE_SAND:
			fill = C_SAND_BG_TILESET_LIT if lit else C_SAND_BG_TILESET_DIM
		GameMapClass.TILE_DUNE:
			fill = C_DUNE_BG_TILESET_LIT if lit else C_DUNE_BG_TILESET_DIM
		GameMapClass.TILE_ROCK:
			fill = C_ROCK_BG_TILESET_LIT if lit else C_ROCK_BG_TILESET_DIM
		GameMapClass.TILE_WATER:
			fill = C_WATER_BG_TILESET_LIT if lit else C_WATER_BG_TILESET_DIM
		GameMapClass.TILE_GRASS:
			fill = C_GRASS_BG_TILESET_LIT if lit else C_GRASS_BG_TILESET_DIM
		GameMapClass.TILE_ROAD:
			fill = C_ROAD_BG_TILESET_LIT if lit else C_ROAD_BG_TILESET_DIM
		GameMapClass.TILE_CAVE_WALL:
			fill = C_CAVE_WALL_BG_TILESET_LIT if lit else C_CAVE_WALL_BG_TILESET_DIM
		GameMapClass.TILE_CAVE_FLOOR:
			fill = C_CAVE_FLOOR_BG_TILESET_LIT if lit else C_CAVE_FLOOR_BG_TILESET_DIM
		_:
			fill = base_color
	fill = fill * _day_tint
	fill.a = 1.0
	return fill


func _ascii_fill_color(tile: int, base_color: Color, lit: bool) -> Color:
	var fill: Color
	match tile:
		GameMapClass.TILE_WALL:
			fill = C_WALL_LIT if lit else C_WALL_DIM
		GameMapClass.TILE_FLOOR:
			fill = C_FLOOR_LIT if lit else C_FLOOR_DIM
		GameMapClass.TILE_SAND:
			fill = C_SAND_LIT if lit else C_SAND_DIM
		GameMapClass.TILE_DUNE:
			fill = C_DUNE_LIT if lit else C_DUNE_DIM
		GameMapClass.TILE_ROCK:
			fill = C_ROCK_LIT if lit else C_ROCK_DIM
		GameMapClass.TILE_WATER:
			fill = C_WATER_LIT if lit else C_WATER_DIM
		GameMapClass.TILE_GRASS:
			fill = C_GRASS_LIT if lit else C_GRASS_DIM
		GameMapClass.TILE_ROAD:
			fill = C_ROAD_LIT if lit else C_ROAD_DIM
		GameMapClass.TILE_CAVE_WALL:
			fill = C_CAVE_WALL_LIT if lit else C_CAVE_WALL_DIM
		GameMapClass.TILE_CAVE_FLOOR:
			fill = C_CAVE_FLOOR_LIT if lit else C_CAVE_FLOOR_DIM
		_:
			fill = base_color
	fill = fill * _day_tint
	var bg: Color = fill.lerp(C_BG, 0.55 if lit else 0.78)
	bg.a = 1.0
	return bg


func _tileset_glyph_tint(base_color: Color, lit: bool) -> Color:
	var glyph_color: Color
	if lit:
		glyph_color = base_color.lerp(Color(1, 1, 1, 1), 0.10)
	else:
		glyph_color = base_color.lerp(Color(0.80, 0.80, 0.80, 1), 0.05)
	glyph_color.a = 1.0
	return glyph_color


func _ascii_glyph_tint(base_color: Color, lit: bool) -> Color:
	var glyph_color: Color
	if lit:
		glyph_color = base_color.lerp(Color(1, 1, 1, 1), 0.12)
	else:
		glyph_color = base_color.lerp(Color(0.85, 0.85, 0.85, 1), 0.06)
	glyph_color.a = 1.0
	return glyph_color


# Returns [char, lit_color] for terrain tiles that support visual variation.
# Uses a deterministic hash of world coords — stable across frames and redraws.
# Returns ["", Color.WHITE] for unhandled tiles (caller uses its own defaults).
func _terrain_cell(tile: int, mx: int, my: int) -> Array:
	if not TERRAIN_VARIATION:
		return ["", Color.WHITE]
	# Avalanche hash — fully mixes both coords so no diagonal banding appears.
	var h: int = mx * 1836311903 ^ my * 2971215073
	h += h << 10
	h ^= h >> 6
	h += h << 3
	h ^= h >> 11
	h += h << 15
	h = abs(h) & 0x7FFFFFFF
	match tile:
		GameMapClass.TILE_GRASS:
			# All chars sit in the upper-mid region of the CP437 cell — no height mismatch.
			var idx: int = h % 4
			var chars := ["\"", "'", "\"", "'"]
			var colors := [
				Color(0.38, 0.73, 0.20),  # slightly darker
				Color(0.42, 0.78, 0.25),  # slightly brighter
				Color(0.40, 0.75, 0.22),  # base
				Color(0.36, 0.70, 0.18),  # more muted
			]
			return [chars[idx], colors[idx]]
		GameMapClass.TILE_DUNE:
			# All chars sit at mid-row in the CP437 cell — no height mismatch.
			var idx: int = h % 4
			var chars := ["~", "-", "~", "="]
			var colors := [
				Color(0.94, 0.68, 0.22),  # base
				Color(0.90, 0.64, 0.18),  # darker
				Color(0.97, 0.72, 0.26),  # lighter
				Color(0.92, 0.66, 0.20),  # mid-dark
			]
			return [chars[idx], colors[idx]]
		_:
			return ["", Color.WHITE]


func _ascii_cell_rect(x: int, y: int) -> Rect2:
	var cell_w: float = _map_cell_w()
	var cell_h: float = _map_cell_h()
	return Rect2(
		float(x) * cell_w - ASCII_BG_OVERDRAW_X,
		float(y) * cell_h - ASCII_BG_OVERDRAW_Y,
		cell_w + ASCII_BG_OVERDRAW_X * 2.0,
		cell_h + ASCII_BG_OVERDRAW_Y * 2.0
	)


func _tileset_cell_rect(x: int, y: int) -> Rect2:
	var cell_w: float = _map_cell_w()
	var cell_h: float = _map_cell_h()
	return Rect2(
		float(x) * cell_w - TILESET_BG_OVERDRAW,
		float(y) * cell_h - TILESET_BG_OVERDRAW,
		cell_w + TILESET_BG_OVERDRAW * 2.0,
		cell_h + TILESET_BG_OVERDRAW * 2.0
	)


func _draw_tileset_cell(x: int, y: int, tile: int, ch: String, base_color: Color, lit: bool, occupied: bool = false) -> void:
	var dest_rect := _tileset_cell_rect(x, y)
	var fill_color := _tileset_fill_color(tile, base_color, lit)
	draw_rect(dest_rect, fill_color)
	if not occupied:
		_put_map_fg(x, y, ch, _tileset_glyph_tint(base_color, lit))


func _draw_ascii_cell(x: int, y: int, tile: int, ch: String, base_color: Color, lit: bool, occupied: bool = false) -> void:
	var dest_rect := _ascii_cell_rect(x, y)
	var fill_color := _ascii_fill_color(tile, base_color, lit)
	draw_rect(dest_rect, fill_color)
	if not occupied:
		_put_map_fg(x, y, ch, _ascii_glyph_tint(base_color, lit))


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

	# Escape â€” always valid.
	if event.physical_keycode == KEY_ESCAPE:
		_screen = Screen.ESCAPE
		_escape_cursor = 0
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	# ? (shift+/) â€” help screen.
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
			if not _world.can_enter_world_map():
				_world.add_msg("Hostiles are too close. You need to get clear before checking the world map.")
				queue_redraw()
				return
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
	var should_highlight: bool = cell.x >= 0 and cell.y >= 0 and _map != null and _map.is_in_bounds(map_pos.x, map_pos.y)
	if _screen == Screen.NONE:
		_hover_active = should_highlight and _map.explored[map_pos.y][map_pos.x]
		if _hover_active:
			_hover_pos = map_pos
			_refresh_hover_path_preview()
		else:
			_hover_path.clear()
	elif _screen == Screen.WORLD_MAP:
		_hover_path.clear()
		var chunk := _world_map_chunk_at_pos(event.position)
		if chunk.x >= 0:
			_world_look_cursor = chunk
			queue_redraw()
	elif _screen == Screen.LOOK:
		_hover_active = false
		_hover_path.clear()
		if should_highlight and _map.explored[map_pos.y][map_pos.x]:
			_look_pos = map_pos
	elif _screen == Screen.TARGET:
		_hover_active = false
		_hover_path.clear()
		if should_highlight and _map.explored[map_pos.y][map_pos.x]:
			_target_pos = map_pos
	else:
		_hover_active = false
		_hover_path.clear()
	if _screen == Screen.NONE or _screen == Screen.LOOK or _screen == Screen.TARGET:
		queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if _screen in [Screen.NONE, Screen.LOOK, Screen.TARGET]:
			_set_chunk_zoom(1)
			get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if _screen in [Screen.NONE, Screen.LOOK, Screen.TARGET]:
			_set_chunk_zoom(-1)
			get_viewport().set_input_as_handled()
		return
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
		Screen.TRAVEL_EVENT:
			_handle_travel_event_mouse_click(event.position)
		Screen.WORLD_MAP:
			_handle_world_map_mouse_click(event.position)


func _mouse_cell(mouse_pos: Vector2) -> Vector2i:
	var rect := _map_px_rect()
	if not rect.has_point(mouse_pos):
		return Vector2i(-1, -1)
	return Vector2i(int(floor(mouse_pos.x / _map_cell_w())), int(floor(mouse_pos.y / _map_cell_h())))


func _mouse_in_control(mouse_pos: Vector2, control: Control) -> bool:
	return control != null and control.get_global_rect().has_point(mouse_pos)


func _screen_to_map(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x + _cam_x, cell.y + _cam_y)


func _handle_map_mouse_click(mouse_pos: Vector2) -> void:
	var cell := _mouse_cell(mouse_pos)
	if cell.x < 0 or cell.y < 0:
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
	if cell.x < 0 or cell.y < 0:
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
	queue_redraw()


func _cycle_target_candidate(step: int) -> void:
	_refresh_target_candidates()
	if _target_candidates.is_empty():
		return
	_target_candidate_index = wrapi(_target_candidate_index + step, 0, _target_candidates.size())
	_target_pos = (_target_candidates[_target_candidate_index] as ActorClass).pos
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
	queue_redraw()


func _handle_target_mouse_click(mouse_pos: Vector2) -> void:
	var cell := _mouse_cell(mouse_pos)
	if cell.x < 0 or cell.y < 0:
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
	return


func _handle_character_mouse_click(mouse_pos: Vector2) -> void:
	return


func _handle_help_mouse_click(mouse_pos: Vector2) -> void:
	return


func _handle_reader_mouse_click(mouse_pos: Vector2) -> void:
	return


func _handle_dialogue_mouse_click(mouse_pos: Vector2) -> void:
	return


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
	return


func _handle_inventory_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE or (key == KEY_I and not event.shift_pressed):
		_screen = Screen.NONE
		_sync_inventory_ui_visibility()
		queue_redraw()
		return

	# w/b/f/h/l â€” unequip slot (unshifted only).
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

	# aâ€“t â€” use / equip / read depending on item category (unshifted only).
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
	return


func _handle_attribute_pick_mouse_click(mouse_pos: Vector2) -> void:
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
		var vis_cols: int = _map_visible_cols()
		var vis_rows: int = _map_visible_rows()
		_cam_x = clampi(_look_pos.x - (vis_cols >> 1), 0, maxi(0, _map.width  - vis_cols))
		_cam_y = clampi(_look_pos.y - (vis_rows >> 1), 0, maxi(0, _map.height - vis_rows))
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
		GameMapClass.TILE_ROAD:       tile = "packed-dirt trade road"
		GameMapClass.TILE_CAVE_WALL:  tile = "rough cave wall"
		GameMapClass.TILE_CAVE_FLOOR: tile = "cave floor"
		_:                            tile = "unknown terrain"

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
	var vis_cols: int = _map_visible_cols()
	var vis_rows: int = _map_visible_rows()
	_cam_x = clampi(_player.pos.x - (vis_cols >> 1), 0, maxi(0, _map.width  - vis_cols))
	_cam_y = clampi(_player.pos.y - (vis_rows >> 1), 0, maxi(0, _map.height - vis_rows))


func _to_screen(mx: int, my: int) -> Vector2i:
	return Vector2i(mx - _cam_x, my - _cam_y)


func _on_screen(mx: int, my: int) -> bool:
	return mx >= _cam_x and mx < _cam_x + _map_visible_cols() \
	   and my >= _cam_y and my < _cam_y + _map_visible_rows()


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


func _handle_attribute_pick_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	for opt: Dictionary in ATTRIBUTE_OPTIONS:
		if event.physical_keycode == int(opt.key):
			if _world.apply_attribute_increase(str(opt.code)):
				_open_attribute_overlay_if_needed()
				queue_redraw()
			return


func _handle_travel_event_mouse_click(mouse_pos: Vector2) -> void:
	return


# ===========================================================================
# Rendering
# ===========================================================================

func _draw() -> void:
	_refresh_hud_ui()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_BG)
	if _screen == Screen.WORLD_MAP or _screen == Screen.TRAVEL_EVENT:
		_sync_world_tilemaps()
		_draw_world_map()
		return
	_sync_chunk_tilemaps()
	if _screen == Screen.NONE:
		_draw_hover_path_preview()
	elif _screen == Screen.TARGET:
		_draw_target_line_preview()
	if _screen == Screen.NONE:
		_draw_hover_cursor()
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
	var occupied_cells: Dictionary = _visible_entity_screen_positions()
	for vy in range(_map_visible_rows()):
		for vx in range(_map_visible_cols()):
			var mx := vx + _cam_x
			var my := vy + _cam_y
			if not _map.is_in_bounds(mx, my):
				continue
			if not _map.explored[my][mx]:
				if _tileset_active():
					draw_rect(_tileset_cell_rect(vx, vy), C_UNEXPLORED_TILESET)
				else:
					draw_rect(_ascii_cell_rect(vx, vy), C_BG)
				continue
			var tile: int = _map.tiles[my][mx]
			var lit: bool = _map.visible[my][mx]
			var ch: String = _map.get_glyph_override(mx, my)
			var color: Color
			match tile:
				GameMapClass.TILE_WALL:
					if ch == "":
						ch = "#"
					color = C_WALL_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_FLOOR:
					if ch == "":
						ch = "."
					color = C_FLOOR_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_SAND:
					if ch == "":
						ch = "."
					color = C_SAND_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_DUNE:
					if ch == "":
						var variant := _terrain_cell(tile, mx, my)
						ch = variant[0] if variant[0] != "" else "^"
						color = (variant[1] as Color) if lit else _tile_dim_color(tile)
					else:
						color = C_DUNE_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_ROCK:
					if ch == "":
						ch = "#"
					color = C_ROCK_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_WATER:
					if ch == "":
						ch = "~"
					color = C_WATER_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_GRASS:
					if ch == "":
						var variant := _terrain_cell(tile, mx, my)
						ch = variant[0] if variant[0] != "" else "\""
						color = (variant[1] as Color) if lit else _tile_dim_color(tile)
					else:
						color = C_GRASS_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_ROAD:
					if ch == "":
						ch = "\u2591"
					color = C_ROAD_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_CAVE_WALL:
					if ch == "":
						ch = "%"
					color = C_CAVE_WALL_LIT if lit else _tile_dim_color(tile)
				GameMapClass.TILE_CAVE_FLOOR:
					if ch == "":
						ch = "."
					color = C_CAVE_FLOOR_LIT if lit else _tile_dim_color(tile)
				_:
					if ch == "":
						ch = "?"
					color = Color.WHITE
			var tinted: Color = color * _day_tint
			if _tileset_active():
				_draw_tileset_cell(vx, vy, tile, ch, tinted, lit, occupied_cells.has(Vector2i(vx, vy)))
			else:
				_draw_ascii_cell(vx, vy, tile, ch, tinted, lit, occupied_cells.has(Vector2i(vx, vy)))


func _sync_chunk_tilemaps() -> void:
	if not _use_tilemap_renderer():
		_draw_map()
		_draw_entities()
		return
	_chunk_tile_root.visible = true
	_world_tile_root.visible = false
	var scale_value: float = _map_font_size() / float(TILESET_TILE_W)
	_chunk_tile_root.position = Vector2.ZERO
	_chunk_tile_root.scale = Vector2(scale_value, scale_value)
	_chunk_bg_layer.clear_with_modulates()
	_chunk_fg_layer.clear_with_modulates()
	# Entity layer: full clear only when camera moved (all screen-space coords shifted).
	# Otherwise erase only cells that previously held entities — saves O(visible_cells)
	# set_cell calls on stationary turns (waiting, inventory open, etc.).
	var cam_moved: bool = (_cam_x != _prev_cam_x or _cam_y != _prev_cam_y)
	if cam_moved:
		_chunk_entity_layer.clear_with_modulates()
		_prev_entity_cells.clear()
	else:
		for coords in _prev_entity_cells:
			_chunk_entity_layer.erase_cell_with_modulate(coords)
	_prev_cam_x = _cam_x
	_prev_cam_y = _cam_y
	_chunk_overlay_bg_layer.clear_with_modulates()
	_chunk_overlay_fg_layer.clear_with_modulates()

	var occupied_cells: Dictionary = _visible_entity_screen_positions()
	for vy in range(_map_visible_rows()):
		for vx in range(_map_visible_cols()):
			var mx := vx + _cam_x
			var my := vy + _cam_y
			if not _map.is_in_bounds(mx, my):
				continue
			var coords := Vector2i(vx, vy)
			if not _map.explored[my][mx]:
				_chunk_bg_layer.set_cell_with_modulate(coords, FILL_SOURCE_ID, Vector2i.ZERO, C_UNEXPLORED_TILESET)
				continue
			var tile: int = _map.tiles[my][mx]
			var lit: bool = _map.visible[my][mx]
			var ch: String = _map.get_glyph_override(mx, my)
			var base_color: Color
			if ch == "":
				match tile:
					GameMapClass.TILE_WALL:
						ch = "#" if _map.map_type == GameMapClass.MAP_DUNGEON else "^"
						base_color = C_WALL_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_FLOOR:
						ch = "."
						base_color = C_FLOOR_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_SAND:
						ch = "."
						base_color = C_SAND_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_DUNE:
						var variant := _terrain_cell(tile, mx, my)
						ch = variant[0] if variant[0] != "" else "^"
						base_color = (variant[1] as Color) if lit else _tile_dim_color(tile)
					GameMapClass.TILE_ROCK:
						ch = "#"
						base_color = C_ROCK_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_WATER:
						ch = "~"
						base_color = C_WATER_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_GRASS:
						var variant := _terrain_cell(tile, mx, my)
						ch = variant[0] if variant[0] != "" else "\""
						base_color = (variant[1] as Color) if lit else _tile_dim_color(tile)
					GameMapClass.TILE_ROAD:
						ch = "\u2591"
						base_color = C_ROAD_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_CAVE_WALL:
						ch = "%"
						base_color = C_CAVE_WALL_LIT if lit else _tile_dim_color(tile)
					GameMapClass.TILE_CAVE_FLOOR:
						ch = "."
						base_color = C_CAVE_FLOOR_LIT if lit else _tile_dim_color(tile)
					_:
						ch = "?"
						base_color = Color.WHITE
			else:
				base_color = C_WALL_LIT if lit else _tile_dim_color(tile)

			var fill_color := _tileset_fill_color(tile, base_color * _day_tint, lit)
			_chunk_bg_layer.set_cell_with_modulate(coords, FILL_SOURCE_ID, Vector2i.ZERO, fill_color)
			if not occupied_cells.has(coords):
				_chunk_fg_layer.set_cell_with_modulate(coords, TILE_SOURCE_ID, _glyph_atlas_coords(ch), _tileset_glyph_tint(base_color * _day_tint, lit))

	var cell_map: Dictionary = {}
	for e in _map.entities:
		if not _on_screen(e.pos.x, e.pos.y) or not _map.visible[e.pos.y][e.pos.x]:
			continue
		var sp := _to_screen(e.pos.x, e.pos.y)
		var key := Vector2i(sp.x, sp.y)
		if not cell_map.has(key):
			cell_map[key] = []
		(cell_map[key] as Array).append(e)

	var new_entity_cells: Array[Vector2i] = []
	for key in cell_map:
		# Skip cells whose tile is owned by an in-progress bump animation.
		if _bump_suppressed.has(key):
			continue
		var e = _display_entity_for_cell(cell_map[key] as Array)
		if e == null:
			continue
		_chunk_entity_layer.set_cell_with_modulate(
			key,
			TILE_SOURCE_ID,
			_glyph_atlas_coords(_entity_glyph(e)),
			_tileset_glyph_tint(e.color * _day_tint, true)
		)
		new_entity_cells.append(key)
	_prev_entity_cells = new_entity_cells

	if _screen == Screen.LOOK and _on_screen(_look_pos.x, _look_pos.y):
		var sp := _to_screen(_look_pos.x, _look_pos.y)
		_chunk_overlay_bg_layer.set_cell_with_modulate(Vector2i(sp.x, sp.y), FILL_SOURCE_ID, Vector2i.ZERO, Color(0.20, 0.75, 0.90, 0.40))
	elif _screen == Screen.TARGET and _on_screen(_target_pos.x, _target_pos.y):
		var tsp := _to_screen(_target_pos.x, _target_pos.y)
		_chunk_overlay_bg_layer.set_cell_with_modulate(Vector2i(tsp.x, tsp.y), FILL_SOURCE_ID, Vector2i.ZERO, Color(0.92, 0.28, 0.12, 0.42))
	elif _screen == Screen.NONE and _hover_active and _on_screen(_hover_pos.x, _hover_pos.y) and _auto_move_mode == AutoMoveMode.NONE:
		var hsp := _to_screen(_hover_pos.x, _hover_pos.y)
		_chunk_overlay_bg_layer.set_cell_with_modulate(Vector2i(hsp.x, hsp.y), FILL_SOURCE_ID, Vector2i.ZERO, Color(0.85, 0.72, 0.20, 0.24))

	if _screen == Screen.NONE and _auto_move_mode == AutoMoveMode.NONE:
		for step in _hover_path:
			if not _on_screen(step.x, step.y):
				continue
			var sp := _to_screen(step.x, step.y)
			var glyph := "X" if step == _hover_pos else "•"
			var color := Color(0.96, 0.96, 0.92, 0.86) if step == _hover_pos else Color(0.90, 0.90, 0.86, 0.62)
			_chunk_overlay_fg_layer.set_cell_with_modulate(Vector2i(sp.x, sp.y), TILE_SOURCE_ID, _glyph_atlas_coords(glyph), color)
	elif _screen == Screen.TARGET:
		var preview: Dictionary = _target_preview_validity()
		var line: Array = preview.get("line", [])
		var line_color: Color = Color(0.90, 0.94, 1.00, 0.62) if bool(preview.get("valid", false)) else Color(0.90, 0.32, 0.22, 0.68)
		for point in line:
			if point == _player.pos or not _on_screen(point.x, point.y):
				continue
			var sp := _to_screen(point.x, point.y)
			var glyph := "X" if point == _target_pos else "•"
			_chunk_overlay_fg_layer.set_cell_with_modulate(Vector2i(sp.x, sp.y), TILE_SOURCE_ID, _glyph_atlas_coords(glyph), line_color)

	_chunk_bg_layer.notify_runtime_tile_data_update()
	_chunk_fg_layer.notify_runtime_tile_data_update()
	_chunk_entity_layer.notify_runtime_tile_data_update()
	_chunk_overlay_bg_layer.notify_runtime_tile_data_update()
	_chunk_overlay_fg_layer.notify_runtime_tile_data_update()


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
		if _tileset_active():
			_put_map_fg(sp.x, sp.y, _entity_glyph(e), _tileset_glyph_tint(e.color * _day_tint, true))
		else:
			_put_map_fg(sp.x, sp.y, _entity_glyph(e), _ascii_glyph_tint(e.color * _day_tint, true))


func _visible_entity_screen_positions() -> Dictionary:
	var occupied: Dictionary = {}
	for e in _map.entities:
		if not _on_screen(e.pos.x, e.pos.y) or not _map.visible[e.pos.y][e.pos.x]:
			continue
		var sp := _to_screen(e.pos.x, e.pos.y)
		occupied[Vector2i(sp.x, sp.y)] = true
	return occupied


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


func _sky_track() -> String:
	const TRACK_LEN: int = 17
	var t: float = _world.time_of_day
	var is_night: bool = _world.is_night
	var body: String = "o" if is_night else "☼"
	var travel_t: float
	if is_night:
		travel_t = (t + 0.20) / 0.40 if t < 0.20 else (t - 0.80) / 0.40
	else:
		travel_t = (t - 0.20) / 0.60
	travel_t = clampf(travel_t, 0.0, 1.0)
	var pos: int = int(round(travel_t * float(TRACK_LEN - 1)))
	var track := ""
	for i in range(TRACK_LEN):
		track += body if i == pos else "-"
	return "[%s]" % track


func _sidebar_target_enemy():
	if _world == null or _map == null:
		return null
	var best = null
	var best_dist: int = 999999
	for e in _map.entities:
		if not (e is ActorClass) or e == _player:
			continue
		if e.ai == null or e.ai.get_script() == null or str(e.ai.get_script().resource_path) != "res://scripts/components/hostile_ai.gd":
			continue
		if not _map.visible[e.pos.y][e.pos.x]:
			continue
		var dist: int = maxi(absi(e.pos.x - _player.pos.x), absi(e.pos.y - _player.pos.y))
		if dist < best_dist:
			best = e
			best_dist = dist
	return best


func _sidebar_hp_bar(actor: ActorClass) -> String:
	if actor == null or actor.max_hp <= 0:
		return "[-----]"
	const BAR_LEN: int = 5
	var filled: int = int(round((float(actor.hp) / float(actor.max_hp)) * float(BAR_LEN)))
	filled = clampi(filled, 0, BAR_LEN)
	return "[%s%s]" % ["#".repeat(filled), "-".repeat(BAR_LEN - filled)]


func _sidebar_nearby_hostiles() -> Array[String]:
	var lines: Array[String] = []
	if _world == null or _map == null:
		return lines
	var hostiles: Array = []
	for e in _map.entities:
		if not (e is ActorClass) or e == _player:
			continue
		if e.ai == null or e.ai.get_script() == null or str(e.ai.get_script().resource_path) != "res://scripts/components/hostile_ai.gd":
			continue
		if not _map.visible[e.pos.y][e.pos.x]:
			continue
		var dist: int = maxi(absi(e.pos.x - _player.pos.x), absi(e.pos.y - _player.pos.y))
		hostiles.append({"actor": e, "dist": dist})
	hostiles.sort_custom(func(a, b): return int(a.dist) < int(b.dist))
	for i in range(mini(4, hostiles.size())):
		var actor: ActorClass = hostiles[i].actor as ActorClass
		var dist: int = int(hostiles[i].dist)
		lines.append("%s (%d)" % [str(actor.name).capitalize(), dist])
	return lines


func _target_description() -> String:
	var weapon = _world.get_equipped_ranged_weapon()
	if weapon == null:
		return "No ranged weapon readied."
	var ammo = _world.get_matching_ammo(weapon)
	var range_str := "range %d" % int((weapon as ItemClass).weapon_range)
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
# Overlay: look mode
# ---------------------------------------------------------------------------
func _draw_look_cursor() -> void:
	if _use_tilemap_renderer():
		return
	var sp := _to_screen(_look_pos.x, _look_pos.y)
	draw_rect(
		Rect2(sp.x * _map_cell_w(), sp.y * _map_cell_h(), _map_cell_w(), _map_cell_h()),
		Color(0.20, 0.75, 0.90, 0.40)
	)


func _draw_target_cursor() -> void:
	if _use_tilemap_renderer():
		return
	if not _on_screen(_target_pos.x, _target_pos.y):
		return
	var sp := _to_screen(_target_pos.x, _target_pos.y)
	draw_rect(
		Rect2(sp.x * _map_cell_w(), sp.y * _map_cell_h(), _map_cell_w(), _map_cell_h()),
		Color(0.92, 0.28, 0.12, 0.42)
	)


func _draw_hover_cursor() -> void:
	if _use_tilemap_renderer():
		return
	if _auto_move_mode != AutoMoveMode.NONE or not _hover_active or not _on_screen(_hover_pos.x, _hover_pos.y):
		return
	var sp := _to_screen(_hover_pos.x, _hover_pos.y)
	draw_rect(
		Rect2(sp.x * _map_cell_w(), sp.y * _map_cell_h(), _map_cell_w(), _map_cell_h()),
		Color(0.85, 0.72, 0.20, 0.24)
	)


func _refresh_hover_path_preview() -> void:
	_hover_path.clear()
	if _auto_move_mode != AutoMoveMode.NONE or _screen != Screen.NONE or not _hover_active or _world == null or _map == null:
		return
	if _hover_pos == _player.pos:
		return
	if not _map.is_in_bounds(_hover_pos.x, _hover_pos.y) or not _map.explored[_hover_pos.y][_hover_pos.x]:
		return
	if not _map.is_walkable(_hover_pos.x, _hover_pos.y):
		return
	var blocker = _map.get_blocking_entity_at(_hover_pos.x, _hover_pos.y)
	if blocker != null and blocker != _player:
		return
	_hover_path = _world._path_to(_hover_pos, true)


func _draw_hover_path_preview() -> void:
	if _use_tilemap_renderer():
		return
	if _auto_move_mode != AutoMoveMode.NONE or _hover_path.is_empty():
		return
	for step in _hover_path:
		if not _on_screen(step.x, step.y):
			continue
		var sp := _to_screen(step.x, step.y)
		var glyph := "X" if step == _hover_pos else "â€¢"
		var color := Color(0.96, 0.96, 0.92, 0.86) if step == _hover_pos else Color(0.90, 0.90, 0.86, 0.62)
		_put_map_fg(sp.x, sp.y, glyph, color)


func _target_preview_validity() -> Dictionary:
	var result := {"line": [], "valid": false}
	if _world == null or _map == null or not _map.is_in_bounds(_target_pos.x, _target_pos.y):
		return result
	var weapon = _world.get_equipped_ranged_weapon()
	if weapon == null:
		return result
	var line: Array = _world._bresenham_line(_player.pos, _target_pos)
	result.line = line
	if _world._cheb(_player.pos, _target_pos) > int((weapon as ItemClass).weapon_range):
		return result
	for i in range(1, line.size()):
		var pos: Vector2i = line[i]
		if not _map.is_in_bounds(pos.x, pos.y):
			return result
		if not _map.is_transparent(pos.x, pos.y):
			if pos == _target_pos:
				result.valid = true
			return result
		var actor_on_tile = _map.get_blocking_entity_at(pos.x, pos.y)
		if actor_on_tile is ActorClass and actor_on_tile != _player and (actor_on_tile as ActorClass).is_alive:
			result.valid = pos == _target_pos
			return result
	result.valid = true
	return result


func _draw_target_line_preview() -> void:
	if _use_tilemap_renderer():
		return
	var preview: Dictionary = _target_preview_validity()
	var line: Array = preview.get("line", [])
	if line.is_empty():
		return
	var line_color: Color = Color(0.90, 0.94, 1.00, 0.62) if bool(preview.get("valid", false)) else Color(0.90, 0.32, 0.22, 0.68)
	for point in line:
		if point == _player.pos or not _on_screen(point.x, point.y):
			continue
		var sp := _to_screen(point.x, point.y)
		var glyph := "X" if point == _target_pos else "â€¢"
		_put_map_fg(sp.x, sp.y, glyph, line_color)

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
			return "%s %s  %s  rng %d" % [item.damage_label(), item.enhancement_label(), item.ammo_type.replace("_", " "), item.weapon_range]
		if item.slot == ItemClass.SLOT_WEAPON:
			return "%s %s  rng %d" % [item.damage_label(), item.enhancement_label(), item.weapon_range]
		if item.defense_bonus > 0:
			return "+%d def" % item.defense_bonus
		if item.slot == ItemClass.SLOT_LIGHT and item.burn_turns > 0:
			return "%dt left" % item.value
		return "equip"
	if item.category == ItemClass.CATEGORY_AMMO:
		return "ammo %s" % item.enhancement_label()
	if item.category == ItemClass.CATEGORY_USABLE:
		return item.dice_label()
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
	return


func _handle_trade_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _trade_npc == null:
		_screen = Screen.NONE
		queue_redraw()
		return
	var npc: NpcClass = _trade_npc as NpcClass
	var key: int = event.physical_keycode
	var sellable: Array = _build_sellable()
	var buy_count: int = npc.trade_stock.size()
	var sell_count: int = sellable.size()

	if key == KEY_ESCAPE:
		_screen = Screen.NONE
		queue_redraw()
		return

	if key == KEY_TAB:
		_trade_panel = 1 - _trade_panel
		if _trade_panel == 0 and buy_count > 0:
			_trade_buy_cursor = clampi(_trade_buy_cursor, 0, buy_count - 1)
		elif _trade_panel == 1 and sell_count > 0:
			_trade_sell_cursor = clampi(_trade_sell_cursor, 0, sell_count - 1)
		queue_redraw()
		return

	match key:
		KEY_UP, KEY_KP_8:
			if _trade_panel == 0 and buy_count > 0:
				_trade_buy_cursor = wrapi(_trade_buy_cursor - 1, 0, buy_count)
			elif _trade_panel == 1 and sell_count > 0:
				_trade_sell_cursor = wrapi(_trade_sell_cursor - 1, 0, sell_count)
			queue_redraw()
			return
		KEY_DOWN, KEY_KP_2:
			if _trade_panel == 0 and buy_count > 0:
				_trade_buy_cursor = wrapi(_trade_buy_cursor + 1, 0, buy_count)
			elif _trade_panel == 1 and sell_count > 0:
				_trade_sell_cursor = wrapi(_trade_sell_cursor + 1, 0, sell_count)
			queue_redraw()
			return
		KEY_LEFT, KEY_KP_4:
			_trade_panel = 0
			if buy_count > 0:
				_trade_buy_cursor = clampi(_trade_buy_cursor, 0, buy_count - 1)
			queue_redraw()
			return
		KEY_RIGHT, KEY_KP_6:
			_trade_panel = 1
			if sell_count > 0:
				_trade_sell_cursor = clampi(_trade_sell_cursor, 0, sell_count - 1)
			queue_redraw()
			return
		KEY_ENTER, KEY_KP_ENTER:
			if _trade_panel == 0 and buy_count > 0:
				_trade_buy(_trade_buy_cursor)
			elif _trade_panel == 1 and sell_count > 0:
				_trade_sell(_trade_sell_cursor)
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
		GameMapClass.BIOME_DESERT:    return "\u00B7"   # · bare sand
		GameMapClass.BIOME_OASIS:     return "\u2248"   # ≈ water / lush
		GameMapClass.BIOME_STEPPES:   return "\""       # " grass / steppe
		GameMapClass.BIOME_MOUNTAINS: return "^"        # ^ mountains
		GameMapClass.BIOME_BADLANDS:  return "%"        # % rocky rubble
		_:                            return "?"


func _biome_color(biome: int) -> Color:
	match biome:
		GameMapClass.BIOME_DESERT:    return Color(0.85, 0.70, 0.35)
		GameMapClass.BIOME_OASIS:     return Color(0.22, 0.72, 0.50)
		GameMapClass.BIOME_STEPPES:   return Color(0.42, 0.72, 0.20)
		GameMapClass.BIOME_MOUNTAINS: return Color(0.62, 0.56, 0.48)
		GameMapClass.BIOME_BADLANDS:  return Color(0.72, 0.44, 0.18)
		_:                            return Color(0.4, 0.4, 0.4)


func _sync_world_tilemaps() -> void:
	if not _use_tilemap_renderer():
		_chunk_tile_root.visible = false
		_world_tile_root.visible = false
		return
	_chunk_tile_root.visible = false
	_world_tile_root.visible = true
	var map_px_w: float = _chunk_view_px_w()
	var map_px_y: float = _map_cell_h() * 2.0
	var map_px_h: float = _divider_y_px() - map_px_y
	var cell_w: float = map_px_w / float(GameState.WORLD_W)
	var cell_h: float = map_px_h / float(GameState.WORLD_H)
	var new_scale := Vector2(cell_w / float(TILESET_TILE_W), cell_h / float(TILESET_TILE_H))
	_world_tile_root.position = Vector2(0.0, map_px_y)
	_world_tile_root.scale = new_scale

	var mount = _world.get_player_mount()
	var current_chunk_char: String = "@"
	var current_chunk_color: Color = Color(0.80, 0.72, 0.55)
	if mount != null and (_mount_cycle_bucket % 2 == 0):
		current_chunk_char = mount.char as String
		current_chunk_color = mount.color
	elif mount != null:
		current_chunk_color = Color(0.95, 0.80, 0.40)

	# Full repaint when viewport scale changed (resize) or first time showing.
	var scale_changed: bool = new_scale != _wm_last_scale
	if scale_changed:
		_world_bg_layer.clear_with_modulates()
		_world_fg_layer.clear_with_modulates()
		_world_overlay_layer.clear_with_modulates()
		for cy in range(GameState.WORLD_H):
			for cx in range(GameState.WORLD_W):
				_wm_paint_cell(cx, cy, current_chunk_char, current_chunk_color)
		_wm_last_scale = new_scale
	else:
		# Incremental: repaint only the cells that could have changed.
		# Collect unique coords to touch using a temp Dictionary as a set.
		var dirty: Dictionary = {}
		dirty[_chunk] = true
		dirty[_wm_prev_chunk] = true
		if _world_look_mode or _wm_prev_look_mode:
			dirty[_world_look_cursor] = true
			dirty[_wm_prev_look_cursor] = true
		for coords: Vector2i in dirty:
			if coords.x >= 0 and coords.y >= 0 and coords.x < GameState.WORLD_W and coords.y < GameState.WORLD_H:
				_wm_paint_cell(coords.x, coords.y, current_chunk_char, current_chunk_color)

	_wm_prev_chunk = _chunk
	_wm_prev_look_cursor = _world_look_cursor
	_wm_prev_look_mode = _world_look_mode

	_world_bg_layer.notify_runtime_tile_data_update()
	_world_fg_layer.notify_runtime_tile_data_update()
	_world_overlay_layer.notify_runtime_tile_data_update()


# Paint a single world-map cell. Called for both full and incremental repaints.
func _wm_paint_cell(cx: int, cy: int, current_chunk_char: String, current_chunk_color: Color) -> void:
	var coords := Vector2i(cx, cy)
	var this_chunk := Vector2i(cx, cy)
	var is_current: bool = this_chunk == _chunk
	var is_lk_curs: bool = _world_look_mode and this_chunk == _world_look_cursor
	var ch: String
	var color: Color
	var village: Variant = _world.get_village_at_chunk(cx, cy)

	if village != null:
		ch = "\u2302"  # ⌂ house symbol
		color = C_VILLAGE_WM
	elif _world.is_road_chunk(cx, cy):
		ch = "\u2261"  # ≡ road markings
		color = Color(0.70, 0.55, 0.32)
	else:
		var biome: int = _world.get_chunk_biome(this_chunk)
		ch = _biome_char(biome)
		color = _biome_color(biome)

	if is_current:
		ch = current_chunk_char
		color = Color(0.95, 0.80, 0.40) if is_lk_curs else current_chunk_color

	var cell_bg: Color = color.lerp(C_BG, 0.70)
	if is_lk_curs:
		cell_bg = Color(0.20, 0.16, 0.10, 0.96)
	elif is_current:
		cell_bg = Color(0.17, 0.13, 0.08, 0.92)

	_world_bg_layer.set_cell_with_modulate(coords, FILL_SOURCE_ID, Vector2i.ZERO, cell_bg)
	_world_fg_layer.set_cell_with_modulate(coords, TILE_SOURCE_ID, _glyph_atlas_coords(ch), color)
	_world_overlay_layer.erase_cell_with_modulate(coords)
	if is_lk_curs:
		_world_overlay_layer.set_cell_with_modulate(coords, FILL_SOURCE_ID, Vector2i.ZERO, Color(0.85, 0.70, 0.32, 0.18))
	elif is_current:
		_world_overlay_layer.set_cell_with_modulate(coords, FILL_SOURCE_ID, Vector2i.ZERO, Color(0.78, 0.62, 0.22, 0.12))


func _draw_world_map() -> void:
	var title_str := "-=[ WORLD MAP - LOOK ]=-" if _world_look_mode else "-=[ WORLD MAP ]=-"
	var map_px_w: float = _chunk_view_px_w()
	var row_y: float = UI_FONT_SIZE  # same baseline as _puts at row 0
	var title_px_w: float = _font.get_string_size(title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE).x
	draw_string(_font, Vector2((map_px_w - title_px_w) * 0.5, row_y),
			title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE, C_STATUS)
	var world_move_hint := "Chunk Travel: %d" % _world.get_world_map_travel_cost(_chunk)
	var hint_px_w: float = _font.get_string_size(world_move_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE).x
	draw_string(_font, Vector2(map_px_w - hint_px_w - CELL_W, row_y),
			world_move_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE, C_DIVIDER)


func _world_map_chunk_at_pos(mouse_pos: Vector2) -> Vector2i:
	var map_px_w: float = _chunk_view_px_w()
	var map_px_y: float = _map_cell_h() * 2.0
	var map_px_h: float = _divider_y_px() - map_px_y
	if mouse_pos.x < 0.0 or mouse_pos.x >= map_px_w:
		return Vector2i(-1, -1)
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


func _put_map(x: int, y: int, ch: String, color: Color) -> void:
	if _tileset_active():
		_put_map_fg(x, y, ch, color)
		return
	_put_map_fg(x, y, ch, color)


func _put_map_fg(x: int, y: int, ch: String, color: Color) -> void:
	if _tileset_active():
		_put_map_tile(x, y, ch, color)
		return
	if _ascii_atlas_active():
		_put_map_atlas_glyph(x, y, ch, color)
		return
	var cell_w: float = _map_cell_w()
	var cell_h: float = _map_cell_h()
	var metrics: Dictionary = _glyph_draw_metrics(ch)
	var font_size: int = maxi(8, int(round(minf(cell_w, cell_h) * float(metrics.get("scale", 0.92)))))
	var px: float = float(x) * cell_w
	var py: float = float(y) * cell_h
	var font_h: float = _font.get_height(font_size)
	var baseline_y: float = py + floor((cell_h - font_h) * 0.5) + font_size + float(metrics.get("y", 0.0))
	var glyph_w: float = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var draw_x: float = px + floor((cell_w - glyph_w) * 0.5) + float(metrics.get("x", 0.0))
	draw_string(_font, Vector2(draw_x, baseline_y), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _put_map_atlas_glyph(x: int, y: int, ch: String, color: Color) -> void:
	var cell_w: float = _map_cell_w()
	var cell_h: float = _map_cell_h()
	var metrics: Dictionary = _glyph_draw_metrics(ch)
	var glyph_size: float = floor(minf(cell_w, cell_h) * float(metrics.get("scale", 0.92)))
	var dest_rect := Rect2(
		float(x) * cell_w + floor((cell_w - glyph_size) * 0.5) + float(metrics.get("x", 0.0)),
		float(y) * cell_h + floor((cell_h - glyph_size) * 0.5) + float(metrics.get("y", 0.0)),
		glyph_size,
		glyph_size
	)
	draw_texture_rect_region(_ascii_atlas, dest_rect, _glyph_region(ch), color, false, true)


func _glyph_draw_metrics(ch: String) -> Dictionary:
	match ch:
		"#":
			return {"scale": 1.10, "x": 0.0, "y": -1.0}
		"^":
			return {"scale": 1.00, "x": 0.0, "y": -1.0}
		".":
			return {"scale": 0.92, "x": 0.0, "y": 0.0}
		"~":
			return {"scale": 0.98, "x": 0.0, "y": 0.0}
		"≈":
			return {"scale": 0.98, "x": 0.0, "y": 0.0}
		"≡":
			return {"scale": 1.00, "x": 0.0, "y": 0.0}
		"·":
			return {"scale": 0.80, "x": 0.0, "y": 2.0}
		"⌂":
			return {"scale": 0.90, "x": 0.0, "y": -1.0}
		"%":
			return {"scale": 0.96, "x": 0.0, "y": 0.0}
		"=":
			return {"scale": 1.00, "x": 0.0, "y": 0.0}
		"═":
			return {"scale": 1.00, "x": 0.0, "y": 0.0}
		"║":
			return {"scale": 1.00, "x": 0.0, "y": 0.0}
		"╔", "╗", "╚", "╝":
			return {"scale": 1.00, "x": 0.0, "y": 0.0}
		"@":
			return {"scale": 1.02, "x": 0.0, "y": -1.0}
		"☺", "☻":
			return {"scale": 1.02, "x": 0.0, "y": -1.0}
		_:
			return {"scale": 0.92, "x": 0.0, "y": 0.0}


func _glyph_region(ch: String) -> Rect2:
	var cp437_index: int = _cp437_index_for_glyph(ch)
	var col: int = posmod(cp437_index, TILESET_COLS)
	var row: int = cp437_index / TILESET_COLS
	return Rect2(
		float(col * TILESET_TILE_W),
		float(row * TILESET_TILE_H),
		float(TILESET_TILE_W),
		float(TILESET_TILE_H)
	)


func _glyph_atlas_coords(ch: String) -> Vector2i:
	var cp437_index: int = _cp437_index_for_glyph(ch)
	return Vector2i(posmod(cp437_index, TILESET_COLS), cp437_index / TILESET_COLS)


func _cp437_index_for_glyph(ch: String) -> int:
	if ch.is_empty():
		return 63
	var codepoint: int = ch.unicode_at(0)
	match codepoint:
		0x263A:
			return 1
		0x263B:
			return 2
		0x2022:
			return 7
		0x266A:
			return 13
		0x266B:
			return 14
		0x263C:
			return 15
		0x2591:
			return 176
		0x2592:
			return 177
		0x2593:
			return 178
		0x2550:
			return 205
		0x2551:
			return 186
		0x2554:
			return 201
		0x2557:
			return 187
		0x255A:
			return 200
		0x255D:
			return 188
		0x03B1:
			return 224
		0x0393:
			return 226
		0x03C0:
			return 227
		0x03A3:
			return 228
		0x03C3:
			return 229
		0x03C4:
			return 231
		0x03A6:
			return 232
		0x0398:
			return 233
		0x03A9:
			return 234
		0x03B4:
			return 235
		0x221E:
			return 236
		0x00B1:
			return 241
		0x2265:
			return 242
		0x2264:
			return 243
		0x00F7:
			return 246
		0x2248:
			return 247  # ≈ almost-equal / water
		0x2261:
			return 240  # ≡ triple-bar / road
		0x00B7:
			return 250  # · middle dot / sand
		0x2302:
			return 127  # ⌂ house / village
		0x2663:
			return 5    # ♣ clubs / oasis vegetation
		0x221A:
			return 251
		_:
			if codepoint >= 0 and codepoint <= 127:
				return codepoint
			return 63


func _put_map_tile(x: int, y: int, ch: String, color: Color) -> void:
	var dest_rect := Rect2(
		float(x) * _map_cell_w(),
		float(y) * _map_cell_h(),
		_map_cell_w(),
		_map_cell_h()
	)
	var src_rect := _glyph_region(ch)
	draw_texture_rect_region(_tileset, dest_rect, src_rect, color, false, true)


func _entity_glyph(entity) -> String:
	if entity == null:
		return "?"
	if _tileset_active() and entity.tileset_char != "":
		return entity.tileset_char
	return str(entity.char)


func _put(x: int, y: int, ch: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + FONT_SIZE),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _puts(x: int, y: int, text: String, color: Color) -> void:
	draw_string(_font, Vector2(x * CELL_W, y * CELL_H + UI_FONT_SIZE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_FONT_SIZE, color)


func _puts_centered(row: int, text: String, color: Color) -> void:
	_puts((COLS - text.length()) >> 1, row, text, color)
