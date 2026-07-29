class_name WarriorCounterAbilityData
extends AbilityData

## Counter — spend stamina to ready a one-shot parry that ends the turn.
##
## Slot: ACTION / CostSlot.ACTION; self-cast (`activates_on_select`).
## Cost: `stamina_cost` (default 10), then **immediately end the turn**.
## While active: the next incoming hit from an attacker within Counter range is fully blocked.
## After that block: if the offender is still in melee range, Warrior interrupt-attacks them.
## Out-of-range hits do not consume Counter. Clears on block or at own turn start if unused.

@export var stamina_cost: int = 10
@export var melee_range: int = 1
@export var range_metric: BattleEnums.RangeMetric = BattleEnums.RangeMetric.CHEBYSHEV

var active: bool = false
## Set when a melee hit is blocked; consumed by battle flow to fire the retaliatory swing.
var _pending_retaliation_target: Unit = null


func _init() -> void:
	id = &"warrior_counter"
	display_name = "Counter"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	if active:
		return false
	if unit == null or not unit.has_resource(BattleEnums.UnitResource.STAMINA):
		return false
	return unit.get_resource(BattleEnums.UnitResource.STAMINA) >= stamina_cost


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


func on_turn_started(unit: Unit) -> void:
	if active:
		_clear_counter(unit, "own_turn")
	_pending_retaliation_target = null


func on_incoming_damage(unit: Unit, context) -> void:
	if not active or unit == null or context == null:
		return
	var attacker = context.attacker
	if attacker == null or not (attacker is Unit):
		return
	var offender: Unit = attacker as Unit
	if not _is_melee(unit, offender):
		return
	var blocked: int = int(context.final_damage)
	context.final_damage = 0
	active = false
	_pending_retaliation_target = offender
	unit.notify_status_fx_changed()
	if blocked > 0:
		unit.emit_ability_log(
			"%s Counters — blocked %d damage" % [unit.display_name, blocked]
		)
	else:
		unit.emit_ability_log("%s Counters" % unit.display_name)


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}
	if unit == null or not is_valid_target(unit, target_pos, ctx):
		return empty

	var cost := stamina_cost
	var turn_manager := ctx.turn_manager

	var execution := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
		"presentation": BattleEnums.Presentation.SELF_BUFF,
	}
	execution["commit"] = func() -> bool:
		if active:
			return false
		if not unit.spend_resource(cost, BattleEnums.UnitResource.STAMINA):
			return false
		_raise_counter(unit)
		return true
	execution["complete"] = func() -> void:
		if unit:
			unit.emit_ability_log(
				"%s readies Counter (−%d stamina) — turn ends" % [unit.display_name, cost]
			)
		if turn_manager:
			turn_manager.call_deferred("finish_turn", unit)
	return execution


func is_counter_up() -> bool:
	return active


func get_status_text() -> String:
	return "COUNTER" if active else ""


func get_resource_spend_preview(_unit: Unit) -> Dictionary:
	return {"lock": 0, "commit": 0, "spend": stamina_cost}


func get_post_execute_status(_unit: Unit) -> String:
	if is_counter_up():
		return "Counter ready — turn ended"
	return ""


func get_tooltip_body() -> String:
	return (
		"Spend %d stamina and end your turn. Fully block the next adjacent hit, "
		+ "then strike back if the attacker is still adjacent."
		% stamina_cost
	)


## Called by battle flow after the blocked attack resolves. Returns the offender to strike, or null.
func take_pending_retaliation() -> Unit:
	var target := _pending_retaliation_target
	_pending_retaliation_target = null
	return target


func on_owner_attacked(
	owner: Unit,
	attacker: Unit,
	hit: bool,
	_damage: int,
	_hit_chance: int,
	combat_system,
) -> void:
	if not hit or owner == null or attacker == null or combat_system == null:
		return
	var offender := take_pending_retaliation()
	if offender == null or offender != attacker:
		return
	if not owner.is_alive() or not offender.is_alive():
		return
	if not _is_melee(owner, offender):
		return
	combat_system.commit_attack(
		owner,
		offender,
		0,
		melee_range,
		false,
		false,
		-1,
		-1,
		range_metric,
	)


func _raise_counter(unit: Unit) -> void:
	active = true
	_pending_retaliation_target = null
	if unit:
		unit.notify_status_fx_changed()


func _clear_counter(unit: Unit = null, reason: String = "") -> void:
	var was_active := active
	active = false
	_pending_retaliation_target = null
	if not was_active:
		return
	if unit:
		unit.notify_status_fx_changed()
		if reason == "own_turn":
			unit.emit_ability_log(
				"%s's Counter fades (own turn began)" % unit.display_name
			)


func _is_melee(a: Unit, b: Unit) -> bool:
	if a == null or b == null or not b.is_alive():
		return false
	return GridMath.is_within_range(a.grid_pos, b.grid_pos, float(melee_range), range_metric)
