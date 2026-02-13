class_name ChunkRequest
extends RefCounted

var chunk_pos: Vector2i
var priority:  float  ## Distance from camera (lower = higher priority)
var timestamp: int

func _init(p_chunk_pos: Vector2i, p_priority: float) -> void:
	chunk_pos = p_chunk_pos
	priority = p_priority
	timestamp = Time.get_ticks_msec()
