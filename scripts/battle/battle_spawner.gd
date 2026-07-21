class_name BattleSpawner
extends RefCounted

const UnitSpawnData := preload("res://scripts/data/unit_spawn.gd")
const UNIT_SCENE := preload("res://scenes/unit/Unit.tscn")


static func spawn_units(
	spawns: Array[UnitSpawnData],
	parent: Node3D,
	grid_system: GridSystem,
) -> Array[Unit]:
	var units: Array[Unit] = []
	for entry in spawns:
		var unit: Unit = UNIT_SCENE.instantiate()
		parent.add_child(unit)
		unit.setup(entry.team, entry.grid_pos, entry.stats.to_dict())
		grid_system.register_unit(unit)
		units.append(unit)
	return units
