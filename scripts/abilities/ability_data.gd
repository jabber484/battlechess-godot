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
		BattleEnums.CostSlot.NONE:
			return true
		_:
			return false


func get_target_tiles(_unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	return []


func is_valid_target(_unit: Unit, _target_pos: Vector2i, _ctx: AbilityContext) -> bool:
	return false


## If true, selecting this ability in the UI runs it immediately (no tile confirm).
func activates_on_select() -> bool:
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


## Damage hook: mutate DamageContext before HP is applied.
## Dispatched to all abilities (PASSIVE soak kits, and ACTION abilities with raised state).
func on_incoming_damage(_unit: Unit, _context) -> void:
	pass


## Called when this unit's turn begins (passives and per-turn ACTION state).
func on_turn_started(_unit: Unit) -> void:
	pass


## Called on this owner when a *different* unit's turn begins (e.g. duration countdowns).
func on_foreign_turn_started(_owner: Unit, _starting_unit: Unit) -> void:
	pass
