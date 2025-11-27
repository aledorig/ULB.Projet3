class_name BiomeManager
extends RefCounted

## Manages biome selection and blending using multi-noise approach
## Based on Minecraft's biome generation system

# ============================================================================
# NOISE GENERATORS
# ============================================================================

var continental_noise: FastNoiseLite  ## Ocean vs land (very large scale)
var erosion_noise:     FastNoiseLite  ## Flat vs mountainous (large scale)
var pv_noise:          FastNoiseLite  ## Peaks and valleys / rivers
var temperature_noise: FastNoiseLite  ## Hot vs cold (medium scale)
var humidity_noise:    FastNoiseLite  ## Dry vs wet (medium scale)

var seed_value: int

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	_setup_noise_maps()


func _setup_noise_maps() -> void:
	# Continental noise - determines ocean vs land
	continental_noise                    = FastNoiseLite.new()
	continental_noise.seed               = seed_value
	continental_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	continental_noise.frequency          = 0.001
	continental_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	continental_noise.fractal_octaves    = 3
	continental_noise.fractal_lacunarity = 2.0
	continental_noise.fractal_gain       = 0.5
	
	# Erosion noise - determines flat vs mountainous
	erosion_noise                    = FastNoiseLite.new()
	erosion_noise.seed               = seed_value
	erosion_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	erosion_noise.frequency          = 0.004
	erosion_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	erosion_noise.fractal_octaves    = 4
	erosion_noise.fractal_lacunarity = 2.0
	erosion_noise.fractal_gain       = 0.5
	
	# Peaks & valleys noise - creates rivers and dramatic terrain
	pv_noise                    = FastNoiseLite.new()
	pv_noise.seed               = seed_value
	pv_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	pv_noise.frequency          = 0.003
	pv_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	pv_noise.fractal_octaves    = 3
	pv_noise.fractal_lacunarity = 2.0
	pv_noise.fractal_gain       = 0.5
	
	# Temperature noise - hot vs cold
	temperature_noise                    = FastNoiseLite.new()
	temperature_noise.seed               = seed_value + 1000
	temperature_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency          = 0.001
	temperature_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	temperature_noise.fractal_octaves    = 3
	temperature_noise.fractal_lacunarity = 2.0
	temperature_noise.fractal_gain       = 0.5
	
	# Humidity noise - dry vs wet
	humidity_noise                    = FastNoiseLite.new()
	humidity_noise.seed               = seed_value + 2000
	humidity_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	humidity_noise.frequency          = 0.004
	humidity_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	humidity_noise.fractal_octaves    = 3
	humidity_noise.fractal_lacunarity = 2.0
	humidity_noise.fractal_gain       = 0.5

# ============================================================================
# BIOME DATA RETRIEVAL
# ============================================================================

func get_biome_data(world_x: float, world_z: float) -> Dictionary:
	# Sample all noise parameters
	var continental: float = continental_noise.get_noise_2d(world_x, world_z)
	var erosion:     float = erosion_noise.get_noise_2d(world_x, world_z)
	var weirdness:   float = pv_noise.get_noise_2d(world_x, world_z)
	var temperature: float = temperature_noise.get_noise_2d(world_x, world_z)
	var humidity:    float = humidity_noise.get_noise_2d(world_x, world_z)
	
	# Calculate PV (peaks and valleys) from weirdness
	# Formula from Minecraft: 1 - |3|weirdness| - 2|
	var pv: float = 1.0 - abs(3.0 * abs(weirdness) - 2.0)
	
	# Determine climate zone and biome
	var climate_zone: TerrainConstants.ClimateZone = _determine_climate_zone(temperature)
	var biome_type: TerrainConstants.BiomeType = _select_biome(
		continental, erosion, pv, temperature, humidity, climate_zone
	)
	
	# Calculate blend weights for smooth transitions
	var blend_weights: Dictionary = _calculate_blend_weights(
		biome_type, continental, erosion, temperature
	)
	
	return {
		"primary_biome": biome_type,
		"climate_zone": climate_zone,
		"continental": continental,
		"erosion": erosion,
		"pv": pv,
		"weirdness": weirdness,
		"temperature": temperature,
		"humidity": humidity,
		"blend_weights": blend_weights,
		"color": _get_blended_color(blend_weights),
		"grass_density": _get_blended_grass_density(blend_weights)
	}

# ============================================================================
# BIOME SELECTION
# ============================================================================

func _determine_climate_zone(temperature: float) -> TerrainConstants.ClimateZone:
	if temperature < -0.4:
		return TerrainConstants.ClimateZone.FROZEN
	elif temperature < -0.1:
		return TerrainConstants.ClimateZone.COLD
	elif temperature < 0.3:
		return TerrainConstants.ClimateZone.TEMPERATE
	else:
		return TerrainConstants.ClimateZone.TROPICAL


func _select_biome(
	continental: float,
	erosion: float,
	pv: float,
	temperature: float,
	humidity: float,
	climate_zone: TerrainConstants.ClimateZone
) -> TerrainConstants.BiomeType:
	# Default to plains
	var biome_type: TerrainConstants.BiomeType = TerrainConstants.BiomeType.PLAINS
	
	# High continental - inland mountains
	if continental > 0.2:
		if erosion < -0.4:
			if climate_zone == TerrainConstants.ClimateZone.FROZEN:
				biome_type = TerrainConstants.BiomeType.FROZEN_PEAKS
			else:
				biome_type = TerrainConstants.BiomeType.MOUNTAINS
	
	# Medium-high continental - land biomes
	elif continental > 0.05:
		if erosion > -0.1:
			match climate_zone:
				TerrainConstants.ClimateZone.FROZEN, TerrainConstants.ClimateZone.COLD:
					biome_type = TerrainConstants.BiomeType.FROZEN_PLAINS
				TerrainConstants.ClimateZone.TEMPERATE:
					if humidity < -0.4:
						biome_type = TerrainConstants.BiomeType.DESERT
					elif humidity > 0.3:
						biome_type = TerrainConstants.BiomeType.JUNGLE
				TerrainConstants.ClimateZone.TROPICAL:
					if humidity < 0.0:
						biome_type = TerrainConstants.BiomeType.DESERT
					else:
						biome_type = TerrainConstants.BiomeType.JUNGLE
	
	# Coastal - beach
	elif continental > -0.15:
		biome_type = TerrainConstants.BiomeType.BEACH
	
	# Shallow ocean
	elif continental > -0.45:
		biome_type = TerrainConstants.BiomeType.OCEAN
		match climate_zone:
			TerrainConstants.ClimateZone.FROZEN:
				biome_type = TerrainConstants.BiomeType.FROZEN_OCEAN
			TerrainConstants.ClimateZone.TROPICAL:
				biome_type = TerrainConstants.BiomeType.WARM_OCEAN
	
	# Deep ocean
	else:
		biome_type = TerrainConstants.BiomeType.DEEP_OCEAN
	
	return biome_type

# ============================================================================
# BIOME BLENDING
# ============================================================================

func _calculate_blend_weights(
	primary_biome: TerrainConstants.BiomeType,
	continental: float,
	erosion: float,
	temperature: float
) -> Dictionary:
	# Initialize all weights to 0
	var weights: Dictionary = {}
	for biome in TerrainConstants.BiomeType.values():
		weights[biome] = 0.0
	
	# Start with primary biome at full weight
	weights[primary_biome] = 1.0
	
	# Apply transition blending based on primary biome
	match primary_biome:
		TerrainConstants.BiomeType.OCEAN, TerrainConstants.BiomeType.DEEP_OCEAN:
			_blend_ocean_to_beach(weights, primary_biome, continental)
		TerrainConstants.BiomeType.BEACH:
			_blend_beach_to_land(weights, continental, temperature)
		TerrainConstants.BiomeType.MOUNTAINS, TerrainConstants.BiomeType.FROZEN_PEAKS:
			_blend_mountains_to_hills(weights, primary_biome, erosion, temperature)
		TerrainConstants.BiomeType.HILLS:
			_blend_hills_to_plains(weights, erosion)
	
	# Normalize weights
	_normalize_weights(weights)
	
	return weights


func _blend_ocean_to_beach(weights: Dictionary, primary: TerrainConstants.BiomeType, continental: float) -> void:
	var beach_blend: float = smoothstep(-0.25, -0.10, continental)
	if beach_blend > 0.0:
		weights[primary] = 1.0 - beach_blend
		weights[TerrainConstants.BiomeType.BEACH] = beach_blend


func _blend_beach_to_land(weights: Dictionary, continental: float, temperature: float) -> void:
	var land_blend: float = smoothstep(-0.05, 0.1, continental)
	if land_blend > 0.0:
		weights[TerrainConstants.BiomeType.BEACH] = 1.0 - land_blend
		if temperature > 0.2:
			weights[TerrainConstants.BiomeType.DESERT] = land_blend
		else:
			weights[TerrainConstants.BiomeType.PLAINS] = land_blend


func _blend_mountains_to_hills(
	weights: Dictionary,
	primary: TerrainConstants.BiomeType,
	erosion: float,
	temperature: float
) -> void:
	var hill_blend: float = smoothstep(-0.4, -0.1, erosion)
	if hill_blend > 0.0:
		weights[primary] = 1.0 - hill_blend
		if temperature < -0.2:
			weights[TerrainConstants.BiomeType.FROZEN_PLAINS] = hill_blend
		else:
			weights[TerrainConstants.BiomeType.HILLS] = hill_blend


func _blend_hills_to_plains(weights: Dictionary, erosion: float) -> void:
	var plains_blend: float = smoothstep(0.0, 0.2, erosion)
	if plains_blend > 0.0:
		weights[TerrainConstants.BiomeType.HILLS] = 1.0 - plains_blend
		weights[TerrainConstants.BiomeType.PLAINS] = plains_blend


func _normalize_weights(weights: Dictionary) -> void:
	var total: float = 0.0
	for biome in weights:
		total += weights[biome]
	
	if total > 0.0:
		for biome in weights:
			weights[biome] /= total


func _get_blended_color(blend_weights: Dictionary) -> Color:
	var color := Color.BLACK
	for biome in blend_weights:
		if blend_weights[biome] > 0.0:
			color += TerrainConstants.BIOME_COLORS[biome] * blend_weights[biome]
	return color


func _get_blended_grass_density(blend_weights: Dictionary) -> float:
	var density: float = 0.0
	for biome in blend_weights:
		density += TerrainConstants.GRASS_DENSITY[biome] * blend_weights[biome]
	return density

# ============================================================================
# SNOW CALCULATION
# ============================================================================

func get_snow_amount(world_y: float, biome_data: Dictionary) -> float:
	var snow: float = 0.0
	
	# Snow in frozen biomes
	if biome_data.climate_zone == TerrainConstants.ClimateZone.FROZEN:
		snow = smoothstep(8.0, 15.0, world_y)
	elif biome_data.climate_zone == TerrainConstants.ClimateZone.COLD:
		snow = smoothstep(20.0, 30.0, world_y) * 0.5
	
	# Additional snow on high mountains
	var mountain_weight: float = biome_data.blend_weights.get(TerrainConstants.BiomeType.MOUNTAINS, 0.0)
	var frozen_peak_weight: float = biome_data.blend_weights.get(TerrainConstants.BiomeType.FROZEN_PEAKS, 0.0)
	
	if mountain_weight > 0.0:
		var mountain_snow: float = smoothstep(40.0, 55.0, world_y) * mountain_weight
		snow = max(snow, mountain_snow)
	
	if frozen_peak_weight > 0.0:
		var peak_snow: float = smoothstep(30.0, 45.0, world_y) * frozen_peak_weight
		snow = max(snow, peak_snow)
	
	return clamp(snow, 0.0, 1.0)
