class_name GenLayerBiomeEdge
extends GenLayer

## Enforces biome compatibility rules by inserting transition biomes
## Prevents incompatible biomes from being directly adjacent

# INITIALIZATION

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)

# GENERATION

func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	# Fetch with 1-cell border
	var parent_width: int = width + 2
	var parent_height: int = height + 2
	var parent_values := parent.get_values(area_x - 1, area_z - 1, parent_width, parent_height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			var center: int = parent_values[(x + 1) + (z + 1) * parent_width]
			var north: int = parent_values[(x + 1) + z * parent_width]
			var south: int = parent_values[(x + 1) + (z + 2) * parent_width]
			var west: int = parent_values[x + (z + 1) * parent_width]
			var east: int = parent_values[(x + 2) + (z + 1) * parent_width]

			var idx: int = x + z * width

			# Apply edge rules
			var new_biome: int = _apply_edge_rules(center, north, south, west, east)
			result[idx] = new_biome

	return result


func _apply_edge_rules(center: int, north: int, south: int, west: int, east: int) -> int:
	# Rule 1: Desert touching frozen biomes -> Plains
	if center == TerrainConstants.Biome.DESERT:
		if _is_frozen(north) or _is_frozen(south) or _is_frozen(west) or _is_frozen(east):
			return TerrainConstants.Biome.PLAINS

	# Rule 2: Jungle touching incompatible -> Forest edge
	if center == TerrainConstants.Biome.JUNGLE:
		if not _is_jungle_compatible(north) or not _is_jungle_compatible(south) or \
		   not _is_jungle_compatible(west) or not _is_jungle_compatible(east):
			return TerrainConstants.Biome.FOREST

	# Rule 3: Snow Peaks touching warm biomes -> Mountains
	if center == TerrainConstants.Biome.SNOW_PEAKS:
		if _is_warm(north) or _is_warm(south) or _is_warm(west) or _is_warm(east):
			return TerrainConstants.Biome.MOUNTAINS

	# Rule 3b: Mountains touching low-land biomes -> Hills (gradual transition)
	if center == TerrainConstants.Biome.MOUNTAINS:
		if _is_lowland(north) or _is_lowland(south) or _is_lowland(west) or _is_lowland(east):
			return TerrainConstants.Biome.HILLS

	# Rule 4: Tundra touching warm biomes -> Plains/Forest
	if center == TerrainConstants.Biome.TUNDRA:
		if _is_warm(north) or _is_warm(south) or _is_warm(west) or _is_warm(east):
			return TerrainConstants.Biome.PLAINS if next_int(2) == 0 else TerrainConstants.Biome.FOREST

	# Rule 5: Check general temperature compatibility
	if not _all_neighbors_compatible(center, north, south, west, east):
		return _get_transition_biome(center)

	return center


func _is_frozen(biome: int) -> bool:
	return biome == TerrainConstants.Biome.TUNDRA or biome == TerrainConstants.Biome.SNOW_PEAKS


func _is_warm(biome: int) -> bool:
	return biome == TerrainConstants.Biome.DESERT or biome == TerrainConstants.Biome.JUNGLE


func _is_lowland(biome: int) -> bool:
	# Biomes with low base height — mountains next to these get replaced with hills
	return biome == TerrainConstants.Biome.PLAINS or \
		   biome == TerrainConstants.Biome.FOREST or \
		   biome == TerrainConstants.Biome.DESERT or \
		   biome == TerrainConstants.Biome.JUNGLE or \
		   biome == TerrainConstants.Biome.BEACH or \
		   biome == TerrainConstants.Biome.TUNDRA


func _is_jungle_compatible(biome: int) -> bool:
	# Jungle can border: jungle, forest, plains, ocean, beach
	return biome == TerrainConstants.Biome.JUNGLE or \
		   biome == TerrainConstants.Biome.FOREST or \
		   biome == TerrainConstants.Biome.PLAINS or \
		   biome == TerrainConstants.Biome.OCEAN or \
		   biome == TerrainConstants.Biome.BEACH


func _can_biomes_be_neighbors(biome_a: int, biome_b: int) -> bool:
	if biome_a == biome_b:
		return true

	var temp_a: int = TerrainConstants.BIOME_TEMPERATURES.get(biome_a, TerrainConstants.TempCategory.MEDIUM)
	var temp_b: int = TerrainConstants.BIOME_TEMPERATURES.get(biome_b, TerrainConstants.TempCategory.MEDIUM)

	# Ocean can border anything
	if temp_a == TerrainConstants.TempCategory.OCEAN or temp_b == TerrainConstants.TempCategory.OCEAN:
		return true

	# Medium temperature can border anything
	if temp_a == TerrainConstants.TempCategory.MEDIUM or temp_b == TerrainConstants.TempCategory.MEDIUM:
		return true

	# Same temperature category can border
	return temp_a == temp_b


func _all_neighbors_compatible(center: int, north: int, south: int, west: int, east: int) -> bool:
	return _can_biomes_be_neighbors(center, north) and \
		   _can_biomes_be_neighbors(center, south) and \
		   _can_biomes_be_neighbors(center, west) and \
		   _can_biomes_be_neighbors(center, east)


func _get_transition_biome(biome: int) -> int:
	# Return a suitable transition biome based on original
	var temp: int = TerrainConstants.BIOME_TEMPERATURES.get(biome, TerrainConstants.TempCategory.MEDIUM)

	match temp:
		TerrainConstants.TempCategory.WARM:
			return TerrainConstants.Biome.PLAINS
		TerrainConstants.TempCategory.COLD:
			return TerrainConstants.Biome.FOREST if next_int(2) == 0 else TerrainConstants.Biome.MOUNTAINS
		_:
			return TerrainConstants.Biome.PLAINS
