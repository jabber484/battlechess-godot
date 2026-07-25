class_name GridView
extends Node3D

signal tile_picked(grid_pos: Vector2i)
signal tile_hovered(grid_pos: Vector2i)

@export var grid_system_path: NodePath
@export var camera_path: NodePath

var grid_system: GridSystem
var _camera: Camera3D
var _floor_body: StaticBody3D
var _highlights: Node3D
var _tile_meshes: Dictionary = {} # Vector2i -> MeshInstance3D
var _highlight_meshes: Dictionary = {} # Vector2i -> MeshInstance3D
var _hovered_tile: Vector2i = Vector2i(-1, -1)

const FLOOR_COLOR := Color(0.45, 0.45, 0.48)
const HALF_COVER_COLOR := Color(0.75, 0.6, 0.25)
const FULL_COVER_COLOR := Color(0.35, 0.7, 0.4)
const REACHABLE_COLOR := Color(0.3, 0.55, 0.95, 0.55)
const ATTACKABLE_COLOR := Color(0.95, 0.35, 0.3, 0.55)
const PATH_COLOR := Color(0.35, 0.95, 0.95, 0.7)
const HOVER_COLOR := Color(1.0, 1.0, 0.4, 0.65)


func _ready() -> void:
	grid_system = get_node(grid_system_path) as GridSystem
	var cam_node := get_node_or_null(camera_path)
	if cam_node is Camera3D:
		_camera = cam_node
	elif cam_node != null and cam_node.has_node("Camera3D"):
		_camera = cam_node.get_node("Camera3D") as Camera3D
	_highlights = Node3D.new()
	_highlights.name = "Highlights"
	add_child(_highlights)
	# GridSystem may still be initializing; defer mesh build one frame.
	call_deferred("_deferred_build")


func _deferred_build() -> void:
	_build_visuals()
	_build_floor_collider()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_emit_hover_if_changed(pick_tile_at_mouse())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := pick_tile_at_mouse()
		if GridMath.is_in_bounds(pos):
			tile_picked.emit(pos)
			tile_clicked_forward(pos)


func _emit_hover_if_changed(pos: Vector2i) -> void:
	if pos == _hovered_tile:
		return
	_hovered_tile = pos
	tile_hovered.emit(pos)


func tile_clicked_forward(grid_pos: Vector2i) -> void:
	if grid_system:
		grid_system.tile_clicked.emit(grid_pos)


func pick_tile_at_mouse() -> Vector2i:
	if _camera == null:
		return Vector2i(-1, -1)
	var mouse := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	return GridMath.world_to_grid(hit.position)


func clear_highlights() -> void:
	for mesh in _highlight_meshes.values():
		if is_instance_valid(mesh):
			mesh.queue_free()
	_highlight_meshes.clear()


func show_reachable(tiles: Array[Vector2i]) -> void:
	_show_colored(tiles, REACHABLE_COLOR)


func show_attackable(tiles: Array[Vector2i]) -> void:
	_show_colored(tiles, ATTACKABLE_COLOR)


func show_path(tiles: Array[Vector2i]) -> void:
	_show_colored(tiles, PATH_COLOR)


func show_hover(grid_pos: Vector2i) -> void:
	if not GridMath.is_in_bounds(grid_pos):
		return
	_ensure_highlight(grid_pos, HOVER_COLOR)


func _show_colored(positions: Array[Vector2i], color: Color) -> void:
	for pos in positions:
		_ensure_highlight(pos, color)


func _ensure_highlight(grid_pos: Vector2i, color: Color) -> void:
	var mesh: MeshInstance3D
	if _highlight_meshes.has(grid_pos):
		mesh = _highlight_meshes[grid_pos]
	else:
		mesh = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.05, 0.9)
		mesh.mesh = box
		mesh.position = GridMath.grid_to_world(grid_pos, 0.06)
		_highlights.add_child(mesh)
		_highlight_meshes[grid_pos] = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat


func _build_visuals() -> void:
	for x in GridMath.GRID_SIZE:
		for y in GridMath.GRID_SIZE:
			var pos := Vector2i(x, y)
			var tile := grid_system.get_tile(pos)
			var floor_mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.95, 0.1, 0.95)
			floor_mesh.mesh = box
			floor_mesh.position = GridMath.grid_to_world(pos, 0.0)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = FLOOR_COLOR
			floor_mesh.material_override = mat
			add_child(floor_mesh)
			_tile_meshes[pos] = floor_mesh
			if tile.has_any_cover():
				_spawn_cover(pos, tile)


func _spawn_cover(grid_pos: Vector2i, tile: BattleTile) -> void:
	var thickness := 0.06
	var width := 0.92
	var root := Node3D.new()
	root.name = "Cover_%d_%d" % [grid_pos.x, grid_pos.y]
	root.position = GridMath.grid_to_world(grid_pos, 0.0)
	add_child(root)

	# Thin wall planes on edges that provide cover (N/E/S/W).
	var wall_by_dir: Dictionary = {
		BattleEnums.Direction.NORTH: {"size": Vector3(width, 1.0, thickness), "offset": Vector3(0.0, 0.0, -0.46)},
		BattleEnums.Direction.SOUTH: {"size": Vector3(width, 1.0, thickness), "offset": Vector3(0.0, 0.0, 0.46)},
		BattleEnums.Direction.WEST: {"size": Vector3(thickness, 1.0, width), "offset": Vector3(-0.46, 0.0, 0.0)},
		BattleEnums.Direction.EAST: {"size": Vector3(thickness, 1.0, width), "offset": Vector3(0.46, 0.0, 0.0)},
	}
	for dir in tile.edge_cover.keys():
		var cover: BattleEnums.Cover = tile.edge_cover[dir]
		if cover == BattleEnums.Cover.NONE:
			continue
		var wall: Dictionary = wall_by_dir[dir]
		var h := 0.55 if cover == BattleEnums.Cover.HALF else 1.1
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size: Vector3 = wall["size"]
		box.size = Vector3(size.x, h, size.z)
		mesh.mesh = box
		var offset: Vector3 = wall["offset"]
		mesh.position = offset + Vector3(0.0, h * 0.5 + 0.05, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = HALF_COVER_COLOR if cover == BattleEnums.Cover.HALF else FULL_COVER_COLOR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = mat
		root.add_child(mesh)


func _build_floor_collider() -> void:
	_floor_body = StaticBody3D.new()
	_floor_body.name = "FloorCollider"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var extent := GridMath.GRID_SIZE * GridMath.TILE_SIZE
	box.size = Vector3(extent, 0.1, extent)
	shape.shape = box
	_floor_body.add_child(shape)
	_floor_body.position = Vector3(0, 0, 0)
	add_child(_floor_body)
