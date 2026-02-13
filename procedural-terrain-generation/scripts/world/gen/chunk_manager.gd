class_name ChunkManager
extends Node3D

signal initial_chunks_ready

@export var chunk_scene: PackedScene

var chunk_size: int = 40
var vertex_spacing: float = 2.0
var render_distance: int = 4
var unload_distance: int = 8
var max_worker_threads: int = 4
var chunks_per_frame: int = 2
var enable_mesh_caching: bool = true
var cache_max_size: int = 256
var unload_chunks_per_tick: int = 5
var generation_timeout_ms: int = 30000

var p_seed: int = GameSettingsAutoload.seed
var debug_terrain_generator: TerrainGenerator = null
var _initial_load_done: bool = false

var loaded_chunks:  Dictionary = {}
var pending_chunks: Dictionary = {}

var chunks_queued_for_unload: Dictionary = {}

var worker_threads:        Array[Thread] = []
var thread_pool_semaphore: Semaphore
var work_queue_mutex:      Mutex
var work_queue:            Array[ChunkRequest] = []
var results_queue_mutex:   Mutex
var results_queue:         Array[ChunkResult] = []
var shutdown_threads:      bool = false

var mesh_cache:         Dictionary = {}
var cache_access_order: Array[Vector2i] = []

var camera: Camera3D
var material_manager: TerrainMaterialManager
var terrain_material: ShaderMaterial

var chunks_generated_this_frame: int = 0
var last_camera_chunk: Vector2i = Vector2i.ZERO

func _ready() -> void:
	chunk_size = GameSettingsAutoload.chunk_size
	vertex_spacing = GameSettingsAutoload.vertex_spacing
	max_worker_threads = GameSettingsAutoload.max_worker_threads
	render_distance = GameSettingsAutoload.render_distance
	unload_distance = render_distance * 2
	chunks_per_frame = GameSettingsAutoload.chunks_per_frame
	enable_mesh_caching = GameSettingsAutoload.enable_mesh_caching
	cache_max_size = GameSettingsAutoload.cache_max_size
	_clear_generation_state()
	_initialize_systems()
	_start_worker_threads()
	GameSettingsAutoload.runtime_settings_changed.connect(_on_settings_changed)
	update_chunks(true)

func _clear_generation_state() -> void:
	for chunk_instance in loaded_chunks.values():
		chunk_instance.node.queue_free()

	loaded_chunks.clear()
	pending_chunks.clear()
	chunks_queued_for_unload.clear()
	mesh_cache.clear()
	cache_access_order.clear()
	last_camera_chunk = Vector2i.ZERO

func _initialize_systems() -> void:
	camera = get_node_or_null("/root/TerrainWorld/MainCamera")
	if not camera:
		camera = get_viewport().get_camera_3d()

	if not camera:
		push_error("ChunkManager: No camera found!")
		return

	material_manager = TerrainMaterialManager.new()
	terrain_material = material_manager.create_terrain_material()

	work_queue_mutex = Mutex.new()
	results_queue_mutex = Mutex.new()
	thread_pool_semaphore = Semaphore.new()

	if not p_seed:
		p_seed = randi()

	debug_terrain_generator = TerrainGenerator.new(p_seed, GameSettingsAutoload.octave)
	debug_terrain_generator.use_biome_blending = GameSettingsAutoload.biome_blending
	debug_terrain_generator.blend_radius = GameSettingsAutoload.blend_radius

	print("ChunkManager: Initialized with %d worker threads" % max_worker_threads)

	# Pre-build the shared index buffer before workers start (thread-safe)
	ChunkMeshBuilder._get_or_build_index_buffer(chunk_size, ChunkMeshBuilder.OVERLAP)


func _start_worker_threads() -> void:
	for i in range(max_worker_threads):
		var thread := Thread.new()
		thread.start(_worker_thread_func.bind(i))
		worker_threads.append(thread)

	print("ChunkManager: Started %d worker threads" % worker_threads.size())

func _process(_delta: float) -> void:
	chunks_generated_this_frame = 0
	_process_completed_chunks()
	update_chunks(false)
	_process_unload_queue()

	if not _initial_load_done and pending_chunks.is_empty() and not loaded_chunks.is_empty():
		_initial_load_done = true
		initial_chunks_ready.emit()


func update_chunks(force_update: bool = false) -> void:
	if not camera:
		return

	var camera_chunk = world_to_chunk(camera.global_position)

	if not force_update and camera_chunk == last_camera_chunk:
		return

	last_camera_chunk = camera_chunk

	var chunks_to_keep: Dictionary = {}
	var generation_requests: Array[ChunkRequest] = []

	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var chunk_pos = camera_chunk + Vector2i(x, z)
			chunks_to_keep[chunk_pos] = true

			var distance = Vector2(x, z).length()

			if not is_chunk_loaded(chunk_pos) and not is_chunk_pending(chunk_pos):
				var request = ChunkRequest.new(chunk_pos, distance)
				generation_requests.append(request)

	generation_requests.sort_custom(_sort_by_priority)

	for request in generation_requests:
		_queue_chunk_generation(request)

	_mark_distant_chunks_for_unload(chunks_to_keep)


func _sort_by_priority(a: ChunkRequest, b: ChunkRequest) -> bool:
	return a.priority < b.priority

func _queue_chunk_generation(request: ChunkRequest) -> void:
	if pending_chunks.has(request.chunk_pos):
		return

	pending_chunks[request.chunk_pos] = request

	work_queue_mutex.lock()
	work_queue.append(request)
	work_queue_mutex.unlock()

	thread_pool_semaphore.post()


func _worker_thread_func(thread_id: int) -> void:
	print("Worker thread %d started" % thread_id)

	while not shutdown_threads:
		thread_pool_semaphore.wait()

		if shutdown_threads:
			break

		var request: ChunkRequest = null
		work_queue_mutex.lock()
		if not work_queue.is_empty():
			request = work_queue.pop_front()
		work_queue_mutex.unlock()

		if not request:
			continue

		var elapsed = Time.get_ticks_msec() - request.timestamp
		if elapsed > generation_timeout_ms:
			print("Worker %d: Request timeout for chunk %v" % [thread_id, request.chunk_pos])
			continue

		var result = _generate_chunk_mesh(request.chunk_pos)

		results_queue_mutex.lock()
		results_queue.append(result)
		results_queue_mutex.unlock()

	print("Worker thread %d stopped" % thread_id)


func _generate_chunk_mesh(chunk_pos: Vector2i) -> ChunkResult:
	var result = ChunkResult.new(chunk_pos)
	var start_time = Time.get_ticks_usec()

	if enable_mesh_caching and mesh_cache.has(chunk_pos):
		result.mesh_data = mesh_cache[chunk_pos]
		result.success = true
		return result

	var terrain_gen = TerrainGenerator.new(GameSettingsAutoload.seed, GameSettingsAutoload.octave)
	var mesh_builder = ChunkMeshBuilder.new(chunk_size, vertex_spacing, terrain_gen)

	result.mesh_data = mesh_builder.build_chunk_mesh(chunk_pos)
	result.success = true

	var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
	result.generation_time_ms = elapsed_ms

	if elapsed_ms > 100:
		print("[CHUNK] %v generated in %.1f ms (SLOW)" % [chunk_pos, elapsed_ms])
	elif elapsed_ms > 50:
		print("[CHUNK] %v generated in %.1f ms" % [chunk_pos, elapsed_ms])

	return result


func _cache_mesh(chunk_pos: Vector2i, mesh: ArrayMesh) -> void:
	if mesh_cache.size() >= cache_max_size:
		var oldest = cache_access_order.pop_front()
		mesh_cache.erase(oldest)

	mesh_cache[chunk_pos] = mesh
	cache_access_order.append(chunk_pos)


func _process_completed_chunks() -> void:
	results_queue_mutex.lock()
	var results_to_process = results_queue.duplicate()
	results_queue.clear()
	results_queue_mutex.unlock()

	for result in results_to_process:
		if chunks_generated_this_frame >= chunks_per_frame:
			results_queue_mutex.lock()
			results_queue.append(result)
			results_queue_mutex.unlock()
			continue

		if result.success:
			_instantiate_chunk(result.chunk_pos, result.mesh_data)

			if enable_mesh_caching and not mesh_cache.has(result.chunk_pos):
				_cache_mesh(result.chunk_pos, result.mesh_data)

			chunks_generated_this_frame += 1
		else:
			push_error("Failed to generate chunk %v: %s" % [result.chunk_pos, result.error_message])

		pending_chunks.erase(result.chunk_pos)


func _instantiate_chunk(chunk_pos: Vector2i, mesh: ArrayMesh) -> void:
	if loaded_chunks.has(chunk_pos):
		return

	var chunk_node: Node3D
	if chunk_scene:
		chunk_node = chunk_scene.instantiate()
	else:
		chunk_node = Node3D.new()

	add_child(chunk_node)

	var mesh_instance = _find_or_create_mesh_instance(chunk_node)

	mesh_instance.mesh = mesh
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, terrain_material)

	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	chunk_node.position = Vector3(
		chunk_pos.x * chunk_world_size,
		0,
		chunk_pos.y * chunk_world_size
	)

	var chunk_instance = ChunkInstance.new(chunk_node, mesh_instance, chunk_pos)
	loaded_chunks[chunk_pos] = chunk_instance


func _find_or_create_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	var mesh_instance = MeshInstance3D.new()
	node.add_child(mesh_instance)
	return mesh_instance

func _mark_distant_chunks_for_unload(chunks_to_keep: Dictionary) -> void:
	for chunk_pos in loaded_chunks.keys():
		if not chunks_to_keep.has(chunk_pos):
			@warning_ignore("unused_variable")
			var chunk_instance = loaded_chunks[chunk_pos]

			var distance = (chunk_pos - last_camera_chunk).length()
			if distance > unload_distance:
				queue_chunk_for_unload(chunk_pos)


func queue_chunk_for_unload(chunk_pos: Vector2i) -> void:
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
		"worker_threads": worker_threads.size(),
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
	_shutdown_worker_threads()
	_clear_all_chunks()


func _shutdown_worker_threads() -> void:
	shutdown_threads = true

	for i in range(worker_threads.size()):
		thread_pool_semaphore.post()

	for thread: Thread in worker_threads:
		thread.wait_to_finish()

	worker_threads.clear()
	print("ChunkManager: All worker threads stopped")


func _clear_all_chunks() -> void:
	for chunk_instance: ChunkInstance in loaded_chunks.values():
		chunk_instance.node.queue_free()

	loaded_chunks.clear()
	pending_chunks.clear()
	chunks_queued_for_unload.clear()
	mesh_cache.clear()
	cache_access_order.clear()

	print("ChunkManager: All chunks cleared")
