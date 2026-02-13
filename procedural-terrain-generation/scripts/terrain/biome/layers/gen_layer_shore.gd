class_name GenLayerShore
extends GenLayer

## Adds beach biomes between land and ocean
## Uses extended radius for wider shores

# CONFIGURATION

## How many cells to check for ocean (larger = wider beaches)
const SHORE_RADIUS: int = 2

# INITIALIZATION

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)

# GENERATION

func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	# Fetch with extended border for wider shore detection
	var border: int = SHORE_RADIUS
	var parent_width: int = width + border * 2
	var parent_height: int = height + border * 2
	var parent_values := parent.get_values(area_x - border, area_z - border, parent_width, parent_height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			var center: int = parent_values[(x + border) + (z + border) * parent_width]
			var idx: int = x + z * width

			# Ocean stays ocean
			if _is_ocean(center):
				result[idx] = center
				continue

			# Check extended radius for ocean
			var has_ocean_nearby: bool = _check_ocean_in_radius(
				parent_values, x + border, z + border, parent_width
			)

			if not has_ocean_nearby:
				result[idx] = center
				continue

			# Apply shore rules
			result[idx] = _apply_shore_rules(center)

	return result


func _check_ocean_in_radius(values: PackedInt32Array, cx: int, cz: int, pw: int) -> bool:
	## Check if any cell within SHORE_RADIUS is ocean
	for dz in range(-SHORE_RADIUS, SHORE_RADIUS + 1):
		for dx in range(-SHORE_RADIUS, SHORE_RADIUS + 1):
			if dx == 0 and dz == 0:
				continue
			var val: int = values[(cx + dx) + (cz + dz) * pw]
			if _is_ocean(val):
				return true
	return false


func _apply_shore_rules(center: int) -> int:
	# Mountains don't become beaches (creates cliffs)
	if center == TerrainConstants.Biome.MOUNTAINS or center == TerrainConstants.Biome.SNOW_PEAKS:
		return center

	# Everything else becomes beach
	return TerrainConstants.Biome.BEACH


func _is_ocean(biome: int) -> bool:
	return biome == TerrainConstants.Biome.OCEAN
