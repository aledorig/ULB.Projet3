class_name DebugInfo
extends Label

## On-screen debug overlay displaying ship, terrain, and performance info

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_FPS_SAMPLES: int = 60

# ============================================================================
# REFERENCES
# ============================================================================

@onready var ship: CharacterBody3D = get_node("/root/TerrainWorld/Executioner")
@onready var terrain_world: Node3D = get_node("/root/TerrainWorld")

# ============================================================================
# STATE
# ============================================================================

var terrain_generator: TerrainGenerator = null
var fps_samples:       Array[float] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if ship == null:
		push_error("DebugInfo: Ship not found!")
		return
	
	if terrain_world == null:
		push_error("DebugInfo: Couldn't get TerrainWorld node")
		return
	
	terrain_generator = TerrainGenerator.new(terrain_world.p_seed)

# ============================================================================
# INPUT
# ============================================================================

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		visible = not visible

# ============================================================================
# UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if ship == null or not visible:
		return
	
	text = "DEBUG INFO:\n\n"
	text += _format_fps_info(delta)
	text += _format_player_info()
	text += _format_biome_info()

# ============================================================================
# FORMATTING HELPERS
# ============================================================================

func _format_fps_info(delta: float) -> String:
	var current_fps: float = 1.0 / delta
	fps_samples.append(current_fps)
	
	if fps_samples.size() > MAX_FPS_SAMPLES:
		fps_samples.pop_front()
	
	var average_fps: float = 0.0
	for fps in fps_samples:
		average_fps += fps
	average_fps /= fps_samples.size()
	
	var result: String = "FPS Info:\n"
	result += "  Average: %.0f\n" % average_fps
	result += "  Current: %d\n\n" % Engine.get_frames_per_second()
	return result


func _format_player_info() -> String:
	var pos: Vector3 = ship.global_position
	
	var result: String = "Ship Info:\n"
	result += "  Position: (%.1f, %.1f, %.1f)\n" % [pos.x, pos.y, pos.z]
	result += "  Speed: %.1f\n" % ship.forward_speed
	result += "  Velocity: %.1f\n\n" % ship.velocity.length()
	return result


func _format_biome_info() -> String:
	var pos: Vector3 = ship.global_position
	var debug_data: Dictionary = terrain_generator.get_debug_info(pos.x, pos.z)
	
	var result: String = "Biome Info:\n"
	result += "  Height Range: %.0f to %.0f\n" % [TerrainConstants.MIN_HEIGHT, TerrainConstants.MAX_HEIGHT]
	result += "  Terrain Height: %.1f\n" % debug_data.height
	result += "  Underwater: %s\n" % str(debug_data.underwater)
	result += "  Biome: %s\n" % debug_data.biome
	result += "  Temperature: %.2f\n" % debug_data.temperature
	result += "  Moisture: %.2f\n" % debug_data.moisture
	result += "  Continentalness: %.2f\n" % debug_data.continentalness
	return result
