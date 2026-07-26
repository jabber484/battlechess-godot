class_name WarlockMeditateAbilityData
extends AbilityData

## Meditate — spend the turn restoring half the mana well.
##
## Slot: ACTION / CostSlot.ACTION; self-cast, runs on ability-bar click (`activates_on_select`).
## Effect: gain `floor(max_resource / 2)` mana (clamped to max), then **immediately end the turn**.
## Gate: owns the action slot and well is not already full.

@export var restore_fraction: float = 0.5


func _init() -> void:
	id = &"warlock_meditate"
	display_name = "Meditate"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	if unit == null or not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	return unit.get_resource(BattleEnums.UnitResource.MANA) < unit.max_resource


func get_target_tiles(unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	result.append(unit.grid_pos)
	return result


func is_valid_target(unit: Unit, target_pos: Vector2i, _ctx: AbilityContext) -> bool:
	return unit != null and target_pos == unit.grid_pos


func activates_on_select() -> bool:
	return true


func _restore_amount(unit: Unit) -> int:
	if unit == null or unit.max_resource <= 0:
		return 0
	return int(floor(float(unit.max_resource) * restore_fraction))


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}
	if unit == null or not is_valid_target(unit, target_pos, ctx):
		return empty

	var amount := _restore_amount(unit)
	var turn_manager := ctx.turn_manager
	var gained_holder := {"amount": 0}

	return {
		"commit": func() -> bool:
			if unit == null or not unit.has_resource(BattleEnums.UnitResource.MANA):
				return false
			if unit.get_resource(BattleEnums.UnitResource.MANA) >= unit.max_resource:
				return false
			if amount <= 0:
				return false
			var before := unit.get_resource(BattleEnums.UnitResource.MANA)
			unit.gain_resource(amount, BattleEnums.UnitResource.MANA)
			gained_holder["amount"] = unit.get_resource(BattleEnums.UnitResource.MANA) - before
			return gained_holder["amount"] > 0,
		"present": Callable(),
		"complete": func() -> void:
			var gained: int = int(gained_holder["amount"])
			if unit and gained > 0:
				unit.emit_ability_log(
					"%s meditates (+%d mana) — turn ends" % [unit.display_name, gained]
				)
			# Defer so ActionRunner can clear busy before the next unit's turn begins.
			if turn_manager:
				turn_manager.call_deferred("finish_turn", unit),
		"death_units": [],
		"presentation": BattleEnums.Presentation.SELF_BUFF,
		"meditate_restore": amount,
	}


func get_tooltip_text() -> String:
	return (
		"Restore half your max mana, then immediately end your turn."
	)
