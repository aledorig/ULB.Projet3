class_name ChunkThreadPool
extends RefCounted

## Thread pool for chunk generation
## Manages worker threads, work queue, and results queue
## Accepts a generation Callable for thread-safe execution

var worker_threads:        Array[Thread] = []
var thread_pool_semaphore: Semaphore
var work_queue_mutex:      Mutex
var work_queue:            Array[ChunkRequest] = []
var results_queue_mutex:   Mutex
var results_queue:         Array[ChunkResult] = []
var shutdown_flag:         bool = false
var generation_timeout_ms: int = 30000

var _generate_func: Callable
var _seed: int
var _octave: int


func start(num_threads: int, generate_func: Callable, p_seed: int, p_octave: int) -> void:
	_generate_func = generate_func
	_seed = p_seed
	_octave = p_octave
	work_queue_mutex = Mutex.new()
	results_queue_mutex = Mutex.new()
	thread_pool_semaphore = Semaphore.new()

	for i in range(num_threads):
		var thread := Thread.new()
		thread.start(_worker_func.bind(i))
		worker_threads.append(thread)

	print("ChunkThreadPool: Started %d worker threads" % num_threads)


func submit(request: ChunkRequest) -> void:
	work_queue_mutex.lock()
	work_queue.append(request)
	work_queue_mutex.unlock()
	thread_pool_semaphore.post()


func get_completed() -> Array[ChunkResult]:
	results_queue_mutex.lock()
	var results := results_queue.duplicate()
	results_queue.clear()
	results_queue_mutex.unlock()
	return results


func requeue(result: ChunkResult) -> void:
	results_queue_mutex.lock()
	results_queue.append(result)
	results_queue_mutex.unlock()


func shutdown() -> void:
	shutdown_flag = true

	for i in range(worker_threads.size()):
		thread_pool_semaphore.post()

	for thread: Thread in worker_threads:
		thread.wait_to_finish()

	worker_threads.clear()
	print("ChunkThreadPool: All worker threads stopped")


func _worker_func(thread_id: int) -> void:
	# One TerrainGenerator per thread
	# avoids rebuilding permutation tables per chunk
	var terrain_gen := TerrainGenerator.new(_seed, _octave)
	print("Worker thread %d started" % thread_id)

	while not shutdown_flag:
		thread_pool_semaphore.wait()

		if shutdown_flag:
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
			var failed := ChunkResult.new(request.chunk_pos)
			failed.success = false
			failed.error_message = "Timeout after %d ms" % elapsed
			results_queue_mutex.lock()
			results_queue.append(failed)
			results_queue_mutex.unlock()
			continue

		var result: ChunkResult = _generate_func.call(request, terrain_gen)

		results_queue_mutex.lock()
		results_queue.append(result)
		results_queue_mutex.unlock()

	print("Worker thread %d stopped" % thread_id)
