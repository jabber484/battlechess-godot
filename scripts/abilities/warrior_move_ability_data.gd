class_name WarriorMoveAbilityData
extends SimpleMoveAbilityData

## Warrior Move — Walk with optional stamina overspend.
##
## Slot: MOVE / CostSlot.MOVE.
## Within `movement_remaining`: free (path cost only).
## Beyond that: up to `extra_range` more octile budget this turn, at `stamina_per_tile` per
## started unit of overflow path cost. Replaces shared Walk on the Warrior kit.

@export var extra_range: float = 2.0
@export var stamina_per_tile: int = 5

## Octile overflow already paid with stamina this turn (cleared on turn start).
var _extension_used: float = 0.0


func _init() -> void:
	id = &"warrior_move"
	display_name = "Move"
	category = BattleEnums.AbilityCategory.MOVE
	cost_slot = BattleEnums.CostSlot.MOVE


func on_turn_started(_unit: Unit) -> void:
	_extension_used = 0.0


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.turn_manager == null:
		return false
	if not ctx.turn_manager.owns_turn(unit) or ctx.turn_manager.is_busy():
		return false
	if unit.can_move_more():
		return true
	return GridMath.cost_within_budget(GridMath.CARDINAL_COST, _affordable_extension(unit))


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	if unit == null or ctx == null or ctx.pathfinding == null:
		return []
	return ctx.pathfinding.get_reachable_tiles(unit, _move_budget(unit))


## Tiles reachable only by spending stamina (beyond `movement_remaining`).
func get_stamina_overspend_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or ctx == null or ctx.pathfinding == null:
		return result
	var free_budget := unit.movement_remaining
	if _move_budget(unit) <= free_budget + GridMath.COST_EPSILON:
		return result
	var free_set: Dictionary = {}
	for pos in ctx.pathfinding.get_reachable_tiles(unit, free_budget):
		free_set[pos] = true
	for pos in get_target_tiles(unit, ctx):
		if free_set.has(pos):
			continue
		result.append(pos)
	return result


func get_costly_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	return get_stamina_overspend_tiles(unit, ctx)


func is_valid_target(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.pathfinding == null:
		return false
	if target_pos == unit.grid_pos:
		return false
	return ctx.pathfinding.is_reachable(unit, target_pos, _move_budget(unit))


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
		"path": [],
	}
	if unit == null or ctx == null or ctx.pathfinding == null or ctx.grid_system == null:
		return empty
	var path: Array[Vector2i] = ctx.pathfinding.find_path(unit.grid_pos, target_pos, unit)
	if path.size() < 2:
		return empty
	var path_cost: float = GridMath.path_cost(path)
	var overflow := _overflow_cost(unit, path_cost)
	var stamina_tiles := 0
	if overflow > GridMath.COST_EPSILON:
		stamina_tiles = int(ceil(overflow - GridMath.COST_EPSILON))
	var stamina_cost := stamina_tiles * stamina_per_tile
	var from := unit.grid_pos
	var turn_manager := ctx.turn_manager
	var grid_system := ctx.grid_system
	var execution := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [unit],
		"path": path,
		"presentation": BattleEnums.Presentation.MOVE,
	}
	execution["commit"] = func() -> bool:
		if stamina_cost > 0:
			if not unit.spend_resource(stamina_cost, BattleEnums.UnitResource.STAMINA):
				return false
		_extension_used += overflow
		grid_system.move_occupant(from, target_pos, unit, false)
		return true
	execution["complete"] = func() -> void:
		if turn_manager:
			turn_manager.notify_moved(unit, path_cost)
	return execution


func _move_budget(unit: Unit) -> float:
	return unit.movement_remaining + _affordable_extension(unit)


func _affordable_extension(unit: Unit) -> float:
	var left := maxf(0.0, extra_range - _extension_used)
	if left <= GridMath.COST_EPSILON or stamina_per_tile <= 0:
		return 0.0
	var stamina := unit.get_resource(BattleEnums.UnitResource.STAMINA)
	var from_stamina := floorf(float(stamina) / float(stamina_per_tile))
	return minf(left, from_stamina)


func _overflow_cost(unit: Unit, path_cost: float) -> float:
	var free := minf(path_cost, unit.movement_remaining)
	var overflow := maxf(0.0, path_cost - free)
	var left := maxf(0.0, extra_range - _extension_used)
	return minf(overflow, left)
