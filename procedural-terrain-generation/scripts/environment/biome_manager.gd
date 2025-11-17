class_name BiomeManager
extends RefCounted

# ============================================================================
# NOISE LAYERS
# ============================================================================

# Noise layers (Minecraft approach)
var continental_noise: FastNoiseLite  # Ocean vs land
var erosion_noise:     FastNoiseLite  # Flat vs mountainous
var pv_noise:          FastNoiseLite  # Peaks and valleys (rivers)
var temperature_noise: FastNoiseLite  # Hot vs cold
var humidity_noise:    FastNoiseLite  # Dry vs wet

var seed_value: int

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int = 0):
	seed_value = p_seed
	_setup_noise_maps()

func _setup_noise_maps():
	# CONTINENTAL NOISE - Determines ocean vs land (very large scale)
	continental_noise                    = FastNoiseLite.new()
	continental_noise.seed               = seed_value
	continental_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	continental_noise.frequency          = 0.001
	continental_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	continental_noise.fractal_octaves    = 3
	continental_noise.fractal_lacunarity = 2.0
	continental_noise.fractal_gain       = 0.5
	
	#var image = continental_noise.get_image(2000,2000)
	#image.save_png("user://continental.png")
	# EROSION NOISE - Determines flat vs mountainous (large scale)
	erosion_noise                    = FastNoiseLite.new()
	erosion_noise.seed               = seed_value
	erosion_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	erosion_noise.frequency          = 0.004
	erosion_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	erosion_noise.fractal_octaves    = 4
	erosion_noise.fractal_lacunarity = 2.0
	erosion_noise.fractal_gain       = 0.5

	# PV (PEAKS & VALLEYS) NOISE - Creates rivers and dramatic terrain
	pv_noise                    = FastNoiseLite.new()
	pv_noise.seed               = seed_value
	pv_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	pv_noise.frequency          = 0.003
	pv_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	pv_noise.fractal_octaves    = 3
	pv_noise.fractal_lacunarity = 2.0
	pv_noise.fractal_gain       = 0.5
	
	# TEMPERATURE NOISE - Hot vs cold (medium scale)
	temperature_noise                    = FastNoiseLite.new()
	temperature_noise.seed               = seed_value + 1000
	temperature_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency          = 0.001
	temperature_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	temperature_noise.fractal_octaves    = 3
	temperature_noise.fractal_lacunarity = 2.0
	temperature_noise.fractal_gain       = 0.5
	
	# HUMIDITY NOISE - Dry vs wet (medium scale)
	humidity_noise                    = FastNoiseLite.new()
	humidity_noise.seed               = seed_value + 2000
	humidity_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	humidity_noise.frequency          = 0.004
	humidity_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	humidity_noise.fractal_octaves    = 3
	humidity_noise.fractal_lacunarity = 2.0
	humidity_noise.fractal_gain       = 0.5

# ============================================================================
# BIOME SELECTION
# ============================================================================

func get_biome_data(world_x: float, world_z: float) -> Dictionary:
	# Sample all noise parameters
	var continental = continental_noise.get_noise_2d(world_x, world_z)
	var erosion     = erosion_noise.get_noise_2d(world_x, world_z)
	var weirdness   = pv_noise.get_noise_2d(world_x, world_z)
	var temperature = temperature_noise.get_noise_2d(world_x, world_z)
	var humidity    = humidity_noise.get_noise_2d(world_x, world_z)
	
	# Calculate PV (peaks and valleys) from weirdness
	# Formula from Minecraft: 1 - |3|weirdness| - 2|
	var pv = 1.0 - abs(3.0 * abs(weirdness) - 2.0)
	
	# Determine climate zone
	var climate_zone = _determine_climate_zone(temperature)
	
	# Select biome based on all parameters
	var biome_type = _select_biome(continental, erosion, pv, temperature, humidity, climate_zone)
	
	# Calculate blend weights for smooth transitions
	var blend_weights = _calculate_blend_weights(biome_type, continental, erosion, temperature)
	
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

func _determine_climate_zone(temperature: float) -> TerrainConstants.ClimateZone:
	if temperature < -0.4:
		return TerrainConstants.ClimateZone.FROZEN
	elif temperature < -0.1:
		return TerrainConstants.ClimateZone.COLD
	elif temperature < 0.3:
		return TerrainConstants.ClimateZone.TEMPERATE
	else:
		return TerrainConstants.ClimateZone.TROPICAL

func _select_biome(continental: float, erosion: float, pv: float, temperature: float, humidity: float, climate_zone: TerrainConstants.ClimateZone) -> TerrainConstants.BiomeType:
	# STEP 1: Check continentalness - ocean vs land
	var biome_type = TerrainConstants.BiomeType.PLAINS

		# STEP 2: Land biomes - mountains (high erosion)
	if continental > 0.2:
		if erosion < -0.4:
			if climate_zone==TerrainConstants.ClimateZone.FROZEN:
				biome_type = TerrainConstants.BiomeType.FROZEN_PEAKS
			else:
				biome_type = TerrainConstants.BiomeType.MOUNTAINS
	elif continental > 0.05:
		if erosion > -0.1:
			match climate_zone:
				TerrainConstants.ClimateZone.FROZEN:
					biome_type = TerrainConstants.BiomeType.FROZEN_PLAINS
				TerrainConstants.ClimateZone.COLD:
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
		if pv < -0.35 and erosion > 0.3:
			biome_type = TerrainConstants.BiomeType.RIVER
	elif continental > -0.15:
		biome_type = TerrainConstants.BiomeType.BEACH
	# Ocean
	elif continental > -0.45:
		biome_type = TerrainConstants.BiomeType.OCEAN
		match climate_zone:
			TerrainConstants.ClimateZone.FROZEN:
				biome_type = TerrainConstants.BiomeType.FROZEN_OCEAN
			TerrainConstants.ClimateZone.TROPICAL:
				biome_type = TerrainConstants.BiomeType.WARM_OCEAN
	elif continental < -0.45:
		biome_type = TerrainConstants.BiomeType.DEEP_OCEAN
	else:
		biome_type = TerrainConstants.BiomeType.PLAINS
	return biome_type

# ============================================================================
# BIOME BLENDING
# ============================================================================

func _calculate_blend_weights(primary_biome: TerrainConstants.BiomeType, continental: float, erosion: float, temperature: float) -> Dictionary:
	# Initialize all weights to 0
	var weights = {}
	for biome in TerrainConstants.BiomeType.values():
		weights[biome] = 0.0
	
	# Start with primary biome at full weight
	weights[primary_biome] = 1.0
	
	# Ocean to beach transitions
	if primary_biome == TerrainConstants.BiomeType.OCEAN or primary_biome == TerrainConstants.BiomeType.DEEP_OCEAN:
		var beach_blend = smoothstep(-0.25, -0.10, continental)
		if beach_blend > 0.0:
			weights[primary_biome] = 1.0 - beach_blend
			weights[TerrainConstants.BiomeType.BEACH] = beach_blend
	
	# Beach to land transitions
	elif primary_biome == TerrainConstants.BiomeType.BEACH:
		var land_blend = smoothstep(-0.05, 0.1, continental)
		if land_blend > 0.0:
			weights[TerrainConstants.BiomeType.BEACH] = 1.0 - land_blend
			# Blend to appropriate land biome
			if temperature > 0.2:
				weights[TerrainConstants.BiomeType.DESERT] = land_blend
			else:
				weights[TerrainConstants.BiomeType.PLAINS] = land_blend
	
	# Mountain to hills transitions
	elif primary_biome == TerrainConstants.BiomeType.MOUNTAINS or primary_biome == TerrainConstants.BiomeType.FROZEN_PEAKS:
		var hill_blend = smoothstep(-0.4, -0.1, erosion)
		if hill_blend > 0.0:
			weights[primary_biome] = 1.0 - hill_blend
			if temperature < -0.2:
				weights[TerrainConstants.BiomeType.FROZEN_PLAINS] = hill_blend
			else:
				weights[TerrainConstants.BiomeType.HILLS] = hill_blend
	
	# Hills to plains transitions
	elif primary_biome == TerrainConstants.BiomeType.HILLS:
		var plains_blend = smoothstep(0.0, 0.2, erosion)
		if plains_blend > 0.0:
			weights[TerrainConstants.BiomeType.HILLS] = 1.0 - plains_blend
			weights[TerrainConstants.BiomeType.PLAINS] = plains_blend
	
	# Normalize weights
	var sum = 0.0
	for biome in weights:
		sum += weights[biome]
	
	if sum > 0.0:
		for biome in weights:
			weights[biome] /= sum
	
	return weights

func _get_blended_color(blend_weights: Dictionary) -> Color:
	var color = Color.BLACK
	for biome in blend_weights:
		if blend_weights[biome] > 0.0:
			color += TerrainConstants.BIOME_COLORS[biome] * blend_weights[biome]
	return color

func _get_blended_grass_density(blend_weights: Dictionary) -> float:
	var density = 0.0
	for biome in blend_weights:
		density += TerrainConstants.GRASS_DENSITY[biome] * blend_weights[biome]
	return density

# ============================================================================
# SNOW CALCULATION
# ============================================================================

func get_snow_amount(world_y: float, biome_data: Dictionary) -> float:
	var snow = 0.0
	
	# Snow in frozen biomes
	if biome_data.climate_zone == TerrainConstants.ClimateZone.FROZEN:
		snow = smoothstep(8.0, 15.0, world_y)
	elif biome_data.climate_zone == TerrainConstants.ClimateZone.COLD:
		snow = smoothstep(20.0, 30.0, world_y) * 0.5
	
	# Additional snow on high mountains
	var mountain_weight = biome_data.blend_weights.get(TerrainConstants.BiomeType.MOUNTAINS, 0.0)
	var frozen_peak_weight = biome_data.blend_weights.get(TerrainConstants.BiomeType.FROZEN_PEAKS, 0.0)
	
	if mountain_weight > 0.0:
		var mountain_snow = smoothstep(40.0, 55.0, world_y) * mountain_weight
		snow = max(snow, mountain_snow)
	
	if frozen_peak_weight > 0.0:
		var peak_snow = smoothstep(30.0, 45.0, world_y) * frozen_peak_weight
		snow = max(snow, peak_snow)
	
	return clamp(snow, 0.0, 1.0)
