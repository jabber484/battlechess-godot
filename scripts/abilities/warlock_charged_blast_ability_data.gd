class_name WarlockChargedBlastAbilityData
extends WarlockChargedBoltAbilityData

## Charged Blast — short-range channel nuke. Same open/sip/fire flow as Charged Bolt.
##
## Range 2 Chebyshev (adjacent ring including diagonals). Higher lock cost and base damage.

func _init() -> void:
	id = &"warlock_charged_blast"
	display_name = "Charged Blast"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 2
	range_metric = BattleEnums.RangeMetric.CHEBYSHEV
	distance_penalty_per_tile = 5
	charge_draw_amount = 15
	max_charge_ticks = 2
	base_bolt_damage = 18
