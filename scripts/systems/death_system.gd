class_name DeathSystem
extends Node

signal unit_killed(unit: Unit)

@export var grid_system_path: NodePath
@export var turn_manager_path: NodePath

var grid_system: GridSystem
var turn_manager: TurnManager


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	turn_manager = get_node(turn_manager_path) as TurnManager


func evaluate_deaths(units: Array[Unit]) -> void:
	var pending: Array[Unit] = []
	for unit in units:
		if unit.is_dead() and not unit.death_processed:
			pending.append(unit)
	for unit in pending:
		await _process_death(unit)


func _process_death(unit: Unit) -> void:
	unit.emit_death()
	grid_system.clear_occupant(unit.grid_pos)
	unit_killed.emit(unit)
	await _present_death(unit)
	unit.visible = false
	turn_manager.process_unit_death(unit)


func _present_death(_unit: Unit) -> void:
	await get_tree().create_timer(0.2).timeout
