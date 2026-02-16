class_name ChunkInstantiator
extends RefCounted

var chunk_size:       int
var vertex_spacing:   float
var terrain_material: ShaderMaterial
var vegetation_mgr:   VegetationManager


func _init(p_chunk_size: int, p_vertex_spacing: float, p_terrain_material: ShaderMaterial, p_vegetation_mgr: VegetationManager) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_material = p_terrain_material
	vegetation_mgr = p_vegetation_mgr


func instantiate(result: ChunkResult, parent: Node3D, camera_chunk: Vector2i, chunk_scene: PackedScene) -> ChunkInstance:
	var chunk_node: Node3D
	if chunk_scene:
		chunk_node = chunk_scene.instantiate()
	else:
		chunk_node = Node3D.new()

	parent.add_child(chunk_node)

	var mesh_instance = _find_or_create_mesh_instance(chunk_node)
	mesh_instance.mesh = result.mesh_data
	if result.mesh_data.get_surface_count() > 0:
		result.mesh_data.surface_set_material(0, terrain_material)

	# Collision
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = result.mesh_data.create_trimesh_shape()
	static_body.add_child(collision_shape)
	chunk_node.add_child(static_body)

	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	chunk_node.position = Vector3(
		result.chunk_pos.x * chunk_world_size,
		0,
		result.chunk_pos.y * chunk_world_size
	)

	var chunk_instance = ChunkInstance.new(chunk_node, mesh_instance, result.chunk_pos)

	# Grass
	chunk_instance.grass_instance = vegetation_mgr.create_vegetation(chunk_node, result.vegetation)
	chunk_instance.grass_lod = GrassLodManager.get_lod((result.chunk_pos - camera_chunk).length())

	# Trees, rocks, foliage
	chunk_instance.tree_instance = vegetation_mgr.create_tree(chunk_node, result.vegetation)
	chunk_instance.rock_instance = vegetation_mgr.create_rock(chunk_node, result.vegetation)
	chunk_instance.foliage_instances = vegetation_mgr.create_foliage(chunk_node, result.vegetation)

	return chunk_instance


func _find_or_create_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	var mesh_instance = MeshInstance3D.new()
	node.add_child(mesh_instance)
	return mesh_instance
