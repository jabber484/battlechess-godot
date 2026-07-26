class_name AISystem
extends Node

const CombatSystemScript := preload("res://scripts/systems/combat_system.gd")

@export var grid_system_path: NodePath
@export var pathfinding_path: NodePath
@export var combat_system_path: NodePath
@export var turn_manager_path: NodePath
@export var battle_state_path: NodePath

var grid_system: GridSystem
var pathfinding: PathfindingSystem
var combat_system: CombatSystemScript
var turn_manager: TurnManager
var battle_state: BattleState

var _mover: Callable
var _attacker: Callable


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	pathfinding = get_node(pathfinding_path) as PathfindingSystem
	combat_system = get_node(combat_system_path) as CombatSystemScript
	turn_manager = get_node(turn_manager_path) as TurnManager
	battle_state = get_node(battle_state_path) as BattleState


func _make_ability_ctx() -> AbilityContext:
	return AbilityContext.new(pathfinding, grid_system, turn_manager, battle_state, combat_system)


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

	var reachable: Array[Vector2i] = []
	var seen: Dictionary = {}
	var ctx := _make_ability_ctx()
	for ability in unit.get_abilities_by_category(BattleEnums.AbilityCategory.MOVE):
		if not ability.can_activate(unit, ctx):
			continue
		for tile in ability.get_target_tiles(unit, ctx):
			if seen.has(tile):
				continue
			seen[tile] = true
			reachable.append(tile)
	reachable.append(unit.grid_pos)
	var best_tile := unit.grid_pos
	var best_score := -999999
	for tile in reachable:
		var score := _score_tile(unit, tile, players)
		if score > best_score:
			best_score = score
			best_tile = tile

	if best_tile != unit.grid_pos:
		var move_ability := unit.resolve_ability(
			BattleEnums.AbilityCategory.MOVE,
			best_tile,
			ctx,
		)
		if move_ability and _mover.is_valid():
			await _mover.call(unit, best_tile)
		elif move_ability:
			_instant_move(unit, best_tile)
	if not turn_manager.owns_turn(unit):
		return

	# Refresh ctx after move (occupancy / turn flags may have changed).
	ctx = _make_ability_ctx()
	var targets: Array[Unit] = []
	var target_seen: Dictionary = {}
	for ability in unit.get_abilities_by_category(BattleEnums.AbilityCategory.ACTION):
		if not ability.can_activate(unit, ctx):
			continue
		for tile in ability.get_target_tiles(unit, ctx):
			var occupant := grid_system.get_occupant(tile)
			if occupant == null or not occupant.is_alive():
				continue
			if occupant.team == unit.team:
				continue
			if target_seen.has(occupant):
				continue
			if unit.resolve_ability(BattleEnums.AbilityCategory.ACTION, tile, ctx) == null:
				continue
			target_seen[occupant] = true
			targets.append(occupant)
	if not targets.is_empty():
		targets.sort_custom(func(a: Unit, b: Unit) -> bool:
			var ca := combat_system.compute_hit_chance(
				unit,
				a,
				_distance_penalty_for_target(unit, a, ctx),
			)
			var cb := combat_system.compute_hit_chance(
				unit,
				b,
				_distance_penalty_for_target(unit, b, ctx),
			)
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
	var distance_penalty_per_tile := _primary_attack_distance_penalty(unit)
	var max_range := _primary_attack_range(unit)
	var best_self_cover_bonus := 0
	for player in players:
		var dist := GridMath.chebyshev(tile, player.grid_pos)
		nearest = mini(nearest, dist)
		match grid_system.get_directional_cover(tile, player.grid_pos):
			BattleEnums.Cover.HALF:
				best_self_cover_bonus = maxi(best_self_cover_bonus, 15)
			BattleEnums.Cover.FULL:
				best_self_cover_bonus = maxi(best_self_cover_bonus, 30)
			_:
				pass
		if dist <= max_range:
			can_shoot_from_here = true
			var distance_penalty := maxi(0, dist - 1) * distance_penalty_per_tile
			var cover_penalty: int = combat_system.cover_penalty_between(tile, player.grid_pos)
			var chance := clampi(unit.accuracy - distance_penalty - cover_penalty, 5, 100)
			score += 40 + chance / 2
			score += maxi(0, 40 - player.current_hp / 3)
	score += maxi(0, 20 - nearest * 2)
	score += best_self_cover_bonus
	if can_shoot_from_here:
		score += 25
	if tile == unit.grid_pos:
		score += 2
	return score


func _instant_move(unit: Unit, to_pos: Vector2i) -> void:
	var from := unit.grid_pos
	grid_system.move_occupant(from, to_pos, unit)
	turn_manager.notify_moved(unit)


func _primary_attack_distance_penalty(unit: Unit) -> int:
	for ability in unit.get_abilities_by_category(BattleEnums.AbilityCategory.ACTION):
		if ability is SimpleAttackAbilityData:
			return (ability as SimpleAttackAbilityData).distance_penalty_per_tile
	return 0


func _primary_attack_range(unit: Unit) -> int:
	for ability in unit.get_abilities_by_category(BattleEnums.AbilityCategory.ACTION):
		if ability is SimpleAttackAbilityData:
			return (ability as SimpleAttackAbilityData).attack_range
	return 0


func _distance_penalty_for_target(unit: Unit, target: Unit, ctx: AbilityContext) -> int:
	var ability := unit.resolve_ability(
		BattleEnums.AbilityCategory.ACTION,
		target.grid_pos,
		ctx,
	)
	if ability is SimpleAttackAbilityData:
		return (ability as SimpleAttackAbilityData).distance_penalty_per_tile
	return 0
