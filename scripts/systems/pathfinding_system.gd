class_name PathfindingSystem
extends Node

const GridMathScript := preload("res://scripts/util/grid_math.gd")

@export var grid_system_path: NodePath

var grid_system: GridSystem


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem


func get_reachable_tiles(unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or unit.is_dead():
		return result
	var budget := unit.movement_remaining
	var costs := _dijkstra_costs(unit.grid_pos, unit, budget)
	for pos in costs:
		var cost: float = costs[pos]
		if cost > GridMathScript.COST_EPSILON and GridMathScript.cost_within_budget(cost, budget):
			result.append(pos)
	return result


func find_path(from_pos: Vector2i, to_pos: Vector2i, mover: Unit = null) -> Array[Vector2i]:
	if not GridMathScript.is_in_bounds(from_pos) or not GridMathScript.is_in_bounds(to_pos):
		return []
	if from_pos == to_pos:
		return [from_pos]
	if mover and not grid_system.can_stand(to_pos, mover):
		return []
	if mover == null and (not grid_system.is_walkable(to_pos) or grid_system.get_occupant(to_pos) != null):
		return []

	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {from_pos: 0.0}
	## Open set: Array of Vector2i; pick min cost each expand (12×12 grid).
	var open: Array[Vector2i] = [from_pos]
	came_from[from_pos] = from_pos

	while not open.is_empty():
		var best_i := 0
		var best_cost: float = cost_so_far[open[0]]
		for i in range(1, open.size()):
			var c: float = cost_so_far[open[i]]
			if c < best_cost:
				best_cost = c
				best_i = i
		var pos: Vector2i = open[best_i]
		open.remove_at(best_i)
		if pos == to_pos:
			break
		for n in GridMathScript.chebyshev_neighbors(pos):
			if n != to_pos and not _can_step_on(n, mover):
				continue
			var new_cost: float = best_cost + GridMathScript.step_cost(pos, n)
			if cost_so_far.has(n) and new_cost >= float(cost_so_far[n]) - GridMathScript.COST_EPSILON:
				continue
			cost_so_far[n] = new_cost
			came_from[n] = pos
			if not open.has(n):
				open.append(n)

	if not came_from.has(to_pos):
		return []

	var path: Array[Vector2i] = []
	var cursor := to_pos
	while true:
		path.push_front(cursor)
		if cursor == from_pos:
			break
		cursor = came_from[cursor]
	return path


func is_reachable(unit: Unit, target: Vector2i) -> bool:
	return get_reachable_tiles(unit).has(target)


func _dijkstra_costs(start: Vector2i, mover: Unit, budget: float) -> Dictionary:
	var cost_so_far: Dictionary = {start: 0.0}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var best_i := 0
		var best_cost: float = cost_so_far[open[0]]
		for i in range(1, open.size()):
			var c: float = cost_so_far[open[i]]
			if c < best_cost:
				best_cost = c
				best_i = i
		var pos: Vector2i = open[best_i]
		open.remove_at(best_i)
		if not GridMathScript.cost_within_budget(best_cost, budget):
			continue
		for n in GridMathScript.chebyshev_neighbors(pos):
			if not _can_step_on(n, mover):
				continue
			var new_cost: float = best_cost + GridMathScript.step_cost(pos, n)
			if not GridMathScript.cost_within_budget(new_cost, budget):
				continue
			if cost_so_far.has(n) and new_cost >= float(cost_so_far[n]) - GridMathScript.COST_EPSILON:
				continue
			cost_so_far[n] = new_cost
			if not open.has(n):
				open.append(n)
	return cost_so_far


func _can_step_on(pos: Vector2i, mover: Unit) -> bool:
	if grid_system == null:
		return false
	if mover:
		return grid_system.can_stand(pos, mover)
	return grid_system.is_walkable(pos) and grid_system.get_occupant(pos) == null
