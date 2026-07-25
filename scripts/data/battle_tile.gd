class_name BattleTile
extends RefCounted

var grid_pos: Vector2i = Vector2i.ZERO
var walkable: bool = true
var height: float = 0.0
## Cover on each cardinal edge of this tile (Direction -> Cover).
var edge_cover: Dictionary = {}
var occupant = null # Unit


func is_occupied() -> bool:
	return occupant != null and is_instance_valid(occupant) and not occupant.is_dead()


func clear_occupant() -> void:
	occupant = null


func get_edge_cover(dir: BattleEnums.Direction) -> BattleEnums.Cover:
	return edge_cover.get(dir, BattleEnums.Cover.NONE) as BattleEnums.Cover


func set_edge_cover(dir: BattleEnums.Direction, cover: BattleEnums.Cover) -> void:
	if cover == BattleEnums.Cover.NONE:
		edge_cover.erase(dir)
		return
	var existing: BattleEnums.Cover = get_edge_cover(dir)
	if int(cover) >= int(existing):
		edge_cover[dir] = cover


func has_any_cover() -> bool:
	return not edge_cover.is_empty()
