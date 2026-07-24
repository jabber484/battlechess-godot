class_name ActionRunner
extends Node

signal action_started
signal action_ended

@export var turn_manager_path: NodePath
@export var battle_state_path: NodePath
@export var death_system_path: NodePath

var turn_manager: TurnManager
var battle_state: BattleState
var death_system: DeathSystem


func _ready() -> void:
	turn_manager = get_node(turn_manager_path) as TurnManager
	battle_state = get_node(battle_state_path) as BattleState
	death_system = get_node(death_system_path) as DeathSystem


func run( commit: Callable, present: Callable, complete: Callable = Callable(), death_units: Array[Unit] = [] ) -> void:
	turn_manager.set_busy(true)
	action_started.emit()
	var aborted := false
	if commit.is_valid():
		var commit_result: Variant = commit.call()
		if commit_result == false:
			aborted = true
	if not aborted and present.is_valid():
		await present.call()
	if aborted:
		turn_manager.set_busy(false)
		action_ended.emit()
		return
	var units_to_check := death_units
	if units_to_check.is_empty() and battle_state:
		units_to_check = battle_state.get_units()
	await death_system.evaluate_deaths(units_to_check)
	if battle_state and battle_state.check_end_conditions():
		turn_manager.handle_battle_over()
	elif complete.is_valid():
		complete.call()
	turn_manager.set_busy(false)
	action_ended.emit()
