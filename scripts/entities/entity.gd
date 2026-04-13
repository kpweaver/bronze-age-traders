class_name Entity
extends RefCounted

var pos: Vector2i
@warning_ignore("shadowed_global_identifier")
var char: String
var tileset_char: String = ""
var color: Color
var name: String
var blocks_movement: bool
var light_radius: int = 0  # > 0 for placed light fixtures (braziers, road torches)


func _init(
	p_pos: Vector2i,
	p_char: String,
	p_color: Color,
	p_name: String,
	p_blocks: bool = true
) -> void:
	pos = p_pos
	char = p_char
	tileset_char = p_char
	color = p_color
	name = p_name
	blocks_movement = p_blocks
