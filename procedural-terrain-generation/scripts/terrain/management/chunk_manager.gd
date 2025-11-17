class_name ChunkManager
extends Node3D

## Minecraft-inspired chunk manager with threading
## Based on ChunkProviderServer architecture

# ============================================================================
# CONFIGURATION
# ============================================================================

@export_group("Chunk Settings")
@export var chunk_scene:     PackedScene
@export var chunk_size:      int = 40
@export var vertex_spacing:  float = 2.0
@export var render_distance: int = 4
@export var unload_distance: int = 8

@export_group("Threading")
@export var max_worker_threads:    int = 4
@export var chunks_per_frame:      int = 2
@export var generation_timeout_ms: int = 30000

@export_group("Performance")
@export var enable_mesh_caching:    bool = true
@export var cache_max_size:         int = 256
@export var unload_chunks_per_tick: int = 5

# ============================================================================
# INTERNAL STATE
# ============================================================================

#seed for random generation
var p_seed = 1

# Chunk storage (similar to Minecraft's id2ChunkMap)
var loaded_chunks: Dictionary = {}   # Vector2i -> ChunkInstance
var pending_chunks: Dictionary = {}  # Vector2i -> ChunkRequest

# Unload queue (similar to Minecraft's droppedChunksSet)
var chunks_queued_for_unload: Dictionary = {}  # Vector2i -> bool

# Thread pool for chunk generation
var worker_threads:        Array[Thread] = []
var thread_pool_semaphore: Semaphore
var work_queue_mutex:      Mutex
var work_queue:            Array[ChunkRequest] = []
var results_queue_mutex:   Mutex
var results_queue:         Array[ChunkResult] = []
var shutdown_threads:      bool = false

# Mesh cache
var mesh_cache:         Dictionary = {}  # Vector2i -> ArrayMesh
var cache_access_order: Array[Vector2i] = []  # LRU tracking

# References
var camera:           Camera3D
var material_manager: TerrainMaterialManager
var terrain_material: StandardMaterial3D

# Performance tracking
var chunks_generated_this_frame: int = 0
var last_camera_chunk: Vector2i = Vector2i.ZERO

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_initialize_systems()
	_start_worker_threads()
	
	# Initial chunk generation
	update_chunks(true)

func _initialize_systems() -> void:
	# Find or create camera
	camera = get_node_or_null("/root/TerrainWorld/MainCamera")
	if not camera:
		camera = get_viewport().get_camera_3d()
	
	if not camera:
		push_error("ChunkManager: No camera found!")
		return
	
	# Initialize material
	material_manager = TerrainMaterialManager.new()
	terrain_material = material_manager.create_terrain_material()
	
	# Initialize threading primitives
	work_queue_mutex = Mutex.new()
	results_queue_mutex = Mutex.new()
	thread_pool_semaphore = Semaphore.new()
	
	#initialize seed
	if not p_seed:
		p_seed = randi()
	
	print("ChunkManager: Initialized with %d worker threads" % max_worker_threads)

func _start_worker_threads() -> void:
	for i in range(max_worker_threads):
		var thread = Thread.new()
		thread.start(_worker_thread_func.bind(i))
		worker_threads.append(thread)
	
	print("ChunkManager: Started %d worker threads" % worker_threads.size())

# ============================================================================
# MAIN UPDATE LOOP
# ============================================================================

func _process(_delta: float) -> void:
	chunks_generated_this_frame = 0
	
	# Process completed chunks from worker threads
	_process_completed_chunks()
	
	# Update chunk loading based on camera position
	update_chunks(false)
	
	# Unload distant chunks
	_process_unload_queue()

func update_chunks(force_update: bool = false) -> void:
	if not camera:
		return
	
	var camera_chunk = world_to_chunk(camera.global_position)
	
	# Skip if camera hasn't moved to a new chunk (unless forced)
	if not force_update and camera_chunk == last_camera_chunk:
		return
	
	last_camera_chunk = camera_chunk
	
	# Determine chunks that should be loaded
	var chunks_to_keep: Dictionary = {}
	var generation_requests: Array[ChunkRequest] = []
	
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var chunk_pos = camera_chunk + Vector2i(x, z)
			chunks_to_keep[chunk_pos] = true
			
			# Calculate priority (distance from camera)
			var distance = Vector2(x, z).length()
			
			# Check if chunk needs to be loaded/generated
			if not is_chunk_loaded(chunk_pos) and not is_chunk_pending(chunk_pos):
				var request = ChunkRequest.new(chunk_pos, distance)
				generation_requests.append(request)
	
	# Sort requests by priority (closest chunks first)
	generation_requests.sort_custom(_sort_by_priority)
	
	# Queue chunk generation requests
	for request in generation_requests:
		_queue_chunk_generation(request)
	
	# Mark distant chunks for unload
	_mark_distant_chunks_for_unload(chunks_to_keep)

func _sort_by_priority(a: ChunkRequest, b: ChunkRequest) -> bool:
	return a.priority < b.priority

# ============================================================================
# CHUNK LOADING & GENERATION
# ============================================================================

func _queue_chunk_generation(request: ChunkRequest) -> void:
	# Check if already pending
	if pending_chunks.has(request.chunk_pos):
		return
	
	# Mark as pending
	pending_chunks[request.chunk_pos] = request
	
	# Add to work queue
	work_queue_mutex.lock()
	work_queue.append(request)
	work_queue_mutex.unlock()
	
	# Signal worker threads
	thread_pool_semaphore.post()

func _worker_thread_func(thread_id: int) -> void:
	print("Worker thread %d started" % thread_id)
	
	while not shutdown_threads:
		# Wait for work
		thread_pool_semaphore.wait()
		
		if shutdown_threads:
			break
		
		# Get work from queue
		var request: ChunkRequest = null
		work_queue_mutex.lock()
		if not work_queue.is_empty():
			request = work_queue.pop_front()
		work_queue_mutex.unlock()
		
		if not request:
			continue
		
		# Check for timeout
		var elapsed = Time.get_ticks_msec() - request.timestamp
		if elapsed > generation_timeout_ms:
			print("Worker %d: Request timeout for chunk %v" % [thread_id, request.chunk_pos])
			continue
		
		# Generate chunk mesh
		var result = _generate_chunk_mesh(request.chunk_pos)
		
		# Add result to results queue
		results_queue_mutex.lock()
		results_queue.append(result)
		results_queue_mutex.unlock()
	
	print("Worker thread %d stopped" % thread_id)

func _generate_chunk_mesh(chunk_pos: Vector2i) -> ChunkResult:
	var result = ChunkResult.new(chunk_pos)
	var start_time = Time.get_ticks_msec()
	
	# Check mesh cache first (cache is thread-safe for reads)
	if enable_mesh_caching and mesh_cache.has(chunk_pos):
		result.mesh_data = mesh_cache[chunk_pos]
		result.success = true
		return result
	
	# Create temporary generators (thread-local)
	var terrain_gen = TerrainGenerator.new(p_seed, vertex_spacing)
	var mesh_builder = ChunkMeshBuilder.new(chunk_size, vertex_spacing, terrain_gen)
	
	# Generate mesh
	result.mesh_data = mesh_builder.build_chunk_mesh(chunk_pos)
	result.success = true
	
	var elapsed = Time.get_ticks_msec() - start_time
	if elapsed > 1000:  # Only log if took more than 1 second
		print("Chunk %v took %d ms to generate" % [chunk_pos, elapsed])
	
	return result

func _cache_mesh(chunk_pos: Vector2i, mesh: ArrayMesh) -> void:
	# Simple LRU cache
	if mesh_cache.size() >= cache_max_size:
		# Remove oldest entry
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
			# Re-queue for next frame
			results_queue_mutex.lock()
			results_queue.append(result)
			results_queue_mutex.unlock()
			continue
		
		if result.success:
			_instantiate_chunk(result.chunk_pos, result.mesh_data)
			
			# Cache the mesh on main thread
			if enable_mesh_caching and not mesh_cache.has(result.chunk_pos):
				_cache_mesh(result.chunk_pos, result.mesh_data)
			
			chunks_generated_this_frame += 1
		else:
			push_error("Failed to generate chunk %v: %s" % [result.chunk_pos, result.error_message])
		
		# Remove from pending
		pending_chunks.erase(result.chunk_pos)

func _instantiate_chunk(chunk_pos: Vector2i, mesh: ArrayMesh) -> void:
	# Don't instantiate if already loaded
	if loaded_chunks.has(chunk_pos):
		return
	
	# Create chunk node
	var chunk_node: Node3D
	if chunk_scene:
		chunk_node = chunk_scene.instantiate()
	else:
		chunk_node = Node3D.new()
	
	add_child(chunk_node)
	
	# Find or create MeshInstance3D
	var mesh_instance = _find_or_create_mesh_instance(chunk_node)
	
	# Set mesh and material
	mesh_instance.mesh = mesh
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, terrain_material)
	
	# Position chunk in world
	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	chunk_node.position = Vector3(
		chunk_pos.x * chunk_world_size,
		0,
		chunk_pos.y * chunk_world_size
	)
	
	# Store chunk instance
	var chunk_instance = ChunkInstance.new(chunk_node, mesh_instance, chunk_pos)
	loaded_chunks[chunk_pos] = chunk_instance

func _find_or_create_mesh_instance(node: Node) -> MeshInstance3D:
	# Search for existing MeshInstance3D
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	
	# Create new MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	node.add_child(mesh_instance)
	return mesh_instance

# ============================================================================
# CHUNK UNLOADING
# ============================================================================

func _mark_distant_chunks_for_unload(chunks_to_keep: Dictionary) -> void:
	for chunk_pos in loaded_chunks.keys():
		if not chunks_to_keep.has(chunk_pos):
			@warning_ignore("unused_variable")
			var chunk_instance = loaded_chunks[chunk_pos]
			
			# Check if beyond unload distance
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
			
			# Unload the chunk
			chunk_instance.node.queue_free()
			loaded_chunks.erase(chunk_pos)
			chunks_to_remove.append(chunk_pos)
			chunks_unloaded += 1
	
	# Clean up unload queue
	for chunk_pos in chunks_to_remove:
		chunks_queued_for_unload.erase(chunk_pos)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func world_to_chunk(world_pos: Vector3) -> Vector2i:
	var chunk_world_size = (chunk_size - 1) * vertex_spacing
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
	var chunk_pos = world_to_chunk(world_pos)
	if not loaded_chunks.has(chunk_pos):
		return 0.0
	
	var chunk_instance = loaded_chunks[chunk_pos]
	var mesh_inst = chunk_instance.mesh_instance
	
	# Try to call get_height_at if available
	if mesh_inst.has_method("get_height_at"):
		return mesh_inst.get_height_at(world_pos.x, world_pos.z)
	
	return 0.0

# ============================================================================
# STATISTICS & DEBUG
# ============================================================================

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
	var stats = get_stats()
	print("=== Chunk Manager Stats ===")
	print("  Loaded: %d" % stats.loaded_chunks)
	print("  Pending: %d" % stats.pending_chunks)
	print("  Queued for unload: %d" % stats.queued_for_unload)
	print("  Cached meshes: %d" % stats.cached_meshes)
	print("  Worker threads: %d" % stats.worker_threads)
	print("  Chunks this frame: %d" % stats.chunks_this_frame)

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	_shutdown_worker_threads()
	_clear_all_chunks()

func _shutdown_worker_threads() -> void:
	shutdown_threads = true
	
	# Wake up all threads
	for i in range(worker_threads.size()):
		thread_pool_semaphore.post()
	
	# Wait for threads to finish
	for thread in worker_threads:
		thread.wait_to_finish()
	
	worker_threads.clear()
	print("ChunkManager: All worker threads stopped")

func _clear_all_chunks() -> void:
	for chunk_instance in loaded_chunks.values():
		chunk_instance.node.queue_free()
	
	loaded_chunks.clear()
	pending_chunks.clear()
	chunks_queued_for_unload.clear()
	mesh_cache.clear()
	cache_access_order.clear()
	
	print("ChunkManager: All chunks cleared")

func clear_cache() -> void:
	mesh_cache.clear()
	cache_access_order.clear()
	print("ChunkManager: Mesh cache cleared")
