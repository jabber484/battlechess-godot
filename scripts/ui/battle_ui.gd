class_name BattleUI
extends CanvasLayer

signal end_turn_pressed

@onready var round_label: Label = %RoundLabel
@onready var initiative_bar: HBoxContainer = %InitiativeBar
@onready var active_label: Label = %ActiveLabel
@onready var flags_label: Label = %FlagsLabel
@onready var hit_chance_label: Label = %HitChanceLabel
@onready var status_label: Label = %StatusLabel
@onready var end_turn_button: Button = %EndTurnButton


func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	hit_chance_label.text = ""
	status_label.text = ""


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
	active_label.text = "Active: %s  HP %d/%d  Sp %d" % [
		unit.display_name, unit.current_hp, unit.max_hp, unit.speed
	]
	_refresh_flags(unit)


func _refresh_flags(unit: Unit) -> void:
	var move_txt := "Moved" if unit.has_moved else "Move ready"
	var act_txt := "Acted" if unit.has_acted else "Action ready"
	flags_label.text = "%s | %s" % [move_txt, act_txt]


func set_hit_chance(text: String) -> void:
	hit_chance_label.text = text


func set_status(text: String) -> void:
	status_label.text = text


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


func show_battle_result(result: BattleEnums.BattleResult) -> void:
	match result:
		BattleEnums.BattleResult.VICTORY:
			status_label.text = "VICTORY"
		BattleEnums.BattleResult.DEFEAT:
			status_label.text = "DEFEAT"
		_:
			pass
