class_name Item
extends "res://scripts/entities/entity.gd"

const ItemDataClass = preload("res://content/items.gd")

# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------
const CATEGORY_GOLD      := 0   # currency — auto-collected into player.gold
const CATEGORY_USABLE    := 1   # consumable (potions, draughts)
const CATEGORY_TRADE     := 2   # trade goods (metals, cloth, oil, etc.)
const CATEGORY_EQUIPMENT := 3   # wearable gear — goes into an equipment slot
const CATEGORY_READABLE  := 4   # clay tablets, scrolls — press R in inventory to read
const CATEGORY_AMMO      := 5   # ammunition stacks for ranged weapons

# ---------------------------------------------------------------------------
# Equipment slots
# ---------------------------------------------------------------------------
const SLOT_NONE   := ""
const SLOT_WEAPON := "weapon"
const SLOT_RANGED := "ranged"
const SLOT_BODY   := "body"
const SLOT_FEET   := "feet"
const SLOT_HEAD   := "head"
const SLOT_LIGHT  := "light"

# ---------------------------------------------------------------------------
# Usable item types
# ---------------------------------------------------------------------------
const TYPE_HEALTH_POTION   := "health_potion"
const TYPE_HEALING_DRAUGHT := "healing_draught"

# ---------------------------------------------------------------------------
# Currency
# ---------------------------------------------------------------------------
const TYPE_GOLD := "gold"

# ---------------------------------------------------------------------------
# Trade goods
# ---------------------------------------------------------------------------
const TYPE_POTTERY      := "pottery"
const TYPE_LINEN_CLOTH  := "linen_cloth"
const TYPE_CEDAR_WOOD   := "cedar_wood"
const TYPE_TIN_INGOT    := "tin_ingot"
const TYPE_COPPER_INGOT := "copper_ingot"
const TYPE_BRONZE_INGOT := "bronze_ingot"
const TYPE_OLIVE_OIL    := "olive_oil"
const TYPE_WINE         := "wine"
const TYPE_IVORY        := "ivory"
const TYPE_LAPIS_LAZULI := "lapis_lazuli"
const TYPE_SILVER_INGOT := "silver_ingot"
const TYPE_PURPLE_DYE   := "purple_dye"
const TYPE_WHEAT        := "wheat"
const TYPE_CLAY_TABLET  := "clay_tablet"

# ---------------------------------------------------------------------------
# Weapons  (SLOT_WEAPON)
# ---------------------------------------------------------------------------
const TYPE_DAGGER      := "dagger"
const TYPE_SHORT_SWORD := "short_sword"
const TYPE_SPEAR       := "spear"
const TYPE_CLUB        := "club"
const TYPE_SLING       := "sling"
const TYPE_SHORT_BOW   := "short_bow"

# ---------------------------------------------------------------------------
# Ammunition
# ---------------------------------------------------------------------------
const TYPE_SLING_STONE := "sling_stone"
const TYPE_REED_ARROW  := "reed_arrow"

# ---------------------------------------------------------------------------
# Body armour  (SLOT_BODY)
# ---------------------------------------------------------------------------
const TYPE_LINEN_TUNIC  := "linen_tunic"
const TYPE_WOOL_CLOAK   := "wool_cloak"
const TYPE_LEATHER_VEST := "leather_vest"

# ---------------------------------------------------------------------------
# Footwear  (SLOT_FEET)
# ---------------------------------------------------------------------------
const TYPE_SANDALS       := "sandals"
const TYPE_LEATHER_BOOTS := "leather_boots"

# ---------------------------------------------------------------------------
# Headwear  (SLOT_HEAD)
# ---------------------------------------------------------------------------
const TYPE_LINEN_HEADBAND := "linen_headband"
const TYPE_LEATHER_CAP    := "leather_cap"
const TYPE_BRONZE_HELMET  := "bronze_helmet"

# ---------------------------------------------------------------------------
# Light sources  (SLOT_LIGHT)
# ---------------------------------------------------------------------------
const TYPE_TORCH := "torch"

# ---------------------------------------------------------------------------
# Instance fields
# ---------------------------------------------------------------------------
var item_type: String  = ""
var category: int      = CATEGORY_USABLE
var slot: String       = SLOT_NONE
var material: String   = ""

var value: int         = 0   # gold coin amount (TYPE_GOLD only)
var base_value: int    = 0   # canonical trade / buy-sell price in gold
var weight: int        = 0   # carrying weight in pounds

var dice_count: int    = 0   # usable items — dice rolled on use
var dice_sides: int    = 0

var attack_bonus: int  = 0   # equipment — added to attacker's damage roll
var defense_bonus: int = 0   # equipment — added to wearer's AC
var ammo_type: String  = ""  # ranged weapons — which ammo item_type they consume
var ranged_range: int  = 0   # ranged weapons — max range in tiles

var light_fov: int     = 0   # light sources — FOV radius when equipped and lit
var burn_turns: int    = 0   # light sources — max lifetime in turns (0 = infinite)

var text: String       = ""  # readable items — full text shown in the reader screen


func _init(p_pos: Vector2i, p_type: String, p_value: int) -> void:
	item_type = p_type
	var d: Dictionary = ItemDataClass.get_item(p_type)
	var ch:  String = d.get("char", "?")
	var col: Color  = Color(float(d.get("cr", 1.0)), float(d.get("cg", 1.0)), float(d.get("cb", 1.0)))
	var nm:  String = d.get("name", "unknown item")
	category     = int(d.get("category", CATEGORY_USABLE))
	slot         = str(d.get("slot", SLOT_NONE))
	material     = str(d.get("material", ""))
	base_value   = int(d.get("base_value", 0))
	weight       = int(d.get("weight", 0))
	dice_count   = int(d.get("dice_count", 0))
	dice_sides   = int(d.get("dice_sides", 0))
	attack_bonus  = int(d.get("attack_bonus",  0))
	defense_bonus = int(d.get("defense_bonus", 0))
	ammo_type      = str(d.get("ammo_type", ""))
	ranged_range   = int(d.get("ranged_range", 0))
	light_fov     = int(d.get("light_fov",    0))
	burn_turns    = int(d.get("burn_turns",   0))
	text          = str(d.get("text", ""))
	# Gold coins carry a runtime quantity — use p_value directly.
	if category == CATEGORY_GOLD:
		value = p_value
	elif category == CATEGORY_AMMO:
		var default_stack: int = int(d.get("stack_size", 1))
		value = p_value if p_value > 0 else default_stack
	# Light sources use value as burn_remaining; restore saved value or seed from burn_turns.
	elif slot == SLOT_LIGHT and burn_turns > 0:
		value = p_value if p_value > 0 else burn_turns

	super._init(p_pos, ch, col, nm, false)


# Roll dice_count d dice_sides — used by usable items.
func _roll() -> int:
	var total := 0
	for _i in range(dice_count):
		total += randi_range(1, dice_sides)
	return total


# Human-readable dice label e.g. "1d6".
func dice_label() -> String:
	return "%dd%d" % [dice_count, dice_sides]


func weight_label() -> String:
	return "%d lbs." % total_weight()


func stack_count() -> int:
	if category == CATEGORY_AMMO:
		return maxi(0, value)
	if category == CATEGORY_GOLD:
		return maxi(0, value)
	return 1


func total_weight() -> int:
	return weight * stack_count() if category == CATEGORY_AMMO else weight


func stack_label() -> String:
	return "x%d" % stack_count() if category == CATEGORY_AMMO and stack_count() > 1 else ""


# Applies the item effect to actor. Returns a log message. Usable items only.
func use(actor) -> String:
	match item_type:
		TYPE_HEALTH_POTION, TYPE_HEALING_DRAUGHT:
			var rolled: int  = _roll()
			var healed: int  = mini(rolled, actor.max_hp - actor.hp)
			actor.hp = mini(actor.max_hp, actor.hp + rolled)
			if healed == 0:
				return "You drink the %s but are already at full health." % name.to_lower()
			return "You drink the %s and recover %d HP." % [name.to_lower(), healed]
	return ""
