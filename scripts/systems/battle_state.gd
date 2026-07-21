class_name BattleState
extends Node

signal battle_ended(result: BattleEnums.BattleResult)
signal result_changed(result: BattleEnums.BattleResult)

var result: BattleEnums.BattleResult = BattleEnums.BattleResult.NONE
var _units: Array[Unit] = []


func register_units(units: Array[Unit]) -> void:
	_units = units.duplicate()


func get_units() -> Array[Unit]:
	return _units


func get_living_units() -> Array[Unit]:
	var living: Array[Unit] = []
	for unit in _units:
		if unit.is_alive():
			living.append(unit)
	return living


func get_living_players() -> Array[Unit]:
	var living: Array[Unit] = []
	for unit in _units:
		if unit.is_alive() and unit.is_player():
			living.append(unit)
	return living


func get_living_enemies() -> Array[Unit]:
	var living: Array[Unit] = []
	for unit in _units:
		if unit.is_alive() and unit.is_enemy():
			living.append(unit)
	return living


func check_end_conditions() -> bool:
	if result != BattleEnums.BattleResult.NONE:
		return true
	if get_living_enemies().is_empty():
		_set_result(BattleEnums.BattleResult.VICTORY)
		return true
	if get_living_players().is_empty():
		_set_result(BattleEnums.BattleResult.DEFEAT)
		return true
	return false


func is_over() -> bool:
	return result != BattleEnums.BattleResult.NONE


func _set_result(r: BattleEnums.BattleResult) -> void:
	result = r
	result_changed.emit(result)
	battle_ended.emit(result)
