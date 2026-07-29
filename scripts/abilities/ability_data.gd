class_name AbilityData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Ability"
@export var category: BattleEnums.AbilityCategory = BattleEnums.AbilityCategory.ACTION
@export var cost_slot: BattleEnums.CostSlot = BattleEnums.CostSlot.ACTION


func can_activate(unit: Unit, ctx: AbilityContext) -> bool:
	if category == BattleEnums.AbilityCategory.PASSIVE:
		return false
	if unit == null or ctx == null or ctx.turn_manager == null:
		return false
	if not ctx.turn_manager.owns_turn(unit) or ctx.turn_manager.is_busy():
		return false
	match cost_slot:
		BattleEnums.CostSlot.MOVE:
			return unit.can_move_more()
		BattleEnums.CostSlot.ACTION:
			return unit.can_act_more()
		BattleEnums.CostSlot.NONE:
			return true
		_:
			return false


func get_target_tiles(_unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	return []


func is_valid_target(_unit: Unit, _target_pos: Vector2i, _ctx: AbilityContext) -> bool:
	return false


## If true, selecting this ability in the UI runs it immediately (no tile confirm).
func activates_on_select() -> bool:
	return false


## Returns keys: commit, present, complete (Callable), death_units (Array[Unit]).
## Subclasses may add extras (e.g. path) for presentation helpers.
func build_execution(
	_unit: Unit,
	_target_pos: Vector2i,
	_ctx: AbilityContext,
) -> Dictionary:
	return {
		"commit": Callable(),
		"present": Callable(),
		"complete": Callable(),
		"death_units": [],
	}


## Damage hook: mutate DamageContext before HP is applied.
## Dispatched to all abilities (PASSIVE soak kits, and ACTION abilities with raised block state).
func on_incoming_damage(_unit: Unit, _context) -> void:
	pass


## Called after an attack against this owner fully resolves.
## Useful for reactive effects that care about "was attacked" rather than raw damage mutation.
func on_owner_attacked(
	_owner: Unit,
	_attacker: Unit,
	_hit: bool,
	_damage: int,
	_hit_chance: int,
	_combat_system,
) -> void:
	pass


## Called when this unit's turn begins (passives and per-turn ACTION state).
func on_turn_started(_unit: Unit) -> void:
	pass


## Called on this owner when a *different* unit's turn begins (e.g. duration countdowns).
func on_foreign_turn_started(_owner: Unit, _starting_unit: Unit) -> void:
	pass


# --- Optional UI / targeting hooks (BattleController / BattleUI) ---


## HUD resource ghost: keys `lock`, `commit`, `spend` (amounts ≥ 0).
func get_resource_spend_preview(_unit: Unit) -> Dictionary:
	return {"lock": 0, "commit": 0, "spend": 0}


## Status line after the player selects this ability (before targeting confirm).
func get_selection_prompt() -> String:
	match category:
		BattleEnums.AbilityCategory.MOVE:
			return "Selected %s — click a highlighted tile" % display_name
		BattleEnums.AbilityCategory.ACTION:
			return "Selected %s — click a target" % display_name
		_:
			return "Selected %s" % display_name


## Status after a successful execute. Empty → controller uses a generic fallback.
func get_post_execute_status(_unit: Unit) -> String:
	return ""


## Verb in the attack-resolved log ("shoots", "blasts", …).
func get_attack_log_verb() -> String:
	return "shoots"


## Extra text appended to the hit-chance hover line (e.g. charged damage preview).
func format_hit_chance_extra(_attacker: Unit, _defender: Unit) -> String:
	return ""


## Ability bar button label (may include charge state).
func get_button_label() -> String:
	return display_name


## Distance falloff per tile for hit chance. Attacks override.
func get_distance_penalty_per_tile() -> int:
	return 0


## Reach metric for hit chance / range checks. Attacks override.
func get_range_metric() -> BattleEnums.RangeMetric:
	return BattleEnums.RangeMetric.CHEBYSHEV


## True if `to_pos` is within this ability's attack reach from `from_pos`.
func is_in_attack_range(_from_pos: Vector2i, _to_pos: Vector2i) -> bool:
	return false


## Full attack-range ring for UI (not only occupied enemy tiles).
func get_range_preview_tiles(_unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	return []


## If true, style `get_target_tiles` as self-target instead of attackable.
func uses_self_target_highlight() -> bool:
	return activates_on_select()


## MOVE: tiles that cost a resource overspend (e.g. stamina). Empty = all targets are free.
func get_costly_target_tiles(_unit: Unit, _ctx: AbilityContext) -> Array[Vector2i]:
	return []
