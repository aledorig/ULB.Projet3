class_name TerrainGenerator
extends RefCounted

var height_noise: OctaveNoise
var depth_noise: OctaveNoise
var surface_noise: SimplexNoise

var continentalness_noise: OctaveNoise
var peaks_noise: OctaveNoise
var temperature_noise: SimplexNoise
var moisture_noise: SimplexNoise
var roughness_noise: OctaveNoise

var seed_value: int


func _init(p_seed: int = GameSettingsAutoload.seed, p_octaves: int = GameSettingsAutoload.octave) -> void:
	seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed

	height_noise = OctaveNoise.new(rng, p_octaves)
	depth_noise = OctaveNoise.new(rng, p_octaves)
	surface_noise = SimplexNoise.new(rng)

	continentalness_noise = OctaveNoise.new(rng, p_octaves)
	peaks_noise = OctaveNoise.new(rng, p_octaves)
	temperature_noise = SimplexNoise.new(rng)
	moisture_noise = SimplexNoise.new(rng)
	roughness_noise = OctaveNoise.new(rng, p_octaves)


static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func shape_noise(n: float) -> float:
	return absf(n) ** 1.8 * signf(n)


func compute_base(cont: float) -> float:
	var sea_land: float = lerpf(TerrainConfig.OCEAN_BASE, TerrainConfig.LAND_BASE, smoothstep(-0.5, -0.15, cont))
	var inland_boost: float = smoothstep(-0.15, 0.2, cont) * TerrainConfig.INLAND_BOOST
	return sea_land + inland_boost


func compute_amplitude(cont: float, peaks: float) -> float:
	var land_factor: float = smoothstep(-0.5, -0.15, cont)
	# mountains appear frequently and reach extreme heights
	return lerpf(TerrainConfig.MIN_AMPLITUDE, TerrainConfig.MAX_AMPLITUDE, smoothstep(-0.8, 0.2, peaks)) * lerpf(0.3, 1.0, land_factor)


func get_height(x: float, z: float, height_freq: float = TerrainConfig.HEIGHT_FREQ) -> float:
	var cont: float = continentalness_noise.get_value(
		x,
		z,
		TerrainConfig.CONTINENT_FREQ,
		TerrainConfig.CONTINENT_FREQ,
	)

	var peaks: float = peaks_noise.get_value(
		x,
		z,
		TerrainConfig.PEAKS_FREQ,
		TerrainConfig.PEAKS_FREQ,
	)

	var base: float = compute_base(cont)
	var amplitude: float = compute_amplitude(cont, peaks)

	var shaped: float = shape_noise(
		height_noise.get_value(
			x,
			z,
			height_freq,
			height_freq,
		),
	)

	var depth_mod: float = depth_noise.get_value(
		x,
		z,
		TerrainConfig.DEPTH_FREQ,
		TerrainConfig.DEPTH_FREQ,
	)

	var surface_detail: float = surface_noise.get_value(
		x * TerrainConfig.SURFACE_FREQ,
		z * TerrainConfig.SURFACE_FREQ,
	) * TerrainConfig.SURFACE_AMP / 70.0

	var base_h: float = base + (shaped * amplitude * (1.0 + depth_mod * 0.6)) + surface_detail

	var altitude_factor: float = smoothstep(
		TerrainConfig.ROUGHNESS_ALT_LOW,
		TerrainConfig.ROUGHNESS_ALT_HIGH,
		base_h,
	)

	var rough: float = roughness_noise.get_value(
		x,
		z,
		TerrainConfig.ROUGHNESS_FREQ,
		TerrainConfig.ROUGHNESS_FREQ,
	) * TerrainConfig.ROUGHNESS_AMP * altitude_factor

	return base_h + rough


func get_climate_color(x: float, z: float) -> Color:
	var temp_raw: float = temperature_noise.get_value(
		x * TerrainConfig.TEMPERATURE_FREQ,
		z * TerrainConfig.TEMPERATURE_FREQ,
	)
	var moist_raw: float = moisture_noise.get_value(
		x * TerrainConfig.MOISTURE_FREQ,
		z * TerrainConfig.MOISTURE_FREQ,
	)
	var cont_raw: float = continentalness_noise.get_value(
		x,
		z,
		TerrainConfig.CONTINENT_FREQ,
		TerrainConfig.CONTINENT_FREQ,
	)

	return Color(
		clampf(temp_raw * 0.5 + 0.5, 0.0, 1.0),
		clampf(moist_raw * 0.5 + 0.5, 0.0, 1.0),
		clampf(cont_raw * 0.5 + 0.5, 0.0, 1.0),
	)


func get_vertex_data(x: float, z: float) -> Dictionary:
	var height: float = get_height(x, z)
	var color: Color = get_climate_color(x, z)
	return { "height": height, "color": color }


func get_all_grids_batch(
		origin_x: float,
		origin_z: float,
		width: int,
		height: int,
		spacing: float,
		max_octaves: int = -1,
		height_freq: float = TerrainConfig.HEIGHT_FREQ,
) -> Dictionary:
	var total_verts: int = width * height
	var inv_spacing: float = 1.0 / spacing

	var cont_grid := PackedFloat32Array()
	cont_grid.resize(total_verts)
	continentalness_noise.generate_octaves(
		cont_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.CONTINENT_FREQ,
		spacing * TerrainConfig.CONTINENT_FREQ,
		max_octaves,
	)

	var peaks_grid := PackedFloat32Array()
	peaks_grid.resize(total_verts)
	peaks_noise.generate_octaves(
		peaks_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.PEAKS_FREQ,
		spacing * TerrainConfig.PEAKS_FREQ,
		max_octaves,
	)

	var noise_grid := PackedFloat32Array()
	noise_grid.resize(total_verts)
	height_noise.generate_octaves(
		noise_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * height_freq,
		spacing * height_freq,
		max_octaves,
	)

	var depth_grid := PackedFloat32Array()
	depth_grid.resize(total_verts)
	depth_noise.generate_octaves(
		depth_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.DEPTH_FREQ,
		spacing * TerrainConfig.DEPTH_FREQ,
		max_octaves,
	)

	var surface_grid := PackedFloat32Array()
	surface_grid.resize(total_verts)
	surface_noise.add(
		surface_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.SURFACE_FREQ,
		spacing * TerrainConfig.SURFACE_FREQ,
		TerrainConfig.SURFACE_AMP / 70.0,
	)

	var roughness_grid := PackedFloat32Array()
	roughness_grid.resize(total_verts)
	roughness_noise.generate_octaves(
		roughness_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.ROUGHNESS_FREQ,
		spacing * TerrainConfig.ROUGHNESS_FREQ,
		max_octaves,
	)

	var temp_grid := PackedFloat32Array()
	temp_grid.resize(total_verts)
	temperature_noise.add(
		temp_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.TEMPERATURE_FREQ,
		spacing * TerrainConfig.TEMPERATURE_FREQ,
		1.0,
	)

	var moist_grid := PackedFloat32Array()
	moist_grid.resize(total_verts)
	moisture_noise.add(
		moist_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.MOISTURE_FREQ,
		spacing * TerrainConfig.MOISTURE_FREQ,
		1.0,
	)

	return {
		"cont": cont_grid,
		"peaks": peaks_grid,
		"noise": noise_grid,
		"depth": depth_grid,
		"surface": surface_grid,
		"roughness": roughness_grid,
		"temp": temp_grid,
		"moist": moist_grid,
	}


func get_vertex_data_batch(
		origin_x: float,
		origin_z: float,
		width: int,
		height: int,
		spacing: float,
		out_vertices: PackedVector3Array,
		out_colors: PackedColorArray,
		max_octaves: int = -1,
		height_freq: float = TerrainConfig.HEIGHT_FREQ,
) -> void:
	var total_verts: int = width * height
	var inv_spacing: float = 1.0 / spacing

	var cont_grid: PackedFloat32Array = PackedFloat32Array()
	cont_grid.resize(total_verts)
	continentalness_noise.generate_octaves(
		cont_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.CONTINENT_FREQ,
		spacing * TerrainConfig.CONTINENT_FREQ,
		max_octaves,
	)

	var peaks_grid: PackedFloat32Array = PackedFloat32Array()
	peaks_grid.resize(total_verts)
	peaks_noise.generate_octaves(
		peaks_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.PEAKS_FREQ,
		spacing * TerrainConfig.PEAKS_FREQ,
		max_octaves,
	)

	var noise_grid: PackedFloat32Array = PackedFloat32Array()
	noise_grid.resize(total_verts)
	height_noise.generate_octaves(
		noise_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * height_freq,
		spacing * height_freq,
		max_octaves,
	)

	var depth_grid: PackedFloat32Array = PackedFloat32Array()
	depth_grid.resize(total_verts)
	depth_noise.generate_octaves(
		depth_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.DEPTH_FREQ,
		spacing * TerrainConfig.DEPTH_FREQ,
		max_octaves,
	)

	var surface_grid: PackedFloat32Array = PackedFloat32Array()
	surface_grid.resize(total_verts)
	surface_noise.add(
		surface_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.SURFACE_FREQ,
		spacing * TerrainConfig.SURFACE_FREQ,
		TerrainConfig.SURFACE_AMP / 70.0,
	)

	var roughness_grid: PackedFloat32Array = PackedFloat32Array()
	roughness_grid.resize(total_verts)
	roughness_noise.generate_octaves(
		roughness_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.ROUGHNESS_FREQ,
		spacing * TerrainConfig.ROUGHNESS_FREQ,
		max_octaves,
	)

	var temp_grid: PackedFloat32Array = PackedFloat32Array()
	temp_grid.resize(total_verts)
	temperature_noise.add(
		temp_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.TEMPERATURE_FREQ,
		spacing * TerrainConfig.TEMPERATURE_FREQ,
		1.0,
	)

	var moist_grid: PackedFloat32Array = PackedFloat32Array()
	moist_grid.resize(total_verts)
	moisture_noise.add(
		moist_grid,
		origin_x * inv_spacing,
		origin_z * inv_spacing,
		width,
		height,
		spacing * TerrainConfig.MOISTURE_FREQ,
		spacing * TerrainConfig.MOISTURE_FREQ,
		1.0,
	)

	var idx: int = 0
	for z in range(height):
		for x in range(width):
			var cont: float = cont_grid[idx]
			var peaks: float = peaks_grid[idx]

			var base: float = compute_base(cont)
			var amplitude: float = compute_amplitude(cont, peaks)

			var shaped_noise: float = shape_noise(noise_grid[idx])
			var base_h: float = base + (shaped_noise * amplitude * (1.0 + depth_grid[idx] * 0.6)) + surface_grid[idx]

			# roughness at altitude
			var altitude_factor: float = smoothstep(
				TerrainConfig.ROUGHNESS_ALT_LOW,
				TerrainConfig.ROUGHNESS_ALT_HIGH,
				base_h,
			)
			var h: float = base_h + roughness_grid[idx] * TerrainConfig.ROUGHNESS_AMP * altitude_factor

			var temp_01: float = clampf(temp_grid[idx] * 0.5 + 0.5, 0.0, 1.0)
			var moist_01: float = clampf(moist_grid[idx] * 0.5 + 0.5, 0.0, 1.0)
			var cont_01: float = clampf(cont * 0.5 + 0.5, 0.0, 1.0)

			var local_x: float = x * spacing
			var local_z: float = z * spacing
			out_vertices[idx] = Vector3(local_x, h, local_z)
			out_colors[idx] = Color(temp_01, moist_01, cont_01)
			idx += 1


func is_underwater(height_val: float) -> bool:
	return height_val < TerrainConfig.SEA_LEVEL


func get_debug_info(x: float, z: float) -> Dictionary:
	var height_val: float = get_height(x, z)
	var cont: float = continentalness_noise.get_value(
		x,
		z,
		TerrainConfig.CONTINENT_FREQ,
		TerrainConfig.CONTINENT_FREQ,
	)
	var peaks: float = peaks_noise.get_value(
		x,
		z,
		TerrainConfig.PEAKS_FREQ,
		TerrainConfig.PEAKS_FREQ,
	)
	var temp: float = temperature_noise.get_value(
		x * TerrainConfig.TEMPERATURE_FREQ,
		z * TerrainConfig.TEMPERATURE_FREQ,
	)
	var moist: float = moisture_noise.get_value(
		x * TerrainConfig.MOISTURE_FREQ,
		z * TerrainConfig.MOISTURE_FREQ,
	)

	return {
		"zone": _get_zone_name(cont, peaks, temp, moist, height_val),
		"height": height_val,
		"continentalness": cont,
		"peaks": peaks,
		"temperature": temp,
		"moisture": moist,
		"underwater": is_underwater(height_val),
	}


func _get_zone_name(
		_cont: float,
		_peaks: float,
		temp: float,
		moist: float,
		h: float,
) -> String:
	if h < TerrainConfig.SEA_LEVEL - TerrainConfig.DEEP_OCEAN_OFFSET:
		return "Deep Ocean"
	if h < TerrainConfig.SEA_LEVEL:
		return "Ocean"
	if h < TerrainConfig.COAST_MAX:
		return "Coast"
	if h >= TerrainConfig.HIGH_PEAKS_MIN:
		if temp < TerrainConfig.TUNDRA_TEMP:
			return "Snow Peaks"
		return "High Peaks"
	if h >= TerrainConfig.MOUNTAINS_MIN:
		if temp < TerrainConfig.TUNDRA_TEMP:
			return "Snow Mountains"
		return "Mountains"
	if h >= TerrainConfig.HIGHLANDS_MIN:
		if temp < TerrainConfig.TUNDRA_TEMP:
			return "Tundra Hills"
		return "Highlands"
	if temp > TerrainConfig.HOT_TEMP:
		if moist < TerrainConfig.JUNGLE_MOIST:
			return "Desert"
		return "Jungle"
	if temp < TerrainConfig.COLD_TEMP:
		return "Tundra"
	if moist > TerrainConfig.FOREST_MOIST:
		return "Forest"
	return "Plains"
