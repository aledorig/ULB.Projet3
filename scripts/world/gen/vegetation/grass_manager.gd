class_name GrassManager
extends RefCounted
## Handles grass mesh construction, material caching, and MMI creation/replacement

var _grass_mesh: Mesh = null
var _grass_material: ShaderMaterial = null


func create(chunk_node: Node3D, veg: VegetationData) -> MultiMeshInstance3D:
	if veg.grass_count == 0:
		return null

	var grass_mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _get_mesh()
	multimesh.instance_count = veg.grass_count
	multimesh.buffer = veg.grass_buffer

	grass_mm.multimesh = multimesh
	grass_mm.material_override = _get_material()
	grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass_mm.visibility_range_end = TerrainConfig.VIS_RANGE_GRASS
	grass_mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	chunk_node.add_child(grass_mm)
	return grass_mm


func replace(
		chunk_instance: ChunkInstance,
		grass_buffer: PackedFloat32Array,
		veg_count: int,
) -> void:
	if chunk_instance.grass_instance:
		chunk_instance.grass_instance.queue_free()
		chunk_instance.grass_instance = null

	if veg_count == 0:
		return

	var grass_mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _get_mesh()
	multimesh.instance_count = veg_count
	multimesh.buffer = grass_buffer

	grass_mm.multimesh = multimesh
	grass_mm.material_override = _get_material()
	grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass_mm.visibility_range_end = TerrainConfig.VIS_RANGE_GRASS
	grass_mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	chunk_instance.node.add_child(grass_mm)
	chunk_instance.grass_instance = grass_mm


func _get_mesh() -> Mesh:
	if _grass_mesh == null:
		_grass_mesh = _build_quad_mesh()
	return _grass_mesh


func _build_quad_mesh() -> ArrayMesh:
	# 3-quad triangle pattern: each quad offset to form an equilateral triangle cross-section
	var hw: float = 0.5
	var h: float = 1.3
	var offset: float = 0.15

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for i in range(3):
		var angle: float = deg_to_rad(i * 120.0)
		var dx: float = cos(angle) * hw
		var dz: float = sin(angle) * hw

		var perp_x: float = -sin(angle) * offset
		var perp_z: float = cos(angle) * offset

		var base_idx: int = verts.size()

		verts.append(Vector3(-dx + perp_x, 0.0, -dz + perp_z))
		verts.append(Vector3(dx + perp_x, 0.0, dz + perp_z))
		verts.append(Vector3(dx + perp_x, h, dz + perp_z))
		verts.append(Vector3(-dx + perp_x, h, -dz + perp_z))

		uvs.append(Vector2(0.0, 1.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(0.0, 0.0))

		var n := Vector3(-dz, 0.0, dx).normalized()
		for j in range(4):
			normals.append(n)

		indices.append(base_idx)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _get_material() -> ShaderMaterial:
	if _grass_material == null:
		var shader = load("res://shaders/environment/grass.gdshader") as Shader
		if shader:
			_grass_material = ShaderMaterial.new()
			_grass_material.shader = shader

			var grass_tex_1 = load("res://assets/textures/grass-silhouette.png")
			var grass_tex_2 = load("res://assets/textures/grass-silhouette-2.png")
			_grass_material.set_shader_parameter("grass_texture", grass_tex_1)
			_grass_material.set_shader_parameter("grass_texture_2", grass_tex_2)
	return _grass_material
