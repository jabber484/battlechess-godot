class_name BattleController
extends Node3D

const BattleSpawnerScript := preload("res://scripts/battle/battle_spawner.gd")
const BattlePresenterScript := preload("res://scripts/battle/battle_presenter.gd")
const DefaultBattleSetupScript := preload("res://scripts/data/default_battle_setup.gd")
const AbilityContextScript := preload("res://scripts/abilities/ability_context.gd")
const CombatSystemScript := preload("res://scripts/systems/combat_system.gd")

@onready var grid_system: GridSystem = $Systems/GridSystem
@onready var pathfinding: PathfindingSystem = $Systems/PathfindingSystem
@onready var turn_manager: TurnManager = $Systems/TurnManager
@onready var combat_system: CombatSystemScript = $Systems/CombatSystem
@onready var action_runner: ActionRunner = $Systems/ActionRunner
@onready var ai_system: AISystem = $Systems/AISystem
@onready var battle_state: BattleState = $Systems/BattleState
@onready var grid_view: GridView = $World/GridView
@onready var units_root: Node3D = $World/Units
@onready var camera_rig: CameraRig = $World/CameraRig
@onready var battle_ui: BattleUI = $UI

var _units: Array[Unit] = []
var _pending_attack_target: Unit = null
var _selected_ability: AbilityData = null
var _hovered_ability: AbilityData = null
var _ability_ctx: AbilityContext
var _presenter: BattlePresenterScript
var _hovered_tile: Vector2i = Vector2i(-1, -1)


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
		unit.resource_changed.connect(_on_unit_resource_changed)
		unit.status_fx_changed.connect(_on_unit_status_fx_changed)
		unit.ability_log.connect(_on_unit_ability_log)
	battle_state.register_units(_units)
	turn_manager.register_units(_units)
	turn_manager.keep_turn_open_check = _unit_has_available_ability
	turn_manager.start_battle()
	battle_ui.append_log("Battle started", Color(0.7, 0.9, 1.0))


func _connect_signals() -> void:
	ai_system.set_move_executor(_execute_ai_move)
	ai_system.set_attack_executor(_execute_ai_attack)
	grid_view.tile_picked.connect(_on_tile_picked)
	grid_view.tile_hovered.connect(_on_tile_hovered)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.queue_changed.connect(_on_queue_changed)
	turn_manager.unit_flags_changed.connect(_on_unit_flags_changed)
	combat_system.attack_resolved.connect(_on_attack_resolved)
	battle_state.battle_ended.connect(_on_battle_ended)
	battle_ui.end_turn_pressed.connect(_on_end_turn_pressed)
	battle_ui.ability_selected.connect(_on_ability_selected)
	battle_ui.ability_hovered.connect(_on_ability_hovered)
	battle_ui.ability_unhovered.connect(_on_ability_unhovered)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()


func _on_round_started(round_number: int) -> void:
	battle_ui.set_round(round_number)
	battle_ui.set_status("Round %d" % round_number)
	battle_ui.append_log("--- Round %d ---" % round_number, Color(0.7, 0.9, 1.0))


func _on_turn_started(unit: Unit) -> void:
	_pending_attack_target = null
	_selected_ability = null
	_hovered_ability = null
	_hovered_tile = Vector2i(-1, -1)
	# Duration ticks on other units fire before the active unit's own turn-start hooks.
	for other in _units:
		if other == null or not other.is_alive():
			continue
		if other == unit:
			continue
		other.notify_foreign_turn_started(unit)
	if unit:
		unit.notify_turn_started()
	battle_ui.set_active_unit(unit)
	battle_ui.set_hit_chance("")
	battle_ui.set_end_turn_enabled(unit.is_player())
	_presenter.focus_unit(unit)
	_refresh_ability_bar()
	_refresh_highlights()
	var team_tag := "Player" if unit.is_player() else "Enemy"
	battle_ui.append_log("[%s] %s's turn" % [team_tag, unit.display_name], _log_color_for(unit))
	if unit.is_enemy():
		battle_ui.set_status("Enemy turn: %s" % unit.display_name)
		ai_system.run_unit_turn(unit)
	else:
		battle_ui.set_status("Your turn: %s — select an ability" % unit.display_name)


func _on_turn_ended(unit: Unit) -> void:
	if unit:
		unit.notify_turn_ended()
		battle_ui.append_log("%s ended turn" % unit.display_name, _log_color_for(unit))
	_selected_ability = null
	_hovered_ability = null
	_pending_attack_target = null
	_hovered_tile = Vector2i(-1, -1)
	_clear_resource_spend_preview()
	battle_ui.clear_abilities()
	grid_view.clear_highlights()
	battle_ui.set_hit_chance("")


func _on_queue_changed(queue: Array) -> void:
	battle_ui.set_initiative(queue, turn_manager.active_unit)


func _on_unit_flags_changed(unit: Unit) -> void:
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)
		_refresh_ability_bar()
		_refresh_highlights()


func _on_unit_hp_changed(unit: Unit, _hp: int, _max_hp: int) -> void:
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)


func _on_unit_resource_changed(
	unit: Unit,
	_resource_id: BattleEnums.UnitResource,
	_current: int,
	_max_resource: int,
) -> void:
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)
		if unit.is_player():
			_refresh_ability_bar()
			_refresh_highlights()


func _on_unit_status_fx_changed(unit: Unit) -> void:
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)


func _on_unit_ability_log(unit: Unit, message: String) -> void:
	battle_ui.append_log(message, _log_color_for(unit))
	battle_ui.set_status(message)


func _on_attack_resolved(attacker: Unit, defender: Unit, hit: bool, damage: int, hit_chance: int) -> void:
	var verb := "shoots"
	if (
		_selected_ability != null
		and _selected_ability is WarlockChargedBoltAbilityData
	):
		verb = "blasts"
	var msg := "%s %s %s (%d%%): " % [attacker.display_name, verb, defender.display_name, hit_chance]
	if hit:
		if damage > 0:
			msg += "HIT for %d" % damage
		else:
			msg += "HIT (absorbed)"
	else:
		msg += "MISS"
	battle_ui.set_status(msg)
	battle_ui.append_log(msg, _log_color_for(attacker))
	if not hit:
		defender.show_miss_float()
	battle_ui.set_hit_chance("")
	_pending_attack_target = null
	if attacker == turn_manager.active_unit:
		battle_ui.set_active_unit(attacker)
	if defender != null:
		defender.notify_attacked(attacker, hit, damage, hit_chance, combat_system)


func _on_battle_ended(result: BattleEnums.BattleResult) -> void:
	battle_ui.show_battle_result(result)
	match result:
		BattleEnums.BattleResult.VICTORY:
			battle_ui.append_log("VICTORY!", Color(0.4, 1.0, 0.5))
		BattleEnums.BattleResult.DEFEAT:
			battle_ui.append_log("DEFEAT!", Color(1.0, 0.4, 0.4))
	_selected_ability = null
	battle_ui.clear_abilities()
	battle_ui.set_end_turn_enabled(false)
	grid_view.clear_highlights()


func _on_end_turn_pressed() -> void:
	if turn_manager.active_unit and turn_manager.active_unit.is_player():
		turn_manager.request_end_turn()


func _on_ability_selected(ability: AbilityData) -> void:
	if battle_state.is_over() or turn_manager.is_busy():
		return
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or ability == null:
		return
	if not ability.can_activate(active, _ability_ctx):
		battle_ui.set_status("%s is not available" % ability.display_name)
		_refresh_ability_bar()
		_refresh_highlights()
		return

	# Self-targeted / instant abilities run on button click — no second confirm.
	if ability.activates_on_select():
		_selected_ability = null
		_hovered_ability = null
		_pending_attack_target = null
		battle_ui.set_hit_chance("")
		battle_ui.set_selected_ability(null)
		_clear_resource_spend_preview()
		grid_view.clear_highlights()
		await _execute_ability(ability, active, active.grid_pos)
		return

	_selected_ability = ability
	_hovered_ability = null
	_pending_attack_target = null
	battle_ui.set_hit_chance("")
	battle_ui.set_selected_ability(_selected_ability)
	_clear_resource_spend_preview()
	_refresh_highlights()
	match ability.category:
		BattleEnums.AbilityCategory.MOVE:
			battle_ui.set_status("Selected %s — click a highlighted tile" % ability.display_name)
		BattleEnums.AbilityCategory.ACTION:
			if ability is WarlockChargedBoltAbilityData:
				var bolt := ability as WarlockChargedBoltAbilityData
				if bolt.is_charging:
					battle_ui.set_status(
						"Selected %s — click an enemy in range" % bolt.display_name
					)
				else:
					battle_ui.set_status(
						"Selected %s — click self to channel (range shown)" % bolt.display_name
					)
			else:
				battle_ui.set_status("Selected %s — click a target" % ability.display_name)
		_:
			battle_ui.set_status("Selected %s" % ability.display_name)


func _on_ability_hovered(ability: AbilityData) -> void:
	if battle_state.is_over() or turn_manager.is_busy():
		return
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or ability == null:
		return
	_hovered_ability = ability
	_refresh_highlights()
	_update_resource_spend_preview(active, ability)


func _on_ability_unhovered(ability: AbilityData) -> void:
	if _hovered_ability != ability:
		return
	_hovered_ability = null
	_refresh_highlights()
	_clear_resource_spend_preview()


func _update_resource_spend_preview(unit: Unit, ability: AbilityData) -> void:
	if unit == null:
		return
	var hud: UnitHUD = unit.get_unit_hud()
	if hud == null:
		return
	var lock := 0
	var commit := 0
	var spend := 0
	if ability is WarlockChargedBoltAbilityData:
		var bolt := ability as WarlockChargedBoltAbilityData
		if bolt.is_charging:
			commit = bolt.charged_mana
		else:
			lock = bolt.charge_draw_amount
	elif ability is WarlockManaShieldAbilityData:
		var shield := ability as WarlockManaShieldAbilityData
		if not shield.is_charging:
			lock = shield.charge_draw_amount
	elif ability is WarriorBasicAttackAbilityData:
		spend = (ability as WarriorBasicAttackAbilityData).stamina_cost
	elif ability is WarriorBrawlAbilityData:
		spend = (ability as WarriorBrawlAbilityData).stamina_cost
	elif ability is WarriorCounterAbilityData:
		spend = (ability as WarriorCounterAbilityData).stamina_cost
	hud.set_resource_spend_preview(lock, commit, spend)


func _clear_resource_spend_preview() -> void:
	var active := turn_manager.active_unit
	if active == null:
		return
	var hud: UnitHUD = active.get_unit_hud()
	if hud:
		hud.clear_resource_spend_preview()


func _on_tile_picked(grid_pos: Vector2i) -> void:
	if battle_state.is_over() or turn_manager.is_busy():
		return
	var active := turn_manager.active_unit
	if active == null or not active.is_player():
		return
	if _selected_ability == null:
		# No targeting step for free self-casts — ignore stray tile clicks.
		return
	if not _selected_ability.can_activate(active, _ability_ctx):
		_clear_selected_ability()
		battle_ui.set_status("Ability no longer available — select another")
		return

	if _selected_ability.category == BattleEnums.AbilityCategory.ACTION:
		var occupant := grid_system.get_occupant(grid_pos)
		if occupant and occupant.is_enemy():
			if _selected_ability.is_valid_target(active, grid_pos, _ability_ctx):
				await _handle_attack_click(active, occupant)
				return

	if not _selected_ability.is_valid_target(active, grid_pos, _ability_ctx):
		_pending_attack_target = null
		battle_ui.set_hit_chance("")
		battle_ui.set_status("Invalid target for %s" % _selected_ability.display_name)
		return

	await _execute_ability(_selected_ability, active, grid_pos)


func _on_tile_hovered(grid_pos: Vector2i) -> void:
	if _hovered_tile == grid_pos:
		return
	_hovered_tile = grid_pos
	_refresh_highlights()


func _handle_attack_click(attacker: Unit, defender: Unit) -> void:
	var ability := _selected_ability
	if ability == null:
		return
	if not ability.is_valid_target(attacker, defender.grid_pos, _ability_ctx):
		battle_ui.set_status("Out of range")
		return
	if _pending_attack_target == defender:
		await _execute_ability(ability, attacker, defender.grid_pos)
	else:
		_pending_attack_target = defender
		_presenter.focus_unit(defender)
		battle_ui.set_hit_chance(
			"%s — click again to confirm" % _hit_chance_text(attacker, defender, ability)
		)
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
	battle_ui.clear_abilities()
	var typed_death: Array[Unit] = []
	for u in death_units:
		if u is Unit:
			typed_death.append(u as Unit)

	await action_runner.run(commit, present, complete, typed_death)
	# Free-action abilities do not call notify_acted/moved — still try auto-end after them.
	turn_manager.request_auto_finish()
	_pending_attack_target = null
	if unit == turn_manager.active_unit:
		battle_ui.set_active_unit(unit)
	if _selected_ability and not _selected_ability.can_activate(unit, _ability_ctx):
		_selected_ability = null
	_refresh_ability_bar()
	_refresh_highlights()
	if unit.is_player() and not battle_state.is_over():
		if turn_manager.active_unit != unit:
			return
		if ability is WarlockChargedBoltAbilityData:
			var bolt := ability as WarlockChargedBoltAbilityData
			if bolt and bolt.is_charging:
				battle_ui.set_status(
					"%s charged %d/%d — fire at an enemy or End Turn"
					% [bolt.display_name, bolt.charged_mana, bolt.max_charged_mana()]
				)
			else:
				battle_ui.set_status("Select an ability, or End Turn")
		elif ability.id == &"warlock_mana_shield":
			var shield := unit.get_mana_shield()
			if shield and shield.is_shield_up():
				battle_ui.set_status("%s raised" % shield.get_shield_status_text())
			else:
				battle_ui.set_status("Select an ability, or End Turn")
		elif ability.id == &"warrior_counter":
			var counter = unit.get_warrior_counter()
			if counter and counter.is_counter_up():
				battle_ui.set_status("Counter ready — turn ended")
			else:
				battle_ui.set_status("Select an ability, or End Turn")
		elif _selected_ability:
			battle_ui.set_status("Selected %s — choose a target" % _selected_ability.display_name)
		else:
			battle_ui.set_status("Select an ability, or End Turn")


func _player_abilities(unit: Unit) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if unit == null:
		return result
	for ability in unit.abilities:
		if ability == null:
			continue
		if ability.category == BattleEnums.AbilityCategory.PASSIVE:
			continue
		result.append(ability)
	return result


func _unit_has_available_ability(unit: Unit) -> bool:
	if unit == null or _ability_ctx == null:
		return false
	for ability in unit.abilities:
		if ability == null:
			continue
		if ability.category == BattleEnums.AbilityCategory.PASSIVE:
			continue
		if ability.can_activate(unit, _ability_ctx):
			return true
	return false


func _refresh_ability_bar() -> void:
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or battle_state.is_over():
		_selected_ability = null
		_hovered_ability = null
		battle_ui.clear_abilities()
		return
	if turn_manager.is_busy():
		_hovered_ability = null
		battle_ui.clear_abilities()
		return
	if _selected_ability and not _selected_ability.can_activate(active, _ability_ctx):
		_selected_ability = null
	var abilities := _player_abilities(active)
	battle_ui.set_abilities(
		abilities,
		_selected_ability,
		func(ability: AbilityData) -> bool:
			return ability != null and ability.can_activate(active, _ability_ctx)
	)


func _clear_selected_ability() -> void:
	_selected_ability = null
	_pending_attack_target = null
	battle_ui.set_hit_chance("")
	_refresh_ability_bar()
	_refresh_highlights()


func _preview_ability() -> AbilityData:
	if _hovered_ability != null:
		return _hovered_ability
	return _selected_ability


func _refresh_highlights() -> void:
	grid_view.clear_highlights()
	var active := turn_manager.active_unit
	if active == null or not active.is_player() or battle_state.is_over():
		battle_ui.set_hit_chance("")
		return
	var ability := _preview_ability()
	if ability == null:
		battle_ui.set_hit_chance("")
		return
	# Selected abilities still require can_activate; hover can preview range even if unusable.
	var is_hover_preview := ability == _hovered_ability and ability != _selected_ability
	if not is_hover_preview and not ability.can_activate(active, _ability_ctx):
		battle_ui.set_hit_chance("")
		return

	match ability.category:
		BattleEnums.AbilityCategory.MOVE:
			battle_ui.set_hit_chance("")
			var move_tiles := ability.get_target_tiles(active, _ability_ctx)
			if ability is WarriorMoveAbilityData:
				var warrior_move := ability as WarriorMoveAbilityData
				var stamina_tiles: Array[Vector2i] = warrior_move.get_stamina_overspend_tiles(
					active, _ability_ctx
				)
				var stamina_set: Dictionary = {}
				for pos in stamina_tiles:
					stamina_set[pos] = true
				var free_tiles: Array[Vector2i] = []
				for pos in move_tiles:
					if stamina_set.has(pos):
						continue
					free_tiles.append(pos)
				if not free_tiles.is_empty():
					grid_view.show_reachable(free_tiles)
				if not stamina_tiles.is_empty():
					grid_view.show_stamina_reachable(stamina_tiles)
			elif not move_tiles.is_empty():
				grid_view.show_reachable(move_tiles)
			if ability == _selected_ability:
				_refresh_move_hover_preview(active)
		BattleEnums.AbilityCategory.ACTION:
			_show_action_ability_highlights(active, ability)
			if ability == _selected_ability:
				_refresh_attack_hover_preview(active)
		_:
			_show_action_ability_highlights(active, ability)


func _show_action_ability_highlights(unit: Unit, ability: AbilityData) -> void:
	if ability is WarlockChargedBoltAbilityData:
		var bolt := ability as WarlockChargedBoltAbilityData
		var bolt_range := _attack_range_tiles(unit, ability)
		if not bolt_range.is_empty():
			grid_view.show_range(bolt_range)
		if not bolt.is_charging:
			grid_view.show_self_target(ability.get_target_tiles(unit, _ability_ctx))
			battle_ui.set_hit_chance("")
			return
		var bolt_targets := ability.get_target_tiles(unit, _ability_ctx)
		if not bolt_targets.is_empty():
			grid_view.show_attackable(bolt_targets)
		if bolt_targets.is_empty() and bolt_range.is_empty():
			battle_ui.set_hit_chance("")
		return
	if ability.activates_on_select() or ability.id == &"warlock_mana_shield":
		grid_view.show_self_target(ability.get_target_tiles(unit, _ability_ctx))
		battle_ui.set_hit_chance("")
		return
	var range_tiles := _attack_range_tiles(unit, ability)
	if not range_tiles.is_empty():
		grid_view.show_range(range_tiles)
	var target_tiles := ability.get_target_tiles(unit, _ability_ctx)
	if not target_tiles.is_empty():
		grid_view.show_attackable(target_tiles)
	if target_tiles.is_empty() and range_tiles.is_empty():
		battle_ui.set_hit_chance("")


func _attack_range_tiles(unit: Unit, ability: AbilityData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null or not (ability is SimpleAttackAbilityData):
		return result
	var attack := ability as SimpleAttackAbilityData
	for x in GridMath.GRID_SIZE:
		for y in GridMath.GRID_SIZE:
			var pos := Vector2i(x, y)
			if pos == unit.grid_pos:
				continue
			if attack.is_in_attack_range(unit.grid_pos, pos):
				result.append(pos)
	return result


func _refresh_attack_hover_preview(unit: Unit) -> void:
	var ability := _selected_ability
	if unit == null or ability == null:
		battle_ui.set_hit_chance("")
		return
	if not GridMath.is_in_bounds(_hovered_tile):
		battle_ui.set_hit_chance("")
		return
	if not ability.is_valid_target(unit, _hovered_tile, _ability_ctx):
		battle_ui.set_hit_chance("")
		return
	var defender := grid_system.get_occupant(_hovered_tile)
	if defender == null or not defender.is_enemy():
		battle_ui.set_hit_chance("")
		return
	grid_view.show_hover(_hovered_tile)
	var text := _hit_chance_text(unit, defender, ability)
	if _pending_attack_target == defender:
		text = "%s — click again to confirm" % text
	battle_ui.set_hit_chance(text)


func _hit_chance_text(attacker: Unit, defender: Unit, ability: AbilityData) -> String:
	var breakdown := combat_system.explain_hit_chance(
		attacker, defender, _distance_penalty_per_tile(ability), _range_metric(ability)
	)
	var text := combat_system.format_hit_chance(breakdown)
	if ability is WarlockChargedBoltAbilityData:
		var bolt: WarlockChargedBoltAbilityData = ability as WarlockChargedBoltAbilityData
		var ticks: int = bolt.charge_ticks()
		var preview: int = bolt.base_bolt_damage * maxi(1, ticks)
		text += " | dmg ~%d (%d×)" % [preview, maxi(1, ticks)]
	return text


func _refresh_move_hover_preview(unit: Unit) -> void:
	if unit == null or not GridMath.is_in_bounds(_hovered_tile):
		return
	if not _selected_ability.is_valid_target(unit, _hovered_tile, _ability_ctx):
		return
	var path: Array[Vector2i] = pathfinding.find_path(unit.grid_pos, _hovered_tile, unit)
	if path.size() >= 2:
		grid_view.show_path(path)
		grid_view.show_hover(_hovered_tile)
	var attack_tiles := _attack_tiles_from(unit, _hovered_tile)
	if not attack_tiles.is_empty():
		grid_view.show_attackable(attack_tiles)


## Temporarily evaluates ACTION ability targets as if `unit` stood on `from_pos`.
func _attack_tiles_from(unit: Unit, from_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	var seen: Dictionary = {}
	var old_pos := unit.grid_pos
	unit.grid_pos = from_pos
	for ability in unit.get_abilities_by_category(BattleEnums.AbilityCategory.ACTION):
		if ability == null or not ability.can_activate(unit, _ability_ctx):
			continue
		for tile in ability.get_target_tiles(unit, _ability_ctx):
			if seen.has(tile):
				continue
			seen[tile] = true
			result.append(tile)
	unit.grid_pos = old_pos
	return result


func _log_color_for(unit: Unit) -> Color:
	if unit.is_player():
		return Color(0.55, 0.78, 1.0)
	return Color(1.0, 0.55, 0.55)


func _distance_penalty_per_tile(ability: AbilityData) -> int:
	if ability is SimpleAttackAbilityData:
		return (ability as SimpleAttackAbilityData).distance_penalty_per_tile
	return 0


func _range_metric(ability: AbilityData) -> BattleEnums.RangeMetric:
	if ability is SimpleAttackAbilityData:
		return (ability as SimpleAttackAbilityData).range_metric
	return BattleEnums.RangeMetric.CHEBYSHEV
