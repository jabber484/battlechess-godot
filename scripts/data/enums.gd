class_name BattleEnums
extends RefCounted

enum Team { PLAYER, ENEMY }

enum Cover { NONE, HALF, FULL }

## Cardinal edges for directional cover (grid: +x east, +y south).
enum Direction { NORTH, EAST, SOUTH, WEST }

enum TurnPhase { IDLE, UNIT_TURN, ROUND_END, BATTLE_OVER }

enum BattleResult { NONE, VICTORY, DEFEAT }

enum AbilityCategory { MOVE, ACTION, PASSIVE }

enum CostSlot { MOVE, ACTION, NONE }

enum UnitResource { NONE, STAMINA, MANA, ENERGY }

enum Presentation { NONE, MOVE, ATTACK, RECKLESS_ATTACK }

const DIRECTION_VECTORS: Array[Vector2i] = [
	Vector2i(0, -1), # NORTH
	Vector2i(1, 0), # EAST
	Vector2i(0, 1), # SOUTH
	Vector2i(-1, 0), # WEST
]

const ALL_DIRECTIONS: Array[Direction] = [
	Direction.NORTH,
	Direction.EAST,
	Direction.SOUTH,
	Direction.WEST,
]


static func direction_to_vector(dir: Direction) -> Vector2i:
	return DIRECTION_VECTORS[int(dir)]


static func vector_to_direction(offset: Vector2i) -> Direction:
	match offset:
		Vector2i(0, -1):
			return Direction.NORTH
		Vector2i(1, 0):
			return Direction.EAST
		Vector2i(0, 1):
			return Direction.SOUTH
		Vector2i(-1, 0):
			return Direction.WEST
		_:
			push_error("Not a cardinal offset: %s" % offset)
			return Direction.NORTH
