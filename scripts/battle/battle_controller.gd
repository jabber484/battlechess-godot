class_name BattleController
extends Node3D

@onready var grid_system: GridSystem = $Systems/GridSystem
@onready var pathfinding: PathfindingSystem = $Systems/PathfindingSystem
@onready var turn_manager: TurnManager = $Systems/TurnManager
@onready var combat_system: CombatSystem = $Systems/CombatSystem
@onready var ai_system: AISystem = $Systems/AISystem
@onready var battle_state: BattleState = $Systems/BattleState
@onready var grid_view: GridView = $World/GridView
@onready var units_root: Node3D = $World/Units
@onready var camera_rig: CameraRig = $World/CameraRig
@onready var battle_ui: BattleUI = $UI

const UNIT_SCENE := preload("res://scenes/unit/Unit.tscn")

var _units: Array[Unit] = []
var _moving: bool = false
var _pending_attack_target: Unit = null


func _ready() -> void:
	randomize()
	ai_system.set_move_executor(_execute_move)
	grid_view.tile_picked.connect(_on_tile_picked)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.queue_changed.connect(_on_queue_changed)
	turn_manager.unit_flags_changed.connect(_on_unit_flags_changed)
	combat_system.attack_resolved.connect(_on_attack_resolved)
	battle_state.battle_ended.connect(_on_battle_ended)
	battle_ui.end_turn_pressed.connect(_on_end_turn_pressed)
	_spawn_units()
	battle_state.register_units(_units)
	turn_manager.register_units(_units)
	turn_manager.start_battle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()


func _spawn_units() -> void:
	var spawns := [
		{"team": BattleEnums.Team.PLAYER, "pos": Vector2i(1, 1), "stats": {"display_name": "Scout", "speed": 8, "move_range": 5, "attack_range": 5, "accuracy": 75, "damage": 22, "max_hp": 90}},
		{"team": BattleEnums.Team.PLAYER, "pos": Vector2i(2, 1), "stats": {"display_name": "Heavy", "speed": 4, "move_range": 3, "attack_range": 6, "accuracy": 70, "damage": 32, "max_hp": 120}},
		{"team": BattleEnums.Team.ENEMY, "pos": Vector2i(10, 10), "stats": {"display_name": "Raider", "speed": 7, "move_range": 4, "attack_range": 5, "accuracy": 72, "damage": 20, "max_hp": 85}},
		{"team": BattleEnums.Team.ENEMY, "pos": Vector2i(9, 10), "stats": {"display_name": "Guard", "speed": 5, "move_range": 3, "attack_range": 4, "accuracy": 68, "damage": 24, "max_hp": 100}},
		{"team": BattleEnums.Team.ENEMY, "pos": Vector2i(10, 9), "stats": {"display_name": "Sniper", "speed": 3, "move_range": 3, "attack_range": 7, "accuracy": 80, "damage": 28, "max_hp": 75}},
	]
	for entry in spawns:
		var unit: Unit = UNIT_SCENE.instantiate()
		units_root.add_child(unit)
		unit.setup(entry["team"], entry["pos"], entry["stats"])
		grid_system.register_unit(unit)
		unit.hp_changed.connect(_on_unit_hp_changed)
		_units.append(unit)


func _on_round_started(round_number: int) -> void:
	battle_ui.set_round(round_number)
	battle_ui.set_status("Round %d" % round_number)


func _on_turn_started(unit: Unit) -> void:
	_pending_attack_target = null
	battle_ui.set_active_unit(unit)
	battle_ui.set_hit_chance("")
	battle_ui.set_end_turn_enabled(unit.is_player())
	camera_rig.focus_on(GridMath.grid_to_world(unit.grid_pos))
	_refresh_highlights()
	if unit.is_enemy():
		battle_ui.set_status("Enemy turn: %s" % unit.display_name)
		ai_system.run_unit_turn(unit)
	else:
		battle_ui.set_status("Your turn: %s — click move or enemy" % unit.display_name)


func _on_turn_ended(_unit: Unit) -> void:
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
	battle_ui.set_hit_chance("")
	_pending_attack_target = null
	_refresh_highlights()


func _on_battle_ended(result: BattleEnums.BattleResult) -> void:
	battle_ui.show_battle_result(result)
	battle_ui.set_end_turn_enabled(false)
	grid_view.clear_highlights()


func _on_end_turn_pressed() -> void:
	if turn_manager.active_unit and turn_manager.active_unit.is_player():
		turn_manager.request_end_turn()


func _on_tile_picked(grid_pos: Vector2i) -> void:
	if battle_state.is_over() or _moving:
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

	# Second click confirm if target already selected but clicked empty — clear.
	_pending_attack_target = null
	battle_ui.set_hit_chance("")


func _handle_attack_click(attacker: Unit, defender: Unit) -> void:
	if not combat_system.can_attack(attacker, defender):
		battle_ui.set_status("Out of range")
		return
	var chance := combat_system.compute_hit_chance(attacker, defender)
	if _pending_attack_target == defender:
		combat_system.resolve_attack(attacker, defender)
	else:
		_pending_attack_target = defender
		battle_ui.set_hit_chance("Hit chance: %d%% — click again to confirm" % chance)
		battle_ui.set_status("Targeting %s" % defender.display_name)


func _execute_move(unit: Unit, to_pos: Vector2i) -> void:
	if _moving:
		return
	var path := pathfinding.find_path(unit.grid_pos, to_pos, unit)
	if path.size() < 2:
		return
	_moving = true
	turn_manager.set_busy(true)
	grid_view.clear_highlights()
	var from := unit.grid_pos
	# Clear occupancy at start; set at end to avoid blocking path mid-tween.
	grid_system.clear_occupant(from)
	await _tween_along_path(unit, path)
	grid_system.register_unit(unit)
	unit.set_grid_pos(to_pos)
	turn_manager.notify_moved(unit)
	turn_manager.set_busy(false)
	_moving = false
	_refresh_highlights()


func _tween_along_path(unit: Unit, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var target_world := GridMath.grid_to_world(path[i], 0.5)
		var tween := create_tween()
		tween.tween_property(unit, "global_position", target_world, 0.12)
		await tween.finished
	unit.grid_pos = path[path.size() - 1]


func _refresh_highlights() -> void:
	grid_view.clear_highlights()
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or battle_state.is_over():
		return
	if turn_manager.can_move(active):
		grid_view.show_reachable(pathfinding.get_reachable_tiles(active))
	if turn_manager.can_act(active):
		grid_view.show_attackable(combat_system.get_attackable_tiles(active, battle_state.get_living_enemies()))
