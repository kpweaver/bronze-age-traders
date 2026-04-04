extends Node

# Persists across scene changes. Set before transitioning to the game scene.
var load_save: bool = false

# Player preferences — persist for the session.
var auto_pickup: bool = false
var god_mode: bool    = false

# Fixed seed for the entire world — set once on new game, saved to disk.
# All overworld chunk noise uses this seed so terrain is seamless across borders.
var world_seed: int = 0

# World map dimensions (number of overworld chunks in each direction).
const WORLD_W := 32
const WORLD_H := 20

# Biome grid — [WORLD_H][WORLD_W] of int (BIOME_* constants from GameMap).
# Not saved: regenerated deterministically from world_seed on every load.
var world_biomes: Array = []
