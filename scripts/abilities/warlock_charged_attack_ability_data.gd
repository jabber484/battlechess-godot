class_name WarlockChargedAttackAbilityData
extends SimpleAttackAbilityData

## Shared Warlock charged-attack channel: lock Available→Charging, fire Charging→Used.
##
## Open (free slot): select ability → range ring → click self. Locks `first_tick_lock` (0 = free snap).
## Fire (ACTION): while charging, click an enemy. Commit charge to Used; clear channel.
## Turn start (after unit regen): sip locks `next_tick_lock` if under cap.
## Damage: `base_damage * charge_ticks` — two ticks = double first-tick damage.

@export var first_tick_lock: int = 0
@export var next_tick_lock: int = 1
@export var max_charge_ticks: int = 2
@export var base_damage: int = 10

## Mana locked into this channel (sum of tick locks so far).
var charged_mana: int = 0
## Ticks accumulated on this channel (1 after open, up to max_charge_ticks).
var _charge_ticks: int = 0
var is_charging: bool = false
## Short ability-bar label (e.g. "Bolt"); empty → `display_name`.
var button_short_name: String = ""


func tick_lock_cost(tick_index: int) -> int:
	if tick_index <= 1:
		return maxi(0, first_tick_lock)
	return maxi(0, next_tick_lock)


func max_charged_mana() -> int:
	var total := 0
	for tick in range(1, max_charge_ticks + 1):
		total += tick_lock_cost(tick)
	return total


func charge_ticks() -> int:
	return _charge_ticks


func open_lock_amount() -> int:
	return tick_lock_cost(1)


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if unit == null or ctx == null or ctx.turn_manager == null:
		return false
	if not ctx.turn_manager.owns_turn(unit) or ctx.turn_manager.is_busy():
		return false
	if is_charging:
		if not unit.can_act_more():
			return false
		if _charge_ticks < 1:
			return false
		return not get_target_tiles(unit, ctx).is_empty()
	if not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	var open_cost := open_lock_amount()
	return open_cost <= 0 or unit.get_resource(BattleEnums.UnitResource.MANA) >= open_cost


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


## Lock Available→Charging for `tick_index` and set channel state. Open uses 1; sip uses next.
func _try_lock_tick(unit: Unit, tick_index: int) -> bool:
	if unit == null or tick_index < 1 or tick_index > max_charge_ticks:
		return false
	var cost := tick_lock_cost(tick_index)
	if cost > 0 and not unit.lock_resource(cost, BattleEnums.UnitResource.MANA):
		return false
	elif cost <= 0 and not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	if tick_index == 1:
		charged_mana = cost
		is_charging = true
	else:
		charged_mana += cost
	_charge_ticks = tick_index
	return true


func try_open_channel(unit: Unit) -> bool:
	if is_charging or unit == null:
		return false
	if max_charge_ticks < 1:
		return false
	return _try_lock_tick(unit, 1)


func try_turn_sip(unit: Unit) -> bool:
	if not is_charging or unit == null:
		return false
	if _charge_ticks >= max_charge_ticks:
		return false
	return _try_lock_tick(unit, _charge_ticks + 1)


func spend_charge(unit: Unit) -> int:
	var spent := charged_mana
	if spent > 0 and unit:
		unit.commit_resource_to_used(spent, BattleEnums.UnitResource.MANA)
	charged_mana = 0
	_charge_ticks = 0
	is_charging = false
	return spent


func purge_channel(unit: Unit = null) -> void:
	if charged_mana > 0 and unit:
		unit.commit_resource_to_used(charged_mana, BattleEnums.UnitResource.MANA)
	charged_mana = 0
	_charge_ticks = 0
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
	var amount := open_lock_amount()
	return {
		"commit": func() -> bool:
			return try_open_channel(unit),
		"present": Callable(),
		"complete": func() -> void:
			if unit:
				unit.emit_ability_log(
					"%s channels %s (%d/%d mana, %d/%d ticks)"
					% [
						unit.display_name,
						display_name,
						charged_mana,
						max_charged_mana(),
						_charge_ticks,
						max_charge_ticks,
					]
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
		if not is_charging or _charge_ticks < 1:
			return false
		var ticks_at_fire := _charge_ticks
		var spent: int = spend_charge(unit)
		spent_holder["spent"] = spent
		spent_holder["ticks"] = ticks_at_fire
		if prior_commit.is_valid():
			prior_commit.call()
		return true

	execution["presentation"] = BattleEnums.Presentation.ATTACK
	execution["attack_label"] = "blasts"
	execution["damage_resolver"] = func() -> int:
		var ticks: int = int(spent_holder["ticks"])
		return int(floor(float(base_damage) * float(maxi(1, ticks))))
	execution["spent_charge"] = spent_holder
	return execution


func get_resource_spend_preview(_unit: Unit) -> Dictionary:
	if is_charging:
		return {"lock": 0, "commit": charged_mana, "spend": 0}
	return {"lock": open_lock_amount(), "commit": 0, "spend": 0}


func get_selection_prompt() -> String:
	if is_charging:
		return "Selected %s — click an enemy in range" % display_name
	return "Selected %s — click self to channel (range shown)" % display_name


func get_post_execute_status(_unit: Unit) -> String:
	if is_charging:
		return (
			"%s charged %d/%d — fire at an enemy or End Turn"
			% [display_name, charged_mana, max_charged_mana()]
		)
	return ""


func get_attack_log_verb() -> String:
	return "blasts"


func format_hit_chance_extra(_attacker: Unit, _defender: Unit) -> String:
	var ticks: int = charge_ticks()
	var preview: int = base_damage * maxi(1, ticks)
	return " | dmg ~%d (%d×)" % [preview, maxi(1, ticks)]


func get_button_label() -> String:
	var short := button_short_name if not button_short_name.is_empty() else display_name
	return "%s (%d/%d)" % [short, charged_mana, max_charged_mana()]


func uses_self_target_highlight() -> bool:
	return not is_charging


func get_tooltip_body() -> String:
	if is_charging:
		return (
			"Fire %s (%d/%d mana, %d/%d ticks). Damage = %d × ticks. Spent mana goes to Used timeout."
			% [
				display_name,
				charged_mana,
				max_charged_mana(),
				_charge_ticks,
				max_charge_ticks,
				base_damage,
			]
		)
	return (
		"Open channel: click self (shows range). First tick locks %d, sip locks %d. Cap %d ticks for %d× damage."
		% [first_tick_lock, next_tick_lock, max_charge_ticks, max_charge_ticks]
	)
