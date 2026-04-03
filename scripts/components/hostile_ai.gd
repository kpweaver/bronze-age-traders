class_name HostileAI
extends RefCounted

const ActorClass   = preload("res://scripts/entities/actor.gd")
const GameMapClass = preload("res://scripts/map/game_map.gd")

var actor  # Actor — untyped, loaded via preload below


func _init(p_actor) -> void:
	actor = p_actor


# Called once per enemy turn. Returns a message string or "".
func take_turn(player, game_map) -> String:
	# Only act when in the player's field of view
	if not game_map.visible[actor.pos.y][actor.pos.x]:
		return ""

	var dx: int = player.pos.x - actor.pos.x
	var dy: int = player.pos.y - actor.pos.y
	var dist: int = maxi(absi(dx), absi(dy))  # Chebyshev distance

	if dist <= 1:
		return actor.attack(player)

	# Greedy step: try diagonal first, then cardinal fallbacks
	var step := Vector2i(signi(dx), signi(dy))
	var candidates := [step, Vector2i(step.x, 0), Vector2i(0, step.y)]
	for s in candidates:
		var next: Vector2i = actor.pos + s
		if game_map.is_walkable(next.x, next.y) and not game_map.get_blocking_entity_at(next.x, next.y):
			actor.pos = next
			return ""

	return ""
