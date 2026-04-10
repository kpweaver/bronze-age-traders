class_name Actor
extends "res://scripts/entities/entity.gd"

const ItemClass = preload("res://scripts/entities/item.gd")

const BASE_CARRY_WEIGHT := 60   # pounds
const CARRY_WEIGHT_PER_STR_MOD := 10

var max_hp: int
var hp: int
var defense: int
var power: int
var ai
var inventory: Array = []
var gold: int = 0
var xp: int = 0
var xp_to_next: int = 100
var unspent_attribute_points: int = 0

const THIRST_MAX: int  = 720
const FATIGUE_MAX: int = 720
var thirst: int  = 0
var fatigue: int = 0

var thirst_rate: float = 1.0
var fatigue_rate: float = 1.0

var str_score: int = 10
var dex_score: int = 10
var con_score: int = 10
var int_score: int = 10
var wis_score: int = 10
var cha_score: int = 10

var level: int = 1
var attack_speed: float = 1.0
var is_mountable: bool = false
var is_mounted: bool = false

var str_mod: int:
	get: return (str_score - 10) / 2
var dex_mod: int:
	get: return (dex_score - 10) / 2
var con_mod: int:
	get: return (con_score - 10) / 2
var int_mod: int:
	get: return (int_score - 10) / 2
var wis_mod: int:
	get: return (wis_score - 10) / 2
var cha_mod: int:
	get: return (cha_score - 10) / 2

var equipped: Dictionary = {
	"weapon": null,
	"body": null,
	"feet": null,
	"head": null,
	"light": null,
}

var is_alive: bool:
	get: return hp > 0

var total_defense_bonus: int:
	get:
		var bonus: int = 0
		for slot_key: String in equipped:
			if equipped[slot_key] != null:
				bonus += int(equipped[slot_key].defense_bonus)
		return bonus

var total_attack_bonus: int:
	get:
		var bonus: int = 0
		for slot_key: String in equipped:
			if equipped[slot_key] != null:
				bonus += int(equipped[slot_key].attack_bonus)
		return bonus

var ac: int:
	get: return 10 + defense + dex_mod + total_defense_bonus

var max_carry_weight: int:
	get: return maxi(20, BASE_CARRY_WEIGHT + str_mod * CARRY_WEIGHT_PER_STR_MOD)

var total_carry_weight: int:
	get:
		var total: int = 0
		for item in inventory:
			total += int(item.weight)
		for slot_key: String in equipped:
			var equipped_item = equipped[slot_key]
			if equipped_item != null:
				total += int(equipped_item.weight)
		return total


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


func _subj() -> String:
	return "You" if name == "you" else "The %s" % name


func _obj() -> String:
	return "you" if name == "you" else "the %s" % name


func attack(target: Actor) -> String:
	var roll: int = randi_range(1, 20) + str_mod
	var is_player := name == "you"
	var v_attack := "attack" if is_player else "attacks"
	var v_hit := "hit" if is_player else "hits"
	var v_miss := "miss" if is_player else "misses"
	if roll < target.ac:
		return "%s %s %s but %s. [to hit: %d vs AC %d]" % \
			[_subj(), v_attack, target._obj(), v_miss, roll, target.ac]
	var bonus: int = power + total_attack_bonus + str_mod
	var dmg: int = randi_range(1, 6) + bonus
	target.take_damage(dmg)
	return "%s %s %s for %d damage. [to hit: %d vs AC %d, 1d6+%d = %d]" % \
		[_subj(), v_hit, target._obj(), dmg, roll, target.ac, bonus, dmg]


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


func die() -> String:
	char = "%"
	color = Color(0.45, 0.12, 0.05)
	blocks_movement = false
	ai = null
	return "You fall." if name == "you" else "The %s falls." % name


func can_carry(item) -> bool:
	return item != null and total_carry_weight + int(item.weight) <= max_carry_weight


func equip(item) -> String:
	var slot_key: String = str(item.slot)
	if slot_key == ItemClass.SLOT_NONE:
		return "You can't equip the %s." % item.name
	if not equipped.has(slot_key):
		return "Unknown equipment slot."
	var old = equipped[slot_key]
	equipped[slot_key] = item
	inventory.erase(item)
	if old != null:
		inventory.append(old)
		return "You equip the %s (replacing the %s)." % [item.name, old.name]
	return "You equip the %s." % item.name


func unequip(slot_key: String) -> String:
	var item = equipped.get(slot_key)
	if item == null:
		return ""
	equipped[slot_key] = null
	inventory.append(item)
	return "You unequip the %s." % item.name
