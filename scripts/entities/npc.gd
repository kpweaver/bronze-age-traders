class_name NPC
extends "res://scripts/entities/actor.gd"

# NPC — a village inhabitant built from a data template in content/npcs.gd.
# NPCs are peaceful by default (ai = null). Merchants can open a trade screen.

var npc_type: String   = ""
var dialogue: Array    = []    # cycling lines shown on interact
var trade_stock: Array = []    # Array of {item_type, qty, price} — mutable per instance
var is_merchant: bool  = false
var is_wildlife: bool  = false  # true for overworld animals — changes bump-message format
var buy_mult: float    = 0.70  # fraction of item.base_value we pay when buying from player
var sell_mult: float   = 1.35  # multiplier on item.base_value when selling to player
var _dialogue_idx: int = 0

# Behaviour / movement state
var home_pos: Vector2i  = Vector2i.ZERO  # tile where this NPC was spawned
var wander_radius: int  = 8              # max tiles from home_pos willing to wander


func _init(p_pos: Vector2i, p_type: String, p_data: Dictionary) -> void:
	# Read ability scores before super._init so we can factor CON into max_hp.
	var p_str: int   = int(p_data.get("str", 10))
	var p_dex: int   = int(p_data.get("dex", 10))
	var p_con: int   = int(p_data.get("con", 10))
	var p_int: int   = int(p_data.get("int", 10))
	var p_wis: int   = int(p_data.get("wis", 10))
	var p_cha: int   = int(p_data.get("cha", 10))
	var p_level: int           = int(p_data.get("level", 1))
	var p_attack_speed: float  = float(p_data.get("attack_speed", 1.0))
	var p_con_mod: int         = (p_con - 10) / 2
	# base_hp is the naked value before CON; fall back to max_hp for old data.
	var p_base_hp: int         = int(p_data.get("base_hp", p_data.get("max_hp", 12)))
	var p_max_hp: int          = p_base_hp + p_con_mod * p_level

	var col := Color(
		float(p_data.get("cr", 0.85)),
		float(p_data.get("cg", 0.72)),
		float(p_data.get("cb", 0.38))
	)
	super._init(
		p_pos,
		str(p_data.get("char", "@")),
		col,
		str(p_data.get("name", p_type)),
		p_max_hp,
		int(p_data.get("defense", 0)),
		int(p_data.get("power", 1))
	)
	# Apply ability scores computed above.
	str_score    = p_str
	dex_score    = p_dex
	con_score    = p_con
	int_score    = p_int
	wis_score    = p_wis
	cha_score    = p_cha
	level        = p_level
	attack_speed = p_attack_speed

	npc_type      = p_type
	dialogue      = p_data.get("dialogue", ["..."])
	is_merchant   = bool(p_data.get("is_merchant", false))
	is_wildlife   = bool(p_data.get("is_wildlife", false))
	trade_stock   = p_data.get("trade_stock", []).duplicate(true)
	buy_mult      = float(p_data.get("buy_mult",  0.70))
	sell_mult     = float(p_data.get("sell_mult", 1.35))
	home_pos      = p_pos
	wander_radius = int(p_data.get("wander_radius", 8))
	ai            = null  # peaceful by default — attach WanderAI etc. at spawn


# Return the next cycling dialogue line (advances internal index).
func greet() -> String:
	var line: String = str(dialogue[_dialogue_idx % dialogue.size()])
	_dialogue_idx = (_dialogue_idx + 1) % dialogue.size()
	return line


# Price we charge the player when selling a stock item at the given index.
func sell_price_at(stock_idx: int) -> int:
	if stock_idx < 0 or stock_idx >= trade_stock.size():
		return 0
	return int(trade_stock[stock_idx].get("price", 0))


# Price we pay the player when buying an item from them.
func buy_price(item) -> int:
	return maxi(1, int(float(item.base_value) * buy_mult))
