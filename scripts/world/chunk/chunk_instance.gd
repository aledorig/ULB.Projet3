class_name ChunkInstance
extends RefCounted

var node:             Node3D
var mesh_instance:    MeshInstance3D
var chunk_pos:        Vector2i
var unload_queued:    bool = false
var last_access_time: int

var grass_instance:    MultiMeshInstance3D = null
var grass_lod:         int = 0

var tree_instance:     MultiMeshInstance3D = null
var rock_instance:     MultiMeshInstance3D = null
var foliage_instances: Array = []


func _init(p_node: Node3D, p_mesh_instance: MeshInstance3D, p_chunk_pos: Vector2i) -> void:
	node = p_node
	mesh_instance = p_mesh_instance
	chunk_pos = p_chunk_pos
	last_access_time = Time.get_ticks_msec()
	foliage_instances.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	foliage_instances.fill(null)


func touch() -> void:
	last_access_time = Time.get_ticks_msec()
