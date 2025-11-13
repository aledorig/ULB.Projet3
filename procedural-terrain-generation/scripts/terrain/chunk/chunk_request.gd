class_name ChunkRequest
extends RefCounted

## Represents a request to generate a chunk
## Similar to Minecraft's chunk generation request system

# ============================================================================
# MEMBER VARIABLES
# ============================================================================

var chunk_pos: Vector2i
var priority: float  # Distance from camera (lower = higher priority)
var timestamp: int

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(pos: Vector2i, prio: float):
	chunk_pos = pos
	priority = prio
	timestamp = Time.get_ticks_msec()
