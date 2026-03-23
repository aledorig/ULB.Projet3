extends Node3D

@export var mouse_sensitivity: float = 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI / 2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = PI / 4

var _target_yaw: float = PI
var _target_pitch: float = -0.15
var _distance: float = 15.0
var _min_distance: float = 4.0
var _max_distance: float = 30.0
var _idle_timer: float = 0.0
var _returning: bool = false
var _camera: Camera3D = null

# Ship turn lag
var _ship_yaw_offset: float = 0.0
var _last_parent_yaw: float = 0.0

const IDLE_DELAY: float = 20.0
const RETURN_SPEED: float = 3.0
const SHIP_LAG_SPEED: float = 4.0
const DEFAULT_PITCH: float = -0.15
const DEFAULT_YAW: float = PI


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera = get_node_or_null("MainCamera") as Camera3D
	var parent = get_parent() as Node3D
	if parent:
		_last_parent_yaw = parent.global_rotation.y


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_idle_timer = 0.0
		_returning = false
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_yaw = wrapf(_target_yaw, 0.0, TAU)
		_target_pitch -= event.relative.y * mouse_sensitivity
		_target_pitch = clamp(_target_pitch, min_vertical_angle, max_vertical_angle)

	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance -= 1.0
			_distance = max(_distance, _min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance += 1.0
			_distance = min(_distance, _max_distance)

	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	# Ship turn lag — compensate for parent rotation change, then decay
	var parent = get_parent() as Node3D
	if parent:
		var parent_yaw: float = parent.global_rotation.y
		var yaw_delta: float = angle_difference(_last_parent_yaw, parent_yaw)
		_last_parent_yaw = parent_yaw
		_ship_yaw_offset -= yaw_delta
	_ship_yaw_offset = lerp(_ship_yaw_offset, 0.0, SHIP_LAG_SPEED * delta)

	# Idle return — smooth lerp back to behind ship
	_idle_timer += delta
	if _idle_timer >= IDLE_DELAY:
		_returning = true

	if _returning:
		_target_pitch = lerp(_target_pitch, DEFAULT_PITCH, RETURN_SPEED * delta)
		_target_yaw = lerp_angle(_target_yaw, DEFAULT_YAW, RETURN_SPEED * delta)

	# Apply — mouse input is direct, ship lag and idle return are lerped
	rotation = Vector3(_target_pitch, _target_yaw + _ship_yaw_offset, 0.0)

	if _camera:
		_camera.position = Vector3(0.0, 2.0, _distance)
