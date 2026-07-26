class_name WarlockFistFightAbilityData
extends SimpleAttackAbilityData

## Dry-out melee flop — free of mana / Draw bank, coin-flip miss, adjacent only.

@export var flat_hit_chance: int = 50


func _init() -> void:
	id = &"warlock_fist_fight"
	display_name = "Fist Fight"
	category = BattleEnums.AbilityCategory.ACTION
	cost_slot = BattleEnums.CostSlot.ACTION
	attack_range = 1
	range_metric = BattleEnums.RangeMetric.CHEBYSHEV
	distance_penalty_per_tile = 0


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if not super.can_activate(unit, ctx):
		return false
	# Dry-only desperation: hide/use only when the mana well is empty.
	if unit == null or not unit.has_resource(BattleEnums.UnitResource.MANA):
		return false
	return unit.get_resource(BattleEnums.UnitResource.MANA) <= 0


func build_execution(unit: Unit, target_pos: Vector2i, ctx: AbilityContext) -> Dictionary:
	var execution := super.build_execution(unit, target_pos, ctx)
	if execution.get("defender", null) == null:
		return execution
	execution["presentation"] = BattleEnums.Presentation.ATTACK
	execution["hit_chance_override"] = flat_hit_chance
	execution["attack_label"] = "fist-fights"
	return execution


func get_tooltip_text() -> String:
	return "Pathetic melee punch when the well is dry. 50% hit chance."
