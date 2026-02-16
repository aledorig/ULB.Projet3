extends SpringArm3D

@export var mouse_sensibility: float = 0.005
@export var camera_lerp_speed: float = 3.0
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = PI/4

var _idle_timer: float = 0.0
var _returning: bool = false
var _camera: Camera3D = null
var _target: Node3D = null

const IDLE_DELAY: float = 1.0
const RETURN_SPEED: float = 3.0
const DEFAULT_PITCH: float = 0.0
const DEFAULT_YAW: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera = get_node_or_null("MainCamera") as Camera3D
	_target = get_parent() as Node3D


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_idle_timer = 0.0
		_returning = false
		rotation.y -= event.relative.x * mouse_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * mouse_sensibility
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)

	if event.is_action_pressed("wheel_up"):
		if spring_length >= 4:
			spring_length -= 1

	if event.is_action_pressed("wheel_down"):
		if spring_length <= 30:
			spring_length += 1

	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	_idle_timer += delta
	if _idle_timer >= IDLE_DELAY:
		_returning = true

	if _returning:
		rotation.x = lerp(rotation.x, DEFAULT_PITCH, RETURN_SPEED * delta)
		rotation.y = lerp_angle(rotation.y, DEFAULT_YAW, RETURN_SPEED * delta)


func _physics_process(delta: float) -> void:
	if not _camera or not _target:
		return

	var new_basis := _camera.global_transform.looking_at(_target.global_transform.origin, _target.transform.basis.y)
	_camera.global_transform = _camera.global_transform.interpolate_with(new_basis, camera_lerp_speed * delta)
