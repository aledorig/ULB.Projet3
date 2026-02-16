class_name VegetationPlacer
extends RefCounted

## Thread-safe vegetation placement
## Pre-computes a height/climate grid via batch noise, then samples from it
## avoids thousands of individual noise calls

const LOD_CANDIDATES: Array[int] = [12000, 2400, 200]
const LOD_GRID_RES: Array[int] = [32, 16, 8]

const SAMPLE_JITTER: float = 0.85
const FOLIAGE_DENSITIES: Array[float] = [0.35, 0.30, 0.12, 0.20, 0.25, 0.12]

var terrain_gen:    TerrainGenerator
var chunk_size:     int
var vertex_spacing: float
var rng:            RandomNumberGenerator


func _init(p_terrain_gen: TerrainGenerator, p_chunk_size: int, p_vertex_spacing: float, p_seed: int, p_chunk_pos: Vector2i) -> void:
	terrain_gen = p_terrain_gen
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing

	rng = RandomNumberGenerator.new()
	rng.seed = p_seed ^ (p_chunk_pos.x * 73856093) ^ (p_chunk_pos.y * 19349663)


static func _write_transform(arr: PackedFloat32Array, idx: int,
		local_x: float, height: float, local_z: float,
		scale: float, angle: float, y_offset: float,
		tilt_x: float = 0.0, tilt_z: float = 0.0) -> void:
	# Y-rotation
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var base: int = idx * 12

	if tilt_x == 0.0 and tilt_z == 0.0:
		# Fast path: Y-rotation only
		arr[base]      = cos_a * scale
		arr[base + 1]  = 0.0
		arr[base + 2]  = sin_a * scale
		arr[base + 3]  = 0.0
		arr[base + 4]  = scale
		arr[base + 5]  = 0.0
		arr[base + 6]  = -sin_a * scale
		arr[base + 7]  = 0.0
		arr[base + 8]  = cos_a * scale
	else:
		# Tilted: rotate around X by tilt_x, Z by tilt_z, then Y by angle
		var cx: float = cos(tilt_x)
		var sx: float = sin(tilt_x)
		var cz: float = cos(tilt_z)
		var sz: float = sin(tilt_z)
		# Combined rotation: Ry * Rx * Rz (applied right to left)
		arr[base]      = (cos_a * cz + sin_a * sx * sz) * scale
		arr[base + 1]  = (-cos_a * sz + sin_a * sx * cz) * scale
		arr[base + 2]  = (sin_a * cx) * scale
		arr[base + 3]  = (cx * sz) * scale
		arr[base + 4]  = (cx * cz) * scale
		arr[base + 5]  = (-sx) * scale
		arr[base + 6]  = (-sin_a * cz + cos_a * sx * sz) * scale
		arr[base + 7]  = (sin_a * sz + cos_a * sx * cz) * scale
		arr[base + 8]  = (cos_a * cx) * scale

	arr[base + 9]  = local_x
	arr[base + 10] = height + y_offset
	arr[base + 11] = local_z


static func _pick_variant(chunk_pos: Vector2i, total: int, salt: int) -> int:
	return absi((chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349663) ^ salt) % total


static func _pick_variant_pair(chunk_pos: Vector2i, total: int, salt: int) -> PackedInt32Array:
	var first: int = _pick_variant(chunk_pos, total, salt)
	var second: int = (first + 1 + _pick_variant(chunk_pos, total - 1, salt + 7)) % total
	return PackedInt32Array([first, second])


func _query_shared_grid(chunk_pos: Vector2i) -> Dictionary:
	var grid_res: int = 8
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


func generate_vegetation(chunk_pos: Vector2i, lod_level: int) -> Dictionary:
	var result := {
		"transforms": PackedFloat32Array(),
		"custom_data": PackedFloat32Array(),
		"count": 0
	}

	if lod_level >= LOD_CANDIDATES.size() or LOD_CANDIDATES[lod_level] == 0:
		return result

	var candidates: int = LOD_CANDIDATES[lod_level]
	var grid_res: int = LOD_GRID_RES[lod_level] if lod_level < LOD_GRID_RES.size() else 8
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

	var transforms := PackedFloat32Array()
	transforms.resize(candidates * 12)
	var custom_data := PackedFloat32Array()
	custom_data.resize(candidates * 4)
	var count: int = 0

	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)
	var inv_grid_spacing: float = 1.0 / grid_spacing
	var max_gi: int = grid_res - 2

	for gz in range(grid_side):
		for gx in range(grid_side):
			if count >= candidates:
				break

			# Jittered position within cell
			var jx: float = rng.randf() * SAMPLE_JITTER
			var jz: float = rng.randf() * SAMPLE_JITTER
			var local_x: float = (float(gx) + jx) * cell_size
			var local_z: float = (float(gz) + jz) * cell_size

			# Map to grid coordinates
			var gi: int = clampi(int(local_x * inv_grid_spacing), 0, max_gi)
			var gj: int = clampi(int(local_z * inv_grid_spacing), 0, max_gi)
			var grid_idx: int = gj * grid_res + gi

			# Height from grid
			var height: float = grid_verts[grid_idx].y

			if height < TerrainConfig.GRASS_MIN_HEIGHT or height > TerrainConfig.GRASS_MAX_HEIGHT:
				continue

			# Slope from grid neighbors (cheap — no noise calls)
			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + grid_res].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < TerrainConfig.MIN_NORMAL_Y:
				continue

			# Climate from grid
			var climate: Color = grid_colors[grid_idx]
			var temperature: float = climate.r
			var moisture: float = climate.g

			# Skip desert (hot + dry)
			if temperature > TerrainConfig.DESERT_TEMP and moisture < TerrainConfig.DESERT_MOIST:
				continue

			# Thin out at high altitude (rock zone starts ~60)
			var alt_factor: float = clampf(1.0 - (height - 60.0) / 60.0, 0.1, 1.0)

			# Density based on moisture and altitude
			var density_chance: float = clampf(moisture * 1.5, 0.3, 1.0) * alt_factor
			if rng.randf() > density_chance:
				continue

			# Build transform
			# random Y rotation only
			var angle: float = rng.randf() * TAU
			var cos_a: float = cos(angle)
			var sin_a: float = sin(angle)

			var base: int = count * 12
			transforms[base]      = cos_a
			transforms[base + 1]  = 0.0
			transforms[base + 2]  = sin_a
			transforms[base + 3]  = 0.0
			transforms[base + 4]  = 1.0
			transforms[base + 5]  = 0.0
			transforms[base + 6]  = -sin_a
			transforms[base + 7]  = 0.0
			transforms[base + 8]  = cos_a
			transforms[base + 9]  = local_x
			transforms[base + 10] = height - 0.3
			transforms[base + 11] = local_z

			var cd_base: int = count * 4
			custom_data[cd_base]     = temperature
			custom_data[cd_base + 1] = moisture
			custom_data[cd_base + 2] = float(rng.randi() % 2)  # 0.0 or 1.0: silhouette texture variant
			custom_data[cd_base + 3] = 0.0

			count += 1

	transforms.resize(count * 12)
	custom_data.resize(count * 4)

	result.transforms = transforms
	result.custom_data = custom_data
	result.count = count
	return result


func generate_trees(chunk_pos: Vector2i, grid: Dictionary) -> Dictionary:
	var variant_id: int = _pick_variant(chunk_pos, TerrainConfig.TREE_VARIANTS, 1)
	var candidates: int = TerrainConfig.TREE_CANDIDATES

	var grid_verts: PackedVector3Array = grid["verts"]
	var grid_colors: PackedColorArray = grid["colors"]
	var grid_res: int = grid["grid_res"]
	var grid_spacing: float = grid["grid_spacing"]
	var chunk_world_size: float = grid["chunk_world_size"]

	var transforms := PackedFloat32Array()
	transforms.resize(candidates * 12)
	var count: int = 0

	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)
	var inv_grid_spacing: float = 1.0 / grid_spacing
	var max_gi: int = grid_res - 2

	for gz in range(grid_side):
		for gx in range(grid_side):
			if count >= candidates:
				break

			# Jittered position within cell
			var jx: float = rng.randf() * SAMPLE_JITTER
			var jz: float = rng.randf() * SAMPLE_JITTER
			var local_x: float = (float(gx) + jx) * cell_size
			var local_z: float = (float(gz) + jz) * cell_size

			# Map to grid coordinates
			var gi: int = clampi(int(local_x * inv_grid_spacing), 0, max_gi)
			var gj: int = clampi(int(local_z * inv_grid_spacing), 0, max_gi)
			var grid_idx: int = gj * grid_res + gi

			# Height from grid
			var height: float = grid_verts[grid_idx].y

			if height < TerrainConfig.TREE_MIN_HEIGHT or height > TerrainConfig.TREE_MAX_HEIGHT:
				continue

			# Slope from grid neighbors
			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + grid_res].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < TerrainConfig.MIN_NORMAL_Y:
				continue

			# Climate from grid
			var climate: Color = grid_colors[grid_idx]
			var temp_01: float = climate.r
			var moist_01: float = climate.g

			# Skip cold zone trees
			if temp_01 < TerrainConfig.TREE_MIN_TEMP:
				continue

			# Skip desert (hot + dry)
			if temp_01 > TerrainConfig.DESERT_TEMP and moist_01 < TerrainConfig.DESERT_MOIST:
				continue

			# Biome placement rules
			var place: bool = false

			# Forest: temp_01 in 0.35-0.7 AND moist_01 > 0.55
			if temp_01 >= 0.35 and temp_01 <= 0.7 and moist_01 > 0.55:
				place = true
			# Jungle: temp_01 > 0.7 AND moist_01 > 0.45, only 20% chance
			elif temp_01 > 0.7 and moist_01 > 0.45 and rng.randf() < 0.2:
				place = true

			if not place:
				continue

			# Density filter
			if rng.randf() > TerrainConfig.TREE_DENSITY:
				continue

			# Build transform with random Y rotation, slight tilt, random scale
			var angle: float = rng.randf() * TAU
			var tree_scale: float = rng.randf_range(TerrainConfig.TREE_SCALE_MIN, TerrainConfig.TREE_SCALE_MAX)
			var tilt_x: float = rng.randf_range(-0.06, 0.06)  # ~3.4 degrees max
			var tilt_z: float = rng.randf_range(-0.06, 0.06)
			_write_transform(transforms, count, local_x, height, local_z, tree_scale, angle, TerrainConfig.TREE_Y_OFFSET, tilt_x, tilt_z)
			count += 1

	transforms.resize(count * 12)

	return {
		"variant_id": variant_id,
		"transforms": transforms,
		"count": count
	}


func generate_foliage(chunk_pos: Vector2i, grid: Dictionary) -> Dictionary:
	var picked: PackedInt32Array = _pick_variant_pair(chunk_pos, TerrainConfig.FOLIAGE_TOTAL_TYPES, 3)
	var candidates: int = TerrainConfig.FOLIAGE_CANDIDATES

	var grid_verts: PackedVector3Array = grid["verts"]
	var grid_colors: PackedColorArray = grid["colors"]
	var grid_res: int = grid["grid_res"]
	var grid_spacing: float = grid["grid_spacing"]
	var chunk_world_size: float = grid["chunk_world_size"]

	var transforms_0 := PackedFloat32Array()
	var transforms_1 := PackedFloat32Array()
	transforms_0.resize(candidates * 12)
	transforms_1.resize(candidates * 12)
	var count_0: int = 0
	var count_1: int = 0

	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)
	var inv_grid_spacing: float = 1.0 / grid_spacing
	var max_gi: int = grid_res - 2

	for gz in range(grid_side):
		for gx in range(grid_side):
			if count_0 + count_1 >= candidates:
				break

			# Jittered position within cell
			var jx: float = rng.randf() * SAMPLE_JITTER
			var jz: float = rng.randf() * SAMPLE_JITTER
			var local_x: float = (float(gx) + jx) * cell_size
			var local_z: float = (float(gz) + jz) * cell_size

			# Map to grid coordinates
			var gi: int = clampi(int(local_x * inv_grid_spacing), 0, max_gi)
			var gj: int = clampi(int(local_z * inv_grid_spacing), 0, max_gi)
			var grid_idx: int = gj * grid_res + gi

			# Height from grid
			var height: float = grid_verts[grid_idx].y

			if height < TerrainConfig.GRASS_MIN_HEIGHT or height >= TerrainConfig.HIGHLANDS_MIN:
				continue

			# Slope from grid neighbors
			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + grid_res].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < TerrainConfig.MIN_NORMAL_Y:
				continue

			# Climate from grid
			var climate: Color = grid_colors[grid_idx]
			var temp_01: float = climate.r
			var moist_01: float = climate.g

			# Skip desert (hot + dry)
			if temp_01 > TerrainConfig.DESERT_TEMP and moist_01 < TerrainConfig.DESERT_MOIST:
				continue

			# Determine which of the 2 picked types are eligible here
			var eligible: PackedInt32Array = PackedInt32Array()
			for pi in range(2):
				var type_id: int = picked[pi]
				match type_id:
					0:  # Bush_Common — always eligible in plains
						eligible.append(pi)
					1:  # Fern_1 — needs moisture
						if moist_01 > 0.5:
							eligible.append(pi)
					2:  # Mushroom_Common — forest conditions
						if moist_01 > 0.55 and temp_01 >= 0.35 and temp_01 <= 0.7:
							eligible.append(pi)
					3:  # Flower_3_Group — always eligible in plains
						eligible.append(pi)
					4:  # Plant_7 — always eligible in plains
						eligible.append(pi)
					5:  # Plant_7_Big — always eligible but sparser
						if rng.randf() < 0.5:
							eligible.append(pi)

			if eligible.is_empty():
				continue

			# Randomly choose one eligible picked type
			var chosen_pi: int = eligible[rng.randi() % eligible.size()]
			var chosen_type: int = picked[chosen_pi]

			# Density filter with per-type chance
			if rng.randf() > FOLIAGE_DENSITIES[chosen_type]:
				continue

			# Build transform
			var angle: float = rng.randf() * TAU
			var foliage_scale: float = rng.randf_range(0.8, 1.5)

			if chosen_pi == 0:
				_write_transform(transforms_0, count_0, local_x, height, local_z, foliage_scale, angle, TerrainConfig.FOLIAGE_Y_OFFSET)
				count_0 += 1
			else:
				_write_transform(transforms_1, count_1, local_x, height, local_z, foliage_scale, angle, TerrainConfig.FOLIAGE_Y_OFFSET)
				count_1 += 1

	transforms_0.resize(count_0 * 12)
	transforms_1.resize(count_1 * 12)

	return {
		"variant_ids": picked,
		"transforms": [transforms_0, transforms_1],
		"counts": PackedInt32Array([count_0, count_1])
	}


func generate_all_non_grass(chunk_pos: Vector2i) -> Dictionary:
	var grid: Dictionary = _query_shared_grid(chunk_pos)
	return {
		"trees": generate_trees(chunk_pos, grid),
		"foliage": generate_foliage(chunk_pos, grid)
	}
