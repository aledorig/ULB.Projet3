class_name ChunkInstance
extends RefCounted

var node:             Node3D
var mesh_instance:    MeshInstance3D
var chunk_pos:        Vector2i
var unload_queued:    bool = false
var last_access_time: int
var grass_instance:   MultiMeshInstance3D = null

func _init(p_node: Node3D, p_mesh_instance: MeshInstance3D, p_chunk_pos: Vector2i) -> void:
	node = p_node
	mesh_instance = p_mesh_instance
	chunk_pos = p_chunk_pos
	last_access_time = Time.get_ticks_msec()

func touch() -> void:
	last_access_time = Time.get_ticks_msec()
