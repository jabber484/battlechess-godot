class_name AbilityData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Ability"
@export var category: BattleEnums.AbilityCategory = BattleEnums.AbilityCategory.ACTION
@export var cost_slot: BattleEnums.CostSlot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if category == BattleEnums.AbilityCategory.PASSIVE:
		return false
	if unit == null or ctx == null or ctx.turn_manager == null:
		return false
	if not ctx.turn_manager.owns_turn(unit) or ctx.turn_manager.is_busy():
		return false
	match cost_slot:
		BattleEnums.CostSlot.MOVE:
			return unit.can_move_more()
		BattleEnums.CostSlot.ACTION:
			return unit.can_act_more()
		_:
			return false


func get_target_tiles(_unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	return []


func is_valid_target(_unit: Unit, _target_pos: Vector2i, _ctx: AbilityContext) -> bool:
	return false


## Returns keys: commit, present, complete (Callable), death_units (Array[Unit]).
## Subclasses may add extras (e.g. path) for presentation helpers.
func build_execution(
	_unit: Unit,
	_target_pos: Vector2i,
	_ctx: AbilityContext,
) -> Dictionary:
	return {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}


## Passive hook: mutate DamageContext before HP is applied.
func on_incoming_damage(_unit: Unit, _context) -> void:
	pass
