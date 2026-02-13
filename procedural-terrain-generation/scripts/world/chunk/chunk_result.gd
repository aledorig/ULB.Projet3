class_name ChunkResult
extends RefCounted

var chunk_pos:          Vector2i
var mesh_data:          ArrayMesh
var success:            bool = false
var error_message:      String = ""
var generation_time_ms: float = 0.0

func _init(p_chunk_pos: Vector2i) -> void:
	chunk_pos = p_chunk_pos
