class_name BattlePresenter
extends RefCounted

## Fills ability execution presentation from intent keys (`path`, `defender`),
## not ability class checks. Abilities stay headless; this owns camera/tweens/VFX hooks.

const CombatSystemScript := preload("res://scripts/systems/combat_system.gd")
const MOVE_TILE_DURATION := 0.28
const ATTACK_CAMERA_DELAY := 0.5
const ATTACK_FOCUS_DURATION := 1.0

var _host: Node
var _camera_rig: CameraRig
var _combat_system: CombatSystemScript
var _battle_ui: BattleUI


func _init(
	host: Node,
	camera_rig: CameraRig,
	combat_system: CombatSystemScript,
	battle_ui: BattleUI,
) -> void:
	_host = host
	_camera_rig = camera_rig
	_combat_system = combat_system
	_battle_ui = battle_ui


func focus_unit(unit: Unit) -> void:
	if unit == null:
		return
	focus_grid_pos(unit.grid_pos)


func focus_grid_pos(grid_pos: Vector2i) -> void:
	if _camera_rig == null:
		return
	_camera_rig.focus_on(GridMath.grid_to_world(grid_pos))


## Mutates and returns execution with present/complete filled when left empty.
func enhance_execution(
	unit: Unit,
	target_pos: Vector2i,
	execution: Dictionary,
) -> Dictionary:
	if execution.is_empty():
		return execution
	var present: Callable = execution.get("present", Callable())
	if present.is_valid():
		return execution

	var presentation := _resolve_presentation(execution)
	match presentation:
		BattleEnums.Presentation.MOVE:
			_enhance_move(unit, target_pos, execution)
		BattleEnums.Presentation.ATTACK:
			_enhance_attack(unit, execution)
		BattleEnums.Presentation.RECKLESS_ATTACK:
			_enhance_reckless_attack(unit, execution)
		BattleEnums.Presentation.DRAW:
			_enhance_draw(unit, execution)
		BattleEnums.Presentation.SELF_BUFF:
			_enhance_self_buff(unit, execution)
	return execution


func _resolve_presentation(execution: Dictionary) -> BattleEnums.Presentation:
	var hint: Variant = execution.get("presentation", BattleEnums.Presentation.NONE)
	if typeof(hint) == TYPE_INT:
		var as_enum: BattleEnums.Presentation = hint as BattleEnums.Presentation
		if as_enum != BattleEnums.Presentation.NONE:
			return as_enum

	var path: Array = execution.get("path", [])
	if path.size() >= 2:
		return BattleEnums.Presentation.MOVE
	var defender = execution.get("defender", null)
	if defender is Unit:
		return BattleEnums.Presentation.ATTACK
	return BattleEnums.Presentation.NONE


func _enhance_move(unit: Unit, target_pos: Vector2i, execution: Dictionary) -> void:
	var path: Array = execution.get("path", [])
	var typed_path: Array[Vector2i] = []
	for step in path:
		typed_path.append(step as Vector2i)
	if typed_path.size() < 2:
		return

	var from := unit.grid_pos
	var tile_count := typed_path.size() - 1
	focus_grid_pos(target_pos)
	execution["present"] = func() -> void:
		await _tween_along_path(unit, typed_path)

	var prior_complete: Callable = execution.get("complete", Callable())
	execution["complete"] = func() -> void:
		if prior_complete.is_valid():
			prior_complete.call()
		if _battle_ui:
			_battle_ui.append_log(
				"%s moves %s → %s (%d tiles)" % [
					unit.display_name,
					_fmt_grid_pos(from),
					_fmt_grid_pos(target_pos),
					tile_count,
				],
				_log_color_for(unit),
			)


func _enhance_attack(unit: Unit, execution: Dictionary) -> void:
	var defender = execution.get("defender", null)
	if not defender is Unit:
		return
	var target: Unit = defender as Unit
	var distance_penalty_per_tile := int(execution.get("distance_penalty_per_tile", 0))
	var max_range := int(execution.get("attack_range", 0))
	var hit_chance_override := int(execution.get("hit_chance_override", -1))
	var damage_resolver: Variant = execution.get("damage_resolver", null)
	execution["present"] = func() -> void:
		focus_grid_pos(target.grid_pos)
		await _host.get_tree().create_timer(ATTACK_FOCUS_DURATION).timeout
		if _combat_system:
			var damage_override := -1
			if typeof(damage_resolver) == TYPE_CALLABLE and (damage_resolver as Callable).is_valid():
				damage_override = int((damage_resolver as Callable).call())
			elif execution.has("damage_override"):
				damage_override = int(execution.get("damage_override", -1))
			_combat_system.commit_attack(
				unit,
				target,
				distance_penalty_per_tile,
				max_range,
				true,
				true,
				damage_override,
				hit_chance_override,
			)
		await _host.get_tree().create_timer(ATTACK_CAMERA_DELAY).timeout
		focus_grid_pos(unit.grid_pos)


func _enhance_reckless_attack(unit: Unit, execution: Dictionary) -> void:
	var defender = execution.get("defender", null)
	if not defender is Unit:
		return
	var target: Unit = defender as Unit
	var warrior_falloff := int(execution.get("distance_penalty_per_tile", 0))
	var warrior_range := int(execution.get("attack_range", 1))
	var retal_range := int(execution.get("retaliation_attack_range", 0))
	var retal_falloff := int(execution.get("retaliation_distance_penalty_per_tile", 0))

	execution["present"] = func() -> void:
		focus_grid_pos(target.grid_pos)
		await _host.get_tree().create_timer(ATTACK_FOCUS_DURATION).timeout
		if _combat_system == null:
			return

		# Enemy strikes first (interrupt — no turn/action budget).
		if (
			retal_range > 0
			and target.is_alive()
			and unit.is_alive()
			and GridMath.chebyshev(target.grid_pos, unit.grid_pos) <= retal_range
		):
			_combat_system.commit_attack(
				target,
				unit,
				retal_falloff,
				retal_range,
				false,
				false,
			)
			await _host.get_tree().create_timer(ATTACK_CAMERA_DELAY).timeout

		# Warrior swing if still able (owns turn, free action — no ACTION budget).
		if (
			unit.is_alive()
			and target.is_alive()
			and GridMath.chebyshev(unit.grid_pos, target.grid_pos) <= warrior_range
		):
			focus_grid_pos(target.grid_pos)
			_combat_system.commit_attack(
				unit,
				target,
				warrior_falloff,
				warrior_range,
				false,
				true,
			)
			await _host.get_tree().create_timer(ATTACK_CAMERA_DELAY).timeout

		focus_grid_pos(unit.grid_pos)

	if _battle_ui:
		var prior_complete: Callable = execution.get("complete", Callable())
		execution["complete"] = func() -> void:
			if prior_complete.is_valid():
				prior_complete.call()
			_battle_ui.append_log(
				"%s recklessly attacks %s (enemy strikes first)" % [
					unit.display_name,
					target.display_name,
				],
				_log_color_for(unit),
			)


func _enhance_draw(unit: Unit, execution: Dictionary) -> void:
	var amount := int(execution.get("draw_amount", 0))
	execution["present"] = func() -> void:
		focus_grid_pos(unit.grid_pos)
		await _host.get_tree().create_timer(0.5).timeout
	if _battle_ui:
		var prior_complete: Callable = execution.get("complete", Callable())
		execution["complete"] = func() -> void:
			if prior_complete.is_valid():
				prior_complete.call()
			var bank: int = WarlockDrawBank.get_drawn(unit)
			_battle_ui.append_log(
				"%s draws %d mana (bank %d)" % [unit.display_name, amount, bank],
				_log_color_for(unit),
			)


func _enhance_self_buff(unit: Unit, execution: Dictionary) -> void:
	execution["present"] = func() -> void:
		focus_grid_pos(unit.grid_pos)
		await _host.get_tree().create_timer(0.45).timeout
	if _battle_ui:
		var prior_complete: Callable = execution.get("complete", Callable())
		var spent_holder: Variant = execution.get("spent_drawn", {})
		execution["complete"] = func() -> void:
			if prior_complete.is_valid():
				prior_complete.call()
			var spent := 0
			var overload := false
			if typeof(spent_holder) == TYPE_DICTIONARY:
				spent = int(spent_holder.get("spent", 0))
				overload = bool(spent_holder.get("overload", false))
			var mode := "Overload" if overload else "raised"
			var detail := (
				"up to %d unit turns / until own turn" % 3
				if overload
				else "blocks 1 hit"
			)
			_battle_ui.append_log(
				"%s %s Mana Shield (%s, spent %d)" % [unit.display_name, mode, detail, spent],
				_log_color_for(unit),
			)


func _tween_along_path(unit: Unit, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var target_world := GridMath.grid_to_world(path[i], 0.5)
		var tween := _host.create_tween()
		tween.tween_property(unit, "global_position", target_world, MOVE_TILE_DURATION)
		await tween.finished
	unit.set_grid_pos(path[path.size() - 1])


func _log_color_for(unit: Unit) -> Color:
	if unit.is_player():
		return Color(0.55, 0.78, 1.0)
	return Color(1.0, 0.55, 0.55)


func _fmt_grid_pos(pos: Vector2i) -> String:
	return "(%d,%d)" % [pos.x, pos.y]
