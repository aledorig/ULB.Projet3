class_name GenLayerSmooth
extends GenLayer

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)


func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
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

			if west == east and north == south:
				init_chunk_seed(area_x + x, area_z + z)
				result[idx] = west if next_int(2) == 0 else north
			elif west == east:
				result[idx] = west
			elif north == south:
				result[idx] = north
			else:
				result[idx] = center

	return result
