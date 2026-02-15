class_name TerrainGenerator
extends RefCounted

var height_noise:  OctaveNoise
var depth_noise:   OctaveNoise
var surface_noise: SimplexNoise

var continentalness_noise: OctaveNoise
var peaks_noise:           OctaveNoise
var temperature_noise:     SimplexNoise
var moisture_noise:        SimplexNoise

var seed_value: int

# Noise frequencies
const CONTINENT_FREQ:    float = 0.0004
const PEAKS_FREQ:        float = 0.0012
const TEMPERATURE_FREQ:  float = 0.0015
const MOISTURE_FREQ:     float = 0.0012
const HEIGHT_FREQ:       float = 0.0005
const DEPTH_FREQ:        float = 0.0008
const SURFACE_FREQ:      float = 0.012

# Height shaping
const OCEAN_BASE:     float = -50.0
const LAND_BASE:      float = 6.0
const MIN_AMPLITUDE:  float = 30.0
const MAX_AMPLITUDE:  float = 350.0
const SURFACE_AMP:    float = 3.0


func _init(p_seed: int = GameSettingsAutoload.seed, p_octaves: int = GameSettingsAutoload.octave) -> void:
	seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed

	height_noise  = OctaveNoise.new(rng, p_octaves)
	depth_noise   = OctaveNoise.new(rng, p_octaves)
	surface_noise = SimplexNoise.new(rng)

	continentalness_noise = OctaveNoise.new(rng, p_octaves)
	peaks_noise           = OctaveNoise.new(rng, p_octaves)
	temperature_noise     = SimplexNoise.new(rng)
	moisture_noise        = SimplexNoise.new(rng)


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _shape_noise(n: float) -> float:
	return absf(n) ** 1.6 * signf(n)


func _compute_base(cont: float) -> float:
	var sea_land: float = lerpf(OCEAN_BASE, LAND_BASE, _smoothstep(-0.5, -0.15, cont))
	var inland_boost: float = _smoothstep(-0.15, 0.2, cont) * 35.0
	return sea_land + inland_boost


func _compute_amplitude(cont: float, peaks: float) -> float:
	var land_factor: float = _smoothstep(-0.5, -0.15, cont)
	# Lower peaks threshold (-0.6 to 0.3) means mountains appear more often
	return lerpf(MIN_AMPLITUDE, MAX_AMPLITUDE, _smoothstep(-0.6, 0.3, peaks)) * lerpf(0.3, 1.0, land_factor)


func get_height(x: float, z: float) -> float:
	var cont: float = continentalness_noise.get_value(x, z, CONTINENT_FREQ, CONTINENT_FREQ)
	var peaks: float = peaks_noise.get_value(x, z, PEAKS_FREQ, PEAKS_FREQ)

	var base: float = _compute_base(cont)
	var amplitude: float = _compute_amplitude(cont, peaks)

	var shaped: float = _shape_noise(height_noise.get_value(x, z, HEIGHT_FREQ, HEIGHT_FREQ))
	var depth_mod: float = depth_noise.get_value(x, z, DEPTH_FREQ, DEPTH_FREQ)
	var surface_detail: float = surface_noise.get_value(x * SURFACE_FREQ, z * SURFACE_FREQ) * SURFACE_AMP / 70.0

	return base + (shaped * amplitude * (1.0 + depth_mod * 0.6)) + surface_detail


func get_climate_color(x: float, z: float) -> Color:
	var temp_raw: float = temperature_noise.get_value(x * TEMPERATURE_FREQ, z * TEMPERATURE_FREQ)
	var moist_raw: float = moisture_noise.get_value(x * MOISTURE_FREQ, z * MOISTURE_FREQ)
	var cont_raw: float = continentalness_noise.get_value(x, z, CONTINENT_FREQ, CONTINENT_FREQ)
	return Color(
		clampf(temp_raw * 0.5 + 0.5, 0.0, 1.0),
		clampf(moist_raw * 0.5 + 0.5, 0.0, 1.0),
		clampf(cont_raw * 0.5 + 0.5, 0.0, 1.0),
	)


func get_vertex_data(x: float, z: float) -> Dictionary:
	var height: float = get_height(x, z)
	var color: Color = get_climate_color(x, z)
	return {"height": height, "color": color}


func get_vertex_data_batch(
	origin_x: float, origin_z: float,
	width: int, height: int,
	spacing: float,
	out_vertices: PackedVector3Array,
	out_colors: PackedColorArray
) -> void:
	var total_verts: int = width * height
	var inv_spacing: float = 1.0 / spacing

	var cont_grid: PackedFloat32Array = PackedFloat32Array()
	cont_grid.resize(total_verts)
	continentalness_noise.generate_octaves(
		cont_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * CONTINENT_FREQ, spacing * CONTINENT_FREQ
	)

	var peaks_grid: PackedFloat32Array = PackedFloat32Array()
	peaks_grid.resize(total_verts)
	peaks_noise.generate_octaves(
		peaks_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * PEAKS_FREQ, spacing * PEAKS_FREQ
	)

	var noise_grid: PackedFloat32Array = PackedFloat32Array()
	noise_grid.resize(total_verts)
	height_noise.generate_octaves(
		noise_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * HEIGHT_FREQ, spacing * HEIGHT_FREQ
	)

	var depth_grid: PackedFloat32Array = PackedFloat32Array()
	depth_grid.resize(total_verts)
	depth_noise.generate_octaves(
		depth_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * DEPTH_FREQ, spacing * DEPTH_FREQ
	)

	var surface_grid: PackedFloat32Array = PackedFloat32Array()
	surface_grid.resize(total_verts)
	surface_noise.add(
		surface_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * SURFACE_FREQ, spacing * SURFACE_FREQ,
		SURFACE_AMP / 70.0
	)

	var temp_grid: PackedFloat32Array = PackedFloat32Array()
	temp_grid.resize(total_verts)
	temperature_noise.add(
		temp_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * TEMPERATURE_FREQ, spacing * TEMPERATURE_FREQ,
		1.0
	)

	var moist_grid: PackedFloat32Array = PackedFloat32Array()
	moist_grid.resize(total_verts)
	moisture_noise.add(
		moist_grid,
		origin_x * inv_spacing, origin_z * inv_spacing,
		width, height,
		spacing * MOISTURE_FREQ, spacing * MOISTURE_FREQ,
		1.0
	)

	var idx: int = 0
	for z in range(height):
		for x in range(width):
			var cont: float = cont_grid[idx]
			var peaks: float = peaks_grid[idx]

			var base: float = _compute_base(cont)
			var amplitude: float = _compute_amplitude(cont, peaks)

			var shaped_noise: float = _shape_noise(noise_grid[idx])
			var h: float = base + (shaped_noise * amplitude * (1.0 + depth_grid[idx] * 0.6)) + surface_grid[idx]

			var temp_01: float = clampf(temp_grid[idx] * 0.5 + 0.5, 0.0, 1.0)
			var moist_01: float = clampf(moist_grid[idx] * 0.5 + 0.5, 0.0, 1.0)
			var cont_01: float = clampf(cont * 0.5 + 0.5, 0.0, 1.0)

			var local_x: float = x * spacing
			var local_z: float = z * spacing
			out_vertices[idx] = Vector3(local_x, h, local_z)
			out_colors[idx] = Color(temp_01, moist_01, cont_01)
			idx += 1


func is_underwater(height_val: float) -> bool:
	return height_val < TerrainConstants.SEA_LEVEL


func get_debug_info(x: float, z: float) -> Dictionary:
	var height_val: float = get_height(x, z)
	var cont: float = continentalness_noise.get_value(x, z, CONTINENT_FREQ, CONTINENT_FREQ)
	var peaks: float = peaks_noise.get_value(x, z, PEAKS_FREQ, PEAKS_FREQ)
	var temp: float = temperature_noise.get_value(x * TEMPERATURE_FREQ, z * TEMPERATURE_FREQ)
	var moist: float = moisture_noise.get_value(x * MOISTURE_FREQ, z * MOISTURE_FREQ)

	return {
		"zone": _get_zone_name(cont, peaks, temp, moist, height_val),
		"height": height_val,
		"continentalness": cont,
		"peaks": peaks,
		"temperature": temp,
		"moisture": moist,
		"underwater": is_underwater(height_val),
	}


func _get_zone_name(_cont: float, _peaks: float, temp: float, moist: float, h: float) -> String:
	if h < TerrainConstants.SEA_LEVEL - 20.0:
		return "Deep Ocean"
	if h < TerrainConstants.SEA_LEVEL:
		return "Ocean"
	if h < 8.0:
		return "Coast"
	if h >= 200.0:
		if temp < -0.2:
			return "Snow Peaks"
		return "High Peaks"
	if h >= 120.0:
		if temp < -0.2:
			return "Snow Mountains"
		return "Mountains"
	if h >= 60.0:
		if temp < -0.2:
			return "Tundra Hills"
		return "Highlands"
	if temp > 0.4:
		if moist < -0.1:
			return "Desert"
		return "Jungle"
	if temp < -0.3:
		return "Tundra"
	if moist > 0.1:
		return "Forest"
	return "Plains"
