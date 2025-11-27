class_name ShipController
extends CharacterBody3D

## 6DOF ship controller with smooth input handling

# ============================================================================
# EXPORTS
# ============================================================================

@export_group("Speed")
@export var max_speed:    float = 50.0
@export var acceleration: float = 0.6

@export_group("Rotation")
@export var pitch_speed: float = 1.5
@export var roll_speed:  float = 1.9
@export var yaw_speed:   float = 1.25

@export_group("Input")
@export var input_response: float = 8.0

# ============================================================================
# STATE
# ============================================================================

var forward_speed: float = 0.0
var pitch_input: float = 0.0
var roll_input: float = 0.0
var yaw_input: float = 0.0

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _get_input(delta: float) -> void:
	# Throttle
	if Input.is_action_pressed("throttle_up"):
		forward_speed = lerp(forward_speed, max_speed, acceleration * delta)
	if Input.is_action_pressed("throttle_down"):
		forward_speed = lerp(forward_speed, 0.0, acceleration * delta)
	
	# Rotation inputs with smoothing
	pitch_input = lerp(pitch_input, Input.get_axis("pitch_up", "pitch_down"), input_response * delta)
	roll_input = lerp(roll_input, Input.get_axis("roll_left", "roll_right"), input_response * delta)
	yaw_input = lerp(yaw_input, Input.get_axis("yaw_left", "yaw_right"), input_response * delta)

# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	_get_input(delta)
	_apply_rotation(delta)
	_apply_movement(delta)


func _apply_rotation(delta: float) -> void:
	transform.basis = transform.basis.rotated(transform.basis.z, roll_input * roll_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.x, pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(transform.basis.y, yaw_input * yaw_speed * delta)
	transform.basis = transform.basis.orthonormalized()


func _apply_movement(delta: float) -> void:
	velocity = transform.basis.z * forward_speed
	move_and_collide(velocity * delta)
