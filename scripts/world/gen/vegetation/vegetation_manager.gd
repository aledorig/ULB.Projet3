class_name VegetationManager
extends RefCounted

## Handles grass mesh/material caching and vegetation instantiation
## from pre-computed VegetationData

const GLTF_BASE: String = "res://assets/environment/StylizedStuff/glTF/"

var _grass_mesh:      Mesh = null
var _grass_material:  ShaderMaterial = null

var _pine_meshes:    Array = []  # [5] Mesh, Pine_1..5
var _foliage_meshes: Array = []  # [6] Mesh
var _meshes_loaded:  bool = false


func create_vegetation(chunk_node: Node3D, veg: VegetationData) -> MultiMeshInstance3D:
	if veg.grass_count == 0:
		return null

	var grass_mm := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _get_grass_mesh()
	multimesh.instance_count = veg.grass_count
	multimesh.buffer = veg.grass_buffer  # one native call, no GDScript loop

	grass_mm.multimesh = multimesh
	grass_mm.material_override = _get_grass_material()
	grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	chunk_node.add_child(grass_mm)
	return grass_mm


func replace_vegetation(chunk_instance: ChunkInstance, grass_buffer: PackedFloat32Array, veg_count: int) -> void:
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
	multimesh.buffer = grass_buffer  # one native call, no GDScript loop

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
	# 3-quad triangle pattern: each quad is offset to form an equilateral triangle cross-section
	var hw: float = 0.5
	var h: float = 1.3
	var offset: float = 0.15  # perpendicular offset to create triangle shape

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# 3 quads at 0, 120, 240 degrees (equilateral triangle edges)
	for i in range(3):
		var angle: float = deg_to_rad(i * 120.0)
		var dx: float = cos(angle) * hw
		var dz: float = sin(angle) * hw

		# Perpendicular direction for offset (rotate 90 degrees)
		var perp_x: float = -sin(angle) * offset
		var perp_z: float = cos(angle) * offset

		var base_idx: int = verts.size()

		verts.append(Vector3(-dx + perp_x, 0.0, -dz + perp_z))
		verts.append(Vector3( dx + perp_x, 0.0,  dz + perp_z))
		verts.append(Vector3( dx + perp_x, h,    dz + perp_z))
		verts.append(Vector3(-dx + perp_x, h,   -dz + perp_z))

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

			var grass_tex_1 = load("res://assets/textures/grass-silhouette.png")
			var grass_tex_2 = load("res://assets/textures/grass-silhouette-2.png")
			_grass_material.set_shader_parameter("grass_texture", grass_tex_1)
			_grass_material.set_shader_parameter("grass_texture_2", grass_tex_2)

			var ground_tex = load("res://assets/textures/grass.png")
			_grass_material.set_shader_parameter("ground_texture", ground_tex)
	return _grass_material


func _ensure_meshes_loaded() -> void:
	if _meshes_loaded:
		return
	_meshes_loaded = true

	_pine_meshes.resize(5)
	for i in range(5):
		_pine_meshes[i] = _load_mesh_from_gltf(GLTF_BASE + "Pine_%d.gltf" % (i + 1))

	var foliage_names: Array[String] = [
		"Bush_Common", "Fern_1", "Mushroom_Common",
		"Flower_3_Group", "Plant_7", "Plant_7_Big"
	]
	_foliage_meshes.resize(6)
	for i in range(6):
		_foliage_meshes[i] = _load_mesh_from_gltf(GLTF_BASE + foliage_names[i] + ".gltf")


func _load_mesh_from_gltf(path: String) -> Mesh:
	var scene: PackedScene = load(path)
	if not scene:
		push_error("VegetationManager: Failed to load " + path)
		return null
	var instance: Node3D = scene.instantiate()
	var mesh: Mesh = null
	# Search recursively for MeshInstance3D
	mesh = _find_mesh_recursive(instance)
	instance.free()
	return mesh


func _find_mesh_recursive(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var m: Mesh = _find_mesh_recursive(child)
		if m:
			return m
	return null


func _create_multimesh_instance(parent: Node3D, mesh: Mesh,
		transforms: PackedFloat32Array, count: int,
		vis_range: float, shadows: bool = false) -> MultiMeshInstance3D:
	if count == 0 or mesh == null:
		return null

	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = transforms  # one native call, no GDScript loop

	mmi.multimesh = mm
	if shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_end = vis_range
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	parent.add_child(mmi)
	return mmi


func create_tree(chunk_node: Node3D, veg: VegetationData) -> MultiMeshInstance3D:
	_ensure_meshes_loaded()
	return _create_multimesh_instance(
		chunk_node, _pine_meshes[veg.tree_variant_id],
		veg.tree_transforms, veg.tree_count,
		TerrainConfig.VIS_RANGE_TREE, true
	)


func create_foliage(chunk_node: Node3D, veg: VegetationData) -> Array:
	_ensure_meshes_loaded()
	var result: Array = []
	result.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	for i in range(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK):
		var type_id: int = veg.foliage_variant_ids[i]
		result[i] = _create_multimesh_instance(
			chunk_node, _foliage_meshes[type_id],
			veg.foliage_transforms[i], veg.foliage_counts[i],
			TerrainConfig.VIS_RANGE_FOLIAGE
		)
	return result
