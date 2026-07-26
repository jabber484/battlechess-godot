class_name WarriorBasicAttackAbilityData
extends SimpleAttackAbilityData

@export var stamina_cost: int = 10


func _init() -> void:
	id = &"warrior_basic_attack"
	display_name = "Melee"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 1
	range_metric = BattleEnums.RangeMetric.CHEBYSHEV


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	return unit.get_resource(BattleEnums.UnitResource.STAMINA) >= stamina_cost


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in super.get_target_tiles(unit, ctx):
		if not _has_full_cover_against(unit, pos, ctx):
			result.append(pos)
	return result


func is_valid_target(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> bool:
	if not super.is_valid_target(unit, target_pos, ctx):
		return false
	return not _has_full_cover_against(unit, target_pos, ctx)


func _has_full_cover_against(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.grid_system == null:
		return false
	return (
		ctx.grid_system.get_directional_cover(target_pos, unit.grid_pos)
		== BattleEnums.Cover.FULL
	)


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
