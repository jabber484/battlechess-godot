class_name WarriorStaminaShieldAbilityData
extends AbilityData

## Stamina Shield — passive soak: spend stamina 1:1 to reduce incoming HP damage.
##
## Category: PASSIVE (always on while stamina remains).
## Hook: `on_incoming_damage` via `Unit.modify_incoming_damage`.
## Rule: soak = min(final_damage, current_stamina); spend that stamina; reduce final_damage.
## Misses never reach this path. Empty stamina → no soak until recharge.

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
