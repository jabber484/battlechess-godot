class_name WarlockChargedBoltAbilityData
extends WarlockChargedAttackAbilityData

## Charged Bolt — mid-range channel. Open locks 0 (free snap); sip locks 1.
## Range 4 Euclidean. Base damage 10.


func _init() -> void:
	id = &"warlock_charged_bolt"
	display_name = "Charged Bolt"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 4
	range_metric = BattleEnums.RangeMetric.EUCLIDEAN
	distance_penalty_per_tile = 5
	first_tick_lock = 0
	next_tick_lock = 1
	max_charge_ticks = 2
	base_damage = 10
