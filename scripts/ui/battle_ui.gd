class_name BattleUI
extends CanvasLayer

const WarriorCounterAbilityDataScript := preload("res://scripts/abilities/warrior_counter_ability_data.gd")

signal end_turn_pressed
signal ability_selected(ability: AbilityData)
signal ability_hovered(ability: AbilityData)
signal ability_unhovered(ability: AbilityData)

@onready var round_label: Label = %RoundLabel
@onready var initiative_bar: HBoxContainer = %InitiativeBar
@onready var active_label: Label = %ActiveLabel
@onready var flags_label: Label = %FlagsLabel
@onready var hit_chance_label: Label = %HitChanceLabel
@onready var status_label: Label = %StatusLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var ability_bar: HBoxContainer = %AbilityBar
@onready var log_label: RichTextLabel = %LogLabel
@onready var log_scroll: ScrollContainer = %LogScroll

const MAX_LOG_LINES := 50

var _log_lines: PackedStringArray = PackedStringArray()
var _ability_buttons: Dictionary = {} # AbilityData -> Button


func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	hit_chance_label.text = ""
	status_label.text = ""
	log_label.text = ""


func set_round(round_number: int) -> void:
	round_label.text = "Round %d" % round_number


func set_initiative(units: Array, active: Unit) -> void:
	for child in initiative_bar.get_children():
		child.queue_free()
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		var chip := Label.new()
		var marker := ">" if unit == active else " "
		var team_tag := "P" if unit.is_player() else "E"
		chip.text = "%s[%s %s Sp%d]" % [marker, team_tag, unit.display_name, unit.speed]
		if unit == active:
			chip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		elif unit.is_player():
			chip.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		else:
			chip.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		initiative_bar.add_child(chip)


func set_active_unit(unit: Unit) -> void:
	if unit == null:
		active_label.text = "Active: —"
		flags_label.text = ""
		return
	var resource_txt := ""
	if unit.has_resource():
		var res_name := _resource_label(unit.resource_id)
		if unit.resource_id == BattleEnums.UnitResource.MANA:
			var used := unit.get_resource_used()
			if used > 0:
				resource_txt = "  %s %d + %d / %d (Used %d)" % [
					res_name,
					unit.current_resource,
					unit.get_resource_charging(),
					unit.get_resource_effective_max(),
					used,
				]
			else:
				resource_txt = "  %s %d + %d / %d" % [
					res_name,
					unit.current_resource,
					unit.get_resource_charging(),
					unit.get_resource_effective_max(),
				]
		else:
			resource_txt = "  %s %d/%d" % [res_name, unit.current_resource, unit.max_resource]
	active_label.text = "Active: %s  HP %d/%d  Sp %d%s" % [
		unit.display_name, unit.current_hp, unit.max_hp, unit.speed, resource_txt
	]
	_refresh_flags(unit)


func _resource_label(id: BattleEnums.UnitResource) -> String:
	match id:
		BattleEnums.UnitResource.STAMINA:
			return "Stamina"
		BattleEnums.UnitResource.MANA:
			return "Mana"
		BattleEnums.UnitResource.ENERGY:
			return "Energy"
		_:
			return "Res"


func _refresh_flags(unit: Unit) -> void:
	var move_txt := "Move %d/%d" % [int(floor(unit.movement_remaining)), unit.move_range]
	var act_txt := "Action %d/%d" % [unit.actions_used, unit.max_actions]
	var parts: PackedStringArray = PackedStringArray([move_txt, act_txt])
	var shield := unit.get_mana_shield()
	if shield and shield.is_shield_up():
		parts.append(shield.get_shield_status_text())
	else:
		var counter = unit.get_warrior_counter()
		if counter and counter.is_counter_up():
			parts.append(counter.get_status_text())
	flags_label.text = " | ".join(parts)


func set_hit_chance(text: String) -> void:
	hit_chance_label.text = text


func set_status(text: String) -> void:
	status_label.text = text


func append_log(message: String, color: Color = Color(0.85, 0.85, 0.85)) -> void:
	var hex := color.to_html(false)
	_log_lines.append("[color=#%s]%s[/color]" % [hex, message])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	log_label.text = "\n".join(_log_lines)
	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	var bar := log_scroll.get_v_scroll_bar()
	log_scroll.scroll_vertical = int(bar.max_value)


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


func clear_abilities() -> void:
	_ability_buttons.clear()
	for child in ability_bar.get_children():
		child.queue_free()


func set_abilities(
	abilities: Array[AbilityData],
	selected: AbilityData,
	is_activatable: Callable,
) -> void:
	clear_abilities()
	for ability in abilities:
		if ability == null:
			continue
		var button := Button.new()
		button.text = ability.get_button_label()
		button.custom_minimum_size = Vector2(120, 36)
		var can_use := bool(is_activatable.call(ability))
		# Keep mouse events for range preview even when the ability can't be used yet.
		button.disabled = false
		button.modulate = Color.WHITE if can_use else Color(0.55, 0.55, 0.58, 0.9)
		button.set_meta("can_use", can_use)
		if ability.has_method("get_tooltip_text"):
			button.tooltip_text = str(ability.get_tooltip_text())
		button.pressed.connect(_on_ability_button_pressed.bind(ability))
		button.mouse_entered.connect(_on_ability_button_hovered.bind(ability))
		button.mouse_exited.connect(_on_ability_button_unhovered.bind(ability))
		ability_bar.add_child(button)
		_ability_buttons[ability] = button
	set_selected_ability(selected)


func set_selected_ability(selected: AbilityData) -> void:
	for ability in _ability_buttons:
		var button: Button = _ability_buttons[ability]
		if not is_instance_valid(button):
			continue
		var can_use := true
		if button.has_meta("can_use"):
			can_use = bool(button.get_meta("can_use"))
		var base := Color.WHITE if can_use else Color(0.55, 0.55, 0.58, 0.9)
		if ability == selected:
			button.modulate = Color(1.15, 1.05, 0.65) if can_use else Color(0.85, 0.75, 0.45, 0.9)
		else:
			button.modulate = base


func show_battle_result(result: BattleEnums.BattleResult) -> void:
	match result:
		BattleEnums.BattleResult.VICTORY:
			status_label.text = "VICTORY"
		BattleEnums.BattleResult.DEFEAT:
			status_label.text = "DEFEAT"
		_:
			pass


func _on_ability_button_pressed(ability: AbilityData) -> void:
	ability_selected.emit(ability)


func _on_ability_button_hovered(ability: AbilityData) -> void:
	ability_hovered.emit(ability)


func _on_ability_button_unhovered(ability: AbilityData) -> void:
	ability_unhovered.emit(ability)
