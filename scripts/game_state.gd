extends Node

# Persists across scene changes. Set before transitioning to the game scene.
var load_save: bool = false

# Player preferences — persist for the session.
var auto_pickup: bool = false
