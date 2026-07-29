class_name WarlockManaShieldAbilityData
extends AbilityData

## Mana Shield — ward until one block or own next turn (expire). Charging → Used either way.
##
## Slot: ACTION / CostSlot.NONE (free); self-cast (`activates_on_select`).
## Open: lock `charge_draw_amount`; `blocks_available = 1`.
## Own turn start (after Available regen): if still open, expire → commit Charging to Used.
## Block: full nullify → commit Charging to Used → end channel.
## Used clears on turn end (up to 1 per turn; hole fills on later regen).

@export var charge_draw_amount: int = 2

var charged_mana: int = 0
var is_charging: bool = false
var blocks_available: int = 0


func _init() -> void:
	id = &"warlock_mana_shield"
	display_name = "Mana Shield"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.NONE


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	if is_charging:
		return false
	if unit == null or not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	return unit.get_resource(BattleEnums.UnitResource.MANA) >= charge_draw_amount


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


func try_open_channel(unit: Unit) -> bool:
	if is_charging or unit == null:
		return false
	if charge_draw_amount <= 0:
		return false
	if not unit.lock_resource(charge_draw_amount, BattleEnums.UnitResource.MANA):
		return false
	charged_mana = charge_draw_amount
	is_charging = true
	blocks_available = 1
	if unit:
		unit.notify_status_fx_changed()
	return true


func _end_channel_to_used(unit: Unit) -> int:
	var amount := charged_mana
	charged_mana = 0
	is_charging = false
	blocks_available = 0
	if amount > 0 and unit:
		unit.commit_resource_to_used(amount, BattleEnums.UnitResource.MANA)
	if unit:
		unit.notify_status_fx_changed()
	return amount


func purge_channel(unit: Unit = null) -> void:
	if not is_charging:
		return
	_end_channel_to_used(unit)


func on_incoming_damage(unit: Unit, context) -> void:
	if not is_charging or context == null:
		return
	if blocks_available < 1:
		return
	var final_damage: int = int(context.final_damage)
	if final_damage <= 0:
		return
	context.final_damage = 0
	var spent := _end_channel_to_used(unit)
	if unit:
		unit.emit_ability_log(
			"%s's Mana Shield blocked %d damage (%d mana → Used)"
			% [unit.display_name, final_damage, spent]
		)


func on_turn_started(unit: Unit) -> void:
	# Runs after Available regen. Expire open ward so Charging locks into Used this turn.
	if not is_charging:
		return
	var spent := _end_channel_to_used(unit)
	if unit and spent > 0:
		unit.emit_ability_log(
			"%s's Mana Shield expires (%d mana → Used)" % [unit.display_name, spent]
		)


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}
	if unit == null or not is_valid_target(unit, target_pos, ctx):
		return empty

	return {
		"commit": func() -> bool:
			return try_open_channel(unit),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
		"presentation": BattleEnums.Presentation.SELF_BUFF,
		"mana_shield_open": true,
	}


func is_shield_up() -> bool:
	return is_charging


func get_shield_status_text() -> String:
	if not is_charging:
		return ""
	if blocks_available > 0:
		return "SHIELD"
	return "SHIELD—"


func get_resource_spend_preview(_unit: Unit) -> Dictionary:
	if not is_charging:
		return {"lock": charge_draw_amount, "commit": 0, "spend": 0}
	return {"lock": 0, "commit": 0, "spend": 0}


func get_post_execute_status(_unit: Unit) -> String:
	if is_shield_up():
		return "%s raised" % get_shield_status_text()
	return ""


func get_button_label() -> String:
	if is_charging:
		return "Shield" if blocks_available > 0 else "Shield—"
	return "Mana Shield"


func get_tooltip_body() -> String:
	if is_charging:
		return (
			"Ward open (%d Charging). Blocks one hit or expires on your next turn → Used."
			% charged_mana
		)
	return (
		"Open Mana Shield (free). Locks %d Available→Charging. One block or next turn expire → Used."
		% charge_draw_amount
	)
