class_name WarriorStaminaShieldAbilityData
extends AbilityData


func _init() -> void:
	id = &"warrior_stamina_shield"
	display_name = "WarriorStaminaShield"
	category = BattleEnums.AbilityCategory.PASSIVE
	cost_slot = BattleEnums.CostSlot.NONE


func on_incoming_damage(unit: Unit, context) -> void:
	if unit == null or context == null:
		return
	if not unit.has_resource(BattleEnums.UnitResource.STAMINA):
		return
	var final_damage: int = int(context.final_damage)
	if final_damage <= 0:
		return
	var soak := mini(final_damage, unit.get_resource(BattleEnums.UnitResource.STAMINA))
	if soak <= 0:
		return
	if not unit.spend_resource(soak, BattleEnums.UnitResource.STAMINA):
		return
	context.final_damage = final_damage - soak
