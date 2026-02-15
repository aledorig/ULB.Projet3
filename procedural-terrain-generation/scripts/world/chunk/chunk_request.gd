class_name ChunkRequest
extends RefCounted

var chunk_pos:  Vector2i
var priority:   float  ## Distance from camera (lower = higher priority)
var timestamp:  int
var grass_lod:  int = 0  ## LOD for vegetation density only

func _init(p_chunk_pos: Vector2i, p_priority: float, p_grass_lod: int = 0) -> void:
	chunk_pos = p_chunk_pos
	priority = p_priority
	timestamp = Time.get_ticks_msec()
	grass_lod = p_grass_lod
