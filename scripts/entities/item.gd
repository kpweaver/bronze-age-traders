class_name Item
extends "res://scripts/entities/entity.gd"

# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------
const CATEGORY_GOLD      := 0   # currency — auto-collected into player.gold
const CATEGORY_USABLE    := 1   # consumable (potions, draughts)
const CATEGORY_TRADE     := 2   # trade goods (metals, cloth, oil, etc.)
const CATEGORY_EQUIPMENT := 3   # wearable gear — goes into an equipment slot

# ---------------------------------------------------------------------------
# Equipment slots
# ---------------------------------------------------------------------------
const SLOT_NONE   := ""
const SLOT_WEAPON := "weapon"
const SLOT_BODY   := "body"
const SLOT_FEET   := "feet"
const SLOT_HEAD   := "head"

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
# Instance fields
# ---------------------------------------------------------------------------
var item_type: String  = ""
var category: int      = CATEGORY_USABLE
var slot: String       = SLOT_NONE
var material: String   = ""

var value: int         = 0   # gold coin amount (TYPE_GOLD only)
var base_value: int    = 0   # canonical trade / buy-sell price in gold

var dice_count: int    = 0   # usable items — dice rolled on use
var dice_sides: int    = 0

var attack_bonus: int  = 0   # equipment — added to attacker's damage roll
var defense_bonus: int = 0   # equipment — added to wearer's AC


func _init(p_pos: Vector2i, p_type: String, p_value: int) -> void:
	item_type = p_type
	var ch:  String = "?"
	var col: Color  = Color.WHITE
	var nm:  String = "unknown item"

	match p_type:
		# ── Usable ────────────────────────────────────────────────────────
		TYPE_HEALTH_POTION:
			ch = "!"; col = Color(0.40, 0.85, 0.35); nm = "health potion"
			category = CATEGORY_USABLE; base_value = 8
			dice_count = 1; dice_sides = 6
		TYPE_HEALING_DRAUGHT:
			ch = "!"; col = Color(0.25, 0.65, 0.90); nm = "healing draught"
			category = CATEGORY_USABLE; base_value = 16
			dice_count = 2; dice_sides = 6
		# ── Currency ──────────────────────────────────────────────────────
		TYPE_GOLD:
			ch = "$"; col = Color(0.90, 0.78, 0.15); nm = "gold coins"
			category = CATEGORY_GOLD; value = p_value
		# ── Trade goods ───────────────────────────────────────────────────
		TYPE_POTTERY:
			ch = ","; col = Color(0.72, 0.40, 0.22); nm = "pottery"
			category = CATEGORY_TRADE; base_value = 3; material = "clay"
		TYPE_LINEN_CLOTH:
			ch = "\""; col = Color(0.90, 0.88, 0.75); nm = "linen cloth"
			category = CATEGORY_TRADE; base_value = 4; material = "linen"
		TYPE_CEDAR_WOOD:
			ch = "/"; col = Color(0.55, 0.35, 0.18); nm = "cedar wood"
			category = CATEGORY_TRADE; base_value = 6; material = "wood"
		TYPE_TIN_INGOT:
			ch = "*"; col = Color(0.82, 0.84, 0.86); nm = "tin ingot"
			category = CATEGORY_TRADE; base_value = 12; material = "tin"
		TYPE_COPPER_INGOT:
			ch = "*"; col = Color(0.72, 0.45, 0.25); nm = "copper ingot"
			category = CATEGORY_TRADE; base_value = 8; material = "copper"
		TYPE_BRONZE_INGOT:
			ch = "*"; col = Color(0.80, 0.50, 0.20); nm = "bronze ingot"
			category = CATEGORY_TRADE; base_value = 22; material = "bronze"
		TYPE_OLIVE_OIL:
			ch = "~"; col = Color(0.70, 0.75, 0.30); nm = "olive oil"
			category = CATEGORY_TRADE; base_value = 6; material = "oil"
		TYPE_WINE:
			ch = "~"; col = Color(0.55, 0.18, 0.35); nm = "wine"
			category = CATEGORY_TRADE; base_value = 7; material = "wine"
		TYPE_IVORY:
			ch = "-"; col = Color(0.96, 0.94, 0.88); nm = "ivory"
			category = CATEGORY_TRADE; base_value = 30; material = "ivory"
		TYPE_LAPIS_LAZULI:
			ch = "*"; col = Color(0.18, 0.28, 0.82); nm = "lapis lazuli"
			category = CATEGORY_TRADE; base_value = 40; material = "stone"
		TYPE_SILVER_INGOT:
			ch = "*"; col = Color(0.85, 0.87, 0.90); nm = "silver ingot"
			category = CATEGORY_TRADE; base_value = 35; material = "silver"
		TYPE_PURPLE_DYE:
			ch = "~"; col = Color(0.55, 0.12, 0.68); nm = "purple dye"
			category = CATEGORY_TRADE; base_value = 50; material = "dye"
		TYPE_WHEAT:
			ch = ","; col = Color(0.88, 0.78, 0.38); nm = "wheat"
			category = CATEGORY_TRADE; base_value = 2; material = "grain"
		TYPE_CLAY_TABLET:
			ch = "-"; col = Color(0.75, 0.62, 0.42); nm = "clay tablet"
			category = CATEGORY_TRADE; base_value = 15; material = "clay"
		# ── Weapons ───────────────────────────────────────────────────────
		TYPE_DAGGER:
			ch = ")"; col = Color(0.78, 0.72, 0.55); nm = "dagger"
			category = CATEGORY_EQUIPMENT; slot = SLOT_WEAPON
			attack_bonus = 1; base_value = 15; material = "copper"
		TYPE_SHORT_SWORD:
			ch = ")"; col = Color(0.85, 0.82, 0.60); nm = "short sword"
			category = CATEGORY_EQUIPMENT; slot = SLOT_WEAPON
			attack_bonus = 2; base_value = 28; material = "bronze"
		TYPE_SPEAR:
			ch = "/"; col = Color(0.72, 0.65, 0.42); nm = "spear"
			category = CATEGORY_EQUIPMENT; slot = SLOT_WEAPON
			attack_bonus = 3; base_value = 20; material = "wood"
		TYPE_CLUB:
			ch = ")"; col = Color(0.55, 0.38, 0.22); nm = "club"
			category = CATEGORY_EQUIPMENT; slot = SLOT_WEAPON
			attack_bonus = 1; base_value = 8; material = "wood"
		TYPE_SLING:
			ch = ")"; col = Color(0.65, 0.55, 0.38); nm = "sling"
			category = CATEGORY_EQUIPMENT; slot = SLOT_WEAPON
			attack_bonus = 0; base_value = 5; material = "leather"
		# ── Body armour ───────────────────────────────────────────────────
		TYPE_LINEN_TUNIC:
			ch = "["; col = Color(0.90, 0.88, 0.75); nm = "linen tunic"
			category = CATEGORY_EQUIPMENT; slot = SLOT_BODY
			defense_bonus = 1; base_value = 6; material = "linen"
		TYPE_WOOL_CLOAK:
			ch = "["; col = Color(0.68, 0.58, 0.42); nm = "wool cloak"
			category = CATEGORY_EQUIPMENT; slot = SLOT_BODY
			defense_bonus = 1; base_value = 10; material = "wool"
		TYPE_LEATHER_VEST:
			ch = "["; col = Color(0.60, 0.42, 0.25); nm = "leather vest"
			category = CATEGORY_EQUIPMENT; slot = SLOT_BODY
			defense_bonus = 2; base_value = 18; material = "leather"
		# ── Footwear ──────────────────────────────────────────────────────
		TYPE_SANDALS:
			ch = "["; col = Color(0.78, 0.65, 0.42); nm = "sandals"
			category = CATEGORY_EQUIPMENT; slot = SLOT_FEET
			defense_bonus = 0; base_value = 4; material = "leather"
		TYPE_LEATHER_BOOTS:
			ch = "["; col = Color(0.55, 0.40, 0.25); nm = "leather boots"
			category = CATEGORY_EQUIPMENT; slot = SLOT_FEET
			defense_bonus = 1; base_value = 12; material = "leather"
		# ── Headwear ──────────────────────────────────────────────────────
		TYPE_LINEN_HEADBAND:
			ch = "["; col = Color(0.90, 0.88, 0.75); nm = "linen headband"
			category = CATEGORY_EQUIPMENT; slot = SLOT_HEAD
			defense_bonus = 0; base_value = 3; material = "linen"
		TYPE_LEATHER_CAP:
			ch = "["; col = Color(0.60, 0.42, 0.25); nm = "leather cap"
			category = CATEGORY_EQUIPMENT; slot = SLOT_HEAD
			defense_bonus = 1; base_value = 10; material = "leather"
		TYPE_BRONZE_HELMET:
			ch = "["; col = Color(0.80, 0.50, 0.20); nm = "bronze helmet"
			category = CATEGORY_EQUIPMENT; slot = SLOT_HEAD
			defense_bonus = 2; base_value = 35; material = "bronze"

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
