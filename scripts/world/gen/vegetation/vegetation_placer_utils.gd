class_name VegetationPlacerUtils
extends RefCounted

## Shared utilities for vegetation placers: grid queries, transform writing, variant picking


static func query_grid(terrain_gen: TerrainGenerator, chunk_size: int, vertex_spacing: float,
		chunk_pos: Vector2i, grid_res: int) -> Dictionary:
	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	var origin_x: float = chunk_pos.x * chunk_world_size
	var origin_z: float = chunk_pos.y * chunk_world_size

	var grid_spacing: float = chunk_world_size / float(grid_res - 1)
	var grid_total: int = grid_res * grid_res

	var grid_verts := PackedVector3Array()
	var grid_colors := PackedColorArray()
	grid_verts.resize(grid_total)
	grid_colors.resize(grid_total)

	terrain_gen.get_vertex_data_batch(
		origin_x, origin_z,
		grid_res, grid_res,
		grid_spacing,
		grid_verts, grid_colors
	)

	return {
		"verts": grid_verts,
		"colors": grid_colors,
		"grid_res": grid_res,
		"grid_spacing": grid_spacing,
		"chunk_world_size": chunk_world_size
	}


static func write_transform(arr: PackedFloat32Array, idx: int,
		local_x: float, height: float, local_z: float,
		scale: float, angle: float, y_offset: float,
		tilt_x: float = 0.0, tilt_z: float = 0.0) -> void:
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var base: int = idx * 12

	if tilt_x == 0.0 and tilt_z == 0.0:
		arr[base]      = cos_a * scale
		arr[base + 1]  = 0.0
		arr[base + 2]  = -sin_a * scale
		arr[base + 3]  = local_x
		arr[base + 4]  = 0.0
		arr[base + 5]  = scale
		arr[base + 6]  = 0.0
		arr[base + 7]  = height + y_offset
		arr[base + 8]  = sin_a * scale
		arr[base + 9]  = 0.0
		arr[base + 10] = cos_a * scale
		arr[base + 11] = local_z
	else:
		var cx: float = cos(tilt_x)
		var sx: float = sin(tilt_x)
		var cz: float = cos(tilt_z)
		var sz: float = sin(tilt_z)
		arr[base]      = (cos_a * cz + sin_a * sx * sz) * scale
		arr[base + 1]  = (cx * sz) * scale
		arr[base + 2]  = (-sin_a * cz + cos_a * sx * sz) * scale
		arr[base + 3]  = local_x
		arr[base + 4]  = (-cos_a * sz + sin_a * sx * cz) * scale
		arr[base + 5]  = (cx * cz) * scale
		arr[base + 6]  = (sin_a * sz + cos_a * sx * cz) * scale
		arr[base + 7]  = height + y_offset
		arr[base + 8]  = (sin_a * cx) * scale
		arr[base + 9]  = (-sx) * scale
		arr[base + 10] = (cos_a * cx) * scale
		arr[base + 11] = local_z


static func pick_variant(chunk_pos: Vector2i, total: int, salt: int) -> int:
	return absi((chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349663) ^ salt) % total


static func pick_variant_set(chunk_pos: Vector2i, total: int, pick_count: int, salt: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var base: int = pick_variant(chunk_pos, total, salt)
	var step: int = maxi(total / pick_count, 1)
	for i in range(pick_count):
		result.append((base + i * step) % total)
	return result
