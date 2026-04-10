class_name DocileAI
extends "res://scripts/components/ai_base.gd"

# Docile AI — wanders peacefully; flees permanently once damaged.
# Used by wildlife and non-merchant village NPCs.
#
# Docile state:  random walk within actor.wander_radius, gated by move_chance
#                and the diurnal flag (diurnal=true → stays put at night).
# Fleeing state: each turn moves to the adjacent walkable tile that maximises
#                Chebyshev distance from the player.  Never reverts to docile.
#
# HP comparison is the trigger — no signals or external state needed.

const GameMapClass = preload("res://scripts/map/game_map.gd")

var move_chance:    float = 0.35
var diurnal:        bool  = false  # false = active day and night (default for wildlife)
var world_is_night: bool  = false  # written by GameWorld before each AI tick

var _last_hp: int  = -1
var _fleeing: bool = false


func _init(p_actor, p_move_chance: float = 0.35, p_diurnal: bool = false) -> void:
	super._init(p_actor)
	move_chance = p_move_chance
	diurnal     = p_diurnal
	_last_hp    = p_actor.hp


func take_turn(player, game_map) -> String:
	if not actor.is_alive:
		return ""

	# Only animate when visible — consistent with WanderAI, prevents off-screen churn.
	# Still update _last_hp so off-screen damage triggers flee next time seen.
	if not game_map.visible[actor.pos.y][actor.pos.x]:
		_last_hp = actor.hp
		return ""

	# Damage since last tick → enter flee mode permanently.
	if _last_hp > 0 and actor.hp < _last_hp:
		_fleeing = true
	_last_hp = actor.hp

	if _fleeing:
		return _do_flee(player, game_map)

	if diurnal and world_is_night:
		return ""

	if randf() > move_chance:
		return ""

	return _do_wander(game_map)


# ---------------------------------------------------------------------------
# Wander — same logic as WanderAI: random step within wander_radius.
# ---------------------------------------------------------------------------
func _do_wander(game_map) -> String:
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


# ---------------------------------------------------------------------------
# Flee — move to the adjacent tile that maximises distance from the player.
# ---------------------------------------------------------------------------
func _do_flee(player, game_map) -> String:
	var best_dir: Vector2i = Vector2i.ZERO
	var best_dist := _cheb(actor.pos, player.pos)
	var player_global: Vector2i = player.pos
	if world != null and game_map.map_type == GameMapClass.MAP_OVERWORLD:
		player_global = world.get_overworld_global_pos(player.pos)

	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var dir := Vector2i(dx, dy)
			var d: int = -1
			if world != null and game_map.map_type == GameMapClass.MAP_OVERWORLD:
				var step: Dictionary = world.get_overworld_step_option(actor, dir, false)
				if step.is_empty():
					continue
				d = _cheb(step["global_pos"], player_global)
			else:
				var nx: int = actor.pos.x + dx
				var ny: int = actor.pos.y + dy
				if not game_map.is_in_bounds(nx, ny):
					continue
				if not game_map.is_walkable(nx, ny):
					continue
				if game_map.get_blocking_entity_at(nx, ny) != null:
					continue
				d = _cheb(Vector2i(nx, ny), player.pos)
			if d > best_dist:
				best_dist = d
				best_dir  = dir

	if best_dir == Vector2i.ZERO:
		return ""
	if world != null and game_map.map_type == GameMapClass.MAP_OVERWORLD:
		world.move_overworld_actor(actor, best_dir, false)
	else:
		game_map.move_entity(actor, actor.pos + best_dir)
	return ""


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
