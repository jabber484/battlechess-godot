class_name GridMath
extends RefCounted

const GRID_SIZE := 12
const TILE_SIZE := 1.0

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
