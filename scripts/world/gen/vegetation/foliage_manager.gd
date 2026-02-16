class_name FoliageManager
extends RefCounted

## Loads foliage GLTF meshes and creates/replaces foliage MMIs from VegetationData

const GLTF_BASE: String = "res://assets/environment/StylizedStuff/glTF/"

var _foliage_meshes: Array = []  # [14] Mesh
var _loaded: bool = false

const FOLIAGE_NAMES: Array[String] = [
	"Bush_Common", "Bush_Common_Flowers", "Fern_1",
	"Mushroom_Common", "Mushroom_Laetiporus",
	"Flower_3_Group", "Flower_3_Single",
	"Flower_4_Group", "Flower_4_Single",
	"Plant_7", "Plant_7_Big", "Plant_1",
	"Clover_1", "Clover_2"
]


func create(chunk_node: Node3D, veg: VegetationData) -> Array:
	_ensure_loaded()
	var result: Array = []
	result.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	for i in range(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK):
		var type_id: int = veg.foliage_variant_ids[i]
		result[i] = _create_mmi(
			chunk_node, _foliage_meshes[type_id],
			veg.foliage_transforms[i], veg.foliage_counts[i]
		)
	return result


func replace(chunk_instance: ChunkInstance, foliage_data: Dictionary) -> void:
	_ensure_loaded()

	# Free old foliage
	for i in range(chunk_instance.foliage_instances.size()):
		if chunk_instance.foliage_instances[i]:
			chunk_instance.foliage_instances[i].queue_free()
			chunk_instance.foliage_instances[i] = null

	var variant_ids: PackedInt32Array = foliage_data.variant_ids
	var transforms: Array = foliage_data.transforms
	var counts: PackedInt32Array = foliage_data.counts

	for i in range(variant_ids.size()):
		var type_id: int = variant_ids[i]
		chunk_instance.foliage_instances[i] = _create_mmi(
			chunk_instance.node, _foliage_meshes[type_id],
			transforms[i], counts[i]
		)


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_foliage_meshes.resize(FOLIAGE_NAMES.size())
	for i in range(FOLIAGE_NAMES.size()):
		_foliage_meshes[i] = _load_mesh_from_gltf(GLTF_BASE + FOLIAGE_NAMES[i] + ".gltf")


func _create_mmi(parent: Node3D, mesh: Mesh,
		transforms: PackedFloat32Array, count: int) -> MultiMeshInstance3D:
	if count == 0 or mesh == null:
		return null

	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = transforms

	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_end = TerrainConfig.VIS_RANGE_FOLIAGE
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	parent.add_child(mmi)
	return mmi


func _load_mesh_from_gltf(path: String) -> Mesh:
	var scene: PackedScene = load(path)
	if not scene:
		push_error("FoliageManager: Failed to load " + path)
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
