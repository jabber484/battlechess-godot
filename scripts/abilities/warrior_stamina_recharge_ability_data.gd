class_name WarriorStaminaRechargeAbilityData
extends AbilityData

@export var recharge_amount: int = 10


func _init() -> void:
	id = &"warrior_stamina_recharge"
	display_name = "WarriorStaminaRecharge"
	category = BattleEnums.AbilityCategory.PASSIVE
	cost_slot = BattleEnums.CostSlot.NONE


func on_turn_started(unit: Unit) -> void:
	if unit == null or recharge_amount <= 0:
		return
	unit.gain_resource(recharge_amount, BattleEnums.UnitResource.STAMINA)
