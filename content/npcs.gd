# NPC template data — edit this file to add or modify village inhabitants.
# Systems code reads these templates; do not change field names without updating npc.gd.
#
# Schema for each entry:
#   name          String   — display name shown in-game
#   char          String   — single CP437 glyph
#   cr/cg/cb      float    — RGB colour (0.0–1.0)
#   str/dex/con   int      — ability scores (3–18 range; modifier = (score-10)/2)
#   int/wis/cha   int      — ability scores (int = Intelligence, not GDScript type)
#   base_hp       int      — hit points before CON modifier; max_hp = base_hp + con_mod * level
#   defense       int      — base defence (adds to AC; DEX mod also applies automatically)
#   power         int      — base melee damage bonus (STR mod also applies automatically)
#   level         int      — creature level (1 for all current NPCs; future scaling hook)
#   attack_speed  float    — attacks per turn (1.0 = normal; stub for future multi-attack)
#   is_merchant   bool     — true = player can open the trade screen with this NPC
#   buy_mult      float    — fraction of item.base_value we pay when buying from player
#   sell_mult     float    — multiplier on item.base_value when we sell to player
#   dialogue      Array    — cycling lines shown on interact; first line is the greeting
#   trade_stock   Array    — [{item_type, qty, price}] items the merchant sells
#                            price overrides base_value; qty decreases on purchase
#   spawn_weight  int      — relative spawn probability in village chunks (default 1)

const DATA: Dictionary = {
	"merchant": {
		"name": "merchant", "char": "@",
		"cr": 0.90, "cg": 0.72, "cb": 0.28,
		"str": 10, "dex": 11, "con": 10, "int": 12, "wis": 11, "cha": 13,
		"base_hp": 12, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.65, "sell_mult": 1.40,
		"dialogue": [
			"Well met, traveller. What brings you to these roads?",
			"Bronze is the lifeblood of trade. Have you any to offer?",
			"I have goods from the coast — lapis, cedar, fine dyed cloth.",
			"The road west is treacherous. Bandits. But the profit is worth it.",
		],
		"trade_stock": [
			{"item_type": "copper_ingot", "qty": 3, "price": 9},
			{"item_type": "tin_ingot",    "qty": 2, "price": 14},
			{"item_type": "linen_cloth",  "qty": 5, "price": 5},
			{"item_type": "olive_oil",    "qty": 3, "price": 7},
			{"item_type": "pottery",      "qty": 4, "price": 4},
			{"item_type": "wheat",        "qty": 6, "price": 3},
			{"item_type": "torch",        "qty": 4, "price": 5},
		],
		"spawn_weight": 3,
	},
	"village_elder": {
		"name": "village elder", "char": "@",
		"cr": 0.82, "cg": 0.68, "cb": 0.55,
		"str": 8, "dex": 8, "con": 9, "int": 12, "wis": 14, "cha": 12,
		"base_hp": 11, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": false,
		"dialogue": [
			"This village has stood for seven generations. I hope for seven more.",
			"The caravans come less often now. I fear what that means.",
			"Our well has never run dry — the gods still smile on us.",
			"A stranger in the village is either a merchant or trouble. Which are you?",
		],
		"spawn_weight": 1,
	},
	"smith": {
		"name": "smith", "char": "@",
		"cr": 0.70, "cg": 0.45, "cb": 0.25,
		"str": 15, "dex": 10, "con": 14, "int": 9, "wis": 10, "cha": 8,
		"base_hp": 16, "defense": 1, "power": 3, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.50, "sell_mult": 1.60,
		"dialogue": [
			"Copper I have. Tin is what I need — bring me tin, I'll make you bronze.",
			"A good blade is worth a hundred prayers to the sun god.",
			"Stand back from the forge — I've burned better men than you.",
			"These village commissions keep me fed. But I dream of palace work.",
		],
		"trade_stock": [
			{"item_type": "dagger",        "qty": 2, "price": 18},
			{"item_type": "club",          "qty": 2, "price": 9},
			{"item_type": "spear",         "qty": 1, "price": 24},
			{"item_type": "copper_ingot",  "qty": 4, "price": 10},
			{"item_type": "bronze_ingot",  "qty": 1, "price": 26},
		],
		"spawn_weight": 1,
	},
	"scribe": {
		"name": "scribe", "char": "@",
		"cr": 0.72, "cg": 0.82, "cb": 0.72,
		"str": 8, "dex": 12, "con": 9, "int": 15, "wis": 12, "cha": 10,
		"base_hp": 9, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": false,
		"dialogue": [
			"I keep the records of this village. Every debt, every birth, every death.",
			"Can you read cuneiform? No? Most cannot.",
			"Word from the coast — a fleet was lost. Expect tin shortages.",
			"The palace at Ebla keeps better records. But we manage.",
		],
		"spawn_weight": 1,
	},
	"weaver": {
		"name": "weaver", "char": "@",
		"cr": 0.75, "cg": 0.78, "cb": 0.62,
		"str": 9, "dex": 13, "con": 10, "int": 10, "wis": 12, "cha": 11,
		"base_hp": 8, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.55, "sell_mult": 1.45,
		"dialogue": [
			"Linen, wool, and a patient hand — that is all one needs.",
			"The dyers charge too much for purple. I use madder root instead.",
			"A good cloak is worth more than a weapon in the desert cold.",
		],
		"trade_stock": [
			{"item_type": "linen_cloth",     "qty": 6, "price": 5},
			{"item_type": "linen_tunic",     "qty": 3, "price": 7},
			{"item_type": "wool_cloak",      "qty": 2, "price": 12},
			{"item_type": "linen_headband",  "qty": 4, "price": 4},
			{"item_type": "sandals",         "qty": 3, "price": 5},
		],
		"spawn_weight": 1,
	},
	"priest": {
		"name": "priest", "char": "@",
		"cr": 0.88, "cg": 0.78, "cb": 0.45,
		"str": 9, "dex": 9, "con": 10, "int": 12, "wis": 14, "cha": 13,
		"base_hp": 9, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": false,
		"dialogue": [
			"The grain goddess demands the first harvest. Always the first.",
			"We burn cedar at dawn. The smoke carries our words to the storm god.",
			"You carry weapons in the sight of the temple. Tread carefully.",
			"The omen tablets were read at new moon. I do not share their contents.",
			"Give what you can to the offering bowl. The god remembers.",
		],
		"spawn_weight": 1,
	},
	"dyer": {
		"name": "dyer", "char": "@",
		"cr": 0.65, "cg": 0.45, "cb": 0.70,
		"str": 11, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 11,
		"base_hp": 8, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.50, "sell_mult": 1.55,
		"dialogue": [
			"Purple from the murex — there is nothing like it in all the world.",
			"Do you know how many shells it takes to dye a single bolt? Neither do the nobles.",
			"I have sold cloth to the palace at Ugarit. They paid without complaint.",
			"The smell never leaves you. My wife has long since accepted this.",
		],
		"trade_stock": [
			{"item_type": "purple_dye",  "qty": 3, "price": 22},
			{"item_type": "linen_cloth", "qty": 4, "price": 6},
			{"item_type": "wool_cloak",  "qty": 2, "price": 15},
		],
		"spawn_weight": 1,
	},
	"foreign_trader": {
		"name": "foreign trader", "char": "@",
		"cr": 0.80, "cg": 0.62, "cb": 0.38,
		"str": 9, "dex": 12, "con": 10, "int": 13, "wis": 11, "cha": 14,
		"base_hp": 11, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.60, "sell_mult": 1.50,
		"dialogue": [
			"I have come from the Aegean coast — far longer a road than it sounds.",
			"Ivory from the south, lapis from the east. I trade the length of the world.",
			"I carry letters for four city-states. My loyalty is to profit, not allegiance.",
			"The sea was kind this season. The land roads are another matter.",
			"Ask me no questions about where I have been. Ask only what I carry.",
		],
		"trade_stock": [
			{"item_type": "lapis_lazuli", "qty": 2, "price": 35},
			{"item_type": "ivory",        "qty": 1, "price": 45},
			{"item_type": "cedar_wood",   "qty": 3, "price": 12},
			{"item_type": "wine",         "qty": 4, "price": 8},
			{"item_type": "silver_ingot", "qty": 2, "price": 28},
		],
		"spawn_weight": 2,
	},
	"caravan_guard": {
		"name": "caravan guard", "char": "@",
		"cr": 0.65, "cg": 0.50, "cb": 0.30,
		"str": 14, "dex": 12, "con": 13, "int": 9, "wis": 10, "cha": 9,
		"base_hp": 19, "defense": 2, "power": 3, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.45, "sell_mult": 1.55,
		"dialogue": [
			"I walk the road so merchants do not have to worry about it.",
			"Three caravans this season. One ambush. We lost two men and a donkey.",
			"I sell the gear I have taken off men who no longer need it.",
			"A spear is only as good as the arm behind it. Mine is reliable.",
		],
		"trade_stock": [
			{"item_type": "spear",        "qty": 1, "price": 20},
			{"item_type": "sling",        "qty": 2, "price": 8},
			{"item_type": "leather_vest", "qty": 1, "price": 18},
			{"item_type": "leather_boots","qty": 2, "price": 9},
			{"item_type": "leather_cap",  "qty": 1, "price": 7},
			{"item_type": "torch",        "qty": 3, "price": 5},
		],
		"spawn_weight": 2,
	},
	"herbalist": {
		"name": "herbalist", "char": "@",
		"cr": 0.58, "cg": 0.72, "cb": 0.45,
		"str": 9, "dex": 13, "con": 10, "int": 13, "wis": 14, "cha": 11,
		"base_hp": 8, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": true, "buy_mult": 0.55, "sell_mult": 1.45,
		"dialogue": [
			"Cedar bark for fever. Olive oil for wounds. The rest is patience.",
			"I learned my trade from a woman in Jericho. She knew things no scribe recorded.",
			"Most ailments pass on their own. I sell comfort while they do.",
			"The palace physicians use the same remedies — they just charge more.",
			"Drink water before you think you need it. That is all the medicine most men lack.",
		],
		"trade_stock": [
			{"item_type": "olive_oil",  "qty": 4, "price": 8},
			{"item_type": "cedar_wood", "qty": 3, "price": 11},
			{"item_type": "pottery",    "qty": 5, "price": 4},
		],
		"spawn_weight": 1,
	},
	# -----------------------------------------------------------------------
	# Wildlife — overworld roaming animals spawned by procgen, not villages.
	# is_wildlife: true changes the bump-message format in game_world.gd.
	# wander_radius is larger than village NPCs so they roam freely.
	# -----------------------------------------------------------------------
	"gazelle": {
		"name": "gazelle", "char": "g",
		"cr": 0.85, "cg": 0.73, "cb": 0.38,
		"str": 8, "dex": 16, "con": 10, "int": 2, "wis": 12, "cha": 6,
		"base_hp": 6, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": false, "is_wildlife": true,
		"wander_radius": 30, "move_chance": 0.55,
		"dialogue": [
			"The gazelle watches you with dark eyes, poised to bolt.",
			"The gazelle flicks its ears and takes a few skittish steps away.",
			"A pair of slender horns catch the light as the gazelle turns.",
		],
		"skin_table": {
			"poor":  [{"item_type": "tough_meat",  "qty": 1}],
			"good":  [{"item_type": "game_meat",   "qty": 1}, {"item_type": "light_hide",   "qty": 1}],
			"great": [{"item_type": "game_meat",   "qty": 2}, {"item_type": "light_hide",   "qty": 1}],
			"crit":  [{"item_type": "game_meat",   "qty": 2}, {"item_type": "light_hide",   "qty": 1}, {"item_type": "gazelle_horn", "qty": 1}],
		},
		"spawn_weight": 0,  # spawned by procgen, not village pools
	},
	"onager": {
		"name": "onager", "char": "q",
		"cr": 0.72, "cg": 0.60, "cb": 0.42,
		"str": 13, "dex": 12, "con": 13, "int": 2, "wis": 10, "cha": 5,
		"base_hp": 13, "defense": 0, "power": 2, "level": 1, "attack_speed": 1.0,
		"is_merchant": false, "is_wildlife": true,
		"wander_radius": 25, "move_chance": 0.40,
		"dialogue": [
			"The wild ass regards you with flat, suspicious eyes.",
			"The onager stamps a hoof and sidesteps away.",
			"A braying call rises from the onager and fades into the hot air.",
		],
		"skin_table": {
			"poor":  [{"item_type": "tough_meat",  "qty": 2}],
			"good":  [{"item_type": "game_meat",   "qty": 2}, {"item_type": "heavy_hide",   "qty": 1}],
			"great": [{"item_type": "game_meat",   "qty": 3}, {"item_type": "heavy_hide",   "qty": 1}],
			"crit":  [{"item_type": "game_meat",   "qty": 3}, {"item_type": "heavy_hide",   "qty": 2}],
		},
		"spawn_weight": 0,
	},
	"ibex": {
		"name": "ibex", "char": "i",
		"cr": 0.50, "cg": 0.40, "cb": 0.28,
		"str": 11, "dex": 14, "con": 11, "int": 2, "wis": 12, "cha": 5,
		"base_hp": 10, "defense": 1, "power": 2, "level": 1, "attack_speed": 1.0,
		"is_merchant": false, "is_wildlife": true,
		"wander_radius": 20, "move_chance": 0.25,
		"dialogue": [
			"The ibex picks its way across the rock with unhurried grace.",
			"Curved horns sweep back as the ibex turns to study you.",
			"The ibex stands motionless for a long moment, then moves on.",
		],
		"skin_table": {
			"poor":  [{"item_type": "tough_meat",  "qty": 1}],
			"good":  [{"item_type": "game_meat",   "qty": 1}, {"item_type": "light_hide",   "qty": 1}],
			"great": [{"item_type": "game_meat",   "qty": 2}, {"item_type": "light_hide",   "qty": 1}],
			"crit":  [{"item_type": "game_meat",   "qty": 2}, {"item_type": "light_hide",   "qty": 1}, {"item_type": "ibex_horn",    "qty": 1}],
		},
		"spawn_weight": 0,
	},
	"hyena": {
		"name": "hyena", "char": "h",
		"cr": 0.62, "cg": 0.54, "cb": 0.38,
		"str": 13, "dex": 13, "con": 13, "int": 3, "wis": 12, "cha": 4,
		"base_hp": 15, "defense": 1, "power": 3, "level": 1, "attack_speed": 1.0,
		"is_merchant": false, "is_wildlife": true,
		"wander_radius": 35, "move_chance": 0.35,
		"dialogue": [
			"The hyena circles at a distance, watching.",
			"A low, rising whoop from the hyena carries through the still air.",
			"The hyena's spotted flanks heave as it trots a slow perimeter.",
		],
		"skin_table": {
			"poor":  [{"item_type": "coarse_hide",  "qty": 1}],
			"good":  [{"item_type": "tough_meat",   "qty": 1}, {"item_type": "coarse_hide",  "qty": 1}],
			"great": [{"item_type": "tough_meat",   "qty": 2}, {"item_type": "coarse_hide",  "qty": 1}],
			"crit":  [{"item_type": "tough_meat",   "qty": 2}, {"item_type": "coarse_hide",  "qty": 2}],
		},
		"spawn_weight": 0,
	},
	"water_carrier": {
		"name": "water carrier", "char": "@",
		"cr": 0.60, "cg": 0.68, "cb": 0.78,
		"str": 13, "dex": 11, "con": 12, "int": 8, "wis": 10, "cha": 9,
		"base_hp": 9, "defense": 0, "power": 1, "level": 1, "attack_speed": 1.0,
		"is_merchant": false,
		"dialogue": [
			"Water from the cistern. Fresh as of this morning.",
			"I carry sixty jars before the sun reaches midday. Ask me something useful.",
			"The well runs deep here. In the south I have seen men die for a cupful.",
			"Do not take water for granted. The desert will teach you otherwise.",
		],
		"spawn_weight": 2,
	},
}


static func get_npc(npc_type: String) -> Dictionary:
	return DATA.get(npc_type, DATA["merchant"])


# Returns a list of npc_type strings weighted by spawn_weight.
# Use this to randomly pick NPC types when populating a village.
static func weighted_types() -> Array:
	var pool: Array = []
	for t: String in DATA:
		var w: int = int(DATA[t].get("spawn_weight", 1))
		for _i in range(w):
			pool.append(t)
	return pool
