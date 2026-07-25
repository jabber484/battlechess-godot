class_name CombatSystem
extends Node

signal attack_resolved(attacker: Unit, defender: Unit, hit: bool, damage: int, hit_chance: int)

@export var grid_system_path: NodePath
@export var turn_manager_path: NodePath

const HALF_COVER_PENALTY := 20
const FULL_COVER_PENALTY := 40

var grid_system: GridSystem
var turn_manager: TurnManager


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	turn_manager = get_node(turn_manager_path) as TurnManager


func can_attack(attacker: Unit, defender: Unit, max_range: int) -> bool:
	return _validate_attack(attacker, defender, false, max_range)


func get_attackable_units(attacker: Unit, units: Array[Unit], max_range: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if can_attack(attacker, unit, max_range):
			result.append(unit)
	return result


func get_attackable_tiles(attacker: Unit, units: Array[Unit], max_range: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for unit in get_attackable_units(attacker, units, max_range):
		tiles.append(unit.grid_pos)
	return tiles


func compute_hit_chance(
	attacker: Unit,
	defender: Unit,
	distance_penalty_per_tile: int = 0,
) -> int:
	var distance := GridMath.chebyshev(attacker.grid_pos, defender.grid_pos)
	var distance_penalty := distance * distance_penalty_per_tile
	var cover_penalty := cover_penalty_between(attacker.grid_pos, defender.grid_pos)
	return clampi(attacker.accuracy - distance_penalty - cover_penalty, 5, 100)


func cover_penalty_between(attacker_pos: Vector2i, defender_pos: Vector2i) -> int:
	return _penalty_for_cover(grid_system.get_directional_cover(defender_pos, attacker_pos))


func commit_attack(
	attacker: Unit,
	defender: Unit,
	distance_penalty_per_tile: int,
	max_range: int,
) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"hit_chance": 0,
	}
	if not _validate_attack(attacker, defender, true, max_range):
		return result
	var chance := compute_hit_chance(attacker, defender, distance_penalty_per_tile)
	result["hit_chance"] = chance
	var roll := randi_range(1, 100)
	var hit := roll <= chance
	result["hit"] = hit
	if hit:
		var applied: int = defender.receive_damage(attacker.damage, attacker)
		result["damage"] = applied
	attack_resolved.emit(attacker, defender, hit, int(result["damage"]), chance)
	return result


func _validate_attack(
	attacker: Unit,
	defender: Unit,
	for_commit: bool,
	max_range: int,
) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker.is_dead() or defender.is_dead():
		return false
	if attacker.team == defender.team:
		return false
	if turn_manager:
		if for_commit:
			if not turn_manager.owns_turn(attacker) or not attacker.can_act_more():
				return false
		elif not turn_manager.can_act(attacker):
			return false
	return GridMath.chebyshev(attacker.grid_pos, defender.grid_pos) <= max_range


func _penalty_for_cover(cover: BattleEnums.Cover) -> int:
	match cover:
		BattleEnums.Cover.HALF:
			return HALF_COVER_PENALTY
		BattleEnums.Cover.FULL:
			return FULL_COVER_PENALTY
		_:
			return 0
