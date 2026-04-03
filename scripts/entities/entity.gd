class_name Entity
extends RefCounted

var pos: Vector2i
var char: String
var color: Color
var name: String
var blocks_movement: bool
var game_map  # GameMap — untyped to avoid circular dependency


func _init(
	p_pos: Vector2i,
	p_char: String,
	p_color: Color,
	p_name: String,
	p_blocks: bool = true
) -> void:
	pos = p_pos
	char = p_char
	color = p_color
	name = p_name
	blocks_movement = p_blocks
