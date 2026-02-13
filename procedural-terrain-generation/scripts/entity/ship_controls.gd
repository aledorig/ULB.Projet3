class_name ShipController
extends CharacterBody3D

var input_response: float = 8.0
var forward_speed: float = 0.0
var pitch_input: float = 0.0
var roll_input: float = 0.0
var yaw_input: float = 0.0

func _ready() -> void:
	var chunk_manager: ChunkManager = get_node("/root/TerrainWorld")
	if chunk_manager:
		if not chunk_manager.is_node_ready():
			await chunk_manager.ready

		var terrain_height: float = chunk_manager.debug_terrain_generator.get_height(global_position.x, global_position.z)
		global_position.y = terrain_height + 10.0

	GameSettingsAutoload.runtime_settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	pass

func _get_input(delta: float) -> void:
	var max_speed := GameSettingsAutoload.max_speed
	var acceleration := GameSettingsAutoload.acceleration

	if Input.is_action_pressed("throttle_up"):
		forward_speed = lerp(forward_speed, max_speed, acceleration * delta)
	if Input.is_action_pressed("throttle_down"):
		forward_speed = lerp(forward_speed, 0.0, acceleration * delta)

	pitch_input = lerp(pitch_input, Input.get_axis("pitch_up", "pitch_down"), input_response * delta)
	roll_input = lerp(roll_input, Input.get_axis("roll_left", "roll_right"), input_response * delta)
	yaw_input = lerp(yaw_input, Input.get_axis("yaw_left", "yaw_right"), input_response * delta)

func _physics_process(delta: float) -> void:
	_get_input(delta)
	_apply_rotation(delta)
	_apply_movement(delta)


func _apply_rotation(delta: float) -> void:
	transform.basis = transform.basis.rotated(transform.basis.z, roll_input * GameSettingsAutoload.roll_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * GameSettingsAutoload.pitch_speed * delta)
	transform.basis = transform.basis.rotated(-transform.basis.y, yaw_input * GameSettingsAutoload.yaw_speed * delta)
	transform.basis = transform.basis.orthonormalized()


func _apply_movement(delta: float) -> void:
	velocity = transform.basis.z * forward_speed
	move_and_collide(velocity * delta)
