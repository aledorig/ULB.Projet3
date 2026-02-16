class_name VegetationManager
extends RefCounted

## Facade that delegates to GrassManager, TreeManager, FoliageManager

var grass:   GrassManager   = GrassManager.new()
var tree:    TreeManager    = TreeManager.new()
var foliage: FoliageManager = FoliageManager.new()


func create_grass(chunk_node: Node3D, veg: VegetationData) -> MultiMeshInstance3D:
	return grass.create(chunk_node, veg)

func replace_grass(chunk_instance: ChunkInstance, grass_buffer: PackedFloat32Array, veg_count: int) -> void:
	grass.replace(chunk_instance, grass_buffer, veg_count)

func create_tree(chunk_node: Node3D, veg: VegetationData) -> MultiMeshInstance3D:
	return tree.create(chunk_node, veg)

func create_foliage(chunk_node: Node3D, veg: VegetationData) -> Array:
	return foliage.create(chunk_node, veg)

func replace_foliage(chunk_instance: ChunkInstance, foliage_data: Dictionary) -> void:
	foliage.replace(chunk_instance, foliage_data)
