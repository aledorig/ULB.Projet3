class_name ChunkInstance
extends RefCounted

## Represents a loaded chunk in the world
## Similar to Minecraft's Chunk class but simplified for rendering

# ============================================================================
# MEMBER VARIABLES
# ============================================================================

var node: Node3D
var mesh_instance: MeshInstance3D
var chunk_pos: Vector2i
var unload_queued: bool = false
var last_access_time: int

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(n: Node3D, mesh_inst: MeshInstance3D, pos: Vector2i):
	node = n
	mesh_instance = mesh_inst
	chunk_pos = pos
	last_access_time = Time.get_ticks_msec()
