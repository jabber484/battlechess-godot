class_name GridMath
extends RefCounted

const GRID_SIZE := 12
const TILE_SIZE := 1.0
## Cardinal step cost for movement pathfinding.
const CARDINAL_COST := 1.0
## Diagonal step cost (√2). Fractional costs accumulate along a path.
const DIAGONAL_COST := 1.41421356237
## Float slack when comparing path cost to move budget.
const COST_EPSILON := 0.0001

## World origin is the center of the board.
static func grid_to_world(grid_pos: Vector2i, height: float = 0.0) -> Vector3:
	var half := (GRID_SIZE - 1) * TILE_SIZE * 0.5
	return Vector3(
		grid_pos.x * TILE_SIZE - half,
		height,
		grid_pos.y * TILE_SIZE - half
	)


static func world_to_grid(world_pos: Vector3) -> Vector2i:
	var half := (GRID_SIZE - 1) * TILE_SIZE * 0.5
	var gx := int(round((world_pos.x + half) / TILE_SIZE))
	var gz := int(round((world_pos.z + half) / TILE_SIZE))
	return Vector2i(gx, gz)


static func is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.y >= 0 and grid_pos.x < GRID_SIZE and grid_pos.y < GRID_SIZE


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Straight-line grid distance √(dx² + dy²). Used for ranged attack reach.
static func euclidean(a: Vector2i, b: Vector2i) -> float:
	var dx := float(a.x - b.x)
	var dy := float(a.y - b.y)
	return sqrt(dx * dx + dy * dy)


static func range_distance(a: Vector2i, b: Vector2i, metric: BattleEnums.RangeMetric) -> float:
	match metric:
		BattleEnums.RangeMetric.EUCLIDEAN:
			return euclidean(a, b)
		_:
			return float(chebyshev(a, b))


## Attack reach check. Prefer `SimpleAttackAbilityData.is_in_attack_range` from ability code.
static func is_within_range(
	a: Vector2i,
	b: Vector2i,
	max_range: float,
	metric: BattleEnums.RangeMetric,
) -> bool:
	return range_distance(a, b, metric) <= max_range + COST_EPSILON


## Octile / Pythagorean path length on an open grid (min cost with 8-dir steps).
static func octile(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	var straight := maxi(dx, dy) - mini(dx, dy)
	var diagonal := mini(dx, dy)
	return CARDINAL_COST * float(straight) + DIAGONAL_COST * float(diagonal)


## Edge cost for one 8-dir step. Cardinal = 1, diagonal = √2.
static func step_cost(from_pos: Vector2i, to_pos: Vector2i) -> float:
	var dx := absi(to_pos.x - from_pos.x)
	var dy := absi(to_pos.y - from_pos.y)
	if dx == 0 and dy == 0:
		return 0.0
	if dx <= 1 and dy <= 1:
		return DIAGONAL_COST if dx == 1 and dy == 1 else CARDINAL_COST
	return octile(from_pos, to_pos)


static func cost_within_budget(cost: float, budget: float) -> bool:
	return cost <= budget + COST_EPSILON


## Sum of octile step costs along a path (consecutive tiles).
static func path_cost(path: Array[Vector2i]) -> float:
	if path.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(1, path.size()):
		total += step_cost(path[i - 1], path[i])
	return total


static func orthogonal_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for offset in offsets:
		var n: Vector2i = grid_pos + offset
		if is_in_bounds(n):
			result.append(n)
	return result


## 8-directional neighbors. Used for attack range rings and movement steps.
static func chebyshev_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	for offset in offsets:
		var n: Vector2i = grid_pos + offset
		if is_in_bounds(n):
			result.append(n)
	return result
