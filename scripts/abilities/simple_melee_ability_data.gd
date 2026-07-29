class_name SimpleMeleeAbilityData
extends SimpleAttackAbilityData

## Melee — generic adjacent attack (no resource cost).
##
## Slot: ACTION / CostSlot.ACTION.
## Target: adjacent enemy (Chebyshev range 1).
## Hit/damage: unit accuracy and damage; no distance falloff at range 1.


func _init() -> void:
	id = &"simple_melee"
	display_name = "Melee"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 1
	range_metric = BattleEnums.RangeMetric.CHEBYSHEV
	distance_penalty_per_tile = 0


func get_tooltip_body() -> String:
	return "Adjacent melee attack."
