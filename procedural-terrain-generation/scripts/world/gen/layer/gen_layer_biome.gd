class_name GenLayerBiome
extends GenLayer

const WARM_BIOMES: Array[int] = [  # desert-heavy
	TerrainConstants.Biome.DESERT,
	TerrainConstants.Biome.DESERT,
	TerrainConstants.Biome.PLAINS,
	TerrainConstants.Biome.JUNGLE,
]

const MEDIUM_BIOMES: Array[int] = [  # most variety
	TerrainConstants.Biome.FOREST,
	TerrainConstants.Biome.FOREST,
	TerrainConstants.Biome.PLAINS,
	TerrainConstants.Biome.PLAINS,
	TerrainConstants.Biome.HILLS,
	TerrainConstants.Biome.MOUNTAINS,
]

const COLD_BIOMES: Array[int] = [
	TerrainConstants.Biome.FOREST,
	TerrainConstants.Biome.MOUNTAINS,
	TerrainConstants.Biome.TUNDRA,
	TerrainConstants.Biome.HILLS,
]

const FROZEN_BIOMES: Array[int] = [  # tundra/snow heavy
	TerrainConstants.Biome.TUNDRA,
	TerrainConstants.Biome.TUNDRA,
	TerrainConstants.Biome.SNOW_PEAKS,
	TerrainConstants.Biome.SNOW_PEAKS,
]

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)


func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	var parent_values := parent.get_values(area_x, area_z, width, height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			var climate: int = parent_values[x + z * width]
			var idx: int = x + z * width

			match climate:
				0:
					result[idx] = TerrainConstants.Biome.OCEAN
				1:
					result[idx] = _select_from_array(WARM_BIOMES)
				2:
					result[idx] = _select_from_array(MEDIUM_BIOMES)
				3:
					result[idx] = _select_from_array(COLD_BIOMES)
				4:
					result[idx] = _select_from_array(FROZEN_BIOMES)
				_:
					result[idx] = TerrainConstants.Biome.PLAINS

	return result


func _select_from_array(arr: Array[int]) -> int:
	return arr[next_int(arr.size())]
