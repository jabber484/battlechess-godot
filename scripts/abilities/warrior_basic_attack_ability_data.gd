class_name WarriorBasicAttackAbilityData
extends SimpleAttackAbilityData

@export var stamina_cost: int = 10


func _init() -> void:
	id = &"warrior_basic_attack"
	display_name = "WarriorBasicAttack"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 1


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	return unit.get_resource(BattleEnums.UnitResource.STAMINA) >= stamina_cost


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var execution := super.build_execution(unit, target_pos, ctx)
	if execution.get("defender", null) == null:
		return execution
	var cost := stamina_cost
	var prior_commit: Callable = execution.get("commit", Callable())
	execution["commit"] = func() -> bool:
		if not unit.spend_resource(cost, BattleEnums.UnitResource.STAMINA):
			return false
		if prior_commit.is_valid():
			prior_commit.call()
		return true
	return execution
