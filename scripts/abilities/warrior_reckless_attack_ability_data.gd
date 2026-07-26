class_name WarriorRecklessAttackAbilityData
extends WarriorBasicAttackAbilityData

## Once-per-turn free-action melee: spend stamina, enemy strikes first, then Warrior hits.
var used_this_turn: bool = false


func _init() -> void:
	id = &"warrior_reckless_attack"
	display_name = "Reckless"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.NONE
	attack_range = 1
	range_metric = BattleEnums.RangeMetric.CHEBYSHEV
	stamina_cost = 10


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if used_this_turn:
		return false
	# Parent SimpleAttack / AbilityData checks turn ownership + CostSlot.NONE.
	# WarriorBasicAttack adds stamina gate and target availability via super chain.
	return super.can_activate(unit, ctx)


func on_turn_started(_unit: Unit) -> void:
	used_this_turn = false


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
		"defender": null,
	}
	if unit == null or ctx == null or ctx.grid_system == null:
		return empty
	var defender := ctx.grid_system.get_occupant(target_pos)
	if defender == null or not is_valid_target(unit, target_pos, ctx):
		return empty

	var cost := stamina_cost
	var warrior_range := attack_range
	var warrior_falloff := distance_penalty_per_tile
	var retal_range := 0
	var retal_falloff := 0
	var retal_metric := BattleEnums.RangeMetric.CHEBYSHEV
	var retal_attack := _find_attack_ability(defender)
	if retal_attack != null:
		retal_range = retal_attack.attack_range
		retal_falloff = retal_attack.distance_penalty_per_tile
		retal_metric = retal_attack.range_metric

	return {
		"commit": func() -> bool:
			if used_this_turn:
				return false
			if not unit.spend_resource(cost, BattleEnums.UnitResource.STAMINA):
				return false
			used_this_turn = true
			return true,
		"present": Callable(),
		"complete": Callable(),
		"death_units": [unit, defender],
		"defender": defender,
		"presentation": BattleEnums.Presentation.RECKLESS_ATTACK,
		"distance_penalty_per_tile": warrior_falloff,
		"attack_range": warrior_range,
		"range_metric": range_metric,
		"retaliation_attack_range": retal_range,
		"retaliation_distance_penalty_per_tile": retal_falloff,
		"retaliation_range_metric": retal_metric,
	}


func _find_attack_ability(unit: Unit) -> SimpleAttackAbilityData:
	if unit == null:
		return null
	for ability in unit.abilities:
		if ability is SimpleAttackAbilityData and ability.category == BattleEnums.AbilityCategory.ACTION:
			return ability as SimpleAttackAbilityData
	return null
