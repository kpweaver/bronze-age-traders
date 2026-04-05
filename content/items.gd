# Item template data — edit this file to add or modify items.
# Systems code reads these templates; do not change field names without
# updating scripts/entities/item.gd.
#
# Schema for each entry  (key = item_type string):
#   char          String  — single CP437 glyph displayed on the map
#   cr/cg/cb      float   — RGB colour (0.0–1.0)
#   name          String  — display name (lowercase)
#   category      int     — 0=gold  1=usable  2=trade  3=equipment
#   slot          String  — equipment slot: "weapon"|"body"|"feet"|"head"|""
#   base_value    int     — canonical price in gold coins
#   material      String  — period-accurate material descriptor
#   dice_count    int     — usable items: number of HP-recovery dice
#   dice_sides    int     — usable items: sides per die
#   attack_bonus  int     — equipment: added to attacker damage roll
#   defense_bonus int     — equipment: added to wearer's AC
#
# Only include fields relevant to the item — missing numeric fields default to 0,
# missing string fields default to "".  category and slot are always required.

const DATA: Dictionary = {
	# ── Currency ──────────────────────────────────────────────────────────────
	"gold": {
		"char": "$", "cr": 0.90, "cg": 0.78, "cb": 0.15,
		"name": "gold coins", "category": 0, "slot": "",
	},

	# ── Usable items ──────────────────────────────────────────────────────────
	"health_potion": {
		"char": "!", "cr": 0.40, "cg": 0.85, "cb": 0.35,
		"name": "health potion", "category": 1, "slot": "",
		"base_value": 8, "dice_count": 1, "dice_sides": 6,
		"material": "ceramic",
	},
	"healing_draught": {
		"char": "!", "cr": 0.25, "cg": 0.65, "cb": 0.90,
		"name": "healing draught", "category": 1, "slot": "",
		"base_value": 16, "dice_count": 2, "dice_sides": 6,
		"material": "ceramic",
	},

	# ── Trade goods ───────────────────────────────────────────────────────────
	"pottery": {
		"char": ",", "cr": 0.72, "cg": 0.40, "cb": 0.22,
		"name": "pottery", "category": 2, "slot": "",
		"base_value": 3, "material": "clay",
	},
	"linen_cloth": {
		"char": "\"", "cr": 0.90, "cg": 0.88, "cb": 0.75,
		"name": "linen cloth", "category": 2, "slot": "",
		"base_value": 4, "material": "linen",
	},
	"cedar_wood": {
		"char": "/", "cr": 0.55, "cg": 0.35, "cb": 0.18,
		"name": "cedar wood", "category": 2, "slot": "",
		"base_value": 6, "material": "wood",
	},
	"tin_ingot": {
		"char": "*", "cr": 0.82, "cg": 0.84, "cb": 0.86,
		"name": "tin ingot", "category": 2, "slot": "",
		"base_value": 12, "material": "tin",
	},
	"copper_ingot": {
		"char": "*", "cr": 0.72, "cg": 0.45, "cb": 0.25,
		"name": "copper ingot", "category": 2, "slot": "",
		"base_value": 8, "material": "copper",
	},
	"bronze_ingot": {
		"char": "*", "cr": 0.80, "cg": 0.50, "cb": 0.20,
		"name": "bronze ingot", "category": 2, "slot": "",
		"base_value": 22, "material": "bronze",
	},
	"olive_oil": {
		"char": "~", "cr": 0.70, "cg": 0.75, "cb": 0.30,
		"name": "olive oil", "category": 2, "slot": "",
		"base_value": 6, "material": "oil",
	},
	"wine": {
		"char": "~", "cr": 0.55, "cg": 0.18, "cb": 0.35,
		"name": "wine", "category": 2, "slot": "",
		"base_value": 7, "material": "wine",
	},
	"ivory": {
		"char": "-", "cr": 0.96, "cg": 0.94, "cb": 0.88,
		"name": "ivory", "category": 2, "slot": "",
		"base_value": 30, "material": "ivory",
	},
	"lapis_lazuli": {
		"char": "*", "cr": 0.18, "cg": 0.28, "cb": 0.82,
		"name": "lapis lazuli", "category": 2, "slot": "",
		"base_value": 40, "material": "stone",
	},
	"silver_ingot": {
		"char": "*", "cr": 0.85, "cg": 0.87, "cb": 0.90,
		"name": "silver ingot", "category": 2, "slot": "",
		"base_value": 35, "material": "silver",
	},
	"purple_dye": {
		"char": "~", "cr": 0.55, "cg": 0.12, "cb": 0.68,
		"name": "purple dye", "category": 2, "slot": "",
		"base_value": 50, "material": "dye",
	},
	"wheat": {
		"char": ",", "cr": 0.88, "cg": 0.78, "cb": 0.38,
		"name": "wheat", "category": 2, "slot": "",
		"base_value": 2, "material": "grain",
	},
	"clay_tablet": {
		"char": "-", "cr": 0.75, "cg": 0.62, "cb": 0.42,
		"name": "clay tablet", "category": 2, "slot": "",
		"base_value": 15, "material": "clay",
	},

	# ── Weapons  (slot: "weapon") ─────────────────────────────────────────────
	"dagger": {
		"char": ")", "cr": 0.78, "cg": 0.72, "cb": 0.55,
		"name": "dagger", "category": 3, "slot": "weapon",
		"attack_bonus": 1, "base_value": 15, "material": "copper",
	},
	"short_sword": {
		"char": ")", "cr": 0.85, "cg": 0.82, "cb": 0.60,
		"name": "short sword", "category": 3, "slot": "weapon",
		"attack_bonus": 2, "base_value": 28, "material": "bronze",
	},
	"spear": {
		"char": "/", "cr": 0.72, "cg": 0.65, "cb": 0.42,
		"name": "spear", "category": 3, "slot": "weapon",
		"attack_bonus": 3, "base_value": 20, "material": "wood",
	},
	"club": {
		"char": ")", "cr": 0.55, "cg": 0.38, "cb": 0.22,
		"name": "club", "category": 3, "slot": "weapon",
		"attack_bonus": 1, "base_value": 8, "material": "wood",
	},
	"sling": {
		"char": ")", "cr": 0.65, "cg": 0.55, "cb": 0.38,
		"name": "sling", "category": 3, "slot": "weapon",
		"attack_bonus": 0, "base_value": 5, "material": "leather",
	},

	# ── Body armour  (slot: "body") ───────────────────────────────────────────
	"linen_tunic": {
		"char": "[", "cr": 0.90, "cg": 0.88, "cb": 0.75,
		"name": "linen tunic", "category": 3, "slot": "body",
		"defense_bonus": 1, "base_value": 6, "material": "linen",
	},
	"wool_cloak": {
		"char": "[", "cr": 0.68, "cg": 0.58, "cb": 0.42,
		"name": "wool cloak", "category": 3, "slot": "body",
		"defense_bonus": 1, "base_value": 10, "material": "wool",
	},
	"leather_vest": {
		"char": "[", "cr": 0.60, "cg": 0.42, "cb": 0.25,
		"name": "leather vest", "category": 3, "slot": "body",
		"defense_bonus": 2, "base_value": 18, "material": "leather",
	},

	# ── Footwear  (slot: "feet") ──────────────────────────────────────────────
	"sandals": {
		"char": "[", "cr": 0.78, "cg": 0.65, "cb": 0.42,
		"name": "sandals", "category": 3, "slot": "feet",
		"defense_bonus": 0, "base_value": 4, "material": "leather",
	},
	"leather_boots": {
		"char": "[", "cr": 0.55, "cg": 0.40, "cb": 0.25,
		"name": "leather boots", "category": 3, "slot": "feet",
		"defense_bonus": 1, "base_value": 12, "material": "leather",
	},

	# ── Headwear  (slot: "head") ──────────────────────────────────────────────
	"linen_headband": {
		"char": "[", "cr": 0.90, "cg": 0.88, "cb": 0.75,
		"name": "linen headband", "category": 3, "slot": "head",
		"defense_bonus": 0, "base_value": 3, "material": "linen",
	},
	"leather_cap": {
		"char": "[", "cr": 0.60, "cg": 0.42, "cb": 0.25,
		"name": "leather cap", "category": 3, "slot": "head",
		"defense_bonus": 1, "base_value": 10, "material": "leather",
	},
	"bronze_helmet": {
		"char": "[", "cr": 0.80, "cg": 0.50, "cb": 0.20,
		"name": "bronze helmet", "category": 3, "slot": "head",
		"defense_bonus": 2, "base_value": 35, "material": "bronze",
	},
}


static func get_item(item_type: String) -> Dictionary:
	return DATA.get(item_type, {})
