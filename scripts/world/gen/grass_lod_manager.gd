class_name GrassLodManager
extends RefCounted

var _queue: Array[Vector2i] = []

# Background thread for LOD generation (noise is expensive, keep off main thread)
var _lod_thread: Thread = null
var _lod_result_ready: bool = false
var _lod_pending_result: Dictionary = {}  # {chunk_pos, buffer, count, new_lod}


static func get_lod(distance: float) -> int:
	if distance <= 4.0:
		return 0
	elif distance <= 10.0:
		return 1
	else:
		return 2


func rebuild_queue(loaded_chunks: Dictionary, camera_chunk: Vector2i) -> void:
	_queue.clear()
	for chunk_pos: Vector2i in loaded_chunks.keys():
		var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
		if chunk_instance.unload_queued:
			continue
		var distance: float = (chunk_pos - camera_chunk).length()
		var new_lod: int = get_lod(distance)
		if new_lod != chunk_instance.grass_lod:
			_queue.append(chunk_pos)


func process_queue(
	loaded_chunks: Dictionary, camera_chunk: Vector2i,
	_terrain_gen: TerrainGenerator, chunk_size: int, vertex_spacing: float,
	p_seed: int, vegetation_mgr: VegetationManager, _max_updates: int = 1
) -> void:
	# 1. Apply completed result from background thread
	if _lod_result_ready and _lod_thread != null:
		_lod_thread.wait_to_finish()
		_lod_thread = null

		var result: Dictionary = _lod_pending_result
		_lod_pending_result = {}
		_lod_result_ready = false

		if not result.is_empty():
			var chunk_pos: Vector2i = result.chunk_pos
			if loaded_chunks.has(chunk_pos):
				var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
				if not chunk_instance.unload_queued:
					vegetation_mgr.replace_vegetation(chunk_instance, result.buffer, result.count)
					chunk_instance.grass_lod = result.new_lod

	# 2. Submit new work if thread is idle
	if _lod_thread != null:
		return  # still busy

	while not _queue.is_empty():
		var chunk_pos: Vector2i = _queue.pop_front()
		if not loaded_chunks.has(chunk_pos):
			continue

		var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
		if chunk_instance.unload_queued:
			continue

		var distance: float = (chunk_pos - camera_chunk).length()
		var new_lod: int = get_lod(distance)
		if new_lod == chunk_instance.grass_lod:
			continue

		# Start background thread — create own TerrainGenerator for thread safety
		_lod_thread = Thread.new()
		_lod_thread.start(_generate_lod.bind(
			GameSettingsAutoload.seed, GameSettingsAutoload.octave,
			chunk_size, vertex_spacing, p_seed, chunk_pos, new_lod
		))
		break


func _generate_lod(gen_seed: int, octave: int,
		chunk_size: int, vertex_spacing: float,
		p_seed: int, chunk_pos: Vector2i, new_lod: int) -> void:
	# Runs on background thread — own TerrainGenerator, no shared state
	var terrain_gen := TerrainGenerator.new(gen_seed, octave)
	var veg_placer := VegetationPlacer.new(terrain_gen, chunk_size, vertex_spacing, p_seed, chunk_pos)
	var veg_result: Dictionary = veg_placer.generate_vegetation(chunk_pos, new_lod)

	_lod_pending_result = {
		"chunk_pos": chunk_pos,
		"buffer": veg_result.buffer,
		"count": veg_result.count,
		"new_lod": new_lod
	}
	_lod_result_ready = true


func shutdown() -> void:
	if _lod_thread:
		_lod_thread.wait_to_finish()
		_lod_thread = null
