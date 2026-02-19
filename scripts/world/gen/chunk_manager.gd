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
var unload_chunks_per_tick: int = 8

var p_seed:                  int = 0
var debug_terrain_generator: TerrainGenerator = null
var _initial_load_done:      bool = false

# Chunk tracking
var loaded_chunks:  Dictionary = {}
var pending_chunks: Dictionary = {}
var chunks_queued_for_unload: Dictionary = {}

# Subsystems
var thread_pool:      ChunkThreadPool
var vegetation_mgr:   VegetationManager
var mesh_cache:       MeshCache
var veg_lod_mgr:      VegetationLodManager
var terrain_lod_mgr:  TerrainLodManager
var instantiator:     ChunkInstantiator

var river_generator:  RiverGenerator
var river_visualizer: RiverVisualizer

var camera:           Camera3D
var material_manager: TerrainMaterialManager
var terrain_material: ShaderMaterial

var chunks_generated_this_frame: int = 0
var last_camera_chunk:           Vector2i = Vector2i.ZERO

# Debug logging
var _log_timer:     float = 0.0
const LOG_INTERVAL: float = 5.0
var _capture_frame: bool = false


func _ready() -> void:
	p_seed = GameSettingsAutoload.seed
	chunk_size          = GameSettingsAutoload.chunk_size
	vertex_spacing      = GameSettingsAutoload.vertex_spacing
	max_worker_threads  = GameSettingsAutoload.max_worker_threads
	render_distance     = GameSettingsAutoload.render_distance
	unload_distance     = render_distance + 2
	chunks_per_frame    = GameSettingsAutoload.chunks_per_frame
	enable_mesh_caching = GameSettingsAutoload.enable_mesh_caching

	_initialize_systems()

	thread_pool = ChunkThreadPool.new()
	thread_pool.start(max_worker_threads, _generate_chunk_data, p_seed, GameSettingsAutoload.octave)

	vegetation_mgr = VegetationManager.new()
	mesh_cache = MeshCache.new(GameSettingsAutoload.cache_max_size)
	veg_lod_mgr = VegetationLodManager.new()
	terrain_lod_mgr = TerrainLodManager.new()
	instantiator = ChunkInstantiator.new(chunk_size, vertex_spacing, terrain_material, vegetation_mgr)

	GameSettingsAutoload.runtime_settings_changed.connect(_on_settings_changed)
	update_chunks(true)
	initial_chunks_ready.connect(_on_initial_chunks_ready)


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

	# Pre-build index buffers for all LOD levels
	for lod_size in TerrainConfig.MESH_LOD_SIZES:
		ChunkMeshBuilder._get_or_build_index_buffer(lod_size, ChunkMeshBuilder.OVERLAP)

	print("ChunkManager: Initialized with %d worker threads" % max_worker_threads)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_capture_frame = true
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var profiling: bool = _capture_frame
	var t0: int = 0
	var t1: int = 0
	if profiling:
		t0 = Time.get_ticks_usec()

	chunks_generated_this_frame = 0

	_process_completed_chunks()
	if profiling:
		t1 = Time.get_ticks_usec()
		print("[PROFILE] _process_completed_chunks: %.2fms (%d instantiated)" % [(t1 - t0) / 1000.0, chunks_generated_this_frame])
		t0 = t1

	update_chunks(false)
	if profiling:
		t1 = Time.get_ticks_usec()
		print("[PROFILE] update_chunks: %.2fms" % [(t1 - t0) / 1000.0])
		t0 = t1

	veg_lod_mgr.process_queue(loaded_chunks, last_camera_chunk, debug_terrain_generator, chunk_size, vertex_spacing, p_seed, vegetation_mgr)
	terrain_lod_mgr.process_queue(loaded_chunks, last_camera_chunk, chunk_size, vertex_spacing, terrain_material)
	if profiling:
		t1 = Time.get_ticks_usec()
		print("[PROFILE] lod_mgr.process_queue: %.2fms" % [(t1 - t0) / 1000.0])
		t0 = t1

	_ensure_nearby_collision()

	_process_unload_queue()
	if profiling:
		t1 = Time.get_ticks_usec()
		print("[PROFILE] _process_unload_queue: %.2fms" % [(t1 - t0) / 1000.0])
		t0 = t1

	if not _initial_load_done and pending_chunks.is_empty() and not loaded_chunks.is_empty():
		_initial_load_done = true
		initial_chunks_ready.emit()

	if profiling:
		var fps: int = Engine.get_frames_per_second()
		var frame_ms: float = 1000.0 / maxf(fps, 1)
		var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var nav_ms: float = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0

		print("[PROFILE] === Frame Capture (F4) ===")
		print("[PROFILE] fps=%d frame=%.1fms physics=%.2fms nav=%.2fms" % [fps, frame_ms, physics_ms, nav_ms])
		print("[PROFILE] draw_calls=%d primitives=%d mem=%.0fMB objects=%d" % [draw_calls, primitives, mem_mb, objects])
		print("[PROFILE] loaded=%d pending=%d unload_queue=%d cached=%d" % [
			loaded_chunks.size(), pending_chunks.size(),
			chunks_queued_for_unload.size(), mesh_cache.size()
		])

		# Count vegetation instances
		var total_grass: int = 0
		var total_trees: int = 0
		var total_foliage: int = 0
		var total_mmi: int = 0
		for ci: ChunkInstance in loaded_chunks.values():
			if ci.grass_instance:
				total_grass += ci.grass_instance.multimesh.instance_count
				total_mmi += 1
			if ci.tree_instance:
				total_trees += ci.tree_instance.multimesh.instance_count
				total_mmi += 1
			for fi in ci.foliage_instances:
				if fi:
					total_foliage += fi.multimesh.instance_count
					total_mmi += 1

		print("[PROFILE] mmi=%d | grass=%d trees=%d foliage=%d" % [total_mmi, total_grass, total_trees, total_foliage])
		print("[PROFILE] === End Frame Capture ===")
		_capture_frame = false

	_log_timer += _delta
	if _log_timer >= LOG_INTERVAL:
		_log_timer = 0.0
		_print_frame_stats()


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
				var grass_lod: int = VegetationLodManager.get_grass_lod(distance)
				var foliage_lod: int = VegetationLodManager.get_foliage_lod(distance)
				var mesh_lod: int = TerrainLodManager.get_mesh_lod(distance)
				var request = ChunkRequest.new(chunk_pos, distance, grass_lod, foliage_lod, mesh_lod)
				pending_chunks[chunk_pos] = request
				thread_pool.submit(request)

	_mark_distant_chunks_for_unload(chunks_to_keep)
	veg_lod_mgr.rebuild_queue(loaded_chunks, last_camera_chunk)
	terrain_lod_mgr.rebuild_queue(loaded_chunks, last_camera_chunk)


func _generate_chunk_data(request: ChunkRequest, terrain_gen: TerrainGenerator) -> ChunkResult:
	var result = ChunkResult.new(request.chunk_pos)
	var start_time = Time.get_ticks_usec()

	# Mesh (use cache for LOD 0 only)
	var lod_mesh_size: int = TerrainLodManager.get_mesh_size(request.mesh_lod)
	if enable_mesh_caching and request.mesh_lod == 0 and mesh_cache.has(request.chunk_pos):
		result.mesh_data = mesh_cache.get_mesh(request.chunk_pos)
	else:
		var mesh_builder = ChunkMeshBuilder.new(chunk_size, vertex_spacing, terrain_gen, lod_mesh_size)
		result.mesh_data = mesh_builder.build_chunk_mesh(request.chunk_pos)

	result.success = true

	# All vegetation: one shared grid, one call
	var veg_placer = VegetationPlacer.new(terrain_gen, chunk_size, vertex_spacing, p_seed, request.chunk_pos)
	var veg_all: Dictionary = veg_placer.generate_all(request.chunk_pos, request.grass_lod, request.foliage_lod)

	var grass: Dictionary = veg_all.grass
	result.vegetation.grass_buffer = grass.buffer
	result.vegetation.grass_count = grass.count

	var trees: Dictionary = veg_all.trees
	result.vegetation.tree_variant_id = trees.variant_id
	result.vegetation.tree_transforms = trees.transforms
	result.vegetation.tree_count = trees.count

	var foliage: Dictionary = veg_all.foliage
	result.vegetation.foliage_variant_ids = foliage.variant_ids
	for i in range(foliage.transforms.size()):
		result.vegetation.foliage_transforms[i] = foliage.transforms[i]
	for i in range(foliage.counts.size()):
		result.vegetation.foliage_counts[i] = foliage.counts[i]

	var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
	result.generation_time_ms = elapsed_ms

	# Debug logging
	# (skip far chunks with no vegetation detail)
	if request.foliage_lod < 2 or request.grass_lod < 2:
		var veg: VegetationData = result.vegetation
		var foliage_total: int = 0
		for i in range(veg.foliage_counts.size()):
			foliage_total += veg.foliage_counts[i]

		print("[CHUNK] %v  %.1fms  grass=%d tree=%d foliage=%d (g_lod=%d f_lod=%d m_lod=%d)" % [
			request.chunk_pos, elapsed_ms,
			veg.grass_count, veg.tree_count, foliage_total,
			request.grass_lod, request.foliage_lod, request.mesh_lod
		])

	return result


func _process_completed_chunks() -> void:
	var results: Array[ChunkResult] = thread_pool.get_completed()

	for result in results:
		if chunks_generated_this_frame >= chunks_per_frame:
			thread_pool.requeue(result)
			continue

		if result.success:
			var chunk_instance = instantiator.instantiate(result, self, last_camera_chunk, chunk_scene)
			loaded_chunks[result.chunk_pos] = chunk_instance

			# Track initial mesh LOD
			var req: ChunkRequest = pending_chunks.get(result.chunk_pos)
			if req:
				chunk_instance.mesh_lod = req.mesh_lod
				if enable_mesh_caching and req.mesh_lod == 0 and not mesh_cache.has(result.chunk_pos):
					mesh_cache.store(result.chunk_pos, result.mesh_data)

			chunks_generated_this_frame += 1
		else:
			push_error("Failed to generate chunk %v: %s" % [result.chunk_pos, result.error_message])

		pending_chunks.erase(result.chunk_pos)


func _ensure_nearby_collision() -> void:
	for x in range(-ChunkInstantiator.COLLISION_DISTANCE, ChunkInstantiator.COLLISION_DISTANCE + 1):
		for z in range(-ChunkInstantiator.COLLISION_DISTANCE, ChunkInstantiator.COLLISION_DISTANCE + 1):
			var chunk_pos: Vector2i = last_camera_chunk + Vector2i(x, z)
			if loaded_chunks.has(chunk_pos):
				var ci: ChunkInstance = loaded_chunks[chunk_pos]
				# Only create collision from LOD 0 meshes (full quality)
				if ci.mesh_lod == 0:
					instantiator.ensure_collision(ci)


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


func _print_frame_stats() -> void:
	var fps: int = Engine.get_frames_per_second()
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))

	var total_grass: int = 0
	var total_trees: int = 0
	var total_foliage: int = 0
	var total_mmi: int = 0

	for ci: ChunkInstance in loaded_chunks.values():
		if ci.grass_instance:
			total_grass += ci.grass_instance.multimesh.instance_count
			total_mmi += 1
		if ci.tree_instance:
			total_trees += ci.tree_instance.multimesh.instance_count
			total_mmi += 1
		for fi in ci.foliage_instances:
			if fi:
				total_foliage += fi.multimesh.instance_count
				total_mmi += 1

	print("[STATS] fps=%d draw=%d prims=%d mem=%.0fMB obj=%d" % [fps, draw_calls, primitives, mem_mb, objects])
	print("[STATS] chunks=%d mmi=%d | grass=%d trees=%d foliage=%d" % [
		loaded_chunks.size(), total_mmi, total_grass, total_trees, total_foliage
	])

func _on_initial_chunks_ready() -> void:
	river_generator = RiverGenerator.new(debug_terrain_generator)
	var candidates := river_generator.find_source(Vector2.ZERO, 2500.0)
	print("[RIVER] Found %d candidates" % candidates.size())

	river_visualizer = RiverVisualizer.new()
	add_child(river_visualizer)
	
	var paths: Array[PackedVector3Array] = []
	for source in candidates:
		print(source)
		var path = river_generator.build_river_controls_points(source)
		paths.append(path)
	
	river_visualizer.draw_candidates(candidates)
	river_visualizer.draw_rivers(paths)

func _on_settings_changed() -> void:
	var old_distance := render_distance
	render_distance = GameSettingsAutoload.render_distance
	unload_distance = render_distance + 2

	if render_distance != old_distance:
		update_chunks(true)


func _exit_tree() -> void:
	if terrain_lod_mgr:
		terrain_lod_mgr.shutdown()
	if veg_lod_mgr:
		veg_lod_mgr.shutdown()
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

	print("ChunkManager: All chunks cleared")
