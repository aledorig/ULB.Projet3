extends Label

@onready var main_camera: Camera3D = get_node("/root/TerrainWorld/MainCamera")
@onready var terrain_world = get_node("/root/TerrainWorld")
var camera_position = Vector3()
var fps_samples = []
var max_samples = 60  # Average over 60 frames
var terrain_generator: TerrainGenerator = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if main_camera == null:# or terrain_generator == null:
		push_error("Camera not found!")
		return
	if terrain_world == null:
		push_error("Couldn't get TerrainWorld node")
		return
	#if is_instance_of(terrain_world, ChunkManager):
	terrain_generator = TerrainGenerator.new(terrain_world.p_seed)

func _format_player_info() -> String:
	var retval = "Player info\n"
	camera_position = main_camera.global_position
	retval += "x: " + str(camera_position.x) + "\n"
	retval += "y: " + str(camera_position.y) + "\n"
	retval += "z: " + str(camera_position.z) + "\n\n"
	return retval

func _format_biome_info() -> String:
	var retval = "Biome info: \n"
	retval += "Min Height: " + str(TerrainConstants.MIN_HEIGHT) \
			+ " Max height: " + str(TerrainConstants.MAX_HEIGHT) + "\n"
	camera_position = main_camera.global_position
	var biome_data = terrain_generator.get_biome_data(camera_position.x, camera_position.z)
	retval += "Biome Blended data:\n"
	retval += "\tContinental: " + str(biome_data.continental)
	retval += " | Erosion: " + str(biome_data.erosion)
	retval += " | PV: " + str(biome_data.pv) + "\n"
	retval += "\tPrimary biome: " + TerrainConstants.BIOME_TYPE_STRING[biome_data.primary_biome]
	retval += " | Climate zone: " + TerrainConstants.CLIMATE_ZONE_STRING[biome_data.climate_zone]
	retval += " | Temperature: " + str(biome_data.temperature)
	retval += " | Humidity: " + str(biome_data.humidity)
	
	return retval

func _format_fps_info(delta) -> String:
	var retval = "FPS info :\n"
	var current_fps = 1.0 / delta
	fps_samples.append(current_fps)
	if fps_samples.size() > max_samples:
		fps_samples.pop_front()

	var average_fps = 0.0
	for fps in fps_samples:
		average_fps += fps
	average_fps /= fps_samples.size()
	retval += "average fps: " + str(average_fps) + "\n"
	retval += "current fps: " + str(Engine.get_frames_per_second()) + "\n\n"

	return retval

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		self.visible = not self.visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if main_camera == null:
		return
	if self.visible:
		text = "DEBUG INFO:\n\n"
		text += _format_fps_info(delta)
		text += _format_biome_info()
		text += _format_player_info()
