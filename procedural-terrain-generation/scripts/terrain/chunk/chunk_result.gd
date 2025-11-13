class_name ChunkResult
extends RefCounted

## Represents the result of a chunk generation operation
## Contains the generated mesh data and success status

# ============================================================================
# MEMBER VARIABLES
# ============================================================================

var chunk_pos: Vector2i
var mesh_data: ArrayMesh
var success: bool
var error_message: String

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(pos: Vector2i):
	chunk_pos = pos
	success = false
