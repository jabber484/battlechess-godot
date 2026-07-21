class_name Unit
extends Node3D

signal died(unit: Unit)
signal hp_changed(unit: Unit, current_hp: int, max_hp: int)

@export var team: BattleEnums.Team = BattleEnums.Team.PLAYER
@export var display_name: String = "Unit"
@export var speed: int = 5
@export var move_range: int = 4
@export var attack_range: int = 5
@export var accuracy: int = 80
@export var damage: int = 25
@export var max_hp: int = 100

var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 100
var has_moved: bool = false
var has_acted: bool = false

@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	current_hp = max_hp
	_apply_team_color()
	_update_world_position()


func setup(p_team: BattleEnums.Team, p_pos: Vector2i, stats: Dictionary = {}) -> void:
	team = p_team
	grid_pos = p_pos
	if stats.has("display_name"):
		display_name = stats["display_name"]
	if stats.has("speed"):
		speed = stats["speed"]
	if stats.has("move_range"):
		move_range = stats["move_range"]
	if stats.has("attack_range"):
		attack_range = stats["attack_range"]
	if stats.has("accuracy"):
		accuracy = stats["accuracy"]
	if stats.has("damage"):
		damage = stats["damage"]
	if stats.has("max_hp"):
		max_hp = stats["max_hp"]
	current_hp = max_hp
	_apply_team_color()
	_update_world_position()


func is_player() -> bool:
	return team == BattleEnums.Team.PLAYER


func is_enemy() -> bool:
	return team == BattleEnums.Team.ENEMY


func is_dead() -> bool:
	return current_hp <= 0


func is_alive() -> bool:
	return not is_dead()


func reset_turn_flags() -> void:
	has_moved = false
	has_acted = false


func take_damage(amount: int) -> void:
	if is_dead():
		return
	current_hp = maxi(0, current_hp - amount)
	hp_changed.emit(self, current_hp, max_hp)
	if is_dead():
		died.emit(self)
		visible = false


func set_grid_pos(pos: Vector2i) -> void:
	grid_pos = pos
	_update_world_position()


func _update_world_position() -> void:
	global_position = GridMath.grid_to_world(grid_pos, 0.5)


func _apply_team_color() -> void:
	if _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.45, 0.95) if is_player() else Color(0.9, 0.25, 0.25)
	_mesh.material_override = mat
