extends Node

class_name IGameSettings

signal runtime_settings_changed

const DEFAULT_SEED := 732647346203746

# Pre-game settings (set before world loads)
@warning_ignore("shadowed_variable_base_class")
var seed: int = DEFAULT_SEED
var octave: int = 4
var chunk_size: int = 40
var vertex_spacing: float = 3.0
var max_worker_threads: int = 4
var chunks_per_frame: int = 2
var enable_mesh_caching: bool = true
var cache_max_size: int = 256

# Runtime settings (changeable in-game, emit signal)
var render_distance: int = 8:
	set(value):
		render_distance = value
		runtime_settings_changed.emit()

var generation_step: int = ChunkMeshBuilder.STEP_FINAL:
	set(value):
		generation_step = clampi(value, 0, ChunkMeshBuilder.STEP_FINAL)
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
