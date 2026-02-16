class_name VegetationPlacer
extends RefCounted

## Thread-safe vegetation placement
## Pre-computes a height/climate grid via batch noise, then samples from it
## avoids thousands of individual noise calls

const LOD_CANDIDATES: Array[int] = [2000, 600, 150]
const GRID_RES: int = 32

const MIN_HEIGHT:    float = 6.5
const MAX_HEIGHT:    float = 80.0
const MIN_NORMAL_Y:  float = 0.7
const DESERT_TEMP:   float = 0.65
const DESERT_MOIST:  float = 0.38
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
	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	var origin_x: float = chunk_pos.x * chunk_world_size
	var origin_z: float = chunk_pos.y * chunk_world_size

	var grid_spacing: float = chunk_world_size / float(GRID_RES - 1)
	var grid_total: int = GRID_RES * GRID_RES

	var grid_verts := PackedVector3Array()
	var grid_colors := PackedColorArray()
	grid_verts.resize(grid_total)
	grid_colors.resize(grid_total)

	terrain_gen.get_vertex_data_batch(
		origin_x, origin_z,
		GRID_RES, GRID_RES,
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
	var max_gi: int = GRID_RES - 2

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
			var grid_idx: int = gj * GRID_RES + gi

			# Height from grid
			var height: float = grid_verts[grid_idx].y

			if height < MIN_HEIGHT or height > MAX_HEIGHT:
				continue

			# Slope from grid neighbors (cheap — no noise calls)
			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + GRID_RES].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < MIN_NORMAL_Y:
				continue

			# Climate from grid
			var climate: Color = grid_colors[grid_idx]
			var temperature: float = climate.r
			var moisture: float = climate.g

			# Skip desert (hot + dry)
			if temperature > DESERT_TEMP and moisture < DESERT_MOIST:
				continue

			# Thin out at high altitude (rock zone starts ~40)
			var alt_factor: float = clampf(1.0 - (height - 40.0) / 40.0, 0.1, 1.0)

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
			transforms[base + 10] = height
			transforms[base + 11] = local_z

			var cd_base: int = count * 4
			custom_data[cd_base]     = temperature
			custom_data[cd_base + 1] = moisture
			custom_data[cd_base + 2] = 0.0
			custom_data[cd_base + 3] = 0.0

			count += 1

	transforms.resize(count * 12)
	custom_data.resize(count * 4)

	result.transforms = transforms
	result.custom_data = custom_data
	result.count = count
	return result
