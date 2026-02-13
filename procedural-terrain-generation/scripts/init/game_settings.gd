extends Node
class_name GameSettings

signal runtime_settings_changed

const DEFAULT_SEED := 732647346203746

# Pre-game settings (set before world loads)
var seed: int = DEFAULT_SEED
var octave: int = 4
var biome_size: int = 4
var chunk_size: int = 40
var vertex_spacing: float = 2.0
var max_worker_threads: int = 4
var chunks_per_frame: int = 2
var enable_mesh_caching: bool = true
var cache_max_size: int = 256
var biome_blending: bool = true
var blend_radius: float = 16.0

# Runtime settings (changeable in-game, emit signal)
var render_distance: int = 4:
	set(value):
		render_distance = value
		runtime_settings_changed.emit()

var max_speed: float = 50.0:
	set(value):
		max_speed = value
		runtime_settings_changed.emit()

var acceleration: float = 0.6:
	set(value):
		acceleration = value
		runtime_settings_changed.emit()

var pitch_speed: float = 1.5:
	set(value):
		pitch_speed = value
		runtime_settings_changed.emit()

var roll_speed: float = 1.9:
	set(value):
		roll_speed = value
		runtime_settings_changed.emit()

var yaw_speed: float = 1.25:
	set(value):
		yaw_speed = value
		runtime_settings_changed.emit()


func randomize_seed() -> void:
	seed = randi()
