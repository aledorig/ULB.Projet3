extends Node3D

@export var chunk_scene: PackedScene
@export var render_distance: int = 2
@export var chunk_size: int = 40
@export var vertex_spacing: float = 2.0

var chunks: Dictionary = {}
var camera: Camera3D
var material_manager: TerrainMaterialManager
var terrain_material: StandardMaterial3D

func _ready():
	_initialize_systems()
	update_chunks()

func _initialize_systems():
	camera = get_node("MainCamera")
	
	if chunk_scene == null:
		chunk_scene = load("res://scenes/terrain/chunk_mesh.tscn")
	
	material_manager = TerrainMaterialManager.new()
	terrain_material = material_manager.create_terrain_material()

func _process(_delta: float) -> void:
	update_chunks()

func update_chunks():
	if not camera:
		return
	
	var camera_pos = camera.global_position
	var camera_chunk = world_to_chunk(camera_pos)
	
	# Generate chunks around camera
	var chunks_to_keep = {}
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var chunk_pos = camera_chunk + Vector2(x, z)
			var chunk_key = chunk_to_key(chunk_pos)
			chunks_to_keep[chunk_key] = true
			
			if not chunks.has(chunk_key):
				spawn_chunk(chunk_pos)
	
	# Remove chunks that are too far away
	var chunks_to_remove = []
	for chunk_key in chunks.keys():
		if not chunks_to_keep.has(chunk_key):
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		remove_chunk(chunk_key)

func world_to_chunk(world_pos: Vector3) -> Vector2:
	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	return Vector2(floor(world_pos.x / chunk_world_size), floor(world_pos.z / chunk_world_size))

func chunk_to_key(chunk_pos: Vector2) -> String:
	return str(chunk_pos.x) + "," + str(chunk_pos.y)

func spawn_chunk(chunk_pos: Vector2):
	var chunk_instance = chunk_scene.instantiate()
	add_child(chunk_instance)
	
	var mesh_inst = _find_mesh_instance(chunk_instance)
	
	if mesh_inst and mesh_inst.has_method("generate_chunk"):
		mesh_inst.generate_chunk(chunk_pos)
		
		# Apply shared material
		if mesh_inst.mesh:
			mesh_inst.mesh.surface_set_material(0, terrain_material)
		
		# Position the parent container in world space
		var chunk_world_size = (chunk_size - 1) * vertex_spacing
		chunk_instance.position = Vector3(
			chunk_pos.x * chunk_world_size, 
			0, 
			chunk_pos.y * chunk_world_size
		)
	
	chunks[chunk_to_key(chunk_pos)] = chunk_instance

func remove_chunk(chunk_key: String):
	if chunks.has(chunk_key):
		_notify_chunk_removed(chunk_key)
		var chunk_instance = chunks[chunk_key]
		chunk_instance.queue_free()
		chunks.erase(chunk_key)
		
func _notify_chunk_removed(chunk_key: String):
	for child in get_children():
		if child.has_method("on_chunk_removed"):
			child.on_chunk_removed(chunk_key)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	
	return null

## Get height at world position
func get_height_at(world_pos: Vector3) -> float:
	var chunk_pos = world_to_chunk(world_pos)
	var chunk_key = chunk_to_key(chunk_pos)
	
	if chunks.has(chunk_key):
		var chunk_instance = chunks[chunk_key]
		var mesh_inst = _find_mesh_instance(chunk_instance)
		if mesh_inst and mesh_inst.has_method("get_height_at"):
			return mesh_inst.get_height_at(world_pos.x, world_pos.z)
	
	return 0.0
