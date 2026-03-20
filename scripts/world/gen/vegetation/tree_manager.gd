class_name TreeManager
extends RefCounted
## Loads Pine GLTF meshes and creates tree MMIs from VegetationData

const GLTF_BASE: String = "res://assets/environment/StylizedStuff/glTF/"

var _pine_meshes: Array = [] # [5] Mesh, Pine_1..5
var _loaded: bool = false


func create(chunk_node: Node3D, veg: VegetationData) -> MultiMeshInstance3D:
	_ensure_loaded()
	if veg.tree_count == 0:
		return null
	return _create_mmi(
		chunk_node,
		_pine_meshes[veg.tree_variant_id],
		veg.tree_transforms,
		veg.tree_count,
	)


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_pine_meshes.resize(TerrainConfig.TREE_VARIANTS)
	for i in range(TerrainConfig.TREE_VARIANTS):
		_pine_meshes[i] = _load_mesh_from_gltf(GLTF_BASE + "Pine_%d.gltf" % (i + 1))


func _create_mmi(
		parent: Node3D,
		mesh: Mesh,
		transforms: PackedFloat32Array,
		count: int,
) -> MultiMeshInstance3D:
	if count == 0 or mesh == null:
		return null

	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = transforms

	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_end = TerrainConfig.VIS_RANGE_TREE
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	parent.add_child(mmi)
	return mmi


func _load_mesh_from_gltf(path: String) -> Mesh:
	var scene: PackedScene = load(path)
	if not scene:
		push_error("TreeManager: Failed to load " + path)
		return null
	var instance: Node3D = scene.instantiate()
	var mesh: Mesh = _find_mesh_recursive(instance)
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
