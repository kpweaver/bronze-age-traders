# Content Agent Guide

This directory contains data files for NPCs and future content (lore, dialogue, item tables).
**Only edit files in this `content/` folder.** Do not touch GDScript files outside it.

## Tone & Setting
Bronze Age Mediterranean / Near East, ~1500–1200 BCE equivalent. Cities include Ugarit, Byblos,
Jericho, Nippur, Ur. Materials: stone, copper, tin, bronze (no iron yet). Religion: sun gods,
storm gods, grain goddesses. Themes: trade routes, city-state politics, desert survival, bronze
scarcity, palace bureaucracy, writing (cuneiform/proto-alphabetic). Tone: matter-of-fact and
world-weary, not high-fantasy. No elves, no magic systems — mythic undertone only.

---

## `npcs.gd` — NPC Template Data

Each key in `DATA` is an `npc_type` string. Systems code reads these; **do not rename existing
keys or change field types without also updating `scripts/entities/npc.gd`**.

### Field reference

| Field          | Type    | Required | Notes |
|----------------|---------|----------|-------|
| `name`         | String  | yes      | Lowercase display name (e.g. `"merchant"`) |
| `char`         | String  | yes      | Single CP437 glyph — use `@` for humanoids |
| `cr/cg/cb`     | float   | yes      | RGB colour, each 0.0–1.0 |
| `max_hp`       | int     | yes      | Hit points |
| `defense`      | int     | yes      | Added to AC (10 + defense) |
| `power`        | int     | yes      | Base melee damage bonus (keep ≤ 2 for peaceful NPCs) |
| `is_merchant`  | bool    | yes      | `true` → player can open trade screen |
| `buy_mult`     | float   | no       | Fraction of `base_value` paid when buying from player (default 0.70) |
| `sell_mult`    | float   | no       | Multiplier on `base_value` when selling to player (default 1.35) |
| `dialogue`     | Array   | yes      | Cycling lines; first entry is the greeting |
| `trade_stock`  | Array   | if merch | `[{item_type, qty, price}]` — see below |
| `spawn_weight` | int     | no       | Relative spawn frequency in villages (default 1; merchant = 3) |

### `trade_stock` entry

```gdscript
{"item_type": "copper_ingot", "qty": 3, "price": 9}
```

`item_type` must match a `TYPE_*` constant in `scripts/entities/item.gd`.  
`price` is in gold coins and overrides the item's `base_value`.  
`qty` decreases as the player buys; when it hits 0 the item disappears from the merchant's list.

### Valid item_type values (trade goods)

`pottery`, `linen_cloth`, `cedar_wood`, `tin_ingot`, `copper_ingot`, `bronze_ingot`,
`olive_oil`, `wine`, `ivory`, `lapis_lazuli`, `silver_ingot`, `purple_dye`, `wheat`, `clay_tablet`

### Valid item_type values (equipment)

Weapons: `dagger`, `short_sword`, `spear`, `club`, `sling`  
Body: `linen_tunic`, `wool_cloak`, `leather_vest`  
Feet: `sandals`, `leather_boots`  
Head: `linen_headband`, `leather_cap`, `bronze_helmet`

### Dialogue guidelines

- 3–5 lines per NPC; they cycle on repeated bumps.
- First line = greeting (shown immediately on bump).
- Reflect the NPC's profession and the world's themes.
- Keep each line under ~80 characters so it fits in the message log.
- Period-accurate references only — no medieval/fantasy clichés.

### Adding a new NPC type

1. Add an entry to `DATA` in `npcs.gd` following the schema above.
2. Assign a `spawn_weight` (1 = rare, 3 = common).
3. The systems code will automatically pick it up — no other files need editing.

### Example skeleton

```gdscript
"potter": {
    "name": "potter", "char": "@",
    "cr": 0.75, "cg": 0.52, "cb": 0.35,
    "max_hp": 8, "defense": 0, "power": 1,
    "is_merchant": true, "buy_mult": 0.55, "sell_mult": 1.50,
    "dialogue": [
        "Clay from the river, fire from the kiln — that is my trade.",
        "A good vessel holds water for a week's march.",
    ],
    "trade_stock": [
        {"item_type": "pottery", "qty": 6, "price": 4},
    ],
    "spawn_weight": 1,
},
```

---

## `items.gd` — Item Template Data

Each key in `DATA` is an `item_type` string. `scripts/entities/item.gd` reads these at
construction time — **do not rename existing keys or change field types** without also updating
that file.

### Field reference

| Field          | Type    | Required | Notes |
|----------------|---------|----------|-------|
| `char`         | String  | yes      | Single CP437 glyph shown on the map |
| `cr/cg/cb`     | float   | yes      | RGB colour, each 0.0–1.0 |
| `name`         | String  | yes      | Lowercase display name |
| `category`     | int     | yes      | 0=gold  1=usable  2=trade  3=equipment |
| `slot`         | String  | yes      | `"weapon"`, `"body"`, `"feet"`, `"head"`, or `""` |
| `base_value`   | int     | no       | Canonical price in gold coins (0 for gold) |
| `material`     | String  | no       | Period-accurate material descriptor |
| `dice_count`   | int     | no       | Usable items: number of HP-recovery dice |
| `dice_sides`   | int     | no       | Usable items: sides per die |
| `attack_bonus` | int     | no       | Equipment: added to attacker's damage roll |
| `defense_bonus`| int     | no       | Equipment: added to wearer's AC |

Missing numeric fields default to 0; missing string fields default to `""`.

### Adding a new item

1. Add an entry to `DATA` in `items.gd` with at minimum `char`, `cr/cg/cb`, `name`,
   `category`, and `slot`.
2. The systems code will automatically pick it up — no other files need editing.
3. To make it available in a merchant's stock, add it to the NPC's `trade_stock` in `npcs.gd`.

### Example skeleton

```gdscript
"obsidian_blade": {
    "char": ")", "cr": 0.20, "cg": 0.20, "cb": 0.22,
    "name": "obsidian blade", "category": 3, "slot": "weapon",
    "attack_bonus": 2, "base_value": 18, "material": "obsidian",
},
```
