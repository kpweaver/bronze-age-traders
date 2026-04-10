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
		"weight": 0,
	},

	# ── Usable items ──────────────────────────────────────────────────────────
	"health_potion": {
		"char": "!", "cr": 0.40, "cg": 0.85, "cb": 0.35,
		"name": "health potion", "category": 1, "slot": "",
		"base_value": 8, "weight": 1, "dice_count": 1, "dice_sides": 6,
		"material": "ceramic",
	},
	"healing_draught": {
		"char": "!", "cr": 0.25, "cg": 0.65, "cb": 0.90,
		"name": "healing draught", "category": 1, "slot": "",
		"base_value": 16, "weight": 1, "dice_count": 2, "dice_sides": 6,
		"material": "ceramic",
	},

	# ── Trade goods ───────────────────────────────────────────────────────────
	"pottery": {
		"char": ",", "cr": 0.72, "cg": 0.40, "cb": 0.22,
		"name": "pottery", "category": 2, "slot": "",
		"base_value": 3, "weight": 5, "material": "clay",
	},
	"linen_cloth": {
		"char": "\"", "cr": 0.90, "cg": 0.88, "cb": 0.75,
		"name": "linen cloth", "category": 2, "slot": "",
		"base_value": 4, "weight": 2, "material": "linen",
	},
	"cedar_wood": {
		"char": "/", "cr": 0.55, "cg": 0.35, "cb": 0.18,
		"name": "cedar wood", "category": 2, "slot": "",
		"base_value": 6, "weight": 8, "material": "wood",
	},
	"tin_ingot": {
		"char": "*", "cr": 0.82, "cg": 0.84, "cb": 0.86,
		"name": "tin ingot", "category": 2, "slot": "",
		"base_value": 12, "weight": 12, "material": "tin",
	},
	"copper_ingot": {
		"char": "*", "cr": 0.72, "cg": 0.45, "cb": 0.25,
		"name": "copper ingot", "category": 2, "slot": "",
		"base_value": 8, "weight": 12, "material": "copper",
	},
	"bronze_ingot": {
		"char": "*", "cr": 0.80, "cg": 0.50, "cb": 0.20,
		"name": "bronze ingot", "category": 2, "slot": "",
		"base_value": 22, "weight": 13, "material": "bronze",
	},
	"olive_oil": {
		"char": "~", "cr": 0.70, "cg": 0.75, "cb": 0.30,
		"name": "olive oil", "category": 2, "slot": "",
		"base_value": 6, "weight": 4, "material": "oil",
	},
	"wine": {
		"char": "~", "cr": 0.55, "cg": 0.18, "cb": 0.35,
		"name": "wine", "category": 2, "slot": "",
		"base_value": 7, "weight": 4, "material": "wine",
	},
	"ivory": {
		"char": "-", "cr": 0.96, "cg": 0.94, "cb": 0.88,
		"name": "ivory", "category": 2, "slot": "",
		"base_value": 30, "weight": 6, "material": "ivory",
	},
	"lapis_lazuli": {
		"char": "*", "cr": 0.18, "cg": 0.28, "cb": 0.82,
		"name": "lapis lazuli", "category": 2, "slot": "",
		"base_value": 40, "weight": 3, "material": "stone",
	},
	"silver_ingot": {
		"char": "*", "cr": 0.85, "cg": 0.87, "cb": 0.90,
		"name": "silver ingot", "category": 2, "slot": "",
		"base_value": 35, "weight": 12, "material": "silver",
	},
	"purple_dye": {
		"char": "~", "cr": 0.55, "cg": 0.12, "cb": 0.68,
		"name": "purple dye", "category": 2, "slot": "",
		"base_value": 50, "weight": 1, "material": "dye",
	},
	"wheat": {
		"char": ",", "cr": 0.88, "cg": 0.78, "cb": 0.38,
		"name": "wheat", "category": 2, "slot": "",
		"base_value": 2, "weight": 4, "material": "grain",
	},
	"clay_tablet": {
		"char": "-", "cr": 0.75, "cg": 0.62, "cb": 0.42,
		"name": "clay tablet", "category": 2, "slot": "",
		"base_value": 15, "weight": 2, "material": "clay",
	},

	# ── Readable tablets (category 4) ────────────────────────────────────────
	# Add new entries here to put new readable content in the world.
	# Tablets spawn in admin/scribe buildings and are found as loot.
	# The 'text' field is displayed verbatim in the reader screen.
	"tablet_traders_ledger": {
		"char": "=", "cr": 0.82, "cg": 0.70, "cb": 0.48,
		"name": "trader's ledger", "category": 4, "slot": "",
		"base_value": 12, "weight": 2, "material": "clay",
		"text": "Third month. Harrani, son of Kabti, records:\n\nSix talents of tin received from the mountain pass caravan. Copper: twenty-two ingots, of which ten are promised to the palace.\n\nOutstanding debt from Imgur-Enlil: four shekels of silver, now three months late. Send no more goods until settled.\n\nThe road south is closed. Send no wagons until Nisanu.",
	},
	"tablet_hymn_shamash": {
		"char": "=", "cr": 0.82, "cg": 0.70, "cb": 0.48,
		"name": "hymn to Shamash", "category": 4, "slot": "",
		"base_value": 18, "weight": 2, "material": "clay",
		"text": "O Shamash, you rise upon the mountain of heaven and earth.\nYou open the bolt of the shining sky.\n\nThe great gods kneel before you. The Anunnaki bow low.\nYour fierce light covers the land like a net.\n\nYou set the prisoner free, you lift the bowed-down.\nYou cross the sea, its depths and its breadth.",
	},
	"tablet_law_fragment": {
		"char": "=", "cr": 0.82, "cg": 0.70, "cb": 0.48,
		"name": "law tablet", "category": 4, "slot": "",
		"base_value": 20, "weight": 2, "material": "clay",
		"text": "If a man's ox gores another man's ox to death — both men shall share the loss. They shall sell the dead ox and divide the price between them.\n\nIf the ox was known to gore and the owner had warning — the owner shall pay ox for ox.\n\nIf a man strikes a free man without cause, he shall pay ten shekels of silver.",
	},
	"tablet_caravan_letter": {
		"char": "=", "cr": 0.82, "cg": 0.70, "cb": 0.48,
		"name": "caravan letter", "category": 4, "slot": "",
		"base_value": 8, "weight": 2, "material": "clay",
		"text": "To Puzur-Ashur, merchant of the lower road —\n\nI have heard the badlands road is watched by men who are not toll collectors. Three wagons lost near the second waystation this season.\n\nSend your goods north by Anat's road, or wait until the rains. Trust no one who offers to guide you through the passes.\n\nYour brother in trade, Iqisham-Adad.",
	},
	"tablet_mythic_fragment": {
		"char": "=", "cr": 0.82, "cg": 0.70, "cb": 0.48,
		"name": "mythic fragment", "category": 4, "slot": "",
		"base_value": 25, "weight": 2, "material": "clay",
		"text": "He who saw the deep — the land's foundation —\nwho knew the ways, was wise in all things:\n\nGilgamesh, who built the walls of great Uruk, who cut cedar in the mountains, who killed the Bull of Heaven. He walked the long road, was weary, found rest at last.\n\nHe carved his story into lapis lazuli stone, that those who come after might read it.",
	},

	# ── Hunting yields ───────────────────────────────────────────────────────
	# Produced by skinning/butchering wildlife — not sold in shops by default.
	"game_meat": {
		"char": ":", "cr": 0.78, "cg": 0.28, "cb": 0.22,
		"name": "game meat", "category": 1, "slot": "",
		"base_value": 5, "weight": 3, "dice_count": 1, "dice_sides": 6,
		"material": "raw meat",
	},
	"tough_meat": {
		"char": ":", "cr": 0.52, "cg": 0.22, "cb": 0.18,
		"name": "tough meat", "category": 1, "slot": "",
		"base_value": 2, "weight": 3, "dice_count": 1, "dice_sides": 3,
		"material": "raw meat",
	},
	"light_hide": {
		"char": "~", "cr": 0.75, "cg": 0.62, "cb": 0.40,
		"name": "light hide", "category": 2, "slot": "",
		"base_value": 8, "weight": 5, "material": "hide",
	},
	"heavy_hide": {
		"char": "~", "cr": 0.55, "cg": 0.42, "cb": 0.28,
		"name": "heavy hide", "category": 2, "slot": "",
		"base_value": 13, "weight": 8, "material": "hide",
	},
	"coarse_hide": {
		"char": "~", "cr": 0.42, "cg": 0.38, "cb": 0.28,
		"name": "coarse hide", "category": 2, "slot": "",
		"base_value": 4, "weight": 5, "material": "hide",
	},
	"gazelle_horn": {
		"char": "\\", "cr": 0.90, "cg": 0.84, "cb": 0.65,
		"name": "gazelle horn", "category": 2, "slot": "",
		"base_value": 10, "weight": 2, "material": "horn",
	},
	"ibex_horn": {
		"char": "\\", "cr": 0.78, "cg": 0.70, "cb": 0.48,
		"name": "ibex horn", "category": 2, "slot": "",
		"base_value": 22, "weight": 3, "material": "horn",
	},

	# ── Light sources  (slot: "light") ──────────────────────────────────────
	"torch": {
		"char": "f", "cr": 1.0, "cg": 0.65, "cb": 0.15,
		"name": "torch", "category": 3, "slot": "light",
		"base_value": 4, "weight": 2, "material": "reed",
		"light_fov": 3, "burn_turns": 5000,
	},

	# ── Weapons  (slot: "weapon") ─────────────────────────────────────────────
	"dagger": {
		"char": ")", "cr": 0.78, "cg": 0.72, "cb": 0.55,
		"name": "dagger", "category": 3, "slot": "weapon",
		"attack_bonus": 1, "base_value": 15, "weight": 3, "material": "copper",
	},
	"short_sword": {
		"char": ")", "cr": 0.85, "cg": 0.82, "cb": 0.60,
		"name": "short sword", "category": 3, "slot": "weapon",
		"attack_bonus": 2, "base_value": 28, "weight": 5, "material": "bronze",
	},
	"spear": {
		"char": "/", "cr": 0.72, "cg": 0.65, "cb": 0.42,
		"name": "spear", "category": 3, "slot": "weapon",
		"attack_bonus": 3, "base_value": 20, "weight": 6, "material": "wood",
	},
	"club": {
		"char": ")", "cr": 0.55, "cg": 0.38, "cb": 0.22,
		"name": "club", "category": 3, "slot": "weapon",
		"attack_bonus": 1, "base_value": 8, "weight": 5, "material": "wood",
	},
	"sling": {
		"char": ")", "cr": 0.65, "cg": 0.55, "cb": 0.38,
		"name": "sling", "category": 3, "slot": "weapon",
		"attack_bonus": 0, "base_value": 5, "weight": 1, "material": "leather",
	},

	# ── Body armour  (slot: "body") ───────────────────────────────────────────
	"linen_tunic": {
		"char": "[", "cr": 0.90, "cg": 0.88, "cb": 0.75,
		"name": "linen tunic", "category": 3, "slot": "body",
		"defense_bonus": 1, "base_value": 6, "weight": 3, "material": "linen",
	},
	"wool_cloak": {
		"char": "[", "cr": 0.68, "cg": 0.58, "cb": 0.42,
		"name": "wool cloak", "category": 3, "slot": "body",
		"defense_bonus": 1, "base_value": 10, "weight": 4, "material": "wool",
	},
	"leather_vest": {
		"char": "[", "cr": 0.60, "cg": 0.42, "cb": 0.25,
		"name": "leather vest", "category": 3, "slot": "body",
		"defense_bonus": 2, "base_value": 18, "weight": 7, "material": "leather",
	},

	# ── Footwear  (slot: "feet") ──────────────────────────────────────────────
	"sandals": {
		"char": "[", "cr": 0.78, "cg": 0.65, "cb": 0.42,
		"name": "sandals", "category": 3, "slot": "feet",
		"defense_bonus": 0, "base_value": 4, "weight": 1, "material": "leather",
	},
	"leather_boots": {
		"char": "[", "cr": 0.55, "cg": 0.40, "cb": 0.25,
		"name": "leather boots", "category": 3, "slot": "feet",
		"defense_bonus": 1, "base_value": 12, "weight": 3, "material": "leather",
	},

	# ── Headwear  (slot: "head") ──────────────────────────────────────────────
	"linen_headband": {
		"char": "[", "cr": 0.90, "cg": 0.88, "cb": 0.75,
		"name": "linen headband", "category": 3, "slot": "head",
		"defense_bonus": 0, "base_value": 3, "weight": 1, "material": "linen",
	},
	"leather_cap": {
		"char": "[", "cr": 0.60, "cg": 0.42, "cb": 0.25,
		"name": "leather cap", "category": 3, "slot": "head",
		"defense_bonus": 1, "base_value": 10, "weight": 2, "material": "leather",
	},
	"bronze_helmet": {
		"char": "[", "cr": 0.80, "cg": 0.50, "cb": 0.20,
		"name": "bronze helmet", "category": 3, "slot": "head",
		"defense_bonus": 2, "base_value": 35, "weight": 6, "material": "bronze",
	},
}


static func get_item(item_type: String) -> Dictionary:
	return DATA.get(item_type, {})
