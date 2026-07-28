class_name WarlockChargedBoltAbilityData
extends SimpleAttackAbilityData

## Charged Bolt — mid-range channel; locks Available→Charging, fires Charging→Used.
##
## Open (free): select ability → range ring → click self. `lock_resource(charge_draw_amount)`.
## Fire (ACTION): while charging, click an enemy. Commit charge to Used; clear channel.
## Turn start (after unit regen+release): sip another tick if under cap.
## Damage: `floor(base_bolt_damage * ticks)` — two ticks = double first-tick damage.

@export var charge_draw_amount: int = 10
@export var max_charge_ticks: int = 2
@export var base_bolt_damage: int = 10

var charged_mana: int = 0
var is_charging: bool = false


func _init() -> void:
	id = &"warlock_charged_bolt"
	display_name = "Charged Bolt"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 4
	range_metric = BattleEnums.RangeMetric.EUCLIDEAN
	distance_penalty_per_tile = 5


func max_charged_mana() -> int:
	return charge_draw_amount * max_charge_ticks


func charge_ticks() -> int:
	if charge_draw_amount <= 0:
		return 0
	return int(float(charged_mana) / float(charge_draw_amount))


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.turn_manager == null:
		return false
	if not ctx.turn_manager.owns_turn(unit) or ctx.turn_manager.is_busy():
		return false
	if is_charging:
		if not unit.can_act_more():
			return false
		if charged_mana < charge_draw_amount:
			return false
		return not get_target_tiles(unit, ctx).is_empty()
	if not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	return unit.get_resource(BattleEnums.UnitResource.MANA) >= charge_draw_amount


func get_target_tiles(unit: Unit, ctx: AbilityContext) -> Array[Vector2i]:
	if is_charging:
		return super.get_target_tiles(unit, ctx)
	var result: Array[Vector2i] = []
	if unit != null:
		result.append(unit.grid_pos)
	return result


func is_valid_target(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> bool:
	if is_charging:
		return super.is_valid_target(unit, target_pos, ctx)
	return unit != null and target_pos == unit.grid_pos


func try_open_channel(unit: Unit) -> bool:
	if is_charging or unit == null:
		return false
	if charge_draw_amount <= 0:
		return false
	if charged_mana + charge_draw_amount > max_charged_mana():
		return false
	if not unit.lock_resource(charge_draw_amount, BattleEnums.UnitResource.MANA):
		return false
	charged_mana += charge_draw_amount
	is_charging = true
	return true


func try_turn_sip(unit: Unit) -> bool:
	if not is_charging or unit == null:
		return false
	if charged_mana >= max_charged_mana():
		return false
	if charge_draw_amount <= 0:
		return false
	if not unit.lock_resource(charge_draw_amount, BattleEnums.UnitResource.MANA):
		return false
	charged_mana += charge_draw_amount
	return true


func spend_charge(unit: Unit) -> int:
	var spent := charged_mana
	if spent > 0 and unit:
		unit.commit_resource_to_used(spent, BattleEnums.UnitResource.MANA)
	charged_mana = 0
	is_charging = false
	return spent


func purge_channel(unit: Unit = null) -> void:
	if charged_mana > 0 and unit:
		unit.commit_resource_to_used(charged_mana, BattleEnums.UnitResource.MANA)
	charged_mana = 0
	is_charging = false


func on_turn_started(unit: Unit) -> void:
	try_turn_sip(unit)


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	if not is_charging:
		return _build_open_execution(unit, target_pos, ctx)
	return _build_fire_execution(unit, target_pos, ctx)


func _build_open_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var empty := {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}
	if unit == null or not is_valid_target(unit, target_pos, ctx):
		return empty
	var amount := charge_draw_amount
	return {
		"commit": func() -> bool:
			return try_open_channel(unit),
		"present": Callable(),
		"complete": func() -> void:
			if unit:
				unit.emit_ability_log(
					"%s channels %s (%d/%d)"
					% [unit.display_name, display_name, charged_mana, max_charged_mana()]
				),
		"death_units": [],
		"presentation": BattleEnums.Presentation.SELF_BUFF,
		"channel_open": true,
		"draw_amount": amount,
	}


func _build_fire_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var execution := super.build_execution(unit, target_pos, ctx)
	if execution.get("defender", null) == null:
		return execution

	var spent_holder := {"spent": 0, "ticks": 0}
	var prior_commit: Callable = execution.get("commit", Callable())

	execution["commit"] = func() -> bool:
		if charged_mana < charge_draw_amount:
			return false
		var spent: int = spend_charge(unit)
		spent_holder["spent"] = spent
		spent_holder["ticks"] = (
			int(float(spent) / float(charge_draw_amount)) if charge_draw_amount > 0 else 0
		)
		if prior_commit.is_valid():
			prior_commit.call()
		return true

	execution["presentation"] = BattleEnums.Presentation.ATTACK
	execution["attack_label"] = "blasts"
	execution["damage_resolver"] = func() -> int:
		var ticks: int = int(spent_holder["ticks"])
		return int(floor(float(base_bolt_damage) * float(maxi(1, ticks))))
	execution["spent_charge"] = spent_holder
	return execution


func get_tooltip_text() -> String:
	if is_charging:
		return (
			"Fire %s (%d/%d). Damage = %d × ticks. Spent mana goes to Used timeout."
			% [display_name, charged_mana, max_charged_mana(), base_bolt_damage]
		)
	return (
		"Open channel: click self (shows range). Locks %d Available→Charging. Cap %d ticks for %d× damage."
		% [charge_draw_amount, max_charge_ticks, max_charge_ticks]
	)
