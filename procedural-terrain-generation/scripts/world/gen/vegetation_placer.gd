class_name VegetationPlacer
extends RefCounted

## Thread-safe vegetation placement. Generates Transform3D data as
## PackedFloat32Array for main-thread MultiMesh assembly.
## Also outputs per-instance climate data for color matching.

const LOD_CANDIDATES: Array[int] = [800, 300, 0]

const MIN_HEIGHT:    float = 1.5   # Above sea level
const MAX_HEIGHT:    float = 110.0 # Below snow line
const MIN_NORMAL_Y:  float = 0.6   # Not too steep
const DESERT_TEMP:   float = 0.65  # Temperature threshold
const DESERT_MOIST:  float = 0.38  # Moisture threshold (dry)
const SAMPLE_JITTER: float = 0.85  # Random offset within cell (0-1)

var terrain_gen:    TerrainGenerator
var chunk_size:     int
var vertex_spacing: float
var rng:            RandomNumberGenerator


func _init(p_terrain_gen: TerrainGenerator, p_chunk_size: int, p_vertex_spacing: float, p_seed: int, p_chunk_pos: Vector2i) -> void:
	terrain_gen = p_terrain_gen
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing

	# Deterministic per-chunk seed
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

	# Pre-allocate max possible (will truncate later)
	var transforms := PackedFloat32Array()
	transforms.resize(candidates * 12)
	var custom_data := PackedFloat32Array()
	custom_data.resize(candidates * 4)
	var count: int = 0

	# Grid-based placement with jitter for even distribution
	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)

	for gz in range(grid_side):
		for gx in range(grid_side):
			if count >= candidates:
				break

			# Jittered position within cell
			var jx: float = rng.randf() * SAMPLE_JITTER
			var jz: float = rng.randf() * SAMPLE_JITTER
			var world_x: float = origin_x + (float(gx) + jx) * cell_size
			var world_z: float = origin_z + (float(gz) + jz) * cell_size

			# Sample terrain
			var height: float = terrain_gen.get_height(world_x, world_z)

			# Height filter
			if height < MIN_HEIGHT or height > MAX_HEIGHT:
				continue

			# Slope filter via finite difference normal
			var hdx: float = terrain_gen.get_height(world_x + 1.0, world_z) - terrain_gen.get_height(world_x - 1.0, world_z)
			var hdz: float = terrain_gen.get_height(world_x, world_z + 1.0) - terrain_gen.get_height(world_x, world_z - 1.0)
			var normal := Vector3(-hdx, 2.0, -hdz).normalized()
			if normal.y < MIN_NORMAL_Y:
				continue

			# Climate filter
			var climate: Color = terrain_gen.get_climate_color(world_x, world_z)
			var temperature: float = climate.r
			var moisture: float = climate.g

			# Skip desert (hot + dry)
			if temperature > DESERT_TEMP and moisture < DESERT_MOIST:
				continue

			# Density based on moisture — drier areas randomly skip more
			var density_chance: float = clampf(moisture * 1.5, 0.3, 1.0)
			if rng.randf() > density_chance:
				continue

			# Build transform — random Y rotation only, no scale change
			var angle: float = rng.randf() * TAU
			var cos_a: float = cos(angle)
			var sin_a: float = sin(angle)

			# Rotation around Y axis (scale = 1.0)
			var base: int = count * 12
			transforms[base]      = cos_a    # basis.x.x
			transforms[base + 1]  = 0.0      # basis.x.y
			transforms[base + 2]  = sin_a    # basis.x.z
			transforms[base + 3]  = 0.0      # basis.y.x
			transforms[base + 4]  = 1.0      # basis.y.y
			transforms[base + 5]  = 0.0      # basis.y.z
			transforms[base + 6]  = -sin_a   # basis.z.x
			transforms[base + 7]  = 0.0      # basis.z.y
			transforms[base + 8]  = cos_a    # basis.z.z
			# Origin is LOCAL to the chunk node
			transforms[base + 9]  = world_x - origin_x
			transforms[base + 10] = height
			transforms[base + 11] = world_z - origin_z

			# Per-instance climate for color matching
			var cd_base: int = count * 4
			custom_data[cd_base]     = temperature
			custom_data[cd_base + 1] = moisture
			custom_data[cd_base + 2] = 0.0
			custom_data[cd_base + 3] = 0.0

			count += 1

	# Truncate to actual count
	transforms.resize(count * 12)
	custom_data.resize(count * 4)

	result.transforms = transforms
	result.custom_data = custom_data
	result.count = count
	return result
