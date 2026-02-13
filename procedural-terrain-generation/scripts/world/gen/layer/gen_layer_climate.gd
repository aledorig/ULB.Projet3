class_name GenLayerClimate
extends GenLayer

# 0=Ocean, 1=Warm, 2=Medium, 3=Cold, 4=Frozen

func _init(p_base_seed: int, p_parent: GenLayer) -> void:
	super._init(p_base_seed, p_parent)


func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	var parent_values := parent.get_values(area_x, area_z, width, height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			var val: int = parent_values[x + z * width]
			var idx: int = x + z * width

			if val == 0:
				result[idx] = 0
			else:
				var r: int = next_int(6)
				match r:
					0:
						result[idx] = 4
					1:
						result[idx] = 3
					2, 3:
						result[idx] = 2
					4, 5:
						result[idx] = 1

	return result
