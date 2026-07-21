class_name AISystem
extends Node

@export var grid_system_path: NodePath
@export var pathfinding_path: NodePath
@export var combat_system_path: NodePath
@export var turn_manager_path: NodePath
@export var battle_state_path: NodePath

var grid_system: GridSystem
var pathfinding: PathfindingSystem
var combat_system: CombatSystem
var turn_manager: TurnManager
var battle_state: BattleState

var _mover: Callable
var _attacker: Callable


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	pathfinding = get_node(pathfinding_path) as PathfindingSystem
	combat_system = get_node(combat_system_path) as CombatSystem
	turn_manager = get_node(turn_manager_path) as TurnManager
	battle_state = get_node(battle_state_path) as BattleState


func set_move_executor(mover: Callable) -> void:
	_mover = mover


func set_attack_executor(attacker: Callable) -> void:
	_attacker = attacker


func run_unit_turn(unit: Unit) -> void:
	if unit == null or unit.is_dead() or not unit.is_enemy():
		turn_manager.finish_turn(unit)
		return
	await get_tree().create_timer(0.35).timeout
	if not turn_manager.owns_turn(unit):
		return

	var players := battle_state.get_living_players()
	if players.is_empty():
		turn_manager.finish_turn(unit)
		return

	var reachable := pathfinding.get_reachable_tiles(unit)
	reachable.append(unit.grid_pos)
	var best_tile := unit.grid_pos
	var best_score := -999999
	for tile in reachable:
		var score := _score_tile(unit, tile, players)
		if score > best_score:
			best_score = score
			best_tile = tile

	if best_tile != unit.grid_pos and turn_manager.can_move(unit):
		if _mover.is_valid():
			await _mover.call(unit, best_tile)
		else:
			_instant_move(unit, best_tile)
	if not turn_manager.owns_turn(unit):
		return

	var targets := combat_system.get_attackable_units(unit, players)
	if not targets.is_empty() and turn_manager.can_act(unit):
		targets.sort_custom(func(a: Unit, b: Unit) -> bool:
			var ca := combat_system.compute_hit_chance(unit, a)
			var cb := combat_system.compute_hit_chance(unit, b)
			if ca != cb:
				return ca > cb
			return a.current_hp < b.current_hp
		)
		if _attacker.is_valid():
			await _attacker.call(unit, targets[0])
		if not turn_manager.owns_turn(unit):
			return

	turn_manager.finish_turn(unit)


func _score_tile(unit: Unit, tile: Vector2i, players: Array[Unit]) -> int:
	var score := 0
	var nearest := 999
	var can_shoot_from_here := false
	for player in players:
		var dist := GridMath.manhattan(tile, player.grid_pos)
		nearest = mini(nearest, dist)
		if dist <= unit.attack_range:
			can_shoot_from_here = true
			var distance_penalty := dist * CombatSystem.DISTANCE_PENALTY_PER_TILE
			var cover_penalty := 0
			match grid_system.get_cover(player.grid_pos):
				BattleEnums.Cover.HALF:
					cover_penalty = CombatSystem.HALF_COVER_PENALTY
				BattleEnums.Cover.FULL:
					cover_penalty = CombatSystem.FULL_COVER_PENALTY
			var chance := clampi(unit.accuracy - distance_penalty - cover_penalty, 5, 95)
			score += 40 + chance / 2
			score += maxi(0, 40 - player.current_hp / 3)
	score += maxi(0, 20 - nearest * 2)
	match grid_system.get_cover(tile):
		BattleEnums.Cover.HALF:
			score += 15
		BattleEnums.Cover.FULL:
			score += 30
		_:
			pass
	if can_shoot_from_here:
		score += 25
	if tile == unit.grid_pos:
		score += 2
	return score


func _instant_move(unit: Unit, to_pos: Vector2i) -> void:
	var from := unit.grid_pos
	grid_system.move_occupant(from, to_pos, unit)
	turn_manager.notify_moved(unit)
