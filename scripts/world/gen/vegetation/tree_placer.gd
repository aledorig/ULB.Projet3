class_name TreePlacer
extends RefCounted

## Thread-safe tree placement (no LOD — trees use visibility_range only)

var terrain_gen:    TerrainGenerator
var chunk_size:     int
var vertex_spacing: float
var rng:            RandomNumberGenerator


func _init(p_terrain_gen: TerrainGenerator, p_chunk_size: int, p_vertex_spacing: float, p_rng: RandomNumberGenerator) -> void:
	terrain_gen = p_terrain_gen
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	rng = p_rng


func generate(chunk_pos: Vector2i, grid: Dictionary) -> Dictionary:
	var variant_id: int = VegetationPlacerUtils.pick_variant(chunk_pos, TerrainConfig.TREE_VARIANTS, 1)
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

			var jx: float = rng.randf() * TerrainConfig.SAMPLE_JITTER
			var jz: float = rng.randf() * TerrainConfig.SAMPLE_JITTER
			var local_x: float = (float(gx) + jx) * cell_size
			var local_z: float = (float(gz) + jz) * cell_size

			var gi: int = clampi(int(local_x * inv_grid_spacing), 0, max_gi)
			var gj: int = clampi(int(local_z * inv_grid_spacing), 0, max_gi)
			var grid_idx: int = gj * grid_res + gi

			var height: float = grid_verts[grid_idx].y

			if height < TerrainConfig.TREE_MIN_HEIGHT or height > TerrainConfig.TREE_MAX_HEIGHT:
				continue

			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + grid_res].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < TerrainConfig.MIN_NORMAL_Y:
				continue

			var climate: Color = grid_colors[grid_idx]
			var temp_01: float = climate.r
			var moist_01: float = climate.g

			if temp_01 < TerrainConfig.TREE_MIN_TEMP:
				continue

			if temp_01 > TerrainConfig.DESERT_TEMP and moist_01 < TerrainConfig.DESERT_MOIST:
				continue

			var place: bool = false
			if temp_01 >= 0.35 and temp_01 <= 0.7 and moist_01 > 0.55:
				place = true
			elif temp_01 > 0.7 and moist_01 > 0.45 and rng.randf() < 0.2:
				place = true

			if not place:
				continue

			if rng.randf() > TerrainConfig.TREE_DENSITY:
				continue

			var angle: float = rng.randf() * TAU
			var tree_scale: float = rng.randf_range(TerrainConfig.TREE_SCALE_MIN, TerrainConfig.TREE_SCALE_MAX)
			var tilt_x: float = rng.randf_range(-0.06, 0.06)
			var tilt_z: float = rng.randf_range(-0.06, 0.06)
			VegetationPlacerUtils.write_transform(transforms, count, local_x, height, local_z, tree_scale, angle, TerrainConfig.TREE_Y_OFFSET, tilt_x, tilt_z)
			count += 1

	transforms.resize(count * 12)

	return {
		"variant_id": variant_id,
		"transforms": transforms,
		"count": count
	}
