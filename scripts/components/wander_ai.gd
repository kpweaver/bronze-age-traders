class_name WanderAI
extends "res://scripts/components/ai_base.gd"

# Peaceful wandering AI for village NPCs.
# Each turn the NPC takes a random walkable step within wander_radius of its
# home_pos.  It only moves when visible to the player (saves processing and
# looks more natural — you see them actually moving around).
#
# diurnal: when true the NPC rests at night instead of wandering.
# GameWorld.do_enemy_turns() updates world_is_night each turn.

const GameMapClass = preload("res://scripts/map/game_map.gd")

# How often the NPC moves: 1.0 = every visible turn, 0.33 = roughly 1-in-3.
var move_chance: float = 0.40
# Set by GameWorld before each AI tick so NPCs can react to time of day.
var world_is_night: bool = false
# When true the NPC stays near home_pos at night rather than wandering.
var diurnal: bool = true


func _init(p_actor, p_move_chance: float = 0.40, p_diurnal: bool = true) -> void:
	super._init(p_actor)
	move_chance = p_move_chance
	diurnal     = p_diurnal


func take_turn(player, game_map) -> String:
	# Only animate when the player can see the NPC.
	if not game_map.visible[actor.pos.y][actor.pos.x]:
		return ""

	# Diurnal NPCs stay put at night (they're indoors / asleep).
	if diurnal and world_is_night:
		return ""

	if randf() > move_chance:
		return ""

	# Build list of valid candidate tiles:
	#   • walkable
	#   • not blocked by another entity
	#   • within wander_radius of home_pos (Chebyshev distance)
	var candidates: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var dir := Vector2i(dx, dy)
			if world != null and game_map.map_type == GameMapClass.MAP_OVERWORLD:
				var step: Dictionary = world.get_overworld_step_option(actor, dir, true)
				if not step.is_empty():
					candidates.append(dir)
				continue
			var nx: int = actor.pos.x + dx
			var ny: int = actor.pos.y + dy
			if not game_map.is_in_bounds(nx, ny):
				continue
			if not game_map.is_walkable(nx, ny):
				continue
			if game_map.get_blocking_entity_at(nx, ny) != null:
				continue
			# Stay within wander_radius of home.
			var cheb: int = maxi(absi(nx - actor.home_pos.x), absi(ny - actor.home_pos.y))
			if cheb > actor.wander_radius:
				continue
			candidates.append(dir)

	if candidates.is_empty():
		return ""

	var chosen: Vector2i = candidates[randi() % candidates.size()]
	if world != null and game_map.map_type == GameMapClass.MAP_OVERWORLD:
		world.move_overworld_actor(actor, chosen, true)
	else:
		game_map.move_entity(actor, actor.pos + chosen)
	return ""
