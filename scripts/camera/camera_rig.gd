class_name CameraRig
extends Node3D

@export var move_speed: float = 8.0
@export var rotate_speed: float = 1.8
@export var focus_height: float = 8.0
@export var focus_distance: float = 12.0
@export var focus_lerp_speed: float = 6.0

@onready var camera: Camera3D = $Camera3D

var _yaw: float = 0.785398 # 45 deg
var _pitch: float = -0.9
var _target_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_target_position = global_position
	_apply_camera_transform()


func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("camera_pan_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("camera_pan_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("camera_pan_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("camera_pan_back"):
		input_dir.z += 1.0
	if input_dir != Vector3.ZERO:
		var basis_y := Basis(Vector3.UP, _yaw)
		var world_dir := (basis_y * input_dir).normalized()
		global_position += world_dir * move_speed * delta
		_target_position = global_position

	if Input.is_action_pressed("camera_rotate_left"):
		_yaw += rotate_speed * delta
		_apply_camera_transform()
	if Input.is_action_pressed("camera_rotate_right"):
		_yaw -= rotate_speed * delta
		_apply_camera_transform()

	global_position = global_position.lerp(
		_target_position,
		1.0 - exp(-focus_lerp_speed * delta),
	)


func focus_on(world_pos: Vector3) -> void:
	_target_position = Vector3(world_pos.x, 0.0, world_pos.z)
	_apply_camera_transform()


func _apply_camera_transform() -> void:
	if camera == null:
		return
	var offset := Vector3(
		sin(_yaw) * cos(_pitch),
		-sin(_pitch),
		cos(_yaw) * cos(_pitch)
	) * focus_distance
	camera.position = Vector3(0, focus_height * 0.15, 0) + offset
	camera.look_at(global_position + Vector3(0, 0.5, 0), Vector3.UP)
