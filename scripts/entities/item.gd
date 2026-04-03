class_name Item
extends "res://scripts/entities/entity.gd"

const TYPE_HEALTH_POTION   := "health_potion"
const TYPE_HEALING_DRAUGHT := "healing_draught"
const TYPE_GOLD            := "gold"

var item_type: String
var value: int  # HP restored (potions) or coin amount (gold)


func _init(p_pos: Vector2i, p_type: String, p_value: int) -> void:
	var ch: String
	var col: Color
	var nm: String
	match p_type:
		TYPE_HEALTH_POTION:
			ch  = "!"
			col = Color(0.40, 0.85, 0.35)   # pale green
			nm  = "Health Potion"
		TYPE_HEALING_DRAUGHT:
			ch  = "!"
			col = Color(0.25, 0.65, 0.90)   # azure blue
			nm  = "Healing Draught"
		TYPE_GOLD:
			ch  = "$"
			col = Color(0.90, 0.78, 0.15)
			nm  = "Gold Coins"
		_:
			ch  = "?"
			col = Color(1.0, 1.0, 1.0)
			nm  = "Unknown Item"
	super._init(p_pos, ch, col, nm, false)
	item_type = p_type
	value     = p_value


# Applies the item's effect to actor. Returns a log message.
func use(actor) -> String:
	match item_type:
		TYPE_HEALTH_POTION, TYPE_HEALING_DRAUGHT:
			var healed: int = mini(value, actor.max_hp - actor.hp)
			actor.hp = mini(actor.max_hp, actor.hp + value)
			if healed == 0:
				return "You drink the %s but are already at full health." % name.to_lower()
			return "You drink the %s and recover %d HP." % [name.to_lower(), healed]
	return ""
