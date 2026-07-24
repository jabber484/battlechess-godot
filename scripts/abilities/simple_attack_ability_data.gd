class_name SimpleAttackAbilityData
extends AbilityData


func _init() -> void:
	id = &"simple_attack"
	display_name = "SimpleAttack"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or ctx == null or ctx.battle_state == null:
		return result
	for enemy in _opposing_living(unit, ctx):
		if GridMath.manhattan(unit.grid_pos, enemy.grid_pos) <= unit.attack_range:
			result.append(enemy.grid_pos)
	return result


func is_valid_target(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.grid_system == null:
		return false
	var occupant := ctx.grid_system.get_occupant(target_pos)
	if occupant == null or not occupant.is_alive():
		return false
	if occupant.team == unit.team:
		return false
	return GridMath.manhattan(unit.grid_pos, occupant.grid_pos) <= unit.attack_range


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
	var turn_manager := ctx.turn_manager
	return {
		"commit": Callable(),
		"present": Callable(),
		"complete": func() -> void:
			if turn_manager:
				turn_manager.notify_acted(unit),
		"death_units": [unit, defender],
		"defender": defender,
	}


func _opposing_living(unit: Unit, ctx: AbilityContext) -> Array[Unit]:
	if unit.is_player():
		return ctx.battle_state.get_living_enemies()
	return ctx.battle_state.get_living_players()
