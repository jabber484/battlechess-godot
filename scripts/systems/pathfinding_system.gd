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
	var start := unit.grid_pos
	var visited: Dictionary = {}
	var queue: Array = []
	queue.append({"pos": start, "dist": 0})
	visited[start] = 0
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var dist: int = current["dist"]
		if dist > 0:
			result.append(pos)
		if dist >= unit.move_range:
			continue
		for n in GridMathScript.chebyshev_neighbors(pos):
			if visited.has(n):
				continue
			if not _can_step_on(n, unit):
				continue
			visited[n] = dist + 1
			queue.append({"pos": n, "dist": dist + 1})
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
	var queue: Array[Vector2i] = [from_pos]
	came_from[from_pos] = from_pos
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if pos == to_pos:
			break
		for n in GridMathScript.chebyshev_neighbors(pos):
			if came_from.has(n):
				continue
			if n != to_pos and not _can_step_on(n, mover):
				continue
			came_from[n] = pos
			queue.append(n)

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


func _can_step_on(pos: Vector2i, mover: Unit) -> bool:
	if grid_system == null:
		return false
	if mover:
		return grid_system.can_stand(pos, mover)
	return grid_system.is_walkable(pos) and grid_system.get_occupant(pos) == null
