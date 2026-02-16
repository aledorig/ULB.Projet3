class_name GrassLodManager
extends RefCounted

var _queue: Array[Vector2i] = []


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
	terrain_gen: TerrainGenerator, chunk_size: int, vertex_spacing: float,
	p_seed: int, vegetation_mgr: VegetationManager, max_updates: int = 2
) -> void:
	var updates: int = 0
	while not _queue.is_empty() and updates < max_updates:
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

		var veg_placer := VegetationPlacer.new(terrain_gen, chunk_size, vertex_spacing, p_seed, chunk_pos)
		var veg_result: Dictionary = veg_placer.generate_vegetation(chunk_pos, new_lod)

		vegetation_mgr.replace_vegetation(chunk_instance, veg_result.transforms, veg_result.custom_data, veg_result.count)
		chunk_instance.grass_lod = new_lod
		updates += 1
