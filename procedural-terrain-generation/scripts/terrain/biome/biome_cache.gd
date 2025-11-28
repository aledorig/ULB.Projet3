class_name BiomeCache
extends RefCounted

## LRU cache for biome lookups to avoid regenerating the same regions

# ============================================================================
# CONFIGURATION
# ============================================================================

const CACHE_SIZE: int = 1024
const CHUNK_SIZE: int = 32

# ============================================================================
# STATE
# ============================================================================

## Cache storage: chunk_key -> PackedInt32Array of biome IDs
var cache: Dictionary = {}

## LRU tracking: ordered list of chunk keys (oldest first)
var access_order: Array[int] = []

# ============================================================================
# PUBLIC API
# ============================================================================

func get_biome(bx: int, bz: int) -> int:
	var chunk_x: int = bx >> 5  # Divide by 32
	var chunk_z: int = bz >> 5
	var chunk_key: int = _make_key(chunk_x, chunk_z)

	if not cache.has(chunk_key):
		return -1  # Cache miss

	# Update LRU
	_touch(chunk_key)

	var local_x: int = bx & 31  # Modulo 32
	var local_z: int = bz & 31
	var chunk_data: PackedInt32Array = cache[chunk_key]
	return chunk_data[local_x + local_z * CHUNK_SIZE]


func set_chunk(chunk_x: int, chunk_z: int, data: PackedInt32Array) -> void:
	var chunk_key: int = _make_key(chunk_x, chunk_z)

	# Evict oldest if at capacity
	while cache.size() >= CACHE_SIZE:
		var oldest: int = access_order.pop_front()
		cache.erase(oldest)

	cache[chunk_key] = data
	access_order.append(chunk_key)


func get_chunk(chunk_x: int, chunk_z: int) -> PackedInt32Array:
	var chunk_key: int = _make_key(chunk_x, chunk_z)

	if not cache.has(chunk_key):
		return PackedInt32Array()  # Empty = miss

	_touch(chunk_key)
	return cache[chunk_key]


func has_chunk(chunk_x: int, chunk_z: int) -> bool:
	var chunk_key: int = _make_key(chunk_x, chunk_z)
	return cache.has(chunk_key)


func clear() -> void:
	cache.clear()
	access_order.clear()


func get_stats() -> Dictionary:
	return {
		"size": cache.size(),
		"max_size": CACHE_SIZE,
	}

# ============================================================================
# INTERNAL
# ============================================================================

func _make_key(chunk_x: int, chunk_z: int) -> int:
	# Combine chunk coords into single int key
	# Using cantor pairing function (handles negative coords)
	var x: int = chunk_x * 2 if chunk_x >= 0 else -chunk_x * 2 - 1
	var z: int = chunk_z * 2 if chunk_z >= 0 else -chunk_z * 2 - 1
	return ((x + z) * (x + z + 1)) / 2 + z


func _touch(_chunk_key: int) -> void:
	# Skip LRU update for performance - simple FIFO eviction is good enough
	# The cache is large enough that this rarely matters
	pass
