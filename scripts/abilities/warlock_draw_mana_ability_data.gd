class_name WarlockDrawManaAbilityData
extends AbilityData

## Free-action Draw: pulls from the mana well into this ability's bank.

@export var draw_amount: int = 5
@export var max_drawn_mana: int = 20
@export var is_default_draw_bank: bool = true

## Runtime bank — persists across turns until a cast spends it.
var drawn_mana: int = 0


func _init() -> void:
	id = &"warlock_draw_mana"
	display_name = "Draw"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.NONE


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	if unit == null or not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	if unit.get_resource(BattleEnums.UnitResource.MANA) < draw_amount:
		return false
	return drawn_mana + draw_amount <= max_drawn_mana


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


func add_drawn(amount: int) -> bool:
	if amount <= 0:
		return false
	if drawn_mana + amount > max_drawn_mana:
		return false
	drawn_mana += amount
	return true


func spend_entire_bank() -> int:
	var spent := drawn_mana
	drawn_mana = 0
	return spent


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}
	if unit == null or not is_valid_target(unit, target_pos, ctx):
		return empty
	var amount := draw_amount
	return {
		"commit": func() -> bool:
			# Do not call can_activate here — ActionRunner already set turn busy.
			if unit == null or not unit.has_resource(BattleEnums.UnitResource.MANA):
				return false
			if unit.get_resource(BattleEnums.UnitResource.MANA) < amount:
				return false
			if drawn_mana + amount > max_drawn_mana:
				return false
			if not unit.spend_resource(amount, BattleEnums.UnitResource.MANA):
				return false
			if not add_drawn(amount):
				unit.gain_resource(amount, BattleEnums.UnitResource.MANA)
				return false
			WarlockDrawBank.notify_bank_changed(unit)
			return true,
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
		"presentation": BattleEnums.Presentation.DRAW,
		"drawn_mana": drawn_mana + amount,
		"draw_amount": amount,
	}
