class_name WarlockManaShieldAbilityData
extends AbilityData

## Raise a full-block barrier by dumping the Draw bank. Overload: multi-hit soak on a unit-turn timer.
##
## Expiry (whichever comes first for the active mode):
## - Normal: after blocking **1** damaging hit
## - Overload: after **3 other units' turn starts**, OR immediately when the Warlock's **own turn starts**

@export var mana_cost: int = 5
@export var overload_threshold: int = 15
@export var overload_unit_turns: int = 3

var overload_unlocked: bool = false

## Runtime shield state (raised by cast).
var active: bool = false
var charges: int = 0
var remaining_unit_turns: int = 0
var _duration_mode: bool = false


func _init() -> void:
	id = &"warlock_mana_shield"
	display_name = "Mana Shield"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	return WarlockDrawBank.get_drawn(unit) >= mana_cost


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


func on_draw_bank_changed(_unit: Unit, drawn: int) -> void:
	if not overload_unlocked and drawn >= overload_threshold:
		overload_unlocked = true


func on_incoming_damage(unit: Unit, context) -> void:
	if not active or context == null:
		return
	var final_damage: int = int(context.final_damage)
	if final_damage <= 0:
		return
	context.final_damage = 0
	if unit:
		unit.emit_ability_log(
			"%s's Mana Shield blocked %d damage" % [unit.display_name, final_damage]
		)
	if _duration_mode:
		if unit:
			unit.notify_status_fx_changed()
		return
	charges = maxi(0, charges - 1)
	if charges <= 0:
		_clear_shield(unit, "blocked")
	elif unit:
		unit.notify_status_fx_changed()


func on_turn_started(unit: Unit) -> void:
	# Own turn start always clears the shield (whichever-first with unit-turn countdown).
	if active:
		_clear_shield(unit, "own_turn")


func on_foreign_turn_started(owner: Unit, starting_unit: Unit) -> void:
	if not active or not _duration_mode:
		return
	remaining_unit_turns = maxi(0, remaining_unit_turns - 1)
	if remaining_unit_turns <= 0:
		var starter := starting_unit.display_name if starting_unit else "another unit"
		_clear_shield(owner, "duration", starter)
	elif owner:
		owner.notify_status_fx_changed()


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}
	if unit == null or not is_valid_target(unit, target_pos, ctx):
		return empty

	var provider := WarlockDrawBank.get_provider(unit)
	if provider == null:
		return empty

	var turn_manager := ctx.turn_manager
	var spent_holder := {"spent": 0, "overload": false}

	return {
		"commit": func() -> bool:
			if provider.drawn_mana < mana_cost:
				return false
			var spent: int = provider.spend_entire_bank()
			spent_holder["spent"] = spent
			spent_holder["overload"] = spent > overload_threshold
			WarlockDrawBank.notify_bank_changed(unit)
			_raise_shield(unit, bool(spent_holder["overload"]))
			return true,
		"present": Callable(),
		"complete": func() -> void:
			if turn_manager:
				turn_manager.notify_acted(unit),
		"death_units": [],
		"presentation": BattleEnums.Presentation.SELF_BUFF,
		"spent_drawn": spent_holder,
		"shield_overload": spent_holder,
	}


func is_shield_up() -> bool:
	return active


func get_shield_status_text() -> String:
	if not active:
		return ""
	if _duration_mode:
		return "SHIELD %d" % remaining_unit_turns
	return "SHIELD"


func get_tooltip_text() -> String:
	var text := (
		"Spend the entire Draw bank (min %d). Fully blocks one hit."
		% mana_cost
	)
	if overload_unlocked:
		text += (
			"\nOverload (bank > %d): blocks every hit for up to %d unit turns, or until your next turn."
			% [overload_threshold, overload_unit_turns]
		)
	return text


func _raise_shield(unit: Unit, overload: bool) -> void:
	active = true
	if overload:
		_duration_mode = true
		charges = 0
		remaining_unit_turns = overload_unit_turns
	else:
		_duration_mode = false
		charges = 1
		remaining_unit_turns = 0
	if unit:
		unit.notify_status_fx_changed()


func _clear_shield(
	unit: Unit = null,
	reason: String = "",
	other_name: String = "",
) -> void:
	var was_active := active
	var was_duration := _duration_mode
	active = false
	charges = 0
	remaining_unit_turns = 0
	_duration_mode = false
	if not was_active:
		return
	if unit:
		unit.notify_status_fx_changed()
		match reason:
			"blocked":
				unit.emit_ability_log(
					"%s's Mana Shield shattered (blocked one hit)" % unit.display_name
				)
			"duration":
				unit.emit_ability_log(
					"%s's Mana Shield faded (duration ended on %s's turn)"
					% [unit.display_name, other_name if not other_name.is_empty() else "another unit"]
				)
			"own_turn":
				var mode := "Overload" if was_duration else "Mana Shield"
				unit.emit_ability_log(
					"%s's %s faded (own turn began)" % [unit.display_name, mode]
				)
			_:
				pass
