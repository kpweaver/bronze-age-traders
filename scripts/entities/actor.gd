class_name Actor
extends "res://scripts/entities/entity.gd"

const MAX_INVENTORY := 20

var max_hp: int
var hp: int
var defense: int
var power: int
var ai          # HostileAI or null — untyped to break circular dependency
var inventory: Array = []  # Array of Item
var gold: int = 0

var is_alive: bool:
	get: return hp > 0

var ac: int:
	get: return 10 + defense


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
	max_hp   = p_max_hp
	hp       = p_max_hp
	defense  = p_defense
	power    = p_power


func attack(target: Actor) -> String:
	var roll: int = randi_range(1, 20)
	var is_player := name == "You"
	var v_attack  := "attack" if is_player else "attacks"
	var v_hit     := "hit"    if is_player else "hits"
	var t := target.name.to_lower()
	if roll < target.ac:
		var v_miss := "miss" if is_player else "misses"
		return "%s %s %s but %s. [to hit: %d vs AC %d]" % [name, v_attack, t, v_miss, roll, target.ac]
	var dmg: int = randi_range(1, 6) + power
	target.take_damage(dmg)
	return "%s %s %s for %d damage. [to hit: %d vs AC %d, 1d6+%d = %d]" % \
		[name, v_hit, t, dmg, roll, target.ac, power, dmg]


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


func die() -> String:
	char           = "%"
	color          = Color(0.45, 0.12, 0.05)
	blocks_movement = false
	ai             = null
	return "You fall." if name == "You" else "%s falls." % name
