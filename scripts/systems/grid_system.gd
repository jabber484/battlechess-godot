class_name GridSystem
extends Node

signal tile_clicked(grid_pos: Vector2i)
signal occupancy_changed(grid_pos: Vector2i)

var tiles: Dictionary = {} # Vector2i -> BattleTile
var _cover_layout: Array[Dictionary] = [
	{"pos": Vector2i(3, 3), "cover": BattleEnums.Cover.HALF},
	{"pos": Vector2i(4, 3), "cover": BattleEnums.Cover.HALF},
	{"pos": Vector2i(7, 3), "cover": BattleEnums.Cover.FULL},
	{"pos": Vector2i(8, 4), "cover": BattleEnums.Cover.HALF},
	{"pos": Vector2i(3, 8), "cover": BattleEnums.Cover.FULL},
	{"pos": Vector2i(4, 8), "cover": BattleEnums.Cover.HALF},
	{"pos": Vector2i(6, 6), "cover": BattleEnums.Cover.HALF},
	{"pos": Vector2i(7, 7), "cover": BattleEnums.Cover.FULL},
	{"pos": Vector2i(5, 5), "cover": BattleEnums.Cover.HALF},
	{"pos": Vector2i(8, 8), "cover": BattleEnums.Cover.HALF},
]


func _enter_tree() -> void:
	if tiles.is_empty():
		_build_tiles()


func _ready() -> void:
	if tiles.is_empty():
		_build_tiles()


func _build_tiles() -> void:
	tiles.clear()
	for x in GridMath.GRID_SIZE:
		for y in GridMath.GRID_SIZE:
			var pos := Vector2i(x, y)
			var tile := BattleTile.new()
			tile.grid_pos = pos
			tiles[pos] = tile
	for entry in _cover_layout:
		var tile: BattleTile = tiles[entry["pos"]]
		tile.cover = entry["cover"]


func get_tile(grid_pos: Vector2i) -> BattleTile:
	return tiles.get(grid_pos) as BattleTile


func is_walkable(grid_pos: Vector2i) -> bool:
	var tile := get_tile(grid_pos)
	return tile != null and tile.walkable


func can_stand(grid_pos: Vector2i, ignore_unit: Unit = null) -> bool:
	var tile := get_tile(grid_pos)
	if tile == null or not tile.walkable:
		return false
	if not tile.is_occupied():
		return true
	return ignore_unit != null and tile.occupant == ignore_unit


func get_cover(grid_pos: Vector2i) -> BattleEnums.Cover:
	var tile := get_tile(grid_pos)
	if tile == null:
		return BattleEnums.Cover.NONE
	return tile.cover


func get_occupant(grid_pos: Vector2i) -> Unit:
	var tile := get_tile(grid_pos)
	if tile == null:
		return null
	return tile.occupant if tile.is_occupied() else null


func register_unit(unit: Unit) -> void:
	var tile := get_tile(unit.grid_pos)
	if tile == null:
		push_error("Cannot register unit outside grid: %s" % unit.grid_pos)
		return
	tile.occupant = unit
	occupancy_changed.emit(unit.grid_pos)


func clear_occupant(grid_pos: Vector2i) -> void:
	var tile := get_tile(grid_pos)
	if tile == null:
		return
	tile.clear_occupant()
	occupancy_changed.emit(grid_pos)


func move_occupant(from_pos: Vector2i, to_pos: Vector2i, unit: Unit, update_visual: bool = true) -> void:
	clear_occupant(from_pos)
	var tile := get_tile(to_pos)
	if tile == null:
		return
	tile.occupant = unit
	unit.set_grid_pos(to_pos, update_visual)
	occupancy_changed.emit(to_pos)


func all_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in tiles.keys():
		result.append(key)
	return result
