class_name GenLayerIsland
extends GenLayer

## Initial layer that creates basic land/ocean distribution
## This is the first layer in the chain - has no parent

# ============================================================================
# CONFIGURATION
# ============================================================================

## Chance of generating land (1 in land_chance)
var land_chance: int = 10

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_base_seed: int, p_land_chance: int = 10) -> void:
	super._init(p_base_seed, null)
	land_chance = p_land_chance

# ============================================================================
# GENERATION
# ============================================================================

func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			# Special case: force land at origin for spawn point
			if area_x + x == 0 and area_z + z == 0:
				result[x + z * width] = 1  # Land
			else:
				# 1 in land_chance of being land
				result[x + z * width] = 1 if next_int(land_chance) == 0 else 0

	return result
