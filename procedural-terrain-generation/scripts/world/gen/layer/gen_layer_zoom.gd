class_name GenLayerZoom
extends GenLayer

var fuzzy: bool = false

func _init(p_base_seed: int, p_parent: GenLayer, p_fuzzy: bool = false) -> void:
	super._init(p_base_seed, p_parent)
	fuzzy = p_fuzzy


func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	var parent_x: int = area_x >> 1
	var parent_z: int = area_z >> 1
	var parent_width: int = (width >> 1) + 2
	var parent_height: int = (height >> 1) + 2

	var parent_values := parent.get_values(parent_x, parent_z, parent_width, parent_height)
	var temp_width: int = (parent_width - 1) * 2
	var temp_height: int = (parent_height - 1) * 2
	var temp := PackedInt32Array()
	temp.resize(temp_width * temp_height)

	for pz in range(parent_height - 1):
		var temp_idx: int = (pz * 2) * temp_width
		var top_left: int = parent_values[pz * parent_width]
		var bottom_left: int = parent_values[(pz + 1) * parent_width]

		for px in range(parent_width - 1):
			init_chunk_seed((parent_x + px) * 2, (parent_z + pz) * 2)

			var top_right: int = parent_values[px + 1 + pz * parent_width]
			var bottom_right: int = parent_values[px + 1 + (pz + 1) * parent_width]

			# Top-left corner: unchanged
			temp[temp_idx] = top_left

			# Bottom-left corner: interpolate vertically
			temp[temp_idx + temp_width] = _select_random_2(top_left, bottom_left)

			# Top-right corner: interpolate horizontally
			temp[temp_idx + 1] = _select_random_2(top_left, top_right)

			# Center: interpolate all 4
			if fuzzy:
				temp[temp_idx + 1 + temp_width] = _select_random_4(top_left, top_right, bottom_left, bottom_right)
			else:
				temp[temp_idx + 1 + temp_width] = select_mode_or_random(top_left, top_right, bottom_left, bottom_right)

			top_left = top_right
			bottom_left = bottom_right
			temp_idx += 2

	var result := PackedInt32Array()
	result.resize(width * height)

	var offset_x: int = area_x & 1
	var offset_z: int = area_z & 1

	for z in range(height):
		for x in range(width):
			result[x + z * width] = temp[(x + offset_x) + (z + offset_z) * temp_width]

	return result


func _select_random_2(a: int, b: int) -> int:
	return a if next_int(2) == 0 else b


func _select_random_4(a: int, b: int, c: int, d: int) -> int:
	var r: int = next_int(4)
	match r:
		0: return a
		1: return b
		2: return c
		_: return d


static func magnify(base_seed: int, layer: GenLayer, count: int) -> GenLayer:
	var result := layer
	for i in range(count):
		result = GenLayerZoom.new(base_seed + i, result)
	return result
