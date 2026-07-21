class_name BattleTile
extends RefCounted

var grid_pos: Vector2i = Vector2i.ZERO
var walkable: bool = true
var height: float = 0.0
var cover: BattleEnums.Cover = BattleEnums.Cover.NONE
var occupant = null # Unit


func is_occupied() -> bool:
	return occupant != null and is_instance_valid(occupant) and not occupant.is_dead()


func clear_occupant() -> void:
	occupant = null
