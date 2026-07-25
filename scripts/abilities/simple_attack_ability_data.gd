class_name SimpleAttackAbilityData
extends AbilityData

@export var attack_range: int = 5
## Hit-chance reduction per tile of range. 0 = no distance falloff.
@export var distance_penalty_per_tile: int = 5


func _init() -> void:
	id = &"simple_attack"
	display_name = "Attack"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	return not get_target_tiles(unit, ctx).is_empty()


func tile_distance(a: Vector2i, b: Vector2i) -> int:
	return GridMath.chebyshev(a, b)


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or ctx == null or ctx.battle_state == null:
		return result
	for enemy in _opposing_living(unit, ctx):
		if tile_distance(unit.grid_pos, enemy.grid_pos) <= attack_range:
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
	return tile_distance(unit.grid_pos, occupant.grid_pos) <= attack_range


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
		"presentation": BattleEnums.Presentation.ATTACK,
		"distance_penalty_per_tile": distance_penalty_per_tile,
		"attack_range": attack_range,
	}


func _opposing_living(unit: Unit, ctx: AbilityContext) -> Array[Unit]:
	if unit.is_player():
		return ctx.battle_state.get_living_enemies()
	return ctx.battle_state.get_living_players()
