class_name WarlockChargedBoltAbilityData
extends SimpleAttackAbilityData

## Charged Bolt — mid-range nuke that dumps the entire Draw bank.
##
## Slot: ACTION / CostSlot.ACTION.
## Target: enemy in attack range (default 4, Euclidean).
## Cost: requires Draw bank ≥ `mana_cost`, then spends the **whole** bank (`drawn_mana → 0`).
## Damage: `floor(spent * damage_per_mana)`; Overload when spent > `overload_threshold`
## multiplies by `overload_damage_mult` (150%).
## Overload tooltip unlocks the first time Draw bank reaches `overload_threshold`.
## Selectable only with bank + at least one in-range enemy.

@export var mana_cost: int = 5
@export var overload_threshold: int = 15
@export var damage_per_mana: float = 2.0
@export var overload_damage_mult: float = 1.5

var overload_unlocked: bool = false


func _init() -> void:
	id = &"warlock_charged_bolt"
	display_name = "Charged Bolt"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 4
	range_metric = BattleEnums.RangeMetric.EUCLIDEAN
	distance_penalty_per_tile = 5


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	return WarlockDrawBank.get_drawn(unit) >= mana_cost


func on_draw_bank_changed(_unit: Unit, drawn: int) -> void:
	if not overload_unlocked and drawn >= overload_threshold:
		overload_unlocked = true


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var execution := super.build_execution(unit, target_pos, ctx)
	if execution.get("defender", null) == null:
		return execution

	var provider := WarlockDrawBank.get_provider(unit)
	if provider == null:
		return {
			"commit": Callable(),
			"present": Callable(),
			"complete": Callable(),
			"death_units": [],
			"defender": null,
		}

	var prior_commit: Callable = execution.get("commit", Callable())
	var spent_holder := {"spent": 0, "overload": false}

	execution["commit"] = func() -> bool:
		if provider.drawn_mana < mana_cost:
			return false
		var spent: int = provider.spend_entire_bank()
		spent_holder["spent"] = spent
		spent_holder["overload"] = spent > overload_threshold
		WarlockDrawBank.notify_bank_changed(unit)
		if prior_commit.is_valid():
			prior_commit.call()
		return true

	execution["presentation"] = BattleEnums.Presentation.ATTACK
	execution["attack_label"] = "blasts"
	execution["damage_resolver"] = func() -> int:
		var spent: int = int(spent_holder["spent"])
		var base := int(floor(float(spent) * damage_per_mana))
		if spent_holder["overload"]:
			return int(floor(float(base) * overload_damage_mult))
		return base
	execution["spent_drawn"] = spent_holder
	execution["overload_unlocked"] = overload_unlocked
	return execution


func get_tooltip_text() -> String:
	var text := (
		"Spend the entire Draw bank (min %d). Damage = bank × %.1f."
		% [mana_cost, damage_per_mana]
	)
	if overload_unlocked:
		text += (
			"\nOverload (bank > %d): deals %d%% damage."
			% [overload_threshold, int(overload_damage_mult * 100.0)]
		)
	return text
