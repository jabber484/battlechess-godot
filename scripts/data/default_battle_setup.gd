class_name DefaultBattleSetup
extends RefCounted

const UnitSpawnData := preload("res://scripts/data/unit_spawn.gd")
const UnitStatsData := preload("res://scripts/data/unit_stats.gd")
const SimpleMoveAbilityDataScript := preload("res://scripts/abilities/simple_move_ability_data.gd")
const SimpleAttackAbilityDataScript := preload("res://scripts/abilities/simple_attack_ability_data.gd")


static func get_unit_spawns() -> Array[UnitSpawnData]:
	return [
		UnitSpawnData.new(
			BattleEnums.Team.PLAYER,
			Vector2i(10, 10),
			_make_stats("Scout", 8, 5, 5, 75, 22, 90),
		),
		UnitSpawnData.new(
			BattleEnums.Team.PLAYER,
			Vector2i(9, 10),
			_make_stats("Heavy", 4, 3, 6, 70, 32, 120),
		),
		UnitSpawnData.new(
			BattleEnums.Team.ENEMY,
			Vector2i(1, 1),
			_make_stats("Raider", 7, 4, 5, 72, 20, 85),
		),
		UnitSpawnData.new(
			BattleEnums.Team.ENEMY,
			Vector2i(2, 1),
			_make_stats("Guard", 5, 3, 4, 68, 24, 100),
		),
		UnitSpawnData.new(
			BattleEnums.Team.ENEMY,
			Vector2i(1, 2),
			_make_stats("Sniper", 3, 3, 7, 80, 28, 75),
		),
	]


static func _make_stats(
	display_name: String,
	speed: int,
	move_range: int,
	attack_range: int,
	accuracy: int,
	damage: int,
	max_hp: int,
) -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.display_name = display_name
	stats.speed = speed
	stats.move_range = move_range
	stats.attack_range = attack_range
	stats.accuracy = accuracy
	stats.damage = damage
	stats.max_hp = max_hp
	var abilities: Array[AbilityData] = []
	abilities.append(SimpleMoveAbilityDataScript.new())
	abilities.append(SimpleAttackAbilityDataScript.new())
	stats.abilities = abilities
	return stats
