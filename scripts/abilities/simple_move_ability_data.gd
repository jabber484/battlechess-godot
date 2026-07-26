class_name SimpleMoveAbilityData
extends AbilityData

## Move (Walk) — shared pathfinding move ability.
##
## Slot: MOVE / CostSlot.MOVE (spends the move budget).
## Target: tiles reachable within `unit.move_range` using octile step costs (diagonal ≈ √2).
## Presentation: path tween via `BattleEnums.Presentation.MOVE`.

func _init() -> void:
	id = &"simple_move"
	display_name = "Move"
	category = BattleEnums.AbilityCategory.MOVE
	cost_slot = BattleEnums.CostSlot.MOVE


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	if unit == null or ctx == null or ctx.pathfinding == null:
		return []
	return ctx.pathfinding.get_reachable_tiles(unit)


func is_valid_target(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.pathfinding == null:
		return false
	if target_pos == unit.grid_pos:
		return false
	return ctx.pathfinding.is_reachable(unit, target_pos)


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
	var from := unit.grid_pos
	var turn_manager := ctx.turn_manager
	var grid_system := ctx.grid_system
	return {
		"commit": func() -> void:
			grid_system.move_occupant(from, target_pos, unit, false),
		"present": Callable(),
		"complete": func() -> void:
			if turn_manager:
				turn_manager.notify_moved(unit),
		"death_units": [unit],
		"path": path,
		"presentation": BattleEnums.Presentation.MOVE,
	}
