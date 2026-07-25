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
	execution["present"] = func() -> void:
		focus_grid_pos(target.grid_pos)
		await _host.get_tree().create_timer(ATTACK_FOCUS_DURATION).timeout
		if _combat_system:
			_combat_system.commit_attack(
				unit, target, distance_penalty_per_tile, max_range
			)
		await _host.get_tree().create_timer(ATTACK_CAMERA_DELAY).timeout
		focus_grid_pos(unit.grid_pos)


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
