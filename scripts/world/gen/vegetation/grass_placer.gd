class_name GrassPlacer
extends RefCounted

## Thread-safe grass placement with LOD support
## Pre-computes a height/climate grid via batch noise, then jitters candidate positions

var terrain_gen:    TerrainGenerator
var chunk_size:     int
var vertex_spacing: float
var rng:            RandomNumberGenerator


func _init(p_terrain_gen: TerrainGenerator, p_chunk_size: int, p_vertex_spacing: float, p_rng: RandomNumberGenerator) -> void:
	terrain_gen = p_terrain_gen
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	rng = p_rng


func generate(chunk_pos: Vector2i, lod_level: int) -> Dictionary:
	## Returns {buffer: PackedFloat32Array, count: int}
	## Buffer is interleaved 16 floats/instance: 12 transform + 4 custom_data
	var result := {"buffer": PackedFloat32Array(), "count": 0}

	var lod_candidates: Array[int] = TerrainConfig.GRASS_LOD_CANDIDATES
	var lod_grid_res: Array[int] = TerrainConfig.GRASS_LOD_GRID_RES

	if lod_level >= lod_candidates.size() or lod_candidates[lod_level] == 0:
		return result

	var candidates: int = lod_candidates[lod_level]
	var grid_res: int = lod_grid_res[lod_level] if lod_level < lod_grid_res.size() else 8
	var grid: Dictionary = VegetationPlacerUtils.query_grid(terrain_gen, chunk_size, vertex_spacing, chunk_pos, grid_res)

	var grid_verts: PackedVector3Array = grid["verts"]
	var grid_colors: PackedColorArray = grid["colors"]
	var grid_spacing: float = grid["grid_spacing"]
	var chunk_world_size: float = grid["chunk_world_size"]

	var buf := PackedFloat32Array()
	buf.resize(candidates * 16)
	var count: int = 0

	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)
	var inv_grid_spacing: float = 1.0 / grid_spacing
	var max_gi: int = grid_res - 2

	for gz in range(grid_side):
		for gx in range(grid_side):
			if count >= candidates:
				break

			var jx: float = rng.randf() * TerrainConfig.SAMPLE_JITTER
			var jz: float = rng.randf() * TerrainConfig.SAMPLE_JITTER
			var local_x: float = (float(gx) + jx) * cell_size
			var local_z: float = (float(gz) + jz) * cell_size

			var gi: int = clampi(int(local_x * inv_grid_spacing), 0, max_gi)
			var gj: int = clampi(int(local_z * inv_grid_spacing), 0, max_gi)
			var grid_idx: int = gj * grid_res + gi

			var height: float = grid_verts[grid_idx].y

			if height < TerrainConfig.GRASS_MIN_HEIGHT or height > TerrainConfig.GRASS_MAX_HEIGHT:
				continue

			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + grid_res].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < TerrainConfig.MIN_NORMAL_Y:
				continue

			var climate: Color = grid_colors[grid_idx]
			var temperature: float = climate.r
			var moisture: float = climate.g

			if temperature > TerrainConfig.DESERT_TEMP and moisture < TerrainConfig.DESERT_MOIST:
				continue

			var alt_factor: float = clampf(1.0 - (height - 60.0) / 60.0, 0.1, 1.0)
			var density_chance: float = clampf(moisture * 1.5, 0.3, 1.0) * alt_factor
			if rng.randf() > density_chance:
				continue

			var angle: float = rng.randf() * TAU
			var cos_a: float = cos(angle)
			var sin_a: float = sin(angle)

			var b: int = count * 16
			buf[b]      = cos_a
			buf[b + 1]  = 0.0
			buf[b + 2]  = -sin_a
			buf[b + 3]  = local_x
			buf[b + 4]  = 0.0
			buf[b + 5]  = 1.0
			buf[b + 6]  = 0.0
			buf[b + 7]  = height - 0.3
			buf[b + 8]  = sin_a
			buf[b + 9]  = 0.0
			buf[b + 10] = cos_a
			buf[b + 11] = local_z
			buf[b + 12] = temperature
			buf[b + 13] = moisture
			buf[b + 14] = float(rng.randi() % 2)
			buf[b + 15] = 0.0

			count += 1

	buf.resize(count * 16)
	result.buffer = buf
	result.count = count
	return result
