class_name PathfindingSystem
extends Node

@export var grid_system_path: NodePath

var grid_system: GridSystem
var _astar: AStarGrid2D = AStarGrid2D.new()


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	_astar.region = Rect2i(0, 0, GridMath.GRID_SIZE, GridMath.GRID_SIZE)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	rebuild_solids()
	if grid_system:
		grid_system.occupancy_changed.connect(func(_p): rebuild_solids())


func rebuild_solids(ignore_unit: Unit = null) -> void:
	if grid_system == null:
		return
	for x in GridMath.GRID_SIZE:
		for y in GridMath.GRID_SIZE:
			var pos := Vector2i(x, y)
			var solid := not grid_system.can_stand(pos, ignore_unit)
			# Always allow the ignore unit's own tile as passable start.
			if ignore_unit and pos == ignore_unit.grid_pos:
				solid = false
			_astar.set_point_solid(pos, solid)
	# Mark non-walkable tiles solid even if empty.
	for x in GridMath.GRID_SIZE:
		for y in GridMath.GRID_SIZE:
			var pos := Vector2i(x, y)
			if not grid_system.is_walkable(pos):
				_astar.set_point_solid(pos, true)


func get_reachable_tiles(unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or unit.is_dead():
		return result
	rebuild_solids(unit)
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
		for n in GridMath.orthogonal_neighbors(pos):
			if visited.has(n):
				continue
			if not grid_system.can_stand(n, unit):
				continue
			# Path must exist through A* solids (occupied blocked).
			if _astar.is_point_solid(n) and n != unit.grid_pos:
				continue
			visited[n] = dist + 1
			queue.append({"pos": n, "dist": dist + 1})
	return result


func find_path(from_pos: Vector2i, to_pos: Vector2i, mover: Unit = null) -> Array[Vector2i]:
	rebuild_solids(mover)
	if not GridMath.is_in_bounds(from_pos) or not GridMath.is_in_bounds(to_pos):
		return []
	if mover and not grid_system.can_stand(to_pos, mover):
		return []
	if mover == null and (not grid_system.is_walkable(to_pos) or grid_system.get_occupant(to_pos) != null):
		return []
	# Ensure destination is pathable for A*.
	_astar.set_point_solid(to_pos, false)
	if mover:
		_astar.set_point_solid(from_pos, false)
	var id_path := _astar.get_id_path(from_pos, to_pos)
	var path: Array[Vector2i] = []
	for id in id_path:
		path.append(id)
	return path


func is_reachable(unit: Unit, target: Vector2i) -> bool:
	return get_reachable_tiles(unit).has(target)
