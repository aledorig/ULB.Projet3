extends Node3D

@export var grass_mesh:           Mesh
@export var grass_density:        float   = 3.2
@export var grass_height_range:   Vector2 = Vector2(0.8, 1.2)
@export var grass_scale_variance: float   = 0.4
@export var min_slope_for_grass:  float   = 0.9
@export var spawn_radius:         float   = 1.2

var terrain_manager: Node3D
var grass_chunks: Dictionary = {}

func _ready():
	terrain_manager = get_parent()
	if not terrain_manager:
		push_error("GrassSpawner must be a child of TerrainManager!")
		return
	
	set_process(true)

func _process(_delta: float):
	if not terrain_manager:
		return
	
	# Check if terrain manager has new chunks
	for chunk_key in terrain_manager.chunks.keys():
		if not grass_chunks.has(chunk_key):
			var chunk_instance = terrain_manager.chunks[chunk_key]
			spawn_grass_for_chunk(chunk_key, chunk_instance)

func on_chunk_removed(chunk_key: String):
	if grass_chunks.has(chunk_key):
		grass_chunks[chunk_key].queue_free()
		grass_chunks.erase(chunk_key)

func spawn_grass_for_chunk(chunk_key: String, chunk_instance: Node3D):
	if not grass_mesh:
		push_warning("Grass mesh not assigned!")
		return
	
	# Find the MeshInstance3D in the chunk
	var mesh_inst = _find_mesh_instance(chunk_instance)
	if not mesh_inst:
		return
	
	# Generate grass positions by sampling the terrain
	var grass_transforms = _generate_grass_positions(chunk_instance)
	
	if grass_transforms.is_empty():
		return
	
	# Create MultiMesh
	var multi_mesh = _create_grass_multimesh(grass_transforms)
	
	# Create MultiMeshInstance3D
	var grass_instance = MultiMeshInstance3D.new()
	grass_instance.multimesh = multi_mesh
	grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Add to scene
	add_child(grass_instance)
	
	# Position it at the chunk's world position
	grass_instance.global_position = chunk_instance.global_position
	
	# Store reference
	grass_chunks[chunk_key] = grass_instance

func _generate_grass_positions(chunk_instance: Node3D) -> Array:
	var transforms = []
	
	# Get chunk parameters from terrain manager
	var chunk_size = terrain_manager.chunk_size
	var vertex_spacing = terrain_manager.vertex_spacing
	
	# Calculate how many grass samples to take
	var chunk_world_size = (chunk_size - 1) * vertex_spacing
	var samples_per_side = int(chunk_world_size / spawn_radius)
	
	# Sample the terrain at regular intervals
	for z in range(samples_per_side):
		for x in range(samples_per_side):
			# Calculate local position within chunk
			var local_x = x * spawn_radius
			var local_z = z * spawn_radius
			
			# Add random offset for natural look
			local_x += randf_range(-spawn_radius * 0.4, spawn_radius * 0.4)
			local_z += randf_range(-spawn_radius * 0.4, spawn_radius * 0.4)
			
			# Get world position
			var world_pos = chunk_instance.global_position + Vector3(local_x, 0, local_z)
			
			# Get height at this position
			var height = terrain_manager.get_height_at(world_pos)
			
			# Get terrain normal to check slope
			var normal = _estimate_normal(world_pos)
			
			# Only spawn grass on flat-ish surfaces
			if normal.y < min_slope_for_grass:
				continue
			
			# Spawn multiple grass blades per sample point when density > 1.0
			var grass_count = int(grass_density)
			var remainder_chance = grass_density - floor(grass_density)
			
			if randf() < remainder_chance:
				grass_count += 1
			
			for i in range(grass_count):
				# Create transform for this grass blade
				var grass_transform = Transform3D()
				
				# Position (local to chunk) with slight offset for multiple blades
				var offset_x = randf_range(-0.15, 0.15) if i > 0 else 0.0
				var offset_z = randf_range(-0.15, 0.15) if i > 0 else 0.0
				# Lower grass slightly into the ground (subtract a bit from Y)
				grass_transform.origin = Vector3(local_x + offset_x, height - 0.15, local_z + offset_z)
				
				# Random rotation around Y axis
				var rotation_y = randf_range(0, TAU)
				grass_transform.basis = grass_transform.basis.rotated(Vector3.UP, rotation_y)
				
				# Random scale
				var rand_scale = randf_range(
					grass_height_range.x * (1.0 - grass_scale_variance),
					grass_height_range.y * (1.0 + grass_scale_variance)
				)
				grass_transform.basis = grass_transform.basis.scaled(Vector3(rand_scale, rand_scale, rand_scale))
				
				transforms.append(grass_transform)
	
	return transforms

func _estimate_normal(world_pos: Vector3) -> Vector3:
	var offset = 1.0
	
	# Sample heights around the position
	var h_center = terrain_manager.get_height_at(world_pos)
	var h_right = terrain_manager.get_height_at(world_pos + Vector3(offset, 0, 0))
	var h_forward = terrain_manager.get_height_at(world_pos + Vector3(0, 0, offset))
	
	# Calculate tangent vectors
	var tangent_x = Vector3(offset, h_right - h_center, 0)
	var tangent_z = Vector3(0, h_forward - h_center, offset)
	
	# Cross product gives normal
	var normal = tangent_z.cross(tangent_x).normalized()
	
	return normal

func _create_grass_multimesh(transforms: Array) -> MultiMesh:
	var multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = transforms.size()
	multi_mesh.mesh = grass_mesh
	
	# Set all transforms
	for i in range(transforms.size()):
		multi_mesh.set_instance_transform(i, transforms[i])
	
	return multi_mesh

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	
	return null
