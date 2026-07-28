class_name UnitHUD
extends Node3D

const DamageFloatScene := preload("res://scenes/unit/DamageFloat.tscn")
const WarriorCounterAbilityDataScript := preload("res://scripts/abilities/warrior_counter_ability_data.gd")

@onready var _viewport: SubViewport = $SubViewport
@onready var _sprite: Sprite3D = $Sprite3D
@onready var _name_label: Label = $SubViewport/Root/VBox/NameLabel
@onready var _shield_label: Label = $SubViewport/Root/VBox/ShieldLabel
@onready var _hp_bar: ProgressBar = $SubViewport/Root/VBox/HPBar
@onready var _resource_bar: ResourceStackBar = $SubViewport/Root/VBox/ResourceBar

var _unit: Unit
var _preview_lock: int = 0
var _preview_commit: int = 0
var _preview_spend: int = 0


func _ready() -> void:
	_sprite.texture = _viewport.get_texture()


func bind(unit: Unit) -> void:
	if _unit:
		if _unit.hp_changed.is_connected(_on_hp_changed):
			_unit.hp_changed.disconnect(_on_hp_changed)
		if _unit.resource_changed.is_connected(_on_resource_changed):
			_unit.resource_changed.disconnect(_on_resource_changed)
		if _unit.status_fx_changed.is_connected(_on_status_fx_changed):
			_unit.status_fx_changed.disconnect(_on_status_fx_changed)
	_unit = unit
	_preview_lock = 0
	_preview_commit = 0
	_preview_spend = 0
	_name_label.text = unit.display_name
	_refresh_hp(unit.current_hp, unit.max_hp)
	_refresh_resource()
	_refresh_shield()
	_apply_hp_bar_color()
	if not unit.hp_changed.is_connected(_on_hp_changed):
		unit.hp_changed.connect(_on_hp_changed)
	if unit.has_resource() and not unit.resource_changed.is_connected(_on_resource_changed):
		unit.resource_changed.connect(_on_resource_changed)
	if not unit.status_fx_changed.is_connected(_on_status_fx_changed):
		unit.status_fx_changed.connect(_on_status_fx_changed)


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


func _on_status_fx_changed(_unit_ref: Unit) -> void:
	_refresh_shield()


func _refresh_hp(current_hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp


func _refresh_resource() -> void:
	if _unit == null or not _unit.has_resource():
		_resource_bar.visible = false
		return
	_resource_bar.visible = true
	_refresh_resource_from_unit()


func _on_resource_changed(
	_unit_ref: Unit,
	_resource_id: BattleEnums.UnitResource,
	_current: int,
	_max_resource: int,
) -> void:
	_refresh_resource_from_unit()


func set_resource_spend_preview(lock_amount: int = 0, commit_amount: int = 0, spend_amount: int = 0) -> void:
	_preview_lock = maxi(0, lock_amount)
	_preview_commit = maxi(0, commit_amount)
	_preview_spend = maxi(0, spend_amount)
	_refresh_resource_from_unit()


func clear_resource_spend_preview() -> void:
	set_resource_spend_preview(0, 0, 0)


func _refresh_resource_from_unit() -> void:
	if _unit == null or not _unit.has_resource():
		_resource_bar.visible = false
		return
	_resource_bar.visible = true
	if _unit.resource_id == BattleEnums.UnitResource.MANA:
		_resource_bar.set_mana(
			_unit.current_resource,
			_unit.get_resource_charging(),
			_unit.get_resource_used(),
			_unit.max_resource,
			_preview_lock,
			_preview_commit,
		)
	else:
		_resource_bar.set_single(
			_unit.current_resource,
			_unit.max_resource,
			_resource_fill_color(_unit.resource_id),
			_preview_spend,
		)


func _refresh_shield() -> void:
	if _shield_label == null:
		return
	if _unit == null:
		_shield_label.visible = false
		return
	var text := ""
	var shield := _unit.get_mana_shield()
	if shield != null and shield.is_shield_up():
		text = shield.get_shield_status_text()
	else:
		var counter = _unit.get_warrior_counter()
		if counter != null and counter.is_counter_up():
			text = counter.get_status_text()
	if text.is_empty():
		_shield_label.visible = false
		return
	_shield_label.text = text
	_shield_label.visible = true


func _apply_hp_bar_color() -> void:
	if _unit == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.7, 1.0) if _unit.is_player() else Color(0.95, 0.35, 0.3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)


func _resource_fill_color(id: BattleEnums.UnitResource) -> Color:
	match id:
		BattleEnums.UnitResource.STAMINA:
			return Color(0.95, 0.75, 0.2)
		BattleEnums.UnitResource.MANA:
			return Color(0.45, 0.55, 0.95)
		BattleEnums.UnitResource.ENERGY:
			return Color(0.35, 0.9, 0.55)
		_:
			return Color(0.75, 0.75, 0.75)
