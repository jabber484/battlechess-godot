class_name UnitStats
extends Resource

@export var display_name: String = "Unit"
@export var speed: int = 5
@export var move_range: int = 4
@export var attack_range: int = 5
@export var accuracy: int = 80
@export var damage: int = 25
@export var max_hp: int = 100
@export var max_moves: int = 1
@export var max_actions: int = 1
@export var resource_id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE
@export var max_resource: int = 0
@export var abilities: Array[AbilityData] = []


func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"speed": speed,
		"move_range": move_range,
		"attack_range": attack_range,
		"accuracy": accuracy,
		"damage": damage,
		"max_hp": max_hp,
		"max_moves": max_moves,
		"max_actions": max_actions,
		"resource_id": resource_id,
		"max_resource": max_resource,
		"abilities": abilities,
	}
