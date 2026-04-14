extends Node

# Persists across scene changes. Set before transitioning to the game scene.
var load_save: bool = false

# Player preferences — persist for the session.
var auto_pickup: bool = false
var god_mode: bool    = false
var debug_tools_enabled: bool = false
var use_tileset: bool = true
const FONT_PROFILE_BIOS := "bios"
const FONT_PROFILE_VGA_9X14 := "vga_9x14"
var font_profile: String = FONT_PROFILE_BIOS

# Fixed seed for the entire world — set once on new game, saved to disk.
# All overworld chunk noise uses this seed so terrain is seamless across borders.
var world_seed: int = 0

# Character — set during character creation, persisted in save.
var player_name:  String = "Wanderer"
var player_class: String = "Wanderer"  # stub for future class system

# World map dimensions (number of overworld chunks in each direction).
const WORLD_W := 60
const WORLD_H := 36

# Biome grid — [WORLD_H][WORLD_W] of int (BIOME_* constants from GameMap).
# Not saved: regenerated deterministically from world_seed on every load.
var world_biomes: Array = []
# Village list — [{cx, cy, name}]. Regenerated from world_seed on load.
var villages: Array = []
# Road chunks — "cx,cy" string keys. Regenerated from world_seed on load.
var road_chunks: Dictionary = {}


func current_font_path() -> String:
	match font_profile:
		FONT_PROFILE_VGA_9X14:
			return "res://assets/fonts/Px437_IBM_VGA_9x14.ttf"
		_:
			return "res://assets/fonts/Px437_IBM_BIOS.ttf"


func current_font_label() -> String:
	match font_profile:
		FONT_PROFILE_VGA_9X14:
			return "IBM VGA 9x14"
		_:
			return "IBM BIOS"


func current_map_zoom_sizes() -> Array:
	match font_profile:
		FONT_PROFILE_VGA_9X14:
			return [14, 16, 18, 20, 24, 28]
		_:
			return [16, 18, 20, 24, 28, 32]


func toggle_font_profile() -> void:
	font_profile = FONT_PROFILE_VGA_9X14 if font_profile == FONT_PROFILE_BIOS else FONT_PROFILE_BIOS
