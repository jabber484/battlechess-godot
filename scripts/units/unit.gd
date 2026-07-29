class_name Unit
extends Node3D

const _DamageContextRes = preload("res://scripts/data/damage_context.gd")
const GridMathScript := preload("res://scripts/util/grid_math.gd")
const WarriorCounterAbilityDataScript := preload("res://scripts/abilities/warrior_counter_ability_data.gd")

signal died(unit: Unit)
signal hp_changed(unit: Unit, current_hp: int, max_hp: int)
signal resource_changed(
	unit: Unit,
	resource_id: BattleEnums.UnitResource,
	current: int,
	max_resource: int,
)
signal status_fx_changed(unit: Unit)
signal ability_log(unit: Unit, message: String)
signal incoming_damage(context)

@export var team: BattleEnums.Team = BattleEnums.Team.PLAYER
@export var display_name: String = "Unit"
@export var speed: int = 5
@export var move_range: int = 4
@export var accuracy: int = 100
@export var damage: int = 25
@export var max_hp: int = 100
@export var max_actions: int = 1
@export var resource_id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE
@export var max_resource: int = 0

var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 100
## Available resource (mana/stamina/…). For mana kits, Charging/Used are separate partitions.
var current_resource: int = 0
var resource_charging: int = 0
var resource_used: int = 0
## How much Used mana clears each turn end (mana kits).
const MANA_USED_RELEASE_PER_TURN: int = 1
var movement_remaining: float = 4.0
var actions_used: int = 0
var death_processed: bool = false
var abilities: Array[AbilityData] = []

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _hud: UnitHUD = $UnitHUD


func _ready() -> void:
	current_hp = max_hp
	current_resource = max_resource if has_resource() else 0
	resource_charging = 0
	resource_used = 0
	movement_remaining = float(move_range)
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
	if stats.has("accuracy"):
		accuracy = stats["accuracy"]
	if stats.has("damage"):
		damage = stats["damage"]
	if stats.has("max_hp"):
		max_hp = stats["max_hp"]
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
	resource_charging = 0
	resource_used = 0
	movement_remaining = float(move_range)
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
	movement_remaining = float(move_range)
	actions_used = 0


func get_actions_remaining() -> int:
	return maxi(0, max_actions - actions_used)


func can_move_more() -> bool:
	return GridMathScript.cost_within_budget(GridMathScript.CARDINAL_COST, movement_remaining)


func spend_movement(cost: float) -> void:
	if cost <= 0.0:
		return
	movement_remaining = maxf(0.0, movement_remaining - cost)


func can_act_more() -> bool:
	return actions_used < max_actions


func has_resource(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> bool:
	if resource_id == BattleEnums.UnitResource.NONE or max_resource <= 0:
		return false
	return id == BattleEnums.UnitResource.NONE or resource_id == id


func get_resource(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> int:
	return current_resource if has_resource(id) else 0


func get_resource_charging() -> int:
	return resource_charging if has_resource() else 0


func get_resource_used() -> int:
	return resource_used if has_resource() else 0


## Free slots under max not held in Available, Charging, or Used.
func get_resource_free_capacity(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> int:
	if not has_resource(id):
		return 0
	return maxi(0, max_resource - current_resource - resource_charging - resource_used)


## Ceiling shown in UI: max minus Used timeout.
func get_resource_effective_max() -> int:
	if not has_resource():
		return 0
	return maxi(0, max_resource - resource_used)


func get_resource_space(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> int:
	return get_resource_free_capacity(id)


func spend_resource(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> bool:
	if amount <= 0:
		return has_resource(id)
	if not has_resource(id) or current_resource < amount:
		return false
	current_resource -= amount
	_emit_resource_changed()
	return true


## Available → Charging (channel lock).
func lock_resource(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> bool:
	if amount <= 0:
		return has_resource(id)
	if not has_resource(id) or current_resource < amount:
		return false
	current_resource -= amount
	resource_charging += amount
	_emit_resource_changed()
	return true


## Charging → Used (fire / block / expire). Ability amount is authoritative.
func commit_resource_to_used(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> bool:
	if amount <= 0:
		return has_resource(id)
	if not has_resource(id):
		return false
	resource_charging = maxi(0, resource_charging - amount)
	resource_used += amount
	_emit_resource_changed()
	return true


## Drop Charging without refunding Available or parking in Used (rare reset paths).
func discard_resource_charging(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> void:
	if amount <= 0 or not has_resource(id):
		return
	var dropped := mini(amount, resource_charging)
	if dropped <= 0:
		return
	resource_charging -= dropped
	_emit_resource_changed()


func release_used_resource(
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
	amount: int = -1,
) -> int:
	if not has_resource(id) or resource_used <= 0:
		return 0
	var release_cap := amount if amount >= 0 else MANA_USED_RELEASE_PER_TURN
	var released := mini(resource_used, release_cap)
	if released <= 0:
		return 0
	resource_used -= released
	_emit_resource_changed()
	return released


## Fill Available into current free capacity (does not touch Charging/Used).
func regen_resource_to_capacity(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> int:
	if not has_resource(id):
		return 0
	var free := get_resource_free_capacity(id)
	if free <= 0:
		return 0
	current_resource += free
	_emit_resource_changed()
	return free


func gain_resource(
	amount: int,
	id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE,
) -> int:
	if amount <= 0 or not has_resource(id):
		return 0
	var space := get_resource_free_capacity(id)
	if space <= 0:
		return 0
	var add := mini(amount, space)
	current_resource += add
	if add > 0:
		_emit_resource_changed()
	return add


func refill_resource(id: BattleEnums.UnitResource = BattleEnums.UnitResource.NONE) -> void:
	if not has_resource(id):
		return
	regen_resource_to_capacity(id)


func _emit_resource_changed() -> void:
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
		# PASSIVE soak kits and ACTION abilities with raised block state (e.g. Mana Shield).
		ability.on_incoming_damage(self, context)


func notify_turn_started() -> void:
	# Mana kits: fill Available into free capacity first (Used still blocks).
	# Channel hooks run next — Shield expire / Bolt sip. Used releases gradually on turn end.
	if resource_id == BattleEnums.UnitResource.MANA:
		regen_resource_to_capacity()
	for ability in abilities:
		if ability == null:
			continue
		# Passives (recharge, etc.) and ACTION kits with per-turn state (e.g. Brawl / channels).
		ability.on_turn_started(self)


## Call when this unit's turn ends — release up to MANA_USED_RELEASE_PER_TURN from Used.
func notify_turn_ended() -> void:
	if resource_id == BattleEnums.UnitResource.MANA:
		release_used_resource()


func notify_foreign_turn_started(starting_unit: Unit) -> void:
	for ability in abilities:
		if ability == null:
			continue
		ability.on_foreign_turn_started(self, starting_unit)


func notify_attacked(
	attacker: Unit,
	hit: bool,
	damage_taken: int,
	hit_chance: int,
	combat_system,
) -> void:
	for ability in abilities:
		if ability == null:
			continue
		ability.on_owner_attacked(self, attacker, hit, damage_taken, hit_chance, combat_system)


func notify_status_fx_changed() -> void:
	status_fx_changed.emit(self)


func get_unit_hud() -> UnitHUD:
	return _hud as UnitHUD


func emit_ability_log(message: String) -> void:
	if message.is_empty():
		return
	ability_log.emit(self, message)


func get_mana_shield() -> WarlockManaShieldAbilityData:
	for ability in abilities:
		if ability is WarlockManaShieldAbilityData:
			return ability as WarlockManaShieldAbilityData
	return null


func get_warrior_counter() -> WarriorCounterAbilityDataScript:
	for ability in abilities:
		if ability is WarriorCounterAbilityDataScript:
			return ability as WarriorCounterAbilityDataScript
	return null


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
