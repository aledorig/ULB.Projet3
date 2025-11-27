extends Label

@onready var ship: CharacterBody3D = get_node("/root/TerrainWorld/Executioner")
@onready var terrain_world = get_node("/root/TerrainWorld")
var ship_position = Vector3()
var fps_samples = []
var max_samples = 60  # Average over 60 frames
var terrain_generator: TerrainGenerator = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ship == null:
		push_error("Ship not found!")
		return
	if terrain_world == null:
		push_error("Couldn't get TerrainWorld node")
		return
	terrain_generator = TerrainGenerator.new(terrain_world.p_seed)

func _format_player_info() -> String:
	var retval = "Ship Info\n"
	ship_position = ship.global_position
	retval += "Position: (%.1f, %.1f, %.1f)\n" % [ship_position.x, ship_position.y, ship_position.z]
	retval += "Speed: %.1f\n" % ship.forward_speed
	retval += "Velocity: %.1f\n\n" % ship.velocity.length()
	return retval

func _format_biome_info() -> String:
	var retval = "Biome info: \n"
	retval += "Min Height: " + str(TerrainConstants.MIN_HEIGHT) \
			+ " Max height: " + str(TerrainConstants.MAX_HEIGHT) + "\n"
	ship_position = ship.global_position
	var biome_data = terrain_generator.get_biome_data(ship_position.x, ship_position.z)
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
	var retval = "FPS info:\n"
	var current_fps = 1.0 / delta
	fps_samples.append(current_fps)
	if fps_samples.size() > max_samples:
		fps_samples.pop_front()

	var average_fps = 0.0
	for fps in fps_samples:
		average_fps += fps
	average_fps /= fps_samples.size()
	retval += "Average FPS: %.0f\n" % average_fps
	retval += "Current FPS: %d\n\n" % Engine.get_frames_per_second()

	return retval

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		self.visible = not self.visible

func _process(delta: float) -> void:
	if ship == null:
		return
	if self.visible:
		text = "DEBUG INFO:\n\n"
		text += _format_fps_info(delta)
		text += _format_player_info()
		text += _format_biome_info()
