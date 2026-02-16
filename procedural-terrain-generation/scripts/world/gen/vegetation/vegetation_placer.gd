class_name VegetationPlacer
extends RefCounted

## Thread-safe vegetation placement
## Pre-computes a height/climate grid via batch noise, then samples from it
## avoids thousands of individual noise calls

const LOD_CANDIDATES: Array[int] = [8000, 1600, 150]
const LOD_GRID_RES: Array[int] = [32, 16, 8]

const SAMPLE_JITTER: float = 0.85

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


func generate_trees(chunk_pos: Vector2i) -> Dictionary:
	var result := {
		"pine_transforms": PackedFloat32Array(),
		"pine_count": 0,
		"snow_transforms": PackedFloat32Array(),
		"snow_count": 0
	}

	var candidates: int = 25
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

	var pine_transforms := PackedFloat32Array()
	pine_transforms.resize(candidates * 12)
	var snow_transforms := PackedFloat32Array()
	snow_transforms.resize(candidates * 12)
	var pine_count: int = 0
	var snow_count: int = 0

	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)
	var inv_grid_spacing: float = 1.0 / grid_spacing
	var max_gi: int = grid_res - 2

	for gz in range(grid_side):
		for gx in range(grid_side):
			if pine_count + snow_count >= candidates:
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

			if height < TerrainConfig.GRASS_MIN_HEIGHT:
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

			# Classify tree type with per-type height limits
			var is_pine: bool = false
			var is_snow_pine: bool = false

			# Forest: temp_01 in 0.35-0.7 AND moist_01 > 0.55
			if temp_01 >= 0.35 and temp_01 <= 0.7 and moist_01 > 0.55:
				if height <= TerrainConfig.TREE_MAX_HEIGHT:
					is_pine = true
			# Jungle: temp_01 > 0.7 AND moist_01 > 0.45, only 20% chance
			elif temp_01 > 0.7 and moist_01 > 0.45:
				if height <= TerrainConfig.TREE_MAX_HEIGHT and rng.randf() < 0.2:
					is_pine = true
			# Snow pine: temp_01 < 0.35 (Tundra/Snow zones) — can grow on peaks
			elif temp_01 < 0.35 and height <= TerrainConfig.SNOW_PINE_MAX_HEIGHT:
				is_snow_pine = true

			if not is_pine and not is_snow_pine:
				continue

			# Density filter — sparser placement
			if rng.randf() > 0.4:
				continue

			# Build transform with random Y rotation and random scale
			var angle: float = rng.randf() * TAU
			var cos_a: float = cos(angle)
			var sin_a: float = sin(angle)
			var tree_scale: float = rng.randf_range(2.0, 3.5)

			if is_pine:
				var base: int = pine_count * 12
				pine_transforms[base]      = cos_a * tree_scale
				pine_transforms[base + 1]  = 0.0
				pine_transforms[base + 2]  = sin_a * tree_scale
				pine_transforms[base + 3]  = 0.0
				pine_transforms[base + 4]  = tree_scale
				pine_transforms[base + 5]  = 0.0
				pine_transforms[base + 6]  = -sin_a * tree_scale
				pine_transforms[base + 7]  = 0.0
				pine_transforms[base + 8]  = cos_a * tree_scale
				pine_transforms[base + 9]  = local_x
				pine_transforms[base + 10] = height - 1.0
				pine_transforms[base + 11] = local_z
				pine_count += 1
			else:
				var base: int = snow_count * 12
				snow_transforms[base]      = cos_a * tree_scale
				snow_transforms[base + 1]  = 0.0
				snow_transforms[base + 2]  = sin_a * tree_scale
				snow_transforms[base + 3]  = 0.0
				snow_transforms[base + 4]  = tree_scale
				snow_transforms[base + 5]  = 0.0
				snow_transforms[base + 6]  = -sin_a * tree_scale
				snow_transforms[base + 7]  = 0.0
				snow_transforms[base + 8]  = cos_a * tree_scale
				snow_transforms[base + 9]  = local_x
				snow_transforms[base + 10] = height - 1.0
				snow_transforms[base + 11] = local_z
				snow_count += 1

	pine_transforms.resize(pine_count * 12)
	snow_transforms.resize(snow_count * 12)

	result.pine_transforms = pine_transforms
	result.pine_count = pine_count
	result.snow_transforms = snow_transforms
	result.snow_count = snow_count
	return result
