class_name VegetationManager
extends RefCounted

## Handles grass mesh/material caching and vegetation instantiation
## from pre-computed data on ChunkResult

var _grass_mesh:     Mesh = null
var _grass_material: ShaderMaterial = null


func create_vegetation(chunk_node: Node3D, result: ChunkResult) -> MultiMeshInstance3D:
	if result.vegetation_count == 0:
		return null

	var grass_mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _get_grass_mesh()
	multimesh.instance_count = result.vegetation_count

	for i in range(result.vegetation_count):
		var base: int = i * 12
		var t := Transform3D()
		t.basis.x = Vector3(result.vegetation_data[base], result.vegetation_data[base + 1], result.vegetation_data[base + 2])
		t.basis.y = Vector3(result.vegetation_data[base + 3], result.vegetation_data[base + 4], result.vegetation_data[base + 5])
		t.basis.z = Vector3(result.vegetation_data[base + 6], result.vegetation_data[base + 7], result.vegetation_data[base + 8])
		t.origin = Vector3(result.vegetation_data[base + 9], result.vegetation_data[base + 10], result.vegetation_data[base + 11])
		multimesh.set_instance_transform(i, t)

		var cd_base: int = i * 4
		multimesh.set_instance_custom_data(i, Color(
			result.vegetation_custom_data[cd_base],
			result.vegetation_custom_data[cd_base + 1],
			result.vegetation_custom_data[cd_base + 2],
			result.vegetation_custom_data[cd_base + 3]
		))

	grass_mm.multimesh = multimesh
	grass_mm.material_override = _get_grass_material()
	grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	chunk_node.add_child(grass_mm)
	return grass_mm


func replace_vegetation(chunk_instance: ChunkInstance, veg_data: PackedFloat32Array, veg_custom: PackedFloat32Array, veg_count: int) -> void:
	# Remove old grass
	if chunk_instance.grass_instance:
		chunk_instance.grass_instance.queue_free()
		chunk_instance.grass_instance = null

	if veg_count == 0:
		return

	var grass_mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _get_grass_mesh()
	multimesh.instance_count = veg_count

	for i in range(veg_count):
		var base: int = i * 12
		var t := Transform3D()
		t.basis.x = Vector3(veg_data[base], veg_data[base + 1], veg_data[base + 2])
		t.basis.y = Vector3(veg_data[base + 3], veg_data[base + 4], veg_data[base + 5])
		t.basis.z = Vector3(veg_data[base + 6], veg_data[base + 7], veg_data[base + 8])
		t.origin = Vector3(veg_data[base + 9], veg_data[base + 10], veg_data[base + 11])
		multimesh.set_instance_transform(i, t)

		var cd_base: int = i * 4
		multimesh.set_instance_custom_data(i, Color(
			veg_custom[cd_base], veg_custom[cd_base + 1],
			veg_custom[cd_base + 2], veg_custom[cd_base + 3]
		))

	grass_mm.multimesh = multimesh
	grass_mm.material_override = _get_grass_material()
	grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	chunk_instance.node.add_child(grass_mm)
	chunk_instance.grass_instance = grass_mm


func _get_grass_mesh() -> Mesh:
	if _grass_mesh == null:
		_grass_mesh = _build_grass_quad_mesh()
	return _grass_mesh


func _build_grass_quad_mesh() -> ArrayMesh:
	# 3-quad cross
	var hw: float = 0.25
	var h: float = 0.9

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# 3 quads at 0, 60, 120 degrees
	for i in range(3):
		var angle: float = deg_to_rad(i * 60.0)
		var dx: float = cos(angle) * hw
		var dz: float = sin(angle) * hw

		var base_idx: int = verts.size()

		verts.append(Vector3(-dx, 0.0, -dz))
		verts.append(Vector3( dx, 0.0,  dz))
		verts.append(Vector3( dx, h,    dz))
		verts.append(Vector3(-dx, h,   -dz))

		uvs.append(Vector2(0.0, 1.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(0.0, 0.0))

		var n := Vector3(-dz, 0.0, dx).normalized()
		for _j in range(4):
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


func _get_grass_material() -> ShaderMaterial:
	if _grass_material == null:
		var shader = load("res://shaders/environment/grass.gdshader") as Shader
		if shader:
			_grass_material = ShaderMaterial.new()
			_grass_material.shader = shader
			_grass_material.set_shader_parameter("noiseScale", 20.0)

			var noise_tex := NoiseTexture2D.new()
			noise_tex.width = 128
			noise_tex.height = 128

			var fnl := FastNoiseLite.new()
			fnl.frequency = 0.05
			noise_tex.noise = fnl
			_grass_material.set_shader_parameter("noise", noise_tex)

			var grass_tex_1 = load("res://assets/textures/grass-silhouette.png")
			var grass_tex_2 = load("res://assets/textures/grass-silhouette-2.png")
			_grass_material.set_shader_parameter("grass_texture", grass_tex_1)
			_grass_material.set_shader_parameter("grass_texture_2", grass_tex_2)

			var ground_tex = load("res://assets/textures/grass.png")
			_grass_material.set_shader_parameter("ground_texture", ground_tex)
	return _grass_material
