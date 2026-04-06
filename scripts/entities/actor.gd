class_name Actor
extends "res://scripts/entities/entity.gd"

const ItemClass = preload("res://scripts/entities/item.gd")

const MAX_INVENTORY := 20

var max_hp: int
var hp: int
var defense: int
var power: int
var ai          # HostileAI or null — untyped to break circular dependency
var inventory: Array = []  # Array of Item (non-equipped)
var gold: int = 0

const THIRST_MAX: int  = 720   # turns until death from dehydration (1 day)
const FATIGUE_MAX: int = 720   # turns until collapse from exhaustion (1 day)
var thirst: int  = 0           # 0 = fully hydrated,  THIRST_MAX  = dead
var fatigue: int = 0           # 0 = fully rested,    FATIGUE_MAX = collapse

# Per-actor survival rate multipliers — kept at 1.0 for humans.
# Future followers: camels thirst_rate=0.3, pack donkeys fatigue_rate=1.5, etc.
var thirst_rate:  float = 1.0
var fatigue_rate: float = 1.0

# ---------------------------------------------------------------------------
# Attribute scores — D&D-style 3-18 range, default 10 (modifier = 0).
# Modifier formula: (score - 10) / 2  (integer division, floors toward zero).
# Active: STR (to-hit, damage, carry), DEX (AC), CON (max HP).
# Stubs:  INT (trade knowledge, crafting), WIS (FOV, awareness, rumours),
#         CHA (prices, followers, reputation).
# ---------------------------------------------------------------------------
var str_score: int = 10   # Strength     — attack/damage bonus, carry capacity
var dex_score: int = 10   # Dexterity    — AC bonus
var con_score: int = 10   # Constitution — max HP, thirst/fatigue endurance
var int_score: int = 10   # Intelligence — stub
var wis_score: int = 10   # Wisdom       — stub
var cha_score: int = 10   # Charisma     — stub

# Combat stats — level and attack_speed are stubs used by NPCs;
# attack_speed will gate multi-attack or initiative when implemented.
var level: int         = 1
var attack_speed: float = 1.0

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

# Equipment slots — values are Item instances or null.
var equipped: Dictionary = {
	"weapon": null,
	"body":   null,
	"feet":   null,
	"head":   null,
	"light":  null,
}

var is_alive: bool:
	get: return hp > 0

# Sum of defense_bonus across all equipped items.
var total_defense_bonus: int:
	get:
		var b: int = 0
		for s: String in equipped:
			if equipped[s] != null:
				b += int(equipped[s].defense_bonus)
		return b

# Sum of attack_bonus across all equipped items.
var total_attack_bonus: int:
	get:
		var b: int = 0
		for s: String in equipped:
			if equipped[s] != null:
				b += int(equipped[s].attack_bonus)
		return b

# DEX modifier applies to AC automatically for all actors.
var ac: int:
	get: return 10 + defense + dex_mod + total_defense_bonus

# STR modifier expands carry capacity (2 slots per modifier point).
var max_inventory: int:
	get: return MAX_INVENTORY + str_mod * 2


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


# Sentence-start subject: "You" for player, "The raider" for enemies.
func _subj() -> String:
	return "You" if name == "you" else "The %s" % name

# Mid-sentence object: "you" for player, "the raider" for enemies.
func _obj() -> String:
	return "you" if name == "you" else "the %s" % name


func attack(target: Actor) -> String:
	var roll: int  = randi_range(1, 20) + str_mod   # STR mod applies to hit
	var is_player  := name == "you"
	var v_attack   := "attack"  if is_player else "attacks"
	var v_hit      := "hit"     if is_player else "hits"
	var v_miss     := "miss"    if is_player else "misses"
	if roll < target.ac:
		return "%s %s %s but %s. [to hit: %d vs AC %d]" % \
			[_subj(), v_attack, target._obj(), v_miss, roll, target.ac]
	var bonus: int = power + total_attack_bonus + str_mod  # STR mod applies to damage
	var dmg: int   = randi_range(1, 6) + bonus
	target.take_damage(dmg)
	return "%s %s %s for %d damage. [to hit: %d vs AC %d, 1d6+%d = %d]" % \
		[_subj(), v_hit, target._obj(), dmg, roll, target.ac, bonus, dmg]


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


func die() -> String:
	char            = "%"
	color           = Color(0.45, 0.12, 0.05)
	blocks_movement = false
	ai              = null
	return "You fall." if name == "you" else "The %s falls." % name


# Move item from inventory into the matching equipment slot.
# Any previously equipped item is swapped back into inventory.
# Returns a log message.
func equip(item) -> String:
	var s: String = str(item.slot)
	if s == ItemClass.SLOT_NONE:
		return "You can't equip the %s." % item.name
	if not equipped.has(s):
		return "Unknown equipment slot."
	var old = equipped[s]
	equipped[s] = item
	inventory.erase(item)
	if old != null:
		inventory.append(old)
		return "You equip the %s (replacing the %s)." % [item.name, old.name]
	return "You equip the %s." % item.name


# Move equipped item from slot back into inventory.
# Returns a log message, or "" if slot is empty.
func unequip(slot_key: String) -> String:
	var item = equipped.get(slot_key)
	if item == null:
		return ""
	if inventory.size() >= max_inventory:
		return "Your pack is full — can't unequip the %s." % item.name
	equipped[slot_key] = null
	inventory.append(item)
	return "You unequip the %s." % item.name
