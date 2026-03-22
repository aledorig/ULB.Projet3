class_name ChunkInstantiator
extends RefCounted

var chunk_size: int
var vertex_spacing: float
var terrain_material: ShaderMaterial
var debug_material: StandardMaterial3D
var vegetation_mgr: VegetationManager

const COLLISION_DISTANCE: int = 3


func _init(
		p_chunk_size: int,
		p_vertex_spacing: float,
		p_terrain_material: ShaderMaterial,
		p_vegetation_mgr: VegetationManager,
) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_material = p_terrain_material
	vegetation_mgr = p_vegetation_mgr
	debug_material = StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.vertex_color_use_as_albedo = true


func instantiate(
		result: ChunkResult,
		parent: Node3D,
		camera_chunk: Vector2i,
		chunk_scene: PackedScene,
) -> ChunkInstance:
	var chunk_node: Node3D

	if chunk_scene:
		chunk_node = chunk_scene.instantiate()
	else:
		chunk_node = Node3D.new()

	parent.add_child(chunk_node)

	var mesh_node = _find_or_create_mesh_instance(chunk_node)

	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	chunk_node.position = Vector3(
		result.chunk_pos.x * chunk_world_size,
		0,
		result.chunk_pos.y * chunk_world_size,
	)

	var chunk_instance = ChunkInstance.new(chunk_node, mesh_node, result.chunk_pos)

	# store all step meshes and apply material per step
	# steps 0..STEP_FINAL-1  -> flat unshaded vertex colors
	# step STEP_FINAL        -> terrain shader

	chunk_instance.mesh_instance = result.mesh_steps
	for i in range(result.mesh_steps.size()):
		var step_mesh: ArrayMesh = result.mesh_steps[i]
		if step_mesh == null or step_mesh.get_surface_count() == 0:
			continue
		if i < ChunkMeshBuilder.STEP_FINAL:
			step_mesh.surface_set_material(0, debug_material)
		else:
			step_mesh.surface_set_material(0, terrain_material)

	chunk_instance.show_step(GameSettingsAutoload.generation_step)

	# only create collision for nearby chunks (create_trimesh_shape is expensive)
	var distance: float = (result.chunk_pos - camera_chunk).length()
	if distance <= COLLISION_DISTANCE:
		_add_collision(chunk_instance)

	# grass
	chunk_instance.grass_instance = vegetation_mgr.create_grass(chunk_node, result.vegetation)
	chunk_instance.grass_lod = VegetationLodManager.get_grass_lod(distance)

	# trees
	chunk_instance.tree_instance = vegetation_mgr.create_tree(chunk_node, result.vegetation)

	# foliage
	chunk_instance.foliage_instances = vegetation_mgr.create_foliage(chunk_node, result.vegetation)
	chunk_instance.foliage_lod = VegetationLodManager.get_foliage_lod(distance)

	# hide vegetation when not on the final (full render) step
	var is_final: bool = (GameSettingsAutoload.generation_step == ChunkMeshBuilder.STEP_FINAL)

	if chunk_instance.grass_instance:
		chunk_instance.grass_instance.visible = is_final
	if chunk_instance.tree_instance:
		chunk_instance.tree_instance.visible = is_final
	for fi in chunk_instance.foliage_instances:
		if fi:
			fi.visible = is_final

	return chunk_instance


func ensure_collision(chunk_instance: ChunkInstance) -> bool:
	if chunk_instance.has_collision:
		return false

	_add_collision(chunk_instance)
	return true


func _add_collision(chunk_instance: ChunkInstance) -> void:
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = chunk_instance.mesh_node.mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	chunk_instance.node.add_child(static_body)
	chunk_instance.has_collision = true


func _find_or_create_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	var mesh_instance = MeshInstance3D.new()
	node.add_child(mesh_instance)
	return mesh_instance
