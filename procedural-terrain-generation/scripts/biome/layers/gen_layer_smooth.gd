class_name GenLayerSmooth
extends GenLayer

## Smooths biome boundaries by replacing isolated cells
## with values matching their neighbors

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)

# ============================================================================
# GENERATION
# ============================================================================

func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	# Fetch with 1-cell border
	var parent_width: int = width + 2
	var parent_height: int = height + 2
	var parent_values := parent.get_values(area_x - 1, area_z - 1, parent_width, parent_height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			var west: int = parent_values[x + (z + 1) * parent_width]
			var east: int = parent_values[(x + 2) + (z + 1) * parent_width]
			var north: int = parent_values[(x + 1) + z * parent_width]
			var south: int = parent_values[(x + 1) + (z + 2) * parent_width]
			var center: int = parent_values[(x + 1) + (z + 1) * parent_width]

			var idx: int = x + z * width

			# Check if horizontal neighbors match each other
			# AND vertical neighbors match each other
			if west == east and north == south:
				init_chunk_seed(area_x + x, area_z + z)
				# Both pairs match - randomly choose horizontal or vertical
				result[idx] = west if next_int(2) == 0 else north
			elif west == east:
				# Horizontal neighbors match - use their value
				result[idx] = west
			elif north == south:
				# Vertical neighbors match - use their value
				result[idx] = north
			else:
				# No clear pattern - keep original
				result[idx] = center

	return result
