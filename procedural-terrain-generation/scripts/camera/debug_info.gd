extends Label

@onready var main_camera: Camera3D = get_node("/root/TerrainWorld/MainCamera")
var camera_position = Vector3()
var fps_samples = []
var max_samples = 60  # Average over 60 frames

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if main_camera == null:
		push_error("Camera not found!")
		return
	camera_position = main_camera.global_position
	self.text += "x: " + str(camera_position.x) + "\n"
	self.text += "y: " + str(camera_position.y) + "\n"
	self.text += "z: " + str(camera_position.z) + "\n"

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		self.visible = not self.visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if main_camera == null:
		return
	if self.visible:
		var current_fps = 1.0 / delta
		fps_samples.append(current_fps)
		if fps_samples.size() > max_samples:
			fps_samples.pop_front()

		var average_fps = 0.0
		for fps in fps_samples:
			average_fps += fps
		average_fps /= fps_samples.size()

		camera_position = main_camera.global_position
		self.text = "DEBUG INFO:\n"
		self.text += "x: " + str(camera_position.x) + "\n"
		self.text += "y: " + str(camera_position.y) + "\n"
		self.text += "z: " + str(camera_position.z) + "\n"
		self.text += "average fps: " + str(average_fps) + "\n"
		self.text += "current fps: " + str(Engine.get_frames_per_second()) + "\n"
