class_name ChunkInstance
extends RefCounted

var node:             Node3D
var mesh_instance:    MeshInstance3D
var chunk_pos:        Vector2i
var unload_queued:    bool = false
var last_access_time: int
var lod_level:        int = 0
var grass_instance:   MultiMeshInstance3D = null

func _init(p_node: Node3D, p_mesh_instance: MeshInstance3D, p_chunk_pos: Vector2i, p_lod: int = 0) -> void:
	node = p_node
	mesh_instance = p_mesh_instance
	chunk_pos = p_chunk_pos
	last_access_time = Time.get_ticks_msec()
	lod_level = p_lod

func touch() -> void:
	last_access_time = Time.get_ticks_msec()
