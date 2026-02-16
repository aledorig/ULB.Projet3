extends SpringArm3D

@export var mouse_sensibility: float = 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle : float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle : float = PI/4

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * mouse_sensibility
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)
	
	if event.is_action_pressed("wheel_up") :
		if spring_length >= 4 :
			spring_length -= 1
	if event.is_action_pressed("wheel_down") :
		if spring_length <= 30 :
			spring_length += 1
		
	if event.is_action_pressed("toggle_mouse_capture") :
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED :
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else : 
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
		
