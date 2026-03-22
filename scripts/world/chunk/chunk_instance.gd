class_name ChunkInstance
extends RefCounted

var node: Node3D
var mesh_node: MeshInstance3D
var mesh_instance: Array = [] # one mesh per generation step
var chunk_pos: Vector2i
var unload_queued: bool = false
var last_access_time: int

var grass_instance: MultiMeshInstance3D = null
var grass_lod: int = 0

var tree_instance: MultiMeshInstance3D = null
var foliage_instances: Array = []
var foliage_lod: int = 0

var mesh_lod: int = 0
var has_collision: bool = false


func _init(p_node: Node3D, p_mesh_node: MeshInstance3D, p_chunk_pos: Vector2i) -> void:
	node = p_node
	mesh_node = p_mesh_node
	chunk_pos = p_chunk_pos
	last_access_time = Time.get_ticks_msec()
	foliage_instances.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	foliage_instances.fill(null)


func show_step(step: int) -> void:
	if step < mesh_instance.size():
		mesh_node.mesh = mesh_instance[step]

	var veg_visible: bool = (step == ChunkMeshBuilder.STEP_FINAL)

	if grass_instance:
		grass_instance.visible = veg_visible
	if tree_instance:
		tree_instance.visible = veg_visible
	for fi in foliage_instances:
		if fi:
			fi.visible = veg_visible


func touch() -> void:
	last_access_time = Time.get_ticks_msec()
