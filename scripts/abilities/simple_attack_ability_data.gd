class_name SimpleAttackAbilityData
extends AbilityData

## Attack (Shoot) — generic ranged basic attack.
##
## Slot: ACTION / CostSlot.ACTION.
## Target: living enemy within `attack_range` (default metric EUCLIDEAN).
## Hit: unit accuracy minus distance falloff (`distance_penalty_per_tile` × (N−1)) and cover.
## Damage: unit `damage`. Subclasses specialize cost, range metric, and gates.

@export var attack_range: int = 5
## Hit-chance reduction per tile beyond adjacent (distance uses N-1). 0 = no falloff.
@export var distance_penalty_per_tile: int = 5
## Reach geometry. EUCLIDEAN = ranged circle √(dx²+dy²); CHEBYSHEV = melee square (diagonals = 1).
## Prefer `is_in_attack_range` over calling GridMath.chebyshev/euclidean directly. See abilities.mdc.
@export var range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.EUCLIDEAN


func _init() -> void:
	id = &"simple_attack"
	display_name = "Attack"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	return not get_target_tiles(unit, ctx).is_empty()


## True if `to_pos` is within `attack_range` under this ability's `range_metric`.
func is_in_attack_range(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	return GridMath.is_within_range(from_pos, to_pos, float(attack_range), range_metric)


func get_distance_penalty_per_tile() -> int:
	return distance_penalty_per_tile


func get_range_metric() -> BattleEnums.RangeMetric:
	return range_metric


func get_range_preview_tiles(unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	for x in GridMath.GRID_SIZE:
		for y in GridMath.GRID_SIZE:
			var pos := Vector2i(x, y)
			if pos == unit.grid_pos:
				continue
			if is_in_attack_range(unit.grid_pos, pos):
				result.append(pos)
	return result


func get_tooltip_meta_lines() -> PackedStringArray:
	var lines := super.get_tooltip_meta_lines()
	var metric_name := "Chebyshev"
	if range_metric == BattleEnums.RangeMetric.EUCLIDEAN:
		metric_name = "Euclidean"
	lines.append("Range %d (%s)" % [attack_range, metric_name])
	return lines


func get_tooltip_body() -> String:
	return "Ranged attack. Hit chance falls off with distance."


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or ctx == null or ctx.battle_state == null:
		return result
	for enemy in _opposing_living(unit, ctx):
		if is_in_attack_range(unit.grid_pos, enemy.grid_pos):
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
	return is_in_attack_range(unit.grid_pos, occupant.grid_pos)


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
		"range_metric": range_metric,
	}


func _opposing_living(unit: Unit, ctx: AbilityContext) -> Array[Unit]:
	if unit.is_player():
		return ctx.battle_state.get_living_enemies()
	return ctx.battle_state.get_living_players()
