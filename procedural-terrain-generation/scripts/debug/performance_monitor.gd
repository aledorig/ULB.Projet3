class_name PerformanceMonitor
extends RefCounted

## Centralized performance monitoring and logging
## Tracks timing for various subsystems and reports statistics

# ============================================================================
# CONFIGURATION
# ============================================================================

## Enable/disable logging output
static var logging_enabled: bool = true

## Minimum time (ms) to log a timing (filters noise)
static var log_threshold_ms: float = 1.0

## Keep history for averaging
static var history_size: int = 100

# ============================================================================
# TIMING DATA
# ============================================================================

## Active timers: name -> start_time_usec
static var _active_timers: Dictionary = {}

## Completed timings: name -> Array[float] (ms)
static var _timing_history: Dictionary = {}

## Call counts: name -> int
static var _call_counts: Dictionary = {}

## Per-frame accumulators: name -> float (ms)
static var _frame_accumulators: Dictionary = {}

# ============================================================================
# TIMING API
# ============================================================================

static func start(name: String) -> void:
	_active_timers[name] = Time.get_ticks_usec()


static func stop(name: String) -> float:
	if not _active_timers.has(name):
		push_warning("PerformanceMonitor: No active timer '%s'" % name)
		return 0.0

	var elapsed_us: int = Time.get_ticks_usec() - _active_timers[name]
	var elapsed_ms: float = elapsed_us / 1000.0
	_active_timers.erase(name)

	# Track history
	if not _timing_history.has(name):
		_timing_history[name] = []
		_call_counts[name] = 0

	_timing_history[name].append(elapsed_ms)
	_call_counts[name] += 1

	# Trim history
	if _timing_history[name].size() > history_size:
		_timing_history[name].pop_front()

	# Accumulate for frame stats
	if not _frame_accumulators.has(name):
		_frame_accumulators[name] = 0.0
	_frame_accumulators[name] += elapsed_ms

	# Log if above threshold
	if logging_enabled and elapsed_ms >= log_threshold_ms:
		print("[PERF] %s: %.2f ms" % [name, elapsed_ms])

	return elapsed_ms


static func stop_silent(name: String) -> float:
	## Stop timer without logging (for high-frequency operations)
	if not _active_timers.has(name):
		return 0.0

	var elapsed_us: int = Time.get_ticks_usec() - _active_timers[name]
	var elapsed_ms: float = elapsed_us / 1000.0
	_active_timers.erase(name)

	if not _timing_history.has(name):
		_timing_history[name] = []
		_call_counts[name] = 0

	_timing_history[name].append(elapsed_ms)
	_call_counts[name] += 1

	if _timing_history[name].size() > history_size:
		_timing_history[name].pop_front()

	if not _frame_accumulators.has(name):
		_frame_accumulators[name] = 0.0
	_frame_accumulators[name] += elapsed_ms

	return elapsed_ms

# ============================================================================
# STATISTICS
# ============================================================================

static func get_stats(name: String) -> Dictionary:
	if not _timing_history.has(name):
		return {"avg": 0.0, "min": 0.0, "max": 0.0, "count": 0, "total": 0.0}

	var history: Array = _timing_history[name]
	if history.is_empty():
		return {"avg": 0.0, "min": 0.0, "max": 0.0, "count": 0, "total": 0.0}

	var total: float = 0.0
	var min_val: float = history[0]
	var max_val: float = history[0]

	for val in history:
		total += val
		min_val = min(min_val, val)
		max_val = max(max_val, val)

	return {
		"avg": total / history.size(),
		"min": min_val,
		"max": max_val,
		"count": _call_counts[name],
		"total": total,
		"samples": history.size(),
	}


static func get_all_stats() -> Dictionary:
	var result: Dictionary = {}
	for name in _timing_history.keys():
		result[name] = get_stats(name)
	return result

# ============================================================================
# FRAME MANAGEMENT
# ============================================================================

static func end_frame() -> void:
	## Call at end of frame to reset accumulators
	_frame_accumulators.clear()


static func get_frame_total(name: String) -> float:
	return _frame_accumulators.get(name, 0.0)

# ============================================================================
# REPORTING
# ============================================================================

static func print_report() -> void:
	print("\n========== PERFORMANCE REPORT ==========")

	var all_stats := get_all_stats()
	var sorted_names := all_stats.keys()
	sorted_names.sort()

	for name in sorted_names:
		var s: Dictionary = all_stats[name]
		print("%-30s avg: %6.2f ms  min: %6.2f  max: %6.2f  calls: %d" % [
			name, s.avg, s.min, s.max, s.count
		])

	print("=========================================\n")


static func print_summary() -> void:
	## Print condensed summary of key metrics
	var all_stats := get_all_stats()

	var summary_items: Array[String] = []
	for name in ["chunk_generation", "biome_lookup", "mesh_build", "terrain_height"]:
		if all_stats.has(name):
			var s: Dictionary = all_stats[name]
			summary_items.append("%s: %.1fms" % [name, s.avg])

	if not summary_items.is_empty():
		print("[PERF SUMMARY] " + ", ".join(summary_items))

# ============================================================================
# RESET
# ============================================================================

static func reset() -> void:
	_active_timers.clear()
	_timing_history.clear()
	_call_counts.clear()
	_frame_accumulators.clear()


static func reset_history() -> void:
	## Keep structure but clear history (for fresh measurements)
	for name in _timing_history.keys():
		_timing_history[name].clear()
		_call_counts[name] = 0
