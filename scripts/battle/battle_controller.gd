class_name BattleController
extends Node3D

const BattleSpawnerScript := preload("res://scripts/battle/battle_spawner.gd")
const DefaultBattleSetupScript := preload("res://scripts/data/default_battle_setup.gd")
const MOVE_TILE_DURATION := 0.28
const ATTACK_CAMERA_DELAY := 0.5
const ATTACK_FOCUS_DURATION := 1.0

@onready var grid_system: GridSystem = $Systems/GridSystem
@onready var pathfinding: PathfindingSystem = $Systems/PathfindingSystem
@onready var turn_manager: TurnManager = $Systems/TurnManager
@onready var combat_system: CombatSystem = $Systems/CombatSystem
@onready var action_runner: ActionRunner = $Systems/ActionRunner
@onready var ai_system: AISystem = $Systems/AISystem
@onready var battle_state: BattleState = $Systems/BattleState
@onready var grid_view: GridView = $World/GridView
@onready var units_root: Node3D = $World/Units
@onready var camera_rig: CameraRig = $World/CameraRig
@onready var battle_ui: BattleUI = $UI

var _units: Array[Unit] = []
var _pending_attack_target: Unit = null


func _ready() -> void:
	randomize()
	_connect_signals()
	_units = BattleSpawnerScript.spawn_units(
		DefaultBattleSetupScript.get_unit_spawns(),
		units_root,
		grid_system,
	)
	for unit in _units:
		unit.hp_changed.connect(_on_unit_hp_changed)
	battle_state.register_units(_units)
	turn_manager.register_units(_units)
	turn_manager.start_battle()
	battle_ui.append_log("Battle started", Color(0.7, 0.9, 1.0))


func _connect_signals() -> void:
	ai_system.set_move_executor(_execute_move)
	ai_system.set_attack_executor(_execute_attack)
	grid_view.tile_picked.connect(_on_tile_picked)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.queue_changed.connect(_on_queue_changed)
	turn_manager.unit_flags_changed.connect(_on_unit_flags_changed)
	combat_system.attack_resolved.connect(_on_attack_resolved)
	battle_state.battle_ended.connect(_on_battle_ended)
	battle_ui.end_turn_pressed.connect(_on_end_turn_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()


func _on_round_started(round_number: int) -> void:
	battle_ui.set_round(round_number)
	battle_ui.set_status("Round %d" % round_number)
	battle_ui.append_log("--- Round %d ---" % round_number, Color(0.7, 0.9, 1.0))


func _on_turn_started(unit: Unit) -> void:
	_pending_attack_target = null
	battle_ui.set_active_unit(unit)
	battle_ui.set_hit_chance("")
	battle_ui.set_end_turn_enabled(unit.is_player())
	camera_rig.focus_on(GridMath.grid_to_world(unit.grid_pos))
	_refresh_highlights()
	var team_tag := "Player" if unit.is_player() else "Enemy"
	battle_ui.append_log("[%s] %s's turn" % [team_tag, unit.display_name], _log_color_for(unit))
	if unit.is_enemy():
		battle_ui.set_status("Enemy turn: %s" % unit.display_name)
		ai_system.run_unit_turn(unit)
	else:
		battle_ui.set_status("Your turn: %s — click move or enemy" % unit.display_name)


func _on_turn_ended(unit: Unit) -> void:
	if unit:
		battle_ui.append_log("%s ended turn" % unit.display_name, _log_color_for(unit))
	grid_view.clear_highlights()
	battle_ui.set_hit_chance("")
	_pending_attack_target = null


func _on_queue_changed(queue: Array) -> void:
	battle_ui.set_initiative(queue, turn_manager.active_unit)


func _on_unit_flags_changed(unit: Unit) -> void:
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)
		_refresh_highlights()


func _on_unit_hp_changed(unit: Unit, _hp: int, _max_hp: int) -> void:
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)


func _on_attack_resolved(attacker: Unit, defender: Unit, hit: bool, damage: int, hit_chance: int) -> void:
	var msg := "%s shoots %s (%d%%): " % [attacker.display_name, defender.display_name, hit_chance]
	if hit:
		msg += "HIT for %d" % damage
	else:
		msg += "MISS"
	battle_ui.set_status(msg)
	battle_ui.append_log(msg, _log_color_for(attacker))
	if not hit:
		defender.show_miss_float()
	battle_ui.set_hit_chance("")
	_pending_attack_target = null


func _on_battle_ended(result: BattleEnums.BattleResult) -> void:
	battle_ui.show_battle_result(result)
	match result:
		BattleEnums.BattleResult.VICTORY:
			battle_ui.append_log("VICTORY!", Color(0.4, 1.0, 0.5))
		BattleEnums.BattleResult.DEFEAT:
			battle_ui.append_log("DEFEAT!", Color(1.0, 0.4, 0.4))
	battle_ui.set_end_turn_enabled(false)
	grid_view.clear_highlights()


func _on_end_turn_pressed() -> void:
	if turn_manager.active_unit and turn_manager.active_unit.is_player():
		turn_manager.request_end_turn()


func _on_tile_picked(grid_pos: Vector2i) -> void:
	if battle_state.is_over() or turn_manager.is_busy():
		return
	var active := turn_manager.active_unit
	if active == null or not active.is_player():
		return

	var occupant := grid_system.get_occupant(grid_pos)
	if occupant and occupant.is_enemy():
		_handle_attack_click(active, occupant)
		return

	if turn_manager.can_move(active) and pathfinding.is_reachable(active, grid_pos):
		_execute_move(active, grid_pos)
		return

	_pending_attack_target = null
	battle_ui.set_hit_chance("")


func _handle_attack_click(attacker: Unit, defender: Unit) -> void:
	if not combat_system.can_attack(attacker, defender):
		battle_ui.set_status("Out of range")
		return
	var chance := combat_system.compute_hit_chance(attacker, defender)
	if _pending_attack_target == defender:
		_execute_attack(attacker, defender)
	else:
		_pending_attack_target = defender
		camera_rig.focus_on(GridMath.grid_to_world(defender.grid_pos))
		battle_ui.set_hit_chance("Hit chance: %d%% — click again to confirm" % chance)
		battle_ui.set_status("Targeting %s" % defender.display_name)


func _execute_move(unit: Unit, to_pos: Vector2i) -> void:
	if turn_manager.is_busy():
		return
	var path := pathfinding.find_path(unit.grid_pos, to_pos, unit)
	if path.size() < 2:
		return
	grid_view.clear_highlights()
	var from := unit.grid_pos
	var tile_count := path.size() - 1
	camera_rig.focus_on(GridMath.grid_to_world(to_pos))

	await action_runner.run(
		func() -> void:
			grid_system.move_occupant(from, to_pos, unit, false),
		func() -> void:
			await _tween_along_path(unit, path),
		func() -> void:
			turn_manager.notify_moved(unit)
			battle_ui.append_log(
				"%s moves %s → %s (%d tiles)" % [
					unit.display_name,
					_fmt_grid_pos(from),
					_fmt_grid_pos(to_pos),
					tile_count,
				],
				_log_color_for(unit),
			),
		[unit],
	)
	_refresh_highlights()


func _execute_attack(attacker: Unit, defender: Unit) -> void:
	if turn_manager.is_busy():
		return
	if not combat_system.can_attack(attacker, defender):
		return
	grid_view.clear_highlights()

	await action_runner.run(
		Callable(),
		func() -> void:
			camera_rig.focus_on(GridMath.grid_to_world(defender.grid_pos))
			await get_tree().create_timer(ATTACK_FOCUS_DURATION).timeout
			combat_system.commit_attack(attacker, defender)
			await get_tree().create_timer(ATTACK_CAMERA_DELAY).timeout
			camera_rig.focus_on(GridMath.grid_to_world(attacker.grid_pos)),
		func() -> void:
			turn_manager.notify_acted(attacker),
		[attacker, defender],
	)
	_refresh_highlights()


func _tween_along_path(unit: Unit, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var target_world := GridMath.grid_to_world(path[i], 0.5)
		var tween := create_tween()
		tween.tween_property(unit, "global_position", target_world, MOVE_TILE_DURATION)
		await tween.finished
	unit.set_grid_pos(path[path.size() - 1])


func _refresh_highlights() -> void:
	grid_view.clear_highlights()
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or battle_state.is_over():
		return
	if turn_manager.can_move(active):
		grid_view.show_reachable(pathfinding.get_reachable_tiles(active))
	if turn_manager.can_act(active):
		grid_view.show_attackable(combat_system.get_attackable_tiles(active, battle_state.get_living_enemies()))


func _log_color_for(unit: Unit) -> Color:
	if unit.is_player():
		return Color(0.55, 0.78, 1.0)
	return Color(1.0, 0.55, 0.55)


func _fmt_grid_pos(pos: Vector2i) -> String:
	return "(%d,%d)" % [pos.x, pos.y]
