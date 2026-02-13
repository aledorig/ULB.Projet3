class_name BiomeManager
extends RefCounted

const BIOME_SCALE: float = 4.0
const BLEND_GRID_SIZE: float = 8.0

var biome_generator: BiomeGenerator
var cache: BiomeCache
var seed_value: int

var cache_hits: int = 0
var cache_misses: int = 0
var last_report_time: int = 0

func _init(p_seed: int = GameSettingsAutoload.seed) -> void:
	seed_value = p_seed
	biome_generator = BiomeGenerator.new(p_seed)
	cache = BiomeCache.new()

func get_biome(x: float, z: float) -> TerrainConstants.Biome:
	var bx: int = int(floor(x / BIOME_SCALE))
	var bz: int = int(floor(z / BIOME_SCALE))
	return _get_biome_at_grid(bx, bz)


func _get_biome_at_grid(bx: int, bz: int) -> TerrainConstants.Biome:
	var cached: int = cache.get_biome(bx, bz)
	if cached != -1:
		cache_hits += 1
		return cached as TerrainConstants.Biome

	cache_misses += 1

	var chunk_x: int = bx >> 5
	var chunk_z: int = bz >> 5

	if not cache.has_chunk(chunk_x, chunk_z):
		var t0 := Time.get_ticks_usec()

		var chunk_data := biome_generator.get_biome_values(
			chunk_x * 32, chunk_z * 32, 32, 32
		)
		cache.set_chunk(chunk_x, chunk_z, chunk_data)

		var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
		if elapsed_ms > 10:
			print("[BIOME] Generated chunk (%d,%d) in %.1f ms" % [chunk_x, chunk_z, elapsed_ms])

	return cache.get_biome(bx, bz) as TerrainConstants.Biome

func get_terrain_params(x: float, z: float) -> Dictionary:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_PARAMS[biome]


func get_biome_color(x: float, z: float) -> Color:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_COLORS[biome]

func get_blended_params(x: float, z: float, blend_radius: float = 16.0) -> Dictionary:
	var center_biome: TerrainConstants.Biome = get_biome(x, z)
	var center_params: Dictionary = TerrainConstants.BIOME_PARAMS[center_biome]
	var center_color: Color = TerrainConstants.BIOME_COLORS[center_biome]

	var test_biome: TerrainConstants.Biome = get_biome(x + blend_radius, z)

	if test_biome == center_biome:
		return {
			"base": center_params.base,
			"variation": center_params.variation,
			"color": center_color,
		}

	var total_weight: float = 2.0
	var blended_base: float = center_params.base * 2.0
	var blended_variation: float = center_params.variation * 2.0
	var blended_color: Color = center_color * 2.0

	var offsets: Array[Vector2] = [
		Vector2(blend_radius, 0),
		Vector2(0, blend_radius),
	]

	for offset in offsets:
		var params: Dictionary = get_terrain_params(x + offset.x, z + offset.y)
		var color: Color = get_biome_color(x + offset.x, z + offset.y)
		blended_base += params.base
		blended_variation += params.variation
		blended_color += color
		total_weight += 1.0

	return {
		"base": blended_base / total_weight,
		"variation": blended_variation / total_weight,
		"color": blended_color / total_weight,
	}

func get_params_batch_packed(
	origin_x: float, origin_z: float,
	width: int, height: int,
	spacing: float,
	blend_radius: float,
	out_base: PackedFloat32Array,
	out_variation: PackedFloat32Array,
	out_colors: PackedColorArray
) -> void:
	var use_blending: bool = blend_radius > 0.0

	var margin: float = blend_radius + BIOME_SCALE
	var min_bx: int = int(floor((origin_x - margin) / BIOME_SCALE))
	var min_bz: int = int(floor((origin_z - margin) / BIOME_SCALE))
	var max_bx: int = int(floor((origin_x + width * spacing + margin) / BIOME_SCALE))
	var max_bz: int = int(floor((origin_z + height * spacing + margin) / BIOME_SCALE))

	_ensure_biome_region_cached(min_bx, min_bz, max_bx, max_bz)

	var num_biomes: int = TerrainConstants.Biome.size()
	var biome_base: PackedFloat32Array = PackedFloat32Array()
	var biome_var: PackedFloat32Array = PackedFloat32Array()
	var biome_colors: PackedColorArray = PackedColorArray()
	biome_base.resize(num_biomes)
	biome_var.resize(num_biomes)
	biome_colors.resize(num_biomes)

	for i in range(num_biomes):
		var params: Dictionary = TerrainConstants.BIOME_PARAMS[i]
		biome_base[i] = params.base
		biome_var[i] = params.variation
		biome_colors[i] = TerrainConstants.BIOME_COLORS[i]

	var idx: int = 0
	var inv_scale: float = 1.0 / BIOME_SCALE

	for z in range(height):
		var world_z: float = origin_z + z * spacing
		for x in range(width):
			var world_x: float = origin_x + x * spacing

			if use_blending:
				_get_blended_params_packed(
					world_x, world_z, blend_radius, inv_scale,
					biome_base, biome_var, biome_colors,
					idx, out_base, out_variation, out_colors
				)
			else:
				var biome: int = _get_biome_grid_inline(world_x, world_z, inv_scale)
				out_base[idx] = biome_base[biome]
				out_variation[idx] = biome_var[biome]
				out_colors[idx] = biome_colors[biome]
			idx += 1


func _get_biome_grid_inline(x: float, z: float, inv_scale: float) -> int:
	var bx: int = int(floor(x * inv_scale))
	var bz: int = int(floor(z * inv_scale))
	var cached: int = cache.get_biome(bx, bz)
	if cached == -1:
		return _get_biome_at_grid(bx, bz) as int
	return cached


func _get_blended_params_packed(
	x: float, z: float, blend_radius: float, inv_scale: float,
	biome_base: PackedFloat32Array, biome_var: PackedFloat32Array, biome_colors: PackedColorArray,
	idx: int, out_base: PackedFloat32Array, out_variation: PackedFloat32Array, out_colors: PackedColorArray
) -> void:
	var center_biome: int = _get_biome_grid_inline(x, z, inv_scale)

	var test_biome: int = _get_biome_grid_inline(x + blend_radius, z, inv_scale)
	if test_biome == center_biome:
		out_base[idx] = biome_base[center_biome]
		out_variation[idx] = biome_var[center_biome]
		out_colors[idx] = biome_colors[center_biome]
		return

	var blended_base: float = biome_base[center_biome] * 2.0
	var blended_var: float = biome_var[center_biome] * 2.0
	var blended_color: Color = biome_colors[center_biome] * 2.0

	blended_base += biome_base[test_biome]
	blended_var += biome_var[test_biome]
	blended_color += biome_colors[test_biome]

	var biome_z: int = _get_biome_grid_inline(x, z + blend_radius, inv_scale)
	blended_base += biome_base[biome_z]
	blended_var += biome_var[biome_z]
	blended_color += biome_colors[biome_z]

	out_base[idx] = blended_base * 0.25
	out_variation[idx] = blended_var * 0.25
	out_colors[idx] = blended_color * 0.25


func _ensure_biome_region_cached(min_bx: int, min_bz: int, max_bx: int, max_bz: int) -> void:
	var chunk_min_x: int = min_bx >> 5
	var chunk_min_z: int = min_bz >> 5
	var chunk_max_x: int = max_bx >> 5
	var chunk_max_z: int = max_bz >> 5

	for cz in range(chunk_min_z, chunk_max_z + 1):
		for cx in range(chunk_min_x, chunk_max_x + 1):
			if not cache.has_chunk(cx, cz):
				var chunk_data := biome_generator.get_biome_values(cx * 32, cz * 32, 32, 32)
				cache.set_chunk(cx, cz, chunk_data)


func _get_biome_grid_fast(x: float, z: float) -> int:
	var bx: int = int(floor(x / BIOME_SCALE))
	var bz: int = int(floor(z / BIOME_SCALE))
	var cached: int = cache.get_biome(bx, bz)
	if cached == -1:
		return _get_biome_at_grid(bx, bz) as int
	return cached


func _get_blended_params_inline(
	x: float, z: float, blend_radius: float,
	biome_params: Array[Dictionary], biome_colors: Array[Color]
) -> Dictionary:
	var center_biome: int = _get_biome_grid_fast(x, z)
	var center_params: Dictionary = biome_params[center_biome]
	var center_color: Color = biome_colors[center_biome]

	var test_biome: int = _get_biome_grid_fast(x + blend_radius, z)
	if test_biome == center_biome:
		return {
			"base": center_params.base,
			"variation": center_params.variation,
			"color": center_color,
		}

	var total_weight: float = 2.0
	var blended_base: float = center_params.base * 2.0
	var blended_variation: float = center_params.variation * 2.0
	var blended_color: Color = center_color * 2.0

	var biome_x: int = _get_biome_grid_fast(x + blend_radius, z)
	blended_base += biome_params[biome_x].base
	blended_variation += biome_params[biome_x].variation
	blended_color += biome_colors[biome_x]
	total_weight += 1.0

	var biome_z: int = _get_biome_grid_fast(x, z + blend_radius)
	blended_base += biome_params[biome_z].base
	blended_variation += biome_params[biome_z].variation
	blended_color += biome_colors[biome_z]
	total_weight += 1.0

	return {
		"base": blended_base / total_weight,
		"variation": blended_variation / total_weight,
		"color": blended_color / total_weight,
	}


func _catmull_rom_weight(t: float) -> PackedFloat32Array:
	## Compute Catmull-Rom weights for parameter t in [0, 1]
	## Returns weights for points p0, p1, p2, p3 where interpolation is between p1 and p2
	## NOTE: Kept for reference only. The hot path in get_params_batch_catmull_rom()
	## inlines these computations as local floats to avoid PackedFloat32Array allocations.
	var t2: float = t * t
	var t3: float = t2 * t

	var w: PackedFloat32Array = PackedFloat32Array()
	w.resize(4)
	w[0] = -0.5 * t3 + t2 - 0.5 * t          # p0 weight
	w[1] = 1.5 * t3 - 2.5 * t2 + 1.0         # p1 weight
	w[2] = -1.5 * t3 + 2.0 * t2 + 0.5 * t    # p2 weight
	w[3] = 0.5 * t3 - 0.5 * t2               # p3 weight
	return w


func _sample_biome_params_at_grid(grid_x: int, grid_z: int,
	biome_base: PackedFloat32Array, biome_var: PackedFloat32Array,
	biome_colors: PackedColorArray, inv_biome_scale: float
) -> Vector3:
	var world_x: float = grid_x * BLEND_GRID_SIZE
	var world_z: float = grid_z * BLEND_GRID_SIZE
	var biome: int = _get_biome_grid_inline(world_x, world_z, inv_biome_scale)
	return Vector3(biome_base[biome], biome_var[biome], biome)


func get_params_batch_catmull_rom(
	origin_x: float, origin_z: float,
	width: int, height: int,
	spacing: float,
	out_base: PackedFloat32Array,
	out_variation: PackedFloat32Array,
	out_colors: PackedColorArray
) -> void:
	var inv_blend_grid: float = 1.0 / BLEND_GRID_SIZE
	var inv_biome_scale: float = 1.0 / BIOME_SCALE

	var min_gx: int = int(floor(origin_x * inv_blend_grid)) - 1
	var min_gz: int = int(floor(origin_z * inv_blend_grid)) - 1
	var max_gx: int = int(floor((origin_x + width * spacing) * inv_blend_grid)) + 2
	var max_gz: int = int(floor((origin_z + height * spacing) * inv_blend_grid)) + 2

	var grid_width: int = max_gx - min_gx + 1
	var grid_height: int = max_gz - min_gz + 1

	var margin: float = BLEND_GRID_SIZE * 2
	var cache_min_bx: int = int(floor((origin_x - margin) * inv_biome_scale))
	var cache_min_bz: int = int(floor((origin_z - margin) * inv_biome_scale))
	var cache_max_bx: int = int(floor((origin_x + width * spacing + margin) * inv_biome_scale))
	var cache_max_bz: int = int(floor((origin_z + height * spacing + margin) * inv_biome_scale))
	_ensure_biome_region_cached(cache_min_bx, cache_min_bz, cache_max_bx, cache_max_bz)

	var num_biomes: int = TerrainConstants.Biome.size()
	var biome_base: PackedFloat32Array = PackedFloat32Array()
	var biome_var: PackedFloat32Array = PackedFloat32Array()
	var biome_colors_lookup: PackedColorArray = PackedColorArray()
	biome_base.resize(num_biomes)
	biome_var.resize(num_biomes)
	biome_colors_lookup.resize(num_biomes)

	for i in range(num_biomes):
		var params: Dictionary = TerrainConstants.BIOME_PARAMS[i]
		biome_base[i] = params.base
		biome_var[i] = params.variation
		biome_colors_lookup[i] = TerrainConstants.BIOME_COLORS[i]

	var grid_base: PackedFloat32Array = PackedFloat32Array()
	var grid_var: PackedFloat32Array = PackedFloat32Array()
	var grid_biome: PackedInt32Array = PackedInt32Array()
	var grid_size: int = grid_width * grid_height
	grid_base.resize(grid_size)
	grid_var.resize(grid_size)
	grid_biome.resize(grid_size)

	for gz in range(grid_height):
		for gx in range(grid_width):
			var world_x: float = (min_gx + gx) * BLEND_GRID_SIZE
			var world_z: float = (min_gz + gz) * BLEND_GRID_SIZE
			var biome: int = _get_biome_grid_inline(world_x, world_z, inv_biome_scale)
			var grid_idx: int = gz * grid_width + gx
			grid_base[grid_idx] = biome_base[biome]
			grid_var[grid_idx] = biome_var[biome]
			grid_biome[grid_idx] = biome

	var idx: int = 0
	for vz in range(height):
		var world_z: float = origin_z + vz * spacing
		var gz_f: float = world_z * inv_blend_grid
		var gz_i: int = int(floor(gz_f))
		var fz: float = gz_f - gz_i
		var fz2: float = fz * fz
		var fz3: float = fz2 * fz
		var wz0: float = -0.5 * fz3 + fz2 - 0.5 * fz
		var wz1: float = 1.5 * fz3 - 2.5 * fz2 + 1.0
		var wz2: float = -1.5 * fz3 + 2.0 * fz2 + 0.5 * fz
		var wz3: float = 0.5 * fz3 - 0.5 * fz2

		var row0: int = (gz_i - 1 - min_gz) * grid_width
		var row1: int = (gz_i - min_gz) * grid_width
		var row2: int = (gz_i + 1 - min_gz) * grid_width
		var row3: int = (gz_i + 2 - min_gz) * grid_width

		for vx in range(width):
			var world_x: float = origin_x + vx * spacing
			var gx_f: float = world_x * inv_blend_grid
			var gx_i: int = int(floor(gx_f))
			var fx: float = gx_f - gx_i
			var fx2: float = fx * fx
			var fx3: float = fx2 * fx
			var wx0: float = -0.5 * fx3 + fx2 - 0.5 * fx
			var wx1: float = 1.5 * fx3 - 2.5 * fx2 + 1.0
			var wx2: float = -1.5 * fx3 + 2.0 * fx2 + 0.5 * fx
			var wx3: float = 0.5 * fx3 - 0.5 * fx2

			var col0: int = gx_i - 1 - min_gx
			var col1: int = gx_i - min_gx
			var col2: int = gx_i + 1 - min_gx
			var col3: int = gx_i + 2 - min_gx

			var base_val: float = 0.0
			var var_val: float = 0.0

			base_val += wz0 * (wx0 * grid_base[row0 + col0] + wx1 * grid_base[row0 + col1] + wx2 * grid_base[row0 + col2] + wx3 * grid_base[row0 + col3])
			var_val += wz0 * (wx0 * grid_var[row0 + col0] + wx1 * grid_var[row0 + col1] + wx2 * grid_var[row0 + col2] + wx3 * grid_var[row0 + col3])
			base_val += wz1 * (wx0 * grid_base[row1 + col0] + wx1 * grid_base[row1 + col1] + wx2 * grid_base[row1 + col2] + wx3 * grid_base[row1 + col3])
			var_val += wz1 * (wx0 * grid_var[row1 + col0] + wx1 * grid_var[row1 + col1] + wx2 * grid_var[row1 + col2] + wx3 * grid_var[row1 + col3])
			base_val += wz2 * (wx0 * grid_base[row2 + col0] + wx1 * grid_base[row2 + col1] + wx2 * grid_base[row2 + col2] + wx3 * grid_base[row2 + col3])
			var_val += wz2 * (wx0 * grid_var[row2 + col0] + wx1 * grid_var[row2 + col1] + wx2 * grid_var[row2 + col2] + wx3 * grid_var[row2 + col3])
			base_val += wz3 * (wx0 * grid_base[row3 + col0] + wx1 * grid_base[row3 + col1] + wx2 * grid_base[row3 + col2] + wx3 * grid_base[row3 + col3])
			var_val += wz3 * (wx0 * grid_var[row3 + col0] + wx1 * grid_var[row3 + col1] + wx2 * grid_var[row3 + col2] + wx3 * grid_var[row3 + col3])

			out_base[idx] = base_val
			out_variation[idx] = var_val

			# Bilinear on colors to avoid Catmull-Rom artifacts
			var c00: Color = biome_colors_lookup[grid_biome[row1 + col1]]
			var c10: Color = biome_colors_lookup[grid_biome[row1 + col2]]
			var c01: Color = biome_colors_lookup[grid_biome[row2 + col1]]
			var c11: Color = biome_colors_lookup[grid_biome[row2 + col2]]

			var top: Color = c00.lerp(c10, fx)
			var bot: Color = c01.lerp(c11, fx)
			out_colors[idx] = top.lerp(bot, fz)

			idx += 1


func get_biome_name(x: float, z: float) -> String:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_NAMES[biome]


func get_cache_stats() -> Dictionary:
	var stats := cache.get_stats()
	stats["hits"] = cache_hits
	stats["misses"] = cache_misses
	stats["hit_rate"] = 0.0 if (cache_hits + cache_misses) == 0 else float(cache_hits) / float(cache_hits + cache_misses) * 100.0
	return stats


func print_cache_stats() -> void:
	var stats := get_cache_stats()
	print("[BIOME CACHE] size=%d/%d hits=%d misses=%d hit_rate=%.1f%%" % [
		stats.size, stats.max_size, stats.hits, stats.misses, stats.hit_rate
	])


func clear_cache() -> void:
	cache.clear()
	cache_hits = 0
	cache_misses = 0
