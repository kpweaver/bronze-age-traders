class_name Actor
extends "res://scripts/entities/entity.gd"

var max_hp: int
var hp: int
var defense: int
var power: int
var ai  # HostileAI or null — untyped to break circular dependency

var is_alive: bool:
	get: return hp > 0


func _init(
	p_pos: Vector2i,
	p_char: String,
	p_color: Color,
	p_name: String,
	p_max_hp: int,
	p_defense: int,
	p_power: int
) -> void:
	super._init(p_pos, p_char, p_color, p_name, true)
	max_hp = p_max_hp
	hp = p_max_hp
	defense = p_defense
	power = p_power


func attack(target: Actor) -> String:
	var dmg: int = maxi(0, power - target.defense)
	if dmg == 0:
		return "%s strikes %s but deals no damage." % [name, target.name]
	target.take_damage(dmg)
	return "%s hits %s for %d damage." % [name, target.name, dmg]


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


func die() -> String:
	char = "%"
	color = Color(0.45, 0.12, 0.05)
	blocks_movement = false
	ai = null
	return "%s falls." % name
