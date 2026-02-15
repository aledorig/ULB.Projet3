class_name ChunkManager
extends Node3D

signal initial_chunks_ready

@export var chunk_scene: PackedScene

# Settings
var chunk_size:             int = 40
var vertex_spacing:         float = 2.0
var render_distance:        int = 8
var unload_distance:        int = 16
var max_worker_threads:     int = 4
var chunks_per_frame:       int = 4
var enable_mesh_caching:    bool = true
var cache_max_size:         int = 256
var unload_chunks_per_tick: int = 8

var p_seed:                  int = 0
var debug_terrain_generator: TerrainGenerator = null
var _initial_load_done:      bool = false

# Chunk tracking
var loaded_chunks:  Dictionary = {}
var pending_chunks: Dictionary = {}
var chunks_queued_for_unload: Dictionary = {}

# Subsystems
var thread_pool:    ChunkThreadPool
var vegetation_mgr: VegetationManager

# Mesh caching
var mesh_cache:         Dictionary = {}
var cache_access_order: Array[Vector2i] = []

var camera:           Camera3D
var material_manager: TerrainMaterialManager
var terrain_material: ShaderMaterial

var chunks_generated_this_frame: int = 0
var last_camera_chunk:           Vector2i = Vector2i.ZERO


func _ready() -> void:
	p_seed = GameSettingsAutoload.seed
	chunk_size          = GameSettingsAutoload.chunk_size
	vertex_spacing      = GameSettingsAutoload.vertex_spacing
	max_worker_threads  = GameSettingsAutoload.max_worker_threads
	render_distance     = GameSettingsAutoload.render_distance
	unload_distance     = render_distance * 2
	chunks_per_frame    = GameSettingsAutoload.chunks_per_frame
	enable_mesh_caching = GameSettingsAutoload.enable_mesh_caching
	cache_max_size      = GameSettingsAutoload.cache_max_size

	_initialize_systems()

	thread_pool = ChunkThreadPool.new()
	thread_pool.start(max_worker_threads, _generate_chunk_data)

	vegetation_mgr = VegetationManager.new()

	GameSettingsAutoload.runtime_settings_changed.connect(_on_settings_changed)
	update_chunks(true)


func _initialize_systems() -> void:
	camera = get_node_or_null("/root/TerrainWorld/MainCamera")
	if not camera:
		camera = get_viewport().get_camera_3d()

	if not camera:
		push_error("ChunkManager: No camera found!")
		return

	material_manager = TerrainMaterialManager.new()
	terrain_material = material_manager.create_terrain_material()

	if not p_seed:
		p_seed = randi()

	debug_terrain_generator = TerrainGenerator.new(p_seed, GameSettingsAutoload.octave)

	# Pre-build index buffer
	ChunkMeshBuilder._get_or_build_index_buffer(chunk_size, ChunkMeshBuilder.OVERLAP)

	print("ChunkManager: Initialized with %d worker threads" % max_worker_threads)


func _process(_delta: float) -> void:
	chunks_generated_this_frame = 0
	_process_completed_chunks()
	update_chunks(false)
	_process_unload_queue()

	if not _initial_load_done and pending_chunks.is_empty() and not loaded_chunks.is_empty():
		_initial_load_done = true
		initial_chunks_ready.emit()


static func _get_grass_lod(distance: float) -> int:
	if distance <= 4.0:
		return 0
	elif distance <= 10.0:
		return 1
	else:
		return 2


func update_chunks(force_update: bool = false) -> void:
	if not camera:
		return

	var camera_chunk = world_to_chunk(camera.global_position)

	if not force_update and camera_chunk == last_camera_chunk:
		return

	last_camera_chunk = camera_chunk

	var chunks_to_keep: Dictionary = {}

	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var chunk_pos = camera_chunk + Vector2i(x, z)
			var distance = Vector2(x, z).length()

			if distance > render_distance + 0.5:
				continue

			chunks_to_keep[chunk_pos] = true

			if not is_chunk_loaded(chunk_pos) and not is_chunk_pending(chunk_pos):
				var request = ChunkRequest.new(chunk_pos, distance, _get_grass_lod(distance))
				pending_chunks[chunk_pos] = request
				thread_pool.submit(request)

	_mark_distant_chunks_for_unload(chunks_to_keep)


func _generate_chunk_data(request: ChunkRequest) -> ChunkResult:
	var result = ChunkResult.new(request.chunk_pos)
	var start_time = Time.get_ticks_usec()

	var terrain_gen = TerrainGenerator.new(GameSettingsAutoload.seed, GameSettingsAutoload.octave)

	# Mesh (use cache if available)
	if enable_mesh_caching and mesh_cache.has(request.chunk_pos):
		result.mesh_data = mesh_cache[request.chunk_pos]
	else:
		var mesh_builder = ChunkMeshBuilder.new(chunk_size, vertex_spacing, terrain_gen)
		result.mesh_data = mesh_builder.build_chunk_mesh(request.chunk_pos)

	result.success = true

	# Vegetation (thread-safe, no scene tree access)
	var veg_placer = VegetationPlacer.new(terrain_gen, chunk_size, vertex_spacing, p_seed, request.chunk_pos)
	var veg_result: Dictionary = veg_placer.generate_vegetation(request.chunk_pos, request.grass_lod)
	result.vegetation_data = veg_result.transforms
	result.vegetation_custom_data = veg_result.custom_data
	result.vegetation_count = veg_result.count

	var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
	result.generation_time_ms = elapsed_ms

	if elapsed_ms > 100:
		print("[CHUNK] %v generated in %.1f ms (SLOW)" % [request.chunk_pos, elapsed_ms])

	return result


func _process_completed_chunks() -> void:
	var results: Array[ChunkResult] = thread_pool.get_completed()

	for result in results:
		if chunks_generated_this_frame >= chunks_per_frame:
			thread_pool.requeue(result)
			continue

		if result.success:
			_instantiate_chunk(result)

			if enable_mesh_caching and not mesh_cache.has(result.chunk_pos):
				_cache_mesh(result.chunk_pos, result.mesh_data)

			chunks_generated_this_frame += 1
		else:
			push_error("Failed to generate chunk %v: %s" % [result.chunk_pos, result.error_message])

		pending_chunks.erase(result.chunk_pos)


func _instantiate_chunk(result: ChunkResult) -> void:
	if loaded_chunks.has(result.chunk_pos):
		return

	var chunk_node: Node3D
	if chunk_scene:
		chunk_node = chunk_scene.instantiate()
	else:
		chunk_node = Node3D.new()

	add_child(chunk_node)

	var mesh_instance = _find_or_create_mesh_instance(chunk_node)

	mesh_instance.mesh = result.mesh_data
	if result.mesh_data.get_surface_count() > 0:
		result.mesh_data.surface_set_material(0, terrain_material)

	# Collision
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = result.mesh_data.create_trimesh_shape()
	static_body.add_child(collision_shape)
	chunk_node.add_child(static_body)

	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	chunk_node.position = Vector3(
		result.chunk_pos.x * chunk_world_size,
		0,
		result.chunk_pos.y * chunk_world_size
	)

	var chunk_instance = ChunkInstance.new(chunk_node, mesh_instance, result.chunk_pos)

	# Add vegetation via manager
	chunk_instance.grass_instance = vegetation_mgr.create_vegetation(chunk_node, result)

	loaded_chunks[result.chunk_pos] = chunk_instance


func _cache_mesh(chunk_pos: Vector2i, mesh: ArrayMesh) -> void:
	if mesh_cache.size() >= cache_max_size:
		var oldest = cache_access_order.pop_front()
		mesh_cache.erase(oldest)

	mesh_cache[chunk_pos] = mesh
	cache_access_order.append(chunk_pos)


func _mark_distant_chunks_for_unload(chunks_to_keep: Dictionary) -> void:
	for chunk_pos in loaded_chunks.keys():
		if not chunks_to_keep.has(chunk_pos):
			var distance = (chunk_pos - last_camera_chunk).length()
			if distance > unload_distance:
				_queue_chunk_for_unload(chunk_pos)


func _queue_chunk_for_unload(chunk_pos: Vector2i) -> void:
	if not loaded_chunks.has(chunk_pos):
		return

	var chunk_instance = loaded_chunks[chunk_pos]
	if chunk_instance.unload_queued:
		return

	chunk_instance.unload_queued = true
	chunks_queued_for_unload[chunk_pos] = true


func _process_unload_queue() -> void:
	if chunks_queued_for_unload.is_empty():
		return

	var chunks_unloaded = 0
	var chunks_to_remove: Array[Vector2i] = []

	for chunk_pos in chunks_queued_for_unload.keys():
		if chunks_unloaded >= unload_chunks_per_tick:
			break

		if loaded_chunks.has(chunk_pos):
			var chunk_instance = loaded_chunks[chunk_pos]
			chunk_instance.node.queue_free()
			loaded_chunks.erase(chunk_pos)
			chunks_to_remove.append(chunk_pos)
			chunks_unloaded += 1

	for chunk_pos in chunks_to_remove:
		chunks_queued_for_unload.erase(chunk_pos)


func _find_or_create_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	var mesh_instance = MeshInstance3D.new()
	node.add_child(mesh_instance)
	return mesh_instance


func world_to_chunk(world_pos: Vector3) -> Vector2i:
	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	return Vector2i(
		floori(world_pos.x / chunk_world_size),
		floori(world_pos.z / chunk_world_size)
	)


func is_chunk_loaded(chunk_pos: Vector2i) -> bool:
	return loaded_chunks.has(chunk_pos)


func is_chunk_pending(chunk_pos: Vector2i) -> bool:
	return pending_chunks.has(chunk_pos)


func get_chunk_at(chunk_pos: Vector2i) -> ChunkInstance:
	return loaded_chunks.get(chunk_pos)


func get_height_at(world_pos: Vector3) -> float:
	var chunk_pos: Vector2i = world_to_chunk(world_pos)
	if not loaded_chunks.has(chunk_pos):
		return 0.0

	var chunk_instance: ChunkInstance = loaded_chunks[chunk_pos]
	var mesh_inst: MeshInstance3D = chunk_instance.mesh_instance

	if mesh_inst.has_method("get_height_at"):
		return mesh_inst.get_height_at(world_pos.x, world_pos.z)

	return 0.0


func get_stats() -> Dictionary:
	return {
		"loaded_chunks": loaded_chunks.size(),
		"pending_chunks": pending_chunks.size(),
		"queued_for_unload": chunks_queued_for_unload.size(),
		"cached_meshes": mesh_cache.size(),
		"worker_threads": thread_pool.worker_threads.size() if thread_pool else 0,
		"chunks_this_frame": chunks_generated_this_frame
	}


func print_stats() -> void:
	var stats: Dictionary = get_stats()
	print("=== Chunk Manager Stats ===")
	print("  Loaded: %d" % stats.loaded_chunks)
	print("  Pending: %d" % stats.pending_chunks)
	print("  Queued for unload: %d" % stats.queued_for_unload)
	print("  Cached meshes: %d" % stats.cached_meshes)
	print("  Worker threads: %d" % stats.worker_threads)
	print("  Chunks this frame: %d" % stats.chunks_this_frame)


func _on_settings_changed() -> void:
	var old_distance := render_distance
	render_distance = GameSettingsAutoload.render_distance
	unload_distance = render_distance * 2

	if render_distance != old_distance:
		update_chunks(true)


func _exit_tree() -> void:
	if thread_pool:
		thread_pool.shutdown()
	_clear_all_chunks()


func _clear_all_chunks() -> void:
	for chunk_instance: ChunkInstance in loaded_chunks.values():
		chunk_instance.node.queue_free()

	loaded_chunks.clear()
	pending_chunks.clear()
	chunks_queued_for_unload.clear()
	mesh_cache.clear()
	cache_access_order.clear()

	print("ChunkManager: All chunks cleared")
