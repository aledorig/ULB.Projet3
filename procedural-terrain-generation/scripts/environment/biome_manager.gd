class_name BiomeManager
extends RefCounted

## Simplified biome selection using 3 noise parameters:
## - Temperature (hot vs cold)
## - Moisture (dry vs wet)  
## - Continentalness (ocean vs inland)

# ============================================================================
# NOISE GENERATORS
# ============================================================================

var temperature_noise: FastNoiseLite
var moisture_noise:    FastNoiseLite
var continental_noise: FastNoiseLite
var seed_value: int

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	_setup_noise()


func _setup_noise() -> void:
	# Temperature - large scale climate zones
	temperature_noise                 = FastNoiseLite.new()
	temperature_noise.seed            = seed_value
	temperature_noise.noise_type      = FastNoiseLite.TYPE_SIMPLEX
	temperature_noise.frequency       = 0.0008  # Very large scale ~1250 units per cycle
	temperature_noise.fractal_type    = FastNoiseLite.FRACTAL_FBM
	temperature_noise.fractal_octaves = 2
	
	# Moisture - medium-large scale
	moisture_noise                 = FastNoiseLite.new()
	moisture_noise.seed            = seed_value + 1000
	moisture_noise.noise_type      = FastNoiseLite.TYPE_SIMPLEX
	moisture_noise.frequency       = 0.001  # ~1000 units per cycle
	moisture_noise.fractal_type    = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = 2
	
	# Continentalness - controls ocean vs land, largest scale
	continental_noise                 = FastNoiseLite.new()
	continental_noise.seed            = seed_value + 2000
	continental_noise.noise_type      = FastNoiseLite.TYPE_SIMPLEX
	continental_noise.frequency       = 0.0005  # Very large ~2000 units per cycle
	continental_noise.fractal_type    = FastNoiseLite.FRACTAL_FBM
	continental_noise.fractal_octaves = 3

# ============================================================================
# NOISE SAMPLING
# ============================================================================

func get_temperature(x: float, z: float) -> float:
	# Returns -1 to 1: cold to hot
	return temperature_noise.get_noise_2d(x, z)


func get_moisture(x: float, z: float) -> float:
	# Returns -1 to 1: dry to wet
	return moisture_noise.get_noise_2d(x, z)


func get_continentalness(x: float, z: float) -> float:
	# Returns -1 to 1: deep ocean to inland mountains
	return continental_noise.get_noise_2d(x, z)

# ============================================================================
# BIOME SELECTION
# ============================================================================

func get_biome(x: float, z: float) -> TerrainConstants.Biome:
	var temp:        float = get_temperature(x, z)
	var moisture:    float = get_moisture(x, z)
	var continental: float = get_continentalness(x, z)
	return _select_biome(temp, moisture, continental)


func _select_biome(temp: float, moisture: float, continental: float) -> TerrainConstants.Biome:
	# Step 1: Check if we're in ocean/beach based on continentalness
	if continental < -0.3:
		return TerrainConstants.Biome.OCEAN
	
	if continental < -0.1:
		return TerrainConstants.Biome.BEACH
	
	# Step 2: Check if we're in mountains (high continentalness)
	if continental > 0.5:
		if temp < -0.2:
			return TerrainConstants.Biome.SNOW_PEAKS
		else:
			return TerrainConstants.Biome.MOUNTAINS
	
	# Step 3: Land biomes based on temperature and moisture grid
	# 
	#              DRY (< -0.2)    MID (-0.2 to 0.3)    WET (> 0.3)
	# COLD (< -0.2)  Tundra           Tundra              Tundra
	# MID            Desert           Plains              Forest
	# HOT (> 0.3)    Desert           Plains              Jungle
	
	if temp < -0.2:
		# Cold - always tundra regardless of moisture
		return TerrainConstants.Biome.TUNDRA
	
	if moisture < -0.2:
		# Dry - desert
		return TerrainConstants.Biome.DESERT
	
	if moisture > 0.3:
		# Wet
		if temp > 0.3:
			return TerrainConstants.Biome.JUNGLE
		else:
			return TerrainConstants.Biome.FOREST
	
	# Default - plains
	return TerrainConstants.Biome.PLAINS

# ============================================================================
# TERRAIN PARAMETERS (for height generation)
# ============================================================================

func get_terrain_params(x: float, z: float) -> Dictionary:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_PARAMS[biome]


func get_biome_color(x: float, z: float) -> Color:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_COLORS[biome]

# ============================================================================
# BLENDED TERRAIN PARAMETERS (for smooth biome transitions)
# ============================================================================

func get_blended_params(x: float, z: float, blend_radius: float = 16.0) -> Dictionary:
	## Sample biomes in a radius and blend their terrain parameters
	## This prevents harsh cliffs at biome borders
	
	var total_weight: float = 0.0
	var blended_base: float = 0.0
	var blended_variation: float = 0.0
	var blended_color: Color = Color.BLACK
	
	# Sample in a cross pattern (cheaper than full grid)
	var offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-blend_radius, 0),
		Vector2(blend_radius, 0),
		Vector2(0, -blend_radius),
		Vector2(0, blend_radius),
	]
	
	var weights: Array[float] = [2.0, 1.0, 1.0, 1.0, 1.0]  # Center weighted higher
	
	for i in range(offsets.size()):
		var sx: float = x + offsets[i].x
		var sz: float = z + offsets[i].y
		var w: float = weights[i]
		
		var params: Dictionary = get_terrain_params(sx, sz)
		var color: Color = get_biome_color(sx, sz)
		
		blended_base += params.base * w
		blended_variation += params.variation * w
		blended_color += color * w
		total_weight += w
	
	return {
		"base": blended_base / total_weight,
		"variation": blended_variation / total_weight,
		"color": blended_color / total_weight,
	}
