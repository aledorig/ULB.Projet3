class_name VegetationData
extends RefCounted

var grass_transforms:  PackedFloat32Array = PackedFloat32Array()
var grass_custom_data: PackedFloat32Array = PackedFloat32Array()
var grass_count:       int = 0

var tree_variant_id: int = 0
var tree_transforms:  PackedFloat32Array = PackedFloat32Array()
var tree_count:       int = 0

var foliage_variant_ids: PackedInt32Array = PackedInt32Array()
var foliage_transforms:  Array[PackedFloat32Array] = []
var foliage_counts:      PackedInt32Array = PackedInt32Array()


func _init() -> void:
	foliage_variant_ids.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	foliage_counts.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	foliage_transforms.resize(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK)
	for i in range(TerrainConfig.FOLIAGE_TYPES_PER_CHUNK):
		foliage_variant_ids[i] = 0
		foliage_counts[i] = 0
		foliage_transforms[i] = PackedFloat32Array()
