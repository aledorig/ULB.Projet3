class_name GenLayer
extends RefCounted

## Base class for all biome generation layers
## Implements Minecraft's LCG-based PRNG system for deterministic generation

# ============================================================================
# CONSTANTS
# ============================================================================

const LCG_MULTIPLIER: int = 6364136223846793005
const LCG_INCREMENT: int = 1442695040888963407

# ============================================================================
# STATE
# ============================================================================

var parent: GenLayer
var base_seed: int
var world_seed: int
var chunk_seed: int

# ============================================================================
# SHARED CACHE
# ============================================================================

static var _int_cache: IntCache = null

static func get_int_cache() -> IntCache:
	if _int_cache == null:
		_int_cache = IntCache.new()
	return _int_cache


static func reset_cache() -> void:
	if _int_cache != null:
		_int_cache.reset()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_base_seed: int, p_parent: GenLayer = null) -> void:
	parent = p_parent
	base_seed = p_base_seed
	base_seed = _lcg(base_seed)
	base_seed += p_base_seed
	base_seed = _lcg(base_seed)
	base_seed += p_base_seed
	base_seed = _lcg(base_seed)
	base_seed += p_base_seed


func init_world_seed(seed: int) -> void:
	world_seed = seed
	if parent:
		parent.init_world_seed(seed)
	world_seed = _lcg(world_seed)
	world_seed += base_seed
	world_seed = _lcg(world_seed)
	world_seed += base_seed
	world_seed = _lcg(world_seed)
	world_seed += base_seed

# ============================================================================
# PRNG
# ============================================================================

func _lcg(value: int) -> int:
	return value * LCG_MULTIPLIER + LCG_INCREMENT


func init_chunk_seed(x: int, z: int) -> void:
	chunk_seed = world_seed
	chunk_seed = _lcg(chunk_seed) + x
	chunk_seed = _lcg(chunk_seed) + z
	chunk_seed = _lcg(chunk_seed) + x
	chunk_seed = _lcg(chunk_seed) + z


func next_int(bound: int) -> int:
	if bound <= 0:
		return 0
	var result: int = int(chunk_seed >> 24) % bound
	if result < 0:
		result += bound
	chunk_seed = _lcg(chunk_seed) + world_seed
	return result

# ============================================================================
# ABSTRACT METHOD
# ============================================================================

func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	# Override in subclasses
	push_error("GenLayer.get_values() must be overridden")
	return PackedInt32Array()


func _get_result_array(size: int) -> PackedInt32Array:
	## Get a cached array for results - avoids allocations
	return GenLayer.get_int_cache().get_int_cache(size)

# ============================================================================
# HELPER METHODS
# ============================================================================

func select_random(values: Array) -> int:
	return values[next_int(values.size())]


func select_mode_or_random(a: int, b: int, c: int, d: int) -> int:
	## Returns the most common value among the four, or random if no majority

	# Check if 3+ values are the same
	if b == c and c == d:
		return b
	if a == b and a == c:
		return a
	if a == b and a == d:
		return a
	if a == c and a == d:
		return a

	# Check if 2 values match (with different pair not matching)
	if a == b and c != d:
		return a
	if a == c and b != d:
		return a
	if a == d and b != c:
		return a
	if b == c and a != d:
		return b
	if b == d and a != c:
		return b
	if c == d and a != b:
		return c

	# No clear majority, pick randomly
	var choices: Array[int] = [a, b, c, d]
	return choices[next_int(4)]


static func is_biome_oceanic(biome_id: int) -> bool:
	return biome_id == TerrainConstants.Biome.OCEAN
