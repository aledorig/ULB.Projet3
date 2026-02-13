class_name DebugInfo
extends Label

const MAX_FPS_SAMPLES: int = 60

@onready var ship: CharacterBody3D = get_node("/root/TerrainWorld/Executioner")
@onready var terrain_world: Node3D = get_node("/root/TerrainWorld")

var terrain_generator: TerrainGenerator = null
var fps_samples: Array[float] = []
var avg_fps: float = 0.0

func _ready() -> void:
	if ship == null:
		push_error("DebugInfo: Ship not found!")
		return

	if terrain_world == null:
		push_error("DebugInfo: Couldn't get TerrainWorld node")
		return

	terrain_generator = TerrainGenerator.new(terrain_world.p_seed)
	_setup_label_style()

func _setup_label_style() -> void:
	var settings := LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color.WHITE
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	settings.shadow_size = 1
	settings.shadow_color = Color(0, 0, 0, 0.5)
	settings.shadow_offset = Vector2(1, 1)
	label_settings = settings
	position = Vector2(8, 8)

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		visible = not visible

	if Input.is_physical_key_pressed(KEY_P) and Input.is_key_pressed(KEY_SHIFT):
		_print_performance_report()

func _process(delta: float) -> void:
	if ship == null or not visible:
		return

	_update_fps(delta)

	var pos := ship.global_position
	var debug_data := terrain_generator.get_debug_info(pos.x, pos.z)

	var chunk_manager: ChunkManager = terrain_world
	var chunk_pos := chunk_manager.world_to_chunk(pos)
	var chunk_stats := chunk_manager.get_stats()

	text = ""
	text += "Procedural Terrain v0.1\n"
	text += "%d fps (avg %.0f)\n" % [Engine.get_frames_per_second(), avg_fps]
	text += "\n"
	text += "XYZ: %.1f / %.1f / %.1f\n" % [pos.x, pos.y, pos.z]
	text += "Chunk: %d %d, %d L, %d P\n" % [chunk_pos.x, chunk_pos.y, chunk_stats.loaded_chunks, chunk_stats.pending_chunks]
	text += "Speed: %.1f (vel %.1f)\n" % [ship.forward_speed, ship.velocity.length()]
	text += "\n"
	text += "Biome: %s [%s]\n" % [debug_data.biome, debug_data.temp_category]
	text += "Height: %.1f %s\n" % [debug_data.height, "(underwater)" if debug_data.underwater else ""]

func _update_fps(delta: float) -> void:
	fps_samples.append(1.0 / delta)
	if fps_samples.size() > MAX_FPS_SAMPLES:
		fps_samples.pop_front()

	avg_fps = 0.0
	for fps in fps_samples:
		avg_fps += fps
	avg_fps /= fps_samples.size()


func _print_performance_report() -> void:
	print("\n========== PERFORMANCE REPORT ==========")

	var chunk_manager: ChunkManager = terrain_world
	var stats := chunk_manager.get_stats()
	print("[CHUNKS] loaded=%d pending=%d cached=%d unload_queue=%d" % [
		stats.loaded_chunks, stats.pending_chunks, stats.cached_meshes, stats.queued_for_unload
	])

	terrain_generator.biome_manager.print_cache_stats()

	var mem_static := Performance.get_monitor(Performance.MEMORY_STATIC)
	var mem_peak := Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	var obj_count := Performance.get_monitor(Performance.OBJECT_COUNT)
	print("[MEMORY] static=%.1f MB peak=%.1f MB objects=%d" % [
		mem_static / 1048576.0, mem_peak / 1048576.0, obj_count
	])

	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vertices := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("[RENDER] draw_calls=%d primitives=%d" % [draw_calls, vertices])

	print("=========================================\n")
