class_name GenLayerShore
extends GenLayer

const SHORE_RADIUS: int = 2

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)


func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
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

			if _is_ocean(center):
				result[idx] = center
				continue

			var has_ocean_nearby: bool = _check_ocean_in_radius(
				parent_values, x + border, z + border, parent_width
			)

			if not has_ocean_nearby:
				result[idx] = center
				continue

			result[idx] = _apply_shore_rules(center)

	return result


func _check_ocean_in_radius(values: PackedInt32Array, cx: int, cz: int, pw: int) -> bool:
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

	return TerrainConstants.Biome.BEACH


func _is_ocean(biome: int) -> bool:
	return biome == TerrainConstants.Biome.OCEAN
