class_name GenLayerAddIsland
extends GenLayer

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)


func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	var parent_width:  int = width + 2
	var parent_height: int = height + 2
	var parent_values := parent.get_values(area_x - 1, area_z - 1, parent_width, parent_height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			var center: int = parent_values[(x + 1) + (z + 1) * parent_width]
			var north:  int = parent_values[(x + 1) + z * parent_width]
			var south:  int = parent_values[(x + 1) + (z + 2) * parent_width]
			var west:   int = parent_values[x + (z + 1) * parent_width]
			var east:   int = parent_values[(x + 2) + (z + 1) * parent_width]

			var idx: int = x + z * width

			if center == 0:
				var land_neighbors: int = 0
				if north != 0:
					land_neighbors += 1
				if south != 0:
					land_neighbors += 1
				if west != 0:
					land_neighbors += 1
				if east != 0:
					land_neighbors += 1

				if land_neighbors >= 3:
					result[idx] = 1 if next_int(2) == 0 else center
				elif land_neighbors >= 1 and next_int(3) == 0:
					result[idx] = 1
				else:
					result[idx] = center
			else:
				var land_neighbors: int = 0
				if north != 0:
					land_neighbors += 1
				if south != 0:
					land_neighbors += 1
				if west != 0:
					land_neighbors += 1
				if east != 0:
					land_neighbors += 1

				if land_neighbors == 0:
					result[idx] = 0 if next_int(5) == 0 else center
				else:
					result[idx] = center

	return result
