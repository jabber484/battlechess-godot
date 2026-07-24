class_name AbilityContext
extends RefCounted

var pathfinding: PathfindingSystem
var grid_system: GridSystem
var turn_manager: TurnManager
var battle_state: BattleState
var combat_system: CombatSystem


func _init(
	p_pathfinding: PathfindingSystem = null,
	p_grid_system: GridSystem = null,
	p_turn_manager: TurnManager = null,
	p_battle_state: BattleState = null,
	p_combat_system: CombatSystem = null,
) -> void:
	pathfinding = p_pathfinding
	grid_system = p_grid_system
	turn_manager = p_turn_manager
	battle_state = p_battle_state
	combat_system = p_combat_system
