class_name Unit
extends Node3D

const _DamageContextRes = preload("res://scripts/data/damage_context.gd")

signal died(unit: Unit)
signal hp_changed(unit: Unit, current_hp: int, max_hp: int)
signal resource_changed(
	unit: Unit,
	resource_id: BattleEnums.UnitResource,
	current: int,
	max_resource: int,
)
signal incoming_damage(context)

@export var team: BattleEnums.Team = BattleEnums.Team.PLAYER
@export var display_name: String = "Unit"
@export var speed: int = 5
@export var move_range: int = 4
@export var attack_range: int = 5
@export var accuracy: int = 80
@export var damage: int = 25
@export var max_hp: int = 100
@export var max_moves: int = 1
@export var max_actions: int = 1
@export var resource_id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE
@export var max_resource: int = 0

var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 100
var current_resource: int = 0
var moves_used: int = 0
var actions_used: int = 0
var death_processed: bool = false
var abilities: Array[AbilityData] = []

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _hud: UnitHUD = $UnitHUD


func _ready() -> void:
	current_hp = max_hp
	current_resource = max_resource if has_resource() else 0
	_apply_team_color()
	_update_world_position()
	_refresh_hud()


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
	if stats.has("max_moves"):
		max_moves = stats["max_moves"]
	if stats.has("max_actions"):
		max_actions = stats["max_actions"]
	if stats.has("resource_id"):
		resource_id = stats["resource_id"] as BattleEnums.UnitResource
	if stats.has("max_resource"):
		max_resource = int(stats["max_resource"])
	if stats.has("abilities"):
		abilities.clear()
		for ability in stats["abilities"]:
			if ability is AbilityData:
				abilities.append((ability as AbilityData).duplicate(true) as AbilityData)
	current_hp = max_hp
	current_resource = max_resource if has_resource() else 0
	_apply_team_color()
	_update_world_position()
	_refresh_hud()


func get_ability(ability_id: StringName) -> AbilityData:
	for ability in abilities:
		if ability and ability.id == ability_id:
			return ability
	return null


func get_abilities_by_category(category: BattleEnums.AbilityCategory) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability in abilities:
		if ability and ability.category == category:
			result.append(ability)
	return result


func get_move_ability() -> AbilityData:
	var move_abilities := get_abilities_by_category(BattleEnums.AbilityCategory.MOVE)
	if move_abilities.is_empty():
		return null
	return move_abilities[0]


func resolve_ability(
	category: BattleEnums.AbilityCategory,
	target_pos: Vector2i,
	ctx: AbilityContext,
) -> AbilityData:
	for ability in get_abilities_by_category(category):
		if ability.can_activate(self, ctx) and ability.is_valid_target(self, target_pos, ctx):
			return ability
	return null


func _refresh_hud() -> void:
	if _hud:
		_hud.bind(self)


func is_player() -> bool:
	return team == BattleEnums.Team.PLAYER


func is_enemy() -> bool:
	return team == BattleEnums.Team.ENEMY


func is_dead() -> bool:
	return current_hp <= 0


func is_alive() -> bool:
	return not is_dead() and not death_processed


func reset_turn_flags() -> void:
	moves_used = 0
	actions_used = 0


func get_moves_remaining() -> int:
	return maxi(0, max_moves - moves_used)


func get_actions_remaining() -> int:
	return maxi(0, max_actions - actions_used)


func can_move_more() -> bool:
	return moves_used < max_moves


func can_act_more() -> bool:
	return actions_used < max_actions


func has_resource(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> bool:
	if resource_id == BattleEnums.UnitResource.NONE or max_resource <= 0:
		return false
	return id == BattleEnums.UnitResource.NONE or resource_id == id


func get_resource(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> int:
	return current_resource if has_resource(id) else 0


func get_resource_space(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> int:
	if not has_resource(id):
		return 0
	return maxi(0, max_resource - current_resource)


func spend_resource(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> bool:
	if amount <= 0:
		return has_resource(id)
	if not has_resource(id) or current_resource < amount:
		return false
	current_resource -= amount
	resource_changed.emit(self, resource_id, current_resource, max_resource)
	return true


func gain_resource(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> int:
	if amount <= 0 or not has_resource(id):
		return 0
	var before := current_resource
	current_resource = mini(max_resource, current_resource + amount)
	var gained := current_resource - before
	if gained > 0:
		resource_changed.emit(self, resource_id, current_resource, max_resource)
	return gained


func refill_resource(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> void:
	if not has_resource(id):
		return
	if current_resource == max_resource:
		return
	current_resource = max_resource
	resource_changed.emit(self, resource_id, current_resource, max_resource)


func emit_death() -> void:
	if death_processed:
		return
	death_processed = true
	died.emit(self)


func take_damage(amount: int, attacker: Unit = null) -> int:
	return receive_damage(amount, attacker)


func receive_damage(amount: int, attacker: Unit = null) -> int:
	if is_dead() or death_processed:
		return 0
	var ctx: RefCounted = _build_damage_context(amount, attacker)
	modify_incoming_damage(ctx)
	incoming_damage.emit(ctx)
	var applied := maxi(0, ctx.final_damage)
	if applied <= 0:
		return 0
	current_hp = maxi(0, current_hp - applied)
	hp_changed.emit(self, current_hp, max_hp)
	if _hud:
		_hud.show_damage(applied)
	return applied


func modify_incoming_damage(context) -> void:
	for ability in abilities:
		if ability == null:
			continue
		if ability.category != BattleEnums.AbilityCategory.PASSIVE:
			continue
		ability.on_incoming_damage(self, context)


func _build_damage_context(amount: int, attacker: Unit) -> RefCounted:
	var ctx: RefCounted = _DamageContextRes.new()
	ctx.attacker = attacker
	ctx.defender = self
	ctx.raw_damage = amount
	ctx.final_damage = amount
	return ctx


func show_miss_float() -> void:
	if _hud:
		_hud.show_miss()


func set_grid_pos(pos: Vector2i, update_visual: bool = true) -> void:
	grid_pos = pos
	if update_visual:
		_update_world_position()


func _update_world_position() -> void:
	global_position = GridMath.grid_to_world(grid_pos, 0.5)


func _apply_team_color() -> void:
	if _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.45, 0.95) if is_player() else Color(0.9, 0.25, 0.25)
	_mesh.material_override = mat
