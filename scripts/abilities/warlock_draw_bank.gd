class_name WarlockDrawBank
extends RefCounted

## Resolves the unit's default Draw-bank provider. Casts and alternate Draws use this —
## never hard-code bank state on individual cast abilities.

const DEFAULT_DRAW_ID := &"warlock_draw_mana"


static func get_provider(unit: Unit) -> WarlockDrawManaAbilityData:
	if unit == null:
		return null
	var fallback: WarlockDrawManaAbilityData = null
	for ability in unit.abilities:
		if ability == null or not (ability is WarlockDrawManaAbilityData):
			continue
		var draw := ability as WarlockDrawManaAbilityData
		if draw.is_default_draw_bank:
			return draw
		if fallback == null and draw.id == DEFAULT_DRAW_ID:
			fallback = draw
	return fallback


static func get_drawn(unit: Unit) -> int:
	var provider := get_provider(unit)
	return provider.drawn_mana if provider else 0


static func get_max_drawn(unit: Unit) -> int:
	var provider := get_provider(unit)
	return provider.max_drawn_mana if provider else 0


static func spend_entire_bank(unit: Unit) -> int:
	var provider := get_provider(unit)
	if provider == null:
		return 0
	return provider.spend_entire_bank()


static func notify_bank_changed(unit: Unit) -> void:
	var provider := get_provider(unit)
	if provider == null or unit == null:
		return
	var drawn: int = provider.drawn_mana
	for ability in unit.abilities:
		if ability == null:
			continue
		if ability.has_method("on_draw_bank_changed"):
			ability.on_draw_bank_changed(unit, drawn)
