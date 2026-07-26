class_name TurnManager
extends Node

signal round_started(round_number: int)
signal turn_started(unit: Unit)
signal turn_ended(unit: Unit)
signal queue_changed(queue: Array)
signal unit_flags_changed(unit: Unit)
signal phase_changed(phase: BattleEnums.TurnPhase)

@export var battle_state_path: NodePath

var battle_state: BattleState
var phase: BattleEnums.TurnPhase = BattleEnums.TurnPhase.IDLE
var round_number: int = 0
var active_unit: Unit = null
var turn_queue: Array[Unit] = []

var _units: Array[Unit] = []
var _busy: bool = false
## Optional: return true to keep the turn open (e.g. any ability still can_activate).
var keep_turn_open_check: Callable = Callable()


func _ready() -> void:
	battle_state = get_node(battle_state_path) as BattleState


func register_units(units: Array[Unit]) -> void:
	_units = units.duplicate()


func start_battle() -> void:
	round_number = 0
	_set_phase(BattleEnums.TurnPhase.IDLE)
	_start_round()


func can_move(unit: Unit) -> bool:
	return phase == BattleEnums.TurnPhase.UNIT_TURN and unit == active_unit and unit.can_move_more() and not _busy


func can_act(unit: Unit) -> bool:
	return phase == BattleEnums.TurnPhase.UNIT_TURN and unit == active_unit and unit.can_act_more() and not _busy


func notify_moved(unit: Unit) -> void:
	if unit != active_unit:
		return
	unit.moves_used += 1
	unit_flags_changed.emit(unit)


func notify_acted(unit: Unit) -> void:
	if unit != active_unit:
		return
	unit.actions_used += 1
	unit_flags_changed.emit(unit)


func request_end_turn() -> void:
	if active_unit == null or _busy:
		return
	if active_unit.is_player():
		finish_turn(active_unit)


func finish_turn(for_unit: Unit = null) -> void:
	if phase != BattleEnums.TurnPhase.UNIT_TURN:
		return
	if for_unit != null and active_unit != for_unit:
		return
	var finished := active_unit
	active_unit = null
	if finished:
		turn_ended.emit(finished)
	if battle_state and battle_state.check_end_conditions():
		_set_phase(BattleEnums.TurnPhase.BATTLE_OVER)
		return
	_advance_queue()


func owns_turn(unit: Unit) -> bool:
	return phase == BattleEnums.TurnPhase.UNIT_TURN and active_unit == unit


func set_busy(busy: bool) -> void:
	_busy = busy


func is_busy() -> bool:
	return _busy


func handle_battle_over() -> void:
	active_unit = null
	_set_phase(BattleEnums.TurnPhase.BATTLE_OVER)


func process_unit_death(unit: Unit) -> void:
	var remaining: Array[Unit] = []
	for u in turn_queue:
		if u != unit and u.is_alive():
			remaining.append(u)
	turn_queue = remaining
	queue_changed.emit(get_initiative_preview())
	if active_unit == unit:
		finish_turn(unit)


func get_initiative_preview() -> Array[Unit]:
	var preview: Array[Unit] = []
	if active_unit and active_unit.is_alive():
		preview.append(active_unit)
	for unit in turn_queue:
		if unit.is_alive():
			preview.append(unit)
	return preview


func _start_round() -> void:
	if battle_state and battle_state.check_end_conditions():
		_set_phase(BattleEnums.TurnPhase.BATTLE_OVER)
		return
	round_number += 1
	_build_initiative_queue()
	round_started.emit(round_number)
	queue_changed.emit(get_initiative_preview())
	_advance_queue()


func _build_initiative_queue() -> void:
	turn_queue.clear()
	var living: Array[Unit] = []
	for unit in _units:
		if unit.is_alive():
			living.append(unit)
	living.sort_custom(_compare_initiative)
	turn_queue = living
	queue_changed.emit(get_initiative_preview())


func _compare_initiative(a: Unit, b: Unit) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	# Player before enemy on ties.
	if a.team != b.team:
		return a.team == BattleEnums.Team.PLAYER
	return a.get_instance_id() < b.get_instance_id()


func _advance_queue() -> void:
	while not turn_queue.is_empty():
		var next: Unit = turn_queue.pop_front()
		if next == null or not next.is_alive():
			continue
		active_unit = next
		active_unit.reset_turn_flags()
		_set_phase(BattleEnums.TurnPhase.UNIT_TURN)
		unit_flags_changed.emit(active_unit)
		queue_changed.emit(get_initiative_preview())
		turn_started.emit(active_unit)
		return
	_set_phase(BattleEnums.TurnPhase.ROUND_END)
	_start_round()


func _try_auto_finish() -> void:
	if active_unit == null:
		return
	if keep_turn_open_check.is_valid() and bool(keep_turn_open_check.call(active_unit)):
		return
	# Fallback when no check is wired: end when move and action budgets are spent.
	if active_unit.can_move_more() or active_unit.can_act_more():
		return
	finish_turn()


## Call after an ability fully resolves (when not busy) so remaining abilities can keep the turn open.
func request_auto_finish() -> void:
	_try_auto_finish()


func _set_phase(p: BattleEnums.TurnPhase) -> void:
	phase = p
	phase_changed.emit(phase)
