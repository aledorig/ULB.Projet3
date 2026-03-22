class_name TerrainLodManager
extends RefCounted

var _queue: Array[Vector2i] = []

var _lod_thread: Thread = null
var _lod_result_ready: bool = false
var _lod_pending_result: Dictionary = { }


static func get_mesh_lod(distance: float) -> int:
	if distance <= 3.0:
		return 0
	if distance <= 6.0:
		return 1
	return 2


static func get_mesh_size(mesh_lod: int) -> int:
	return TerrainConfig.MESH_LOD_SIZES[clampi(mesh_lod, 0, TerrainConfig.MESH_LOD_SIZES.size() - 1)]


static func get_max_octaves(mesh_lod: int) -> int:
	return TerrainConfig.MESH_LOD_OCTAVES[clampi(mesh_lod, 0, TerrainConfig.MESH_LOD_OCTAVES.size() - 1)]


func rebuild_queue(loaded_chunks: Dictionary, camera_chunk: Vector2i) -> void:
	if GameSettingsAutoload.generation_step < ChunkMeshBuilder.STEP_FINAL:
		return # step mode active, skip LOD transitions

	_queue.clear()

	for chunk_pos: Vector2i in loaded_chunks.keys():
		var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
		if chunk_instance.unload_queued:
			continue
		var distance: float = (chunk_pos - camera_chunk).length()
		var new_mesh_lod: int = get_mesh_lod(distance)
		if new_mesh_lod != chunk_instance.mesh_lod:
			_queue.append(chunk_pos)


func process_queue(
		loaded_chunks: Dictionary,
		camera_chunk: Vector2i,
		chunk_size: int,
		vertex_spacing: float,
		terrain_material: ShaderMaterial,
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
					# swap mesh atomically
					var new_mesh: ArrayMesh = result.mesh_data

					if new_mesh.get_surface_count() > 0:
						new_mesh.surface_set_material(0, terrain_material)
					chunk_instance.mesh_node.mesh = new_mesh

					# if collision existed on old mesh, remove and let it be recreated
					if chunk_instance.has_collision:
						_remove_collision(chunk_instance)

					chunk_instance.mesh_lod = result.new_mesh_lod

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
		var new_mesh_lod: int = get_mesh_lod(distance)

		if new_mesh_lod == chunk_instance.mesh_lod:
			continue

		# start background thread
		_lod_thread = Thread.new()
		_lod_thread.start(
			_regenerate_mesh.bind(
				GameSettingsAutoload.seed,
				GameSettingsAutoload.octave,
				chunk_size,
				vertex_spacing,
				chunk_pos,
				new_mesh_lod,
			),
		)
		break


func _regenerate_mesh(
		gen_seed: int,
		octave: int,
		chunk_size: int,
		vertex_spacing: float,
		chunk_pos: Vector2i,
		new_mesh_lod: int,
) -> void:
	var terrain_gen := TerrainGenerator.new(gen_seed, octave)
	var lod_mesh_size: int = get_mesh_size(new_mesh_lod)
	var mesh_builder := ChunkMeshBuilder.new(chunk_size, vertex_spacing, terrain_gen, lod_mesh_size)
	var mesh: ArrayMesh = mesh_builder.build_chunk_mesh(chunk_pos)

	_lod_pending_result = {
		"chunk_pos": chunk_pos,
		"mesh_data": mesh,
		"new_mesh_lod": new_mesh_lod,
	}
	_lod_result_ready = true


func _remove_collision(chunk_instance: ChunkInstance) -> void:
	# remove old StaticBody3D so it can be recreated from the new mesh
	for child in chunk_instance.node.get_children():
		if child is StaticBody3D:
			child.queue_free()
	chunk_instance.has_collision = false


func shutdown() -> void:
	if _lod_thread:
		_lod_thread.wait_to_finish()
		_lod_thread = null
