class_name BattleController
extends Node3D

const BattleSpawnerScript := preload("res://scripts/battle/battle_spawner.gd")
const BattlePresenterScript := preload("res://scripts/battle/battle_presenter.gd")
const DefaultBattleSetupScript := preload("res://scripts/data/default_battle_setup.gd")
const AbilityContextScript := preload("res://scripts/abilities/ability_context.gd")

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
var _ability_ctx: AbilityContext
var _presenter: BattlePresenter


func _ready() -> void:
	randomize()
	_ability_ctx = AbilityContextScript.new(
		pathfinding, grid_system, turn_manager, battle_state, combat_system
	)
	_presenter = BattlePresenterScript.new(self, camera_rig, combat_system, battle_ui)
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
	ai_system.set_move_executor(_execute_ai_move)
	ai_system.set_attack_executor(_execute_ai_attack)
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
	_presenter.focus_unit(unit)
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

	var move_ability := active.resolve_ability(
		BattleEnums.AbilityCategory.MOVE,
		grid_pos,
		_ability_ctx,
	)
	if move_ability:
		await _execute_ability(move_ability, active, grid_pos)
		return

	_pending_attack_target = null
	battle_ui.set_hit_chance("")


func _handle_attack_click(attacker: Unit, defender: Unit) -> void:
	var ability := attacker.resolve_ability(
		BattleEnums.AbilityCategory.ACTION,
		defender.grid_pos,
		_ability_ctx,
	)
	if ability == null:
		battle_ui.set_status("Out of range")
		return
	var distance_penalty_per_tile := _distance_penalty_per_tile(ability)
	var chance := combat_system.compute_hit_chance(attacker, defender, distance_penalty_per_tile)
	if _pending_attack_target == defender:
		await _execute_ability(ability, attacker, defender.grid_pos)
	else:
		_pending_attack_target = defender
		_presenter.focus_unit(defender)
		battle_ui.set_hit_chance("Hit chance: %d%% — click again to confirm" % chance)
		battle_ui.set_status("Targeting %s" % defender.display_name)


func _execute_ai_move(unit: Unit, to_pos: Vector2i) -> void:
	var ability := unit.resolve_ability(BattleEnums.AbilityCategory.MOVE, to_pos, _ability_ctx)
	if ability == null:
		return
	await _execute_ability(ability, unit, to_pos)


func _execute_ai_attack(attacker: Unit, defender: Unit) -> void:
	if defender == null:
		return
	var ability := attacker.resolve_ability(
		BattleEnums.AbilityCategory.ACTION,
		defender.grid_pos,
		_ability_ctx,
	)
	if ability == null:
		return
	await _execute_ability(ability, attacker, defender.grid_pos)


func _execute_ability(ability: AbilityData, unit: Unit, target_pos: Vector2i) -> void:
	if turn_manager.is_busy() or ability == null:
		return
	if not ability.can_activate(unit, _ability_ctx) or not ability.is_valid_target(unit, target_pos, _ability_ctx):
		return
	var execution := ability.build_execution(unit, target_pos, _ability_ctx)
	execution = _presenter.enhance_execution(unit, target_pos, execution)
	var commit: Callable = execution.get("commit", Callable())
	var present: Callable = execution.get("present", Callable())
	var complete: Callable = execution.get("complete", Callable())
	var death_units: Array = execution.get("death_units", [])
	if not commit.is_valid() and not present.is_valid() and not complete.is_valid():
		return

	grid_view.clear_highlights()
	var typed_death: Array[Unit] = []
	for u in death_units:
		if u is Unit:
			typed_death.append(u as Unit)

	await action_runner.run(commit, present, complete, typed_death)
	_refresh_highlights()


func _refresh_highlights() -> void:
	grid_view.clear_highlights()
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or battle_state.is_over():
		return
	var move_tiles: Array[Vector2i] = []
	var move_seen: Dictionary = {}
	for ability in active.get_abilities_by_category(BattleEnums.AbilityCategory.MOVE):
		if not ability.can_activate(active, _ability_ctx):
			continue
		for tile in ability.get_target_tiles(active, _ability_ctx):
			if move_seen.has(tile):
				continue
			move_seen[tile] = true
			move_tiles.append(tile)
	if not move_tiles.is_empty():
		grid_view.show_reachable(move_tiles)

	var attack_tiles: Array[Vector2i] = []
	var attack_seen: Dictionary = {}
	for ability in active.get_abilities_by_category(BattleEnums.AbilityCategory.ACTION):
		if not ability.can_activate(active, _ability_ctx):
			continue
		for tile in ability.get_target_tiles(active, _ability_ctx):
			if attack_seen.has(tile):
				continue
			attack_seen[tile] = true
			attack_tiles.append(tile)
	if not attack_tiles.is_empty():
		grid_view.show_attackable(attack_tiles)


func _log_color_for(unit: Unit) -> Color:
	if unit.is_player():
		return Color(0.55, 0.78, 1.0)
	return Color(1.0, 0.55, 0.55)


func _distance_penalty_per_tile(ability: AbilityData) -> int:
	if ability is SimpleAttackAbilityData:
		return (ability as SimpleAttackAbilityData).distance_penalty_per_tile
	return 0
