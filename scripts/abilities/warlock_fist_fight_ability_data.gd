class_name WarlockFistFightAbilityData
extends SimpleAttackAbilityData

## Fist Fight — dry-out melee desperation attack.
##
## Slot: ACTION / CostSlot.ACTION.
## Target: adjacent enemy only (Chebyshev range 1).
## Cost: none — never touches the mana well or Draw bank.
## Hit: flat `flat_hit_chance` (default 50%); damage = unit `damage`.
## Availability: listed / usable only when well mana is 0 (empty well).
## Tone: intentional slapstick basic when the Warlock is spent.

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
