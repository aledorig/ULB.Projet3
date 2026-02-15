class_name ChunkRequest
extends RefCounted

var chunk_pos: Vector2i
var priority:  float  ## Distance from camera (lower = higher priority)
var timestamp: int
var lod_level: int = 0

func _init(p_chunk_pos: Vector2i, p_priority: float, p_lod: int = 0) -> void:
	chunk_pos = p_chunk_pos
	priority = p_priority
	timestamp = Time.get_ticks_msec()
	lod_level = p_lod
