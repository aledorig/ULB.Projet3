class_name GenLayerBiome
extends GenLayer

## Converts climate zones into actual biome IDs
## Uses weighted selection arrays for each climate

# ============================================================================
# BIOME SELECTION ARRAYS
# ============================================================================

# Warm climate biomes (desert-heavy)
const WARM_BIOMES: Array[int] = [
	TerrainConstants.Biome.DESERT,
	TerrainConstants.Biome.DESERT,
	TerrainConstants.Biome.PLAINS,
	TerrainConstants.Biome.JUNGLE,
]

# Medium climate biomes (most variety)
const MEDIUM_BIOMES: Array[int] = [
	TerrainConstants.Biome.FOREST,
	TerrainConstants.Biome.FOREST,
	TerrainConstants.Biome.PLAINS,
	TerrainConstants.Biome.PLAINS,
	TerrainConstants.Biome.MOUNTAINS,
]

# Cold climate biomes
const COLD_BIOMES: Array[int] = [
	TerrainConstants.Biome.FOREST,
	TerrainConstants.Biome.MOUNTAINS,
	TerrainConstants.Biome.TUNDRA,
	TerrainConstants.Biome.PLAINS,
]

# Frozen climate biomes (tundra/snow heavy)
const FROZEN_BIOMES: Array[int] = [
	TerrainConstants.Biome.TUNDRA,
	TerrainConstants.Biome.TUNDRA,
	TerrainConstants.Biome.SNOW_PEAKS,
	TerrainConstants.Biome.SNOW_PEAKS,
]

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)

# ============================================================================
# GENERATION
# ============================================================================

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
					# Ocean
					result[idx] = TerrainConstants.Biome.OCEAN
				1:
					# Warm
					result[idx] = _select_from_array(WARM_BIOMES)
				2:
					# Medium
					result[idx] = _select_from_array(MEDIUM_BIOMES)
				3:
					# Cold
					result[idx] = _select_from_array(COLD_BIOMES)
				4:
					# Frozen
					result[idx] = _select_from_array(FROZEN_BIOMES)
				_:
					# Fallback
					result[idx] = TerrainConstants.Biome.PLAINS

	return result


func _select_from_array(arr: Array[int]) -> int:
	return arr[next_int(arr.size())]
