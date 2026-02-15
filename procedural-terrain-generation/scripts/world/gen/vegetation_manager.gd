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


func _get_grass_mesh() -> Mesh:
	if _grass_mesh == null:
		var grass_scene: PackedScene = load("res://assets/environment/grass.glb")
		if grass_scene:
			var grass_node: Node3D = grass_scene.instantiate()
			for child in grass_node.get_children():
				if child is MeshInstance3D:
					_grass_mesh = child.mesh
					break
			grass_node.queue_free()
		else:
			push_error("VegetationManager: Failed to load grass.glb")
	return _grass_mesh


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
	return _grass_material
