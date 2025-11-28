class_name ChunkResult
extends RefCounted

## Represents the result of a chunk generation operation
## Contains the generated mesh data and success status

# ============================================================================
# PROPERTIES
# ============================================================================

var chunk_pos:          Vector2i
var mesh_data:          ArrayMesh
var success:            bool = false
var error_message:      String = ""
var generation_time_ms: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_chunk_pos: Vector2i) -> void:
	chunk_pos = p_chunk_pos
