class_name VegetationLodManager
extends RefCounted

var _queue: Array[Vector2i] = []

var _lod_thread: Thread = null
var _lod_result_ready: bool = false
var _lod_pending_result: Dictionary = { }


static func get_grass_lod(distance: float) -> int:
	if distance <= 4.0:
		return 0
	if distance <= 10.0:
		return 1
	return 2


static func get_foliage_lod(distance: float) -> int:
	if distance <= 2.0:
		return 0
	if distance <= 4.0:
		return 1
	return 2


func rebuild_queue(loaded_chunks: Dictionary, camera_chunk: Vector2i) -> void:
	_queue.clear()
	for chunk_pos: Vector2i in loaded_chunks.keys():
		var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
		if chunk_instance.unload_queued:
			continue

		var distance: float = (chunk_pos - camera_chunk).length()
		var new_grass_lod: int = get_grass_lod(distance)
		var new_foliage_lod: int = get_foliage_lod(distance)

		if new_grass_lod != chunk_instance.grass_lod or new_foliage_lod != chunk_instance.foliage_lod:
			_queue.append(chunk_pos)


func process_queue(
		loaded_chunks: Dictionary,
		camera_chunk: Vector2i,
		_terrain_gen: TerrainGenerator,
		chunk_size: int,
		vertex_spacing: float,
		p_seed: int,
		vegetation_mgr: VegetationManager,
		_max_updates: int = 1,
) -> void:
	# apply completed result from background thread
	if _lod_result_ready and _lod_thread != null:
		_lod_thread.wait_to_finish()
		_lod_thread = null

		var result: Dictionary = _lod_pending_result
		_lod_pending_result = { }
		_lod_result_ready = false

		if not result.is_empty():
			var chunk_pos: Vector2i = result.chunk_pos
			if loaded_chunks.has(chunk_pos):
				var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
				if not chunk_instance.unload_queued:
					# apply grass LOD if it changed
					if result.has("grass_buffer"):
						vegetation_mgr.replace_grass(chunk_instance, result.grass_buffer, result.grass_count)
						chunk_instance.grass_lod = result.new_grass_lod

					# apply foliage LOD if it changed
					if result.has("foliage"):
						vegetation_mgr.replace_foliage(chunk_instance, result.foliage)
						chunk_instance.foliage_lod = result.new_foliage_lod

	# submit new work if thread is idle
	if _lod_thread != null:
		return # still busy

	while not _queue.is_empty():
		var chunk_pos: Vector2i = _queue.pop_front()
		if not loaded_chunks.has(chunk_pos):
			continue

		var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
		if chunk_instance.unload_queued:
			continue

		var distance: float = (chunk_pos - camera_chunk).length()
		var new_grass_lod: int = get_grass_lod(distance)
		var new_foliage_lod: int = get_foliage_lod(distance)

		var grass_changed: bool = new_grass_lod != chunk_instance.grass_lod
		var foliage_changed: bool = new_foliage_lod != chunk_instance.foliage_lod

		if not grass_changed and not foliage_changed:
			continue

		_lod_thread = Thread.new()
		_lod_thread.start(
			_generate_lod.bind(
				GameSettingsAutoload.seed,
				GameSettingsAutoload.octave,
				chunk_size,
				vertex_spacing,
				p_seed,
				chunk_pos,
				new_grass_lod,
				chunk_instance.grass_lod,
				grass_changed,
				new_foliage_lod,
				chunk_instance.foliage_lod,
				foliage_changed,
			),
		)
		break


func _generate_lod(
		gen_seed: int,
		octave: int,
		chunk_size: int,
		vertex_spacing: float,
		p_seed: int,
		chunk_pos: Vector2i,
		new_grass_lod: int,
		_old_grass_lod: int,
		grass_changed: bool,
		new_foliage_lod: int,
		_old_foliage_lod: int,
		foliage_changed: bool,
) -> void:
	var terrain_gen := TerrainGenerator.new(gen_seed, octave)
	var veg_placer := VegetationPlacer.new(terrain_gen, chunk_size, vertex_spacing, p_seed, chunk_pos)

	var result := { "chunk_pos": chunk_pos }

	if grass_changed:
		var grass_result: Dictionary = veg_placer.generate_grass_standalone(chunk_pos, new_grass_lod)
		result["grass_buffer"] = grass_result.buffer
		result["grass_count"] = grass_result.count
		result["new_grass_lod"] = new_grass_lod

	if foliage_changed:
		var foliage_result: Dictionary = veg_placer.generate_foliage_standalone(chunk_pos, new_foliage_lod)
		result["foliage"] = foliage_result
		result["new_foliage_lod"] = new_foliage_lod

	_lod_pending_result = result
	_lod_result_ready = true


func shutdown() -> void:
	if _lod_thread:
		_lod_thread.wait_to_finish()
		_lod_thread = null
