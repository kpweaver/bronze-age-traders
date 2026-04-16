class_name ModulateTileMapLayer
extends TileMapLayer

var cell_modulates: Dictionary = {}


func clear_with_modulates() -> void:
	clear()
	cell_modulates.clear()
	notify_runtime_tile_data_update()


func set_cell_with_modulate(coords: Vector2i, source_id: int, atlas_coords: Vector2i, color: Color, alternative_tile: int = 0) -> void:
	set_cell(coords, source_id, atlas_coords, alternative_tile)
	cell_modulates[coords] = color


func erase_cell_with_modulate(coords: Vector2i) -> void:
	erase_cell(coords)
	cell_modulates.erase(coords)


func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return cell_modulates.has(coords)


func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	tile_data.modulate = cell_modulates.get(coords, Color.WHITE)
