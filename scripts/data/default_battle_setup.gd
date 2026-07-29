class_name DefaultBattleSetup
extends RefCounted

const UnitSpawnData := preload("res://scripts/data/unit_spawn.gd")
const UnitStatsData := preload("res://scripts/data/unit_stats.gd")
const SimpleMoveAbilityDataScript := preload("res://scripts/abilities/simple_move_ability_data.gd")
const SimpleAttackAbilityDataScript := preload("res://scripts/abilities/simple_attack_ability_data.gd")
const SimpleMeleeAbilityDataScript := preload("res://scripts/abilities/simple_melee_ability_data.gd")
const WarriorMoveAbilityDataScript := preload("res://scripts/abilities/warrior_move_ability_data.gd")
const WarriorBasicAttackAbilityDataScript := preload("res://scripts/abilities/warrior_basic_attack_ability_data.gd")
const WarriorBrawlAbilityDataScript := preload("res://scripts/abilities/warrior_brawl_ability_data.gd")
const WarriorCounterAbilityDataScript := preload("res://scripts/abilities/warrior_counter_ability_data.gd")
const WarriorStaminaShieldAbilityDataScript := preload("res://scripts/abilities/warrior_stamina_shield_ability_data.gd")
const WarriorStaminaRechargeAbilityDataScript := preload("res://scripts/abilities/warrior_stamina_recharge_ability_data.gd")
const WarlockManaShieldAbilityDataScript := preload("res://scripts/abilities/warlock_mana_shield_ability_data.gd")
const WarlockChargedBoltAbilityDataScript := preload("res://scripts/abilities/warlock_charged_bolt_ability_data.gd")
const WarlockChargedBlastAbilityDataScript := preload("res://scripts/abilities/warlock_charged_blast_ability_data.gd")


static func get_unit_spawns() -> Array[UnitSpawnData]:
	return [
		UnitSpawnData.new(
			BattleEnums.Team.PLAYER,
			Vector2i(10, 10),
			_make_warlock_stats(),
		),
		UnitSpawnData.new(
			BattleEnums.Team.PLAYER,
			Vector2i(9, 10),
			_make_warrior_stats(),
		),
		UnitSpawnData.new(
			BattleEnums.Team.ENEMY,
			Vector2i(1, 1),
			_make_stats("Raider", 7, 4, 100, 20, 42),
		),
		UnitSpawnData.new(
			BattleEnums.Team.ENEMY,
			Vector2i(2, 1),
			_make_melee_stats("Guard", 5, 3, 100, 24, 50),
		),
		UnitSpawnData.new(
			BattleEnums.Team.ENEMY,
			Vector2i(1, 2),
			_make_stats("Sniper", 3, 3, 100, 28, 38),
		),
	]


static func _make_stats(
	display_name: String,
	speed: int,
	move_range: int,
	accuracy: int,
	damage: int,
	max_hp: int,
) -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.display_name = display_name
	stats.speed = speed
	stats.move_range = move_range
	stats.accuracy = accuracy
	stats.damage = damage
	stats.max_hp = max_hp
	var abilities: Array[AbilityData] = []
	abilities.append(SimpleMoveAbilityDataScript.new())
	abilities.append(SimpleAttackAbilityDataScript.new())
	stats.abilities = abilities
	return stats


static func _make_melee_stats(
	display_name: String,
	speed: int,
	move_range: int,
	accuracy: int,
	damage: int,
	max_hp: int,
) -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.display_name = display_name
	stats.speed = speed
	stats.move_range = move_range
	stats.accuracy = accuracy
	stats.damage = damage
	stats.max_hp = max_hp
	var abilities: Array[AbilityData] = []
	abilities.append(SimpleMoveAbilityDataScript.new())
	abilities.append(SimpleMeleeAbilityDataScript.new())
	stats.abilities = abilities
	return stats


static func _make_warrior_stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.display_name = "Warrior"
	stats.speed = 5
	stats.move_range = 4
	stats.accuracy = 100
	stats.damage = 30
	stats.max_hp = 110
	stats.resource_id = BattleEnums.UnitResource.STAMINA
	stats.max_resource = 50
	var abilities: Array[AbilityData] = []
	abilities.append(WarriorMoveAbilityDataScript.new())
	abilities.append(WarriorBasicAttackAbilityDataScript.new())
	abilities.append(WarriorBrawlAbilityDataScript.new())
	abilities.append(WarriorCounterAbilityDataScript.new())
	abilities.append(WarriorStaminaShieldAbilityDataScript.new())
	abilities.append(WarriorStaminaRechargeAbilityDataScript.new())
	stats.abilities = abilities
	return stats


static func _make_warlock_stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.display_name = "Warlock"
	stats.speed = 5
	stats.move_range = 3
	stats.accuracy = 100
	stats.damage = 8
	stats.max_hp = 75
	stats.resource_id = BattleEnums.UnitResource.MANA
	stats.max_resource = 5
	var abilities: Array[AbilityData] = []
	abilities.append(SimpleMoveAbilityDataScript.new())
	abilities.append(WarlockChargedBoltAbilityDataScript.new())
	abilities.append(WarlockChargedBlastAbilityDataScript.new())
	abilities.append(WarlockManaShieldAbilityDataScript.new())
	stats.abilities = abilities
	return stats
