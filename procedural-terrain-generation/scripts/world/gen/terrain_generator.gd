class_name TerrainGenerator
extends RefCounted

var biome_manager: BiomeManager
var height_noise:  OctaveNoise
var depth_noise:   OctaveNoise
var surface_noise: SimplexNoise
var seed_value:    int

var use_biome_blending: bool = true
var blend_radius: float = 16.0

func _init(p_seed: int = GameSettingsAutoload.seed, p_octaves: int = GameSettingsAutoload.octave) -> void:
	seed_value = p_seed
	biome_manager = BiomeManager.new(p_seed)

	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	height_noise  = OctaveNoise.new(rng, p_octaves)
	depth_noise   = OctaveNoise.new(rng, p_octaves)
	surface_noise = SimplexNoise.new(rng)


func _sample_noise(x: float, z: float) -> float:
	return height_noise.get_value(x, z, 0.005, 0.005)

func get_height(x: float, z: float) -> float:
	var params: Dictionary

	if use_biome_blending:
		params = biome_manager.get_blended_params(x, z, blend_radius)
	else:
		params = biome_manager.get_terrain_params(x, z)

	var base_height: float = params.base
	var variation: float = params.variation

	var noise_val: float = _sample_noise(x, z)
	var depth_mod: float = depth_noise.get_value(x, z, 0.003, 0.003)
	var surface_detail: float = surface_noise.get_value(x * 0.02, z * 0.02) * 2.0

	var height: float = base_height + (noise_val * variation * (1.0 + depth_mod * 0.3)) + surface_detail

	return height

func get_biome(x: float, z: float) -> TerrainConstants.Biome:
	return biome_manager.get_biome(x, z)


func get_surface_color(x: float, z: float, height: float) -> Color:
	var color: Color

	if use_biome_blending:
		var params: Dictionary = biome_manager.get_blended_params(x, z, blend_radius)
		color = params.color
	else:
		color = biome_manager.get_biome_color(x, z)

	if height < TerrainConstants.SEA_LEVEL:
		var depth: float = TerrainConstants.SEA_LEVEL - height
		var darkness: float = clampf(depth / 40.0, 0.0, 0.6)
		color = color.darkened(darkness)

	if height > 60.0:
		var snow_amount: float = smoothstep(60.0, 80.0, height)
		var snow_color: Color = Color(0.95, 0.97, 1.0)
		color = color.lerp(snow_color, snow_amount)

	return color


func get_vertex_data(x: float, z: float) -> Dictionary:
	var params: Dictionary

	if use_biome_blending:
		params = biome_manager.get_blended_params(x, z, blend_radius)
	else:
		var biome: TerrainConstants.Biome = biome_manager.get_biome(x, z)
		params = {
			"base": TerrainConstants.BIOME_PARAMS[biome].base,
			"variation": TerrainConstants.BIOME_PARAMS[biome].variation,
			"color": TerrainConstants.BIOME_COLORS[biome],
		}

	var noise_val: float = _sample_noise(x, z)
	var depth_mod: float = depth_noise.get_value(x, z, 0.003, 0.003)
	var surface_detail: float = surface_noise.get_value(x * 0.02, z * 0.02) * 2.0
	var height: float = params.base + (noise_val * params.variation * (1.0 + depth_mod * 0.3)) + surface_detail
	var color: Color = params.color

	if height < TerrainConstants.SEA_LEVEL:
		var depth: float = TerrainConstants.SEA_LEVEL - height
		var darkness: float = clampf(depth / 40.0, 0.0, 0.6)
		color = color.darkened(darkness)

	if height > 60.0:
		var snow_amount: float = smoothstep(60.0, 80.0, height)
		color = color.lerp(Color(0.95, 0.97, 1.0), snow_amount)

	return {"height": height, "color": color}


func get_vertex_data_batch(
	origin_x: float, origin_z: float,
	width: int, height: int,
	spacing: float,
	out_vertices: PackedVector3Array,
	out_colors: PackedColorArray
) -> void:
	var total_verts: int = width * height

	var base_heights: PackedFloat32Array = PackedFloat32Array()
	var variations: PackedFloat32Array = PackedFloat32Array()
	var biome_colors: PackedColorArray = PackedColorArray()

	base_heights.resize(total_verts)
	variations.resize(total_verts)
	biome_colors.resize(total_verts)

	if use_biome_blending:
		biome_manager.get_params_batch_catmull_rom(
			origin_x, origin_z, width, height, spacing,
			base_heights, variations, biome_colors
		)
	else:
		biome_manager.get_params_batch_packed(
			origin_x, origin_z, width, height, spacing, 0.0,
			base_heights, variations, biome_colors
		)

	# Grid offset for batch noise: gx goes 0..width-1, world pos = origin + gx*spacing
	# generate_octaves computes: d3 * x_scale * (x_off + gx)
	# We want:                   d3 * 0.005 * (origin + gx * spacing)
	# So: x_scale = spacing * freq, x_off = origin / spacing
	var inv_spacing: float = 1.0 / spacing

	var noise_grid: PackedFloat32Array = PackedFloat32Array()
	noise_grid.resize(total_verts)
	height_noise.generate_octaves(
		noise_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * 0.005, spacing * 0.005
	)

	var depth_grid: PackedFloat32Array = PackedFloat32Array()
	depth_grid.resize(total_verts)
	depth_noise.generate_octaves(
		depth_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * 0.003, spacing * 0.003
	)

	var surface_grid: PackedFloat32Array = PackedFloat32Array()
	surface_grid.resize(total_verts)
	surface_noise.add(
		surface_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * 0.02, spacing * 0.02,
		2.0
	)

	var sea_level: float = TerrainConstants.SEA_LEVEL
	var snow_color := Color(0.95, 0.97, 1.0)

	var idx: int = 0
	for z in range(height):
		for x in range(width):
			var h: float = base_heights[idx] + (noise_grid[idx] * variations[idx] * (1.0 + depth_grid[idx] * 0.3)) + surface_grid[idx]
			var color: Color = biome_colors[idx]

			if h < sea_level:
				var depth: float = sea_level - h
				var darkness: float = clampf(depth / 40.0, 0.0, 0.6)
				color = color.darkened(darkness)

			if h > 60.0:
				var snow_amount: float = smoothstep(60.0, 80.0, h)
				color = color.lerp(snow_color, snow_amount)

			var local_x: float = x * spacing
			var local_z: float = z * spacing
			out_vertices[idx] = Vector3(local_x, h, local_z)
			out_colors[idx] = color
			idx += 1


func is_underwater(height: float) -> bool:
	return height < TerrainConstants.SEA_LEVEL

func get_biome_name(x: float, z: float) -> String:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_NAMES[biome]


func get_debug_info(x: float, z: float) -> Dictionary:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	var height: float = get_height(x, z)
	var temp_category: int = TerrainConstants.BIOME_TEMPERATURES.get(biome, TerrainConstants.TempCategory.MEDIUM)

	return {
		"biome": TerrainConstants.BIOME_NAMES[biome],
		"height": height,
		"temp_category": _temp_category_name(temp_category),
		"underwater": is_underwater(height),
	}


func _temp_category_name(category: int) -> String:
	match category:
		TerrainConstants.TempCategory.OCEAN:
			return "Ocean"
		TerrainConstants.TempCategory.COLD:
			return "Cold"
		TerrainConstants.TempCategory.MEDIUM:
			return "Medium"
		TerrainConstants.TempCategory.WARM:
			return "Warm"
		_:
			return "Unknown"
