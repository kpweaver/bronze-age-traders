class_name NPC
extends "res://scripts/entities/actor.gd"

# NPC — a village inhabitant built from a data template in content/npcs.gd.
# NPCs are peaceful by default (ai = null). Merchants can open a trade screen.

var npc_type: String   = ""
var dialogue: Array    = []    # cycling lines shown on interact
var trade_stock: Array = []    # Array of {item_type, qty, price} — mutable per instance
var is_merchant: bool  = false
var buy_mult: float    = 0.70  # fraction of item.base_value we pay when buying from player
var sell_mult: float   = 1.35  # multiplier on item.base_value when selling to player
var _dialogue_idx: int = 0


func _init(p_pos: Vector2i, p_type: String, p_data: Dictionary) -> void:
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
		int(p_data.get("max_hp", 12)),
		int(p_data.get("defense", 0)),
		int(p_data.get("power", 1))
	)
	npc_type    = p_type
	dialogue    = p_data.get("dialogue", ["..."])
	is_merchant = bool(p_data.get("is_merchant", false))
	trade_stock = p_data.get("trade_stock", []).duplicate(true)
	buy_mult    = float(p_data.get("buy_mult",  0.70))
	sell_mult   = float(p_data.get("sell_mult", 1.35))
	ai          = null  # peaceful


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
