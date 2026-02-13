class_name ChunkInstance
extends RefCounted

## Represents a loaded chunk in the world
## Similar to Minecraft's Chunk class but simplified for rendering

# PROPERTIES

var node:             Node3D
var mesh_instance:    MeshInstance3D
var chunk_pos:        Vector2i
var unload_queued:    bool = false
var last_access_time: int

# INITIALIZATION

func _init(p_node: Node3D, p_mesh_instance: MeshInstance3D, p_chunk_pos: Vector2i) -> void:
	node = p_node
	mesh_instance = p_mesh_instance
	chunk_pos = p_chunk_pos
	last_access_time = Time.get_ticks_msec()

# ACCESS TRACKING

func touch() -> void:
	last_access_time = Time.get_ticks_msec()
