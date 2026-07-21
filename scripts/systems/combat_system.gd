class_name CombatSystem
extends Node

signal attack_resolved(attacker: Unit, defender: Unit, hit: bool, damage: int, hit_chance: int)
signal unit_killed(unit: Unit)

@export var grid_system_path: NodePath
@export var turn_manager_path: NodePath

const DISTANCE_PENALTY_PER_TILE := 5
const HALF_COVER_PENALTY := 20
const FULL_COVER_PENALTY := 40

var grid_system: GridSystem
var turn_manager: TurnManager


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	turn_manager = get_node(turn_manager_path) as TurnManager


func can_attack(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker.is_dead() or defender.is_dead():
		return false
	if attacker.team == defender.team:
		return false
	if turn_manager and not turn_manager.can_act(attacker):
		return false
	return GridMath.manhattan(attacker.grid_pos, defender.grid_pos) <= attacker.attack_range


func get_attackable_units(attacker: Unit, units: Array[Unit]) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if can_attack(attacker, unit):
			result.append(unit)
	return result


func get_attackable_tiles(attacker: Unit, units: Array[Unit]) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for unit in get_attackable_units(attacker, units):
		tiles.append(unit.grid_pos)
	return tiles


func compute_hit_chance(attacker: Unit, defender: Unit) -> int:
	var distance := GridMath.manhattan(attacker.grid_pos, defender.grid_pos)
	var distance_penalty := distance * DISTANCE_PENALTY_PER_TILE
	var cover_penalty := _cover_penalty(defender.grid_pos)
	return clampi(attacker.accuracy - distance_penalty - cover_penalty, 5, 95)


func resolve_attack(attacker: Unit, defender: Unit) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"hit_chance": 0,
	}
	if not can_attack(attacker, defender):
		return result
	var chance := compute_hit_chance(attacker, defender)
	result["hit_chance"] = chance
	var roll := randi_range(1, 100)
	var hit := roll <= chance
	result["hit"] = hit
	if hit:
		defender.take_damage(attacker.damage)
		result["damage"] = attacker.damage
		if defender.is_dead():
			grid_system.clear_occupant(defender.grid_pos)
			unit_killed.emit(defender)
	attack_resolved.emit(attacker, defender, hit, int(result["damage"]), chance)
	if turn_manager:
		turn_manager.notify_acted(attacker)
	return result


func _cover_penalty(grid_pos: Vector2i) -> int:
	match grid_system.get_cover(grid_pos):
		BattleEnums.Cover.HALF:
			return HALF_COVER_PENALTY
		BattleEnums.Cover.FULL:
			return FULL_COVER_PENALTY
		_:
			return 0
