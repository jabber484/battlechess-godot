class_name WarriorStaminaRechargeAbilityData
extends AbilityData

## Stamina Recharge — passive restore on the Warrior's turn start.
##
## Category: PASSIVE.
## Hook: `on_turn_started` → gain `recharge_amount` stamina (clamped to max).
## Default +30 / turn ≈ Melee cost (10) plus leftover stamina for shield soak the same turn.

@export var recharge_amount: int = 30


func _init() -> void:
	id = &"warrior_stamina_recharge"
	display_name = "WarriorStaminaRecharge"
	category = BattleEnums.AbilityCategory.PASSIVE
	cost_slot = BattleEnums.CostSlot.NONE


func on_turn_started(unit: Unit) -> void:
	if unit == null or recharge_amount <= 0:
		return
	unit.gain_resource(recharge_amount, BattleEnums.UnitResource.STAMINA)


func get_tooltip_body() -> String:
	return "Passive: restore %d stamina at the start of your turn." % recharge_amount
