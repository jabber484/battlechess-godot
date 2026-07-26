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


func can_attack(
	attacker: Unit,
	defender: Unit,
	max_range: int,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> bool:
	return _validate_attack(attacker, defender, false, max_range, true, true, range_metric)


func get_attackable_units(
	attacker: Unit,
	units: Array[Unit],
	max_range: int,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if can_attack(attacker, unit, max_range, range_metric):
			result.append(unit)
	return result


func get_attackable_tiles(
	attacker: Unit,
	units: Array[Unit],
	max_range: int,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for unit in get_attackable_units(attacker, units, max_range, range_metric):
		tiles.append(unit.grid_pos)
	return tiles


func compute_hit_chance(
	attacker: Unit,
	defender: Unit,
	distance_penalty_per_tile: int = 0,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> int:
	return int(explain_hit_chance(attacker, defender, distance_penalty_per_tile, range_metric)["chance"])


## Accuracy, distance, and cover terms that feed `compute_hit_chance`.
func explain_hit_chance(
	attacker: Unit,
	defender: Unit,
	distance_penalty_per_tile: int = 0,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> Dictionary:
	var distance := GridMath.range_distance(attacker.grid_pos, defender.grid_pos, range_metric)
	## Falloff starts after adjacent (distance 1): penalty uses (N - 1) tiles.
	var distance_steps := maxf(0.0, distance - 1.0)
	var distance_penalty := int(round(distance_steps * float(distance_penalty_per_tile)))
	var cover: BattleEnums.Cover = grid_system.get_directional_cover(
		defender.grid_pos, attacker.grid_pos
	)
	var cover_penalty := _penalty_for_cover(cover)
	var raw := attacker.accuracy - distance_penalty - cover_penalty
	return {
		"chance": clampi(raw, 5, 100),
		"accuracy": attacker.accuracy,
		"distance": distance,
		"distance_steps": distance_steps,
		"distance_penalty": distance_penalty,
		"distance_penalty_per_tile": distance_penalty_per_tile,
		"cover": cover,
		"cover_penalty": cover_penalty,
	}


func format_hit_chance(breakdown: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d base" % int(breakdown["accuracy"]))
	var distance_penalty: int = int(breakdown["distance_penalty"])
	if distance_penalty > 0:
		var steps: float = float(breakdown["distance_steps"])
		var steps_label := (
			"%d" % int(round(steps))
			if is_equal_approx(steps, round(steps))
			else "%.1f" % steps
		)
		parts.append(
			"−%d dist (%s×%d)"
			% [
				distance_penalty,
				steps_label,
				int(breakdown["distance_penalty_per_tile"]),
			]
		)
	var cover_penalty: int = int(breakdown["cover_penalty"])
	if cover_penalty > 0:
		var cover_name := (
			"full cover"
			if breakdown["cover"] == BattleEnums.Cover.FULL
			else "half cover"
		)
		parts.append("−%d %s" % [cover_penalty, cover_name])
	return "Hit %d%%: %s" % [int(breakdown["chance"]), " ".join(parts)]


func cover_penalty_between(attacker_pos: Vector2i, defender_pos: Vector2i) -> int:
	return _penalty_for_cover(grid_system.get_directional_cover(defender_pos, attacker_pos))


## Turn gates for commit_attack:
## - require_action: attacker must own the turn and have an ACTION remaining (normal attacks)
## - require_own_turn: attacker must own the turn (free-action attacks like Reckless)
## - interrupt: no turn/action budget checks (retaliation mid-exchange)
func commit_attack(
	attacker: Unit,
	defender: Unit,
	distance_penalty_per_tile: int,
	max_range: int,
	require_action: bool = true,
	require_own_turn: bool = true,
	damage_override: int = -1,
	hit_chance_override: int = -1,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"hit_chance": 0,
	}
	if not _validate_attack(
		attacker, defender, true, max_range, require_action, require_own_turn, range_metric
	):
		return result
	var chance := (
		clampi(hit_chance_override, 5, 100)
		if hit_chance_override >= 0
		else compute_hit_chance(attacker, defender, distance_penalty_per_tile, range_metric)
	)
	result["hit_chance"] = chance
	var roll := randi_range(1, 100)
	var hit := roll <= chance
	result["hit"] = hit
	if hit:
		var raw_damage := damage_override if damage_override >= 0 else attacker.damage
		var applied: int = defender.receive_damage(raw_damage, attacker)
		result["damage"] = applied
	attack_resolved.emit(attacker, defender, hit, int(result["damage"]), chance)
	return result


func _validate_attack(
	attacker: Unit,
	defender: Unit,
	for_commit: bool,
	max_range: int,
	require_action: bool = true,
	require_own_turn: bool = true,
	range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV,
) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker.is_dead() or defender.is_dead():
		return false
	if attacker.team == defender.team:
		return false
	if turn_manager and for_commit:
		if require_own_turn and not turn_manager.owns_turn(attacker):
			return false
		if require_action and not attacker.can_act_more():
			return false
	elif turn_manager and not for_commit:
		if not turn_manager.can_act(attacker):
			return false
	return GridMath.is_within_range(
		attacker.grid_pos, defender.grid_pos, float(max_range), range_metric
	)


func _penalty_for_cover(cover: BattleEnums.Cover) -> int:
	match cover:
		BattleEnums.Cover.HALF:
			return HALF_COVER_PENALTY
		BattleEnums.Cover.FULL:
			return FULL_COVER_PENALTY
		_:
			return 0
