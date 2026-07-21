class_name UnitHUD
extends Node3D

const DamageFloatScene := preload("res://scenes/unit/DamageFloat.tscn")

@onready var _viewport: SubViewport = $SubViewport
@onready var _sprite: Sprite3D = $Sprite3D
@onready var _name_label: Label = $SubViewport/Root/VBox/NameLabel
@onready var _hp_bar: ProgressBar = $SubViewport/Root/VBox/HPBar

var _unit: Unit


func _ready() -> void:
	_sprite.texture = _viewport.get_texture()


func bind(unit: Unit) -> void:
	if _unit and _unit.hp_changed.is_connected(_on_hp_changed):
		_unit.hp_changed.disconnect(_on_hp_changed)
	_unit = unit
	_name_label.text = unit.display_name
	_refresh_hp(unit.current_hp, unit.max_hp)
	_apply_bar_color()
	if not unit.hp_changed.is_connected(_on_hp_changed):
		unit.hp_changed.connect(_on_hp_changed)


func show_damage(amount: int) -> void:
	var floater: DamageFloat = DamageFloatScene.instantiate()
	add_child(floater)
	floater.position = Vector3(0, 0.25, 0)
	floater.play(amount)


func show_miss() -> void:
	var floater: DamageFloat = DamageFloatScene.instantiate()
	add_child(floater)
	floater.position = Vector3(0, 0.25, 0)
	floater.play_miss()


func _on_hp_changed(_unit_ref: Unit, current_hp: int, max_hp: int) -> void:
	_refresh_hp(current_hp, max_hp)


func _refresh_hp(current_hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp


func _apply_bar_color() -> void:
	if _unit == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.7, 1.0) if _unit.is_player() else Color(0.95, 0.35, 0.3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)
