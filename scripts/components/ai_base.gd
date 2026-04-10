class_name AIBase
extends RefCounted

# Base class for all entity AI components.
# Attach an instance to actor.ai to give that actor a behaviour.
# Subclass and override take_turn() for each behaviour type:
#   HostileAI  — beeline toward player, attack on contact
#   WanderAI   — (future) random walk within wander_radius of home_pos
#   ScheduleAI — (future) follow a time-of-day routine

var actor  # the Actor this AI drives
var world = null  # GameWorld reference, injected before take_turn when needed

func _init(p_actor) -> void:
	actor = p_actor


# Called once per turn for every entity with a non-null ai.
# Returns a log-worthy message string, or "" if silent.
# player   — the player Actor (target / reference point)
# game_map — the current GameMap
func take_turn(_player, _game_map) -> String:
	return ""
