class_name TerrainGenerator
extends RefCounted

## Simplified terrain generation pipeline:
## 1. Sample biome at (x, z) using BiomeManager
## 2. Get terrain params (base_height, variation) from biome
## 3. Sample height noise at (x, z)
## 4. Final height = base_height + (noise * variation)

# ============================================================================
# COMPONENTS
# ============================================================================

var biome_manager: BiomeManager
var height_noise:  FastNoiseLite
var seed_value:    int

# ============================================================================
# CONFIGURATION
# ============================================================================

## Whether to blend biome params at borders (smoother but slower)
var use_biome_blending: bool = true
var blend_radius:       float = 16.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	biome_manager = BiomeManager.new(p_seed)
	_setup_height_noise()


func _setup_height_noise() -> void:
	# Height noise - smaller scale than biome noise, multi-octave for detail
	height_noise                    = FastNoiseLite.new()
	height_noise.seed               = seed_value + 5000
	height_noise.noise_type         = FastNoiseLite.TYPE_SIMPLEX
	height_noise.frequency          = 0.005  # ~200 units per cycle
	height_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	height_noise.fractal_octaves    = 4
	height_noise.fractal_lacunarity = 2.0
	height_noise.fractal_gain       = 0.5

# ============================================================================
# HEIGHT GENERATION
# ============================================================================

func get_height(x: float, z: float) -> float:
	# Step 1: Get biome terrain parameters
	var params: Dictionary
	if use_biome_blending:
		params = biome_manager.get_blended_params(x, z, blend_radius)
	else:
		params = biome_manager.get_terrain_params(x, z)
	
	var base_height: float = params.base
	var variation: float = params.variation
	
	# Step 2: Sample height noise (-1 to 1)
	var noise_val: float = height_noise.get_noise_2d(x, z)
	
	# Step 3: Compute final height
	var height: float = base_height + (noise_val * variation)
	
	return height

# ============================================================================
# SURFACE PROPERTIES
# ============================================================================

func get_biome(x: float, z: float) -> TerrainConstants.Biome:
	return biome_manager.get_biome(x, z)


func get_surface_color(x: float, z: float, height: float) -> Color:
	var color: Color
	
	if use_biome_blending:
		var params: Dictionary = biome_manager.get_blended_params(x, z, blend_radius)
		color = params.color
	else:
		color = biome_manager.get_biome_color(x, z)
	
	# Darken underwater areas
	if height < TerrainConstants.SEA_LEVEL:
		var depth: float = TerrainConstants.SEA_LEVEL - height
		var darkness: float = clampf(depth / 40.0, 0.0, 0.6)
		color = color.darkened(darkness)
	
	# Snow on high peaks
	if height > 60.0:
		var snow_amount: float = smoothstep(60.0, 80.0, height)
		var snow_color: Color = Color(0.95, 0.97, 1.0)
		color = color.lerp(snow_color, snow_amount)
	
	return color


func is_underwater(height: float) -> bool:
	return height < TerrainConstants.SEA_LEVEL

# ============================================================================
# DEBUG / UTILITY
# ============================================================================

func get_biome_name(x: float, z: float) -> String:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	return TerrainConstants.BIOME_NAMES[biome]


func get_debug_info(x: float, z: float) -> Dictionary:
	var biome: TerrainConstants.Biome = get_biome(x, z)
	var height: float = get_height(x, z)
	
	return {
		"biome": TerrainConstants.BIOME_NAMES[biome],
		"height": height,
		"temperature": biome_manager.get_temperature(x, z),
		"moisture": biome_manager.get_moisture(x, z),
		"continentalness": biome_manager.get_continentalness(x, z),
		"underwater": is_underwater(height),
	}
