class_name UnitSpawn
extends RefCounted

const UnitStatsData := preload("res://scripts/data/unit_stats.gd")

var team: BattleEnums.Team
var grid_pos: Vector2i
var stats: UnitStatsData


func _init(p_team: BattleEnums.Team, p_pos: Vector2i, p_stats: UnitStatsData) -> void:
	team = p_team
	grid_pos = p_pos
	stats = p_stats
