class_name MainCamera
extends Camera3D

# ============================================================================
# EXPORTS
# ============================================================================

@export var move_speed:        float = 10.0
@export var sprint_multiplier: float = 2.0
@export var mouse_sensitivity: float = 0.003
@export var smooth_speed:      float = 10.0

# ============================================================================
# MEMBER VARIABLES
# ============================================================================

var velocity:   Vector3 = Vector3.ZERO
var rotation_x: float   = 0.0
var rotation_y: float   = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Capture mouse for looking around
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Init rotation from curr transform
	rotation_y = rotation.y
	rotation_x = rotation.x

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	# Toggle mouse capture with Esc
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -PI/2, PI/2)

# ============================================================================
# CAMERA UPDATE
# ============================================================================

func _process(delta: float) -> void:
	# Apply rotation
	rotation.y = rotation_y
	rotation.x = rotation_x
	
	# Get input direction
	var input_dir = Vector3.ZERO
	
	# WASD and Arrow keys
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	# Up and down movement
	if Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_SHIFT):
		input_dir.y -= 1
	
	# Normalize to prevent faster diagonal movement
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	
	# Apply sprint
	var current_speed = move_speed
	if Input.is_key_pressed(KEY_CTRL):
		current_speed *= sprint_multiplier
	
	# Transform direction to camera's local space
	var direction = transform.basis * input_dir
	
	# Smooth movement
	velocity = velocity.lerp(direction * current_speed, smooth_speed * delta)
	
	# Move camera
	position += velocity * delta
