class_name TerrainGenerator
extends RefCounted

## Generates terrain height using 3D density-based approach
## Inspired by Minecraft's terrain generation system

# ============================================================================
# NOISE GENERATORS
# ============================================================================

var main_noise:   FastNoiseLite  ## Primary terrain shape
var detail_noise: FastNoiseLite  ## Surface detail variation
var ridge_noise:  FastNoiseLite ## Mountain ridges

# ============================================================================
# CONFIGURATION
# ============================================================================

var biome_manager:  BiomeManager
var vertex_spacing: float
var sea_level:      float = TerrainConstants.BEACH_FLOOR

## Grid sampling parameters for interpolation
var sample_spacing: float = 8.0

## Height cache for performance
var height_cache: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int, p_vertex_spacing: float = 2.0) -> void:
	vertex_spacing = p_vertex_spacing
	biome_manager = BiomeManager.new(p_seed)
	_setup_noise(p_seed)


func _setup_noise(terrain_seed: int) -> void:
	# Main noise - determines overall terrain shape
	main_noise                    = FastNoiseLite.new()
	main_noise.seed               = terrain_seed
	main_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	main_noise.frequency          = 0.008
	main_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	main_noise.fractal_octaves    = 8
	main_noise.fractal_lacunarity = 2.0
	main_noise.fractal_gain       = 0.5
	
	# Detail noise for surface variation
	detail_noise                 = FastNoiseLite.new()
	detail_noise.seed            = terrain_seed + 3000
	detail_noise.noise_type      = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency       = 0.08
	detail_noise.fractal_octaves = 2
	
	# Ridge noise for mountains
	ridge_noise                 = FastNoiseLite.new()
	ridge_noise.seed            = terrain_seed + 4000
	ridge_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	ridge_noise.frequency       = 0.008
	ridge_noise.fractal_type    = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.fractal_octaves = 3

# ============================================================================
# HEIGHT GENERATION
# ============================================================================

func get_height(world_x: float, world_z: float) -> float:
	# Calculate which grid cell we're in
	var grid_x: float = floor(world_x / sample_spacing) * sample_spacing
	var grid_z: float = floor(world_z / sample_spacing) * sample_spacing
	
	# Get the 4 corner heights using 3D density calculation
	var h00: float = _get_surface_height(grid_x, grid_z)
	var h10: float = _get_surface_height(grid_x + sample_spacing, grid_z)
	var h01: float = _get_surface_height(grid_x, grid_z + sample_spacing)
	var h11: float = _get_surface_height(grid_x + sample_spacing, grid_z + sample_spacing)
	
	# Get interpolation factors
	var local_x: float = (world_x - grid_x) / sample_spacing
	var local_z: float = (world_z - grid_z) / sample_spacing
	
	# Apply smoothstep for smoother interpolation
	local_x = smoothstep(0.0, 1.0, local_x)
	local_z = smoothstep(0.0, 1.0, local_z)
	
	# Bilinear interpolation
	var h0: float = lerp(h00, h10, local_x)
	var h1: float = lerp(h01, h11, local_x)
	
	return lerp(h0, h1, local_z)


func _get_surface_height(grid_x: float, grid_z: float) -> float:
	var key := Vector2(grid_x, grid_z)
	if key in height_cache:
		return height_cache[key]
	
	var height: float = _calculate_surface_from_density(grid_x, grid_z)
	height_cache[key] = height
	return height

# ============================================================================
# 3D DENSITY CALCULATION
# ============================================================================

func _calculate_surface_from_density(world_x: float, world_z: float) -> float:
	var biome_data: Dictionary = _get_biome_blended_data(world_x, world_z)
	
	var min_y: int = TerrainConstants.MIN_HEIGHT
	var max_y: int = TerrainConstants.MAX_HEIGHT
	var surface_y: float = sea_level
	
	# Scan from top to bottom to find surface (where density > 0)
	for y in range(max_y, min_y, -1):
		var density: float = _calculate_3d_density(world_x, float(y), world_z, biome_data)
		if density > 0.0:
			surface_y = float(y)
			break
	
	return surface_y


func _calculate_3d_density(
	world_x: float,
	world_y: float,
	world_z: float,
	biome_data: Dictionary
) -> float:
	# Base density from 2D noise
	var base_density: float = main_noise.get_noise_2d(world_x, world_z)
	
	# Get biome parameters
	var continental: float = biome_data.continental
	var erosion: float = biome_data.erosion
	
	# Calculate target height based on biome
	var target_height: float = _get_target_height_for_biome(continental, erosion, world_x, world_z)
	
	# Height falloff (solid below target, air above)
	var height_factor: float = (world_y - target_height) * 0.15
	
	# Apply steeper falloff at extreme heights
	if world_y > target_height + 20.0:
		var fade: float = (world_y - target_height - 20.0) / 10.0
		height_factor = lerp(height_factor, height_factor * 4.0, clamp(fade, 0.0, 1.0))
	
	return base_density - height_factor


func _get_target_height_for_biome(
	continental: float,
	erosion: float,
	world_x: float,
	world_z: float
) -> float:
	var base_height: float = sea_level
	
	# Continental offset (deep ocean to high mountains)
	if continental < -0.45:
		base_height += lerp(
			float(TerrainConstants.DEEP_OCEAN_FLOOR),
			float(TerrainConstants.OCEAN_FLOOR),
			remap(continental, -1.0, -0.45, 0.0, 1.0)
		)
	elif continental < 0.0:
		base_height += lerp(
			float(TerrainConstants.OCEAN_FLOOR),
			float(TerrainConstants.BEACH_FLOOR),
			remap(continental, -0.45, 0.0, 0.0, 1.0)
		)
	elif continental < 0.3:
		base_height += lerp(
			float(TerrainConstants.BEACH_FLOOR),
			float(TerrainConstants.HILL_FLOOR),
			remap(continental, 0.0, 0.3, 0.0, 1.0)
		)
	elif continental < 0.6:
		base_height += lerp(
			float(TerrainConstants.HILL_FLOOR),
			float(TerrainConstants.MOUNTAINS_FLOOR),
			remap(continental, 0.3, 0.6, 0.0, 1.0)
		)
	else:
		base_height += lerp(
			float(TerrainConstants.MOUNTAINS_FLOOR),
			float(TerrainConstants.MOUNTAINS_PEAK),
			remap(continental, 0.6, 1.0, 0.0, 1.0)
		)
	
	# Erosion modifies height variation
	if erosion > 0.2:
		# Mountains - add ridge detail
		var ridge_val: float = ridge_noise.get_noise_2d(world_x, world_z)
		var ridge_factor: float = 1.0 - abs(ridge_val)
		ridge_factor = pow(ridge_factor, 1.5)
		base_height += ridge_factor * 20.0
	elif erosion > -0.1:
		# Hills
		base_height += (0.1 - erosion) * 5.0
	
	return base_height

# ============================================================================
# BIOME BLENDING
# ============================================================================

func _get_biome_blended_data(center_x: float, center_z: float) -> Dictionary:
	# 5x5 biome blending (Minecraft approach)
	var total_weight: float = 0.0
	var weighted_continental: float = 0.0
	var weighted_erosion: float = 0.0
	var weighted_pv: float = 0.0
	
	for i in range(-2, 3):
		for j in range(-2, 3):
			var offset_x: float = i * sample_spacing * 0.5
			var offset_z: float = j * sample_spacing * 0.5
			var sample_x: float = center_x + offset_x
			var sample_z: float = center_z + offset_z
			
			# Distance-based weight
			var weight: float = 10.0 / (sqrt(float(i * i + j * j)) + 0.2)
			
			var sample_biome: Dictionary = biome_manager.get_biome_data(sample_x, sample_z)
			
			weighted_continental += sample_biome.continental * weight
			weighted_erosion += sample_biome.erosion * weight
			weighted_pv += sample_biome.pv * weight
			total_weight += weight
	
	return {
		"continental": weighted_continental / total_weight,
		"erosion": weighted_erosion / total_weight,
		"pv": weighted_pv / total_weight
	}


func get_biome_data(world_x: float, world_z: float) -> Dictionary:
	return biome_manager.get_biome_data(world_x, world_z)

# ============================================================================
# SURFACE PROPERTIES
# ============================================================================

func has_water_at(world_y: float) -> bool:
	return world_y < sea_level


func get_surface_color(world_x: float, world_z: float, world_y: float) -> Color:
	var biome_data: Dictionary = get_biome_data(world_x, world_z)
	var base_color: Color = biome_data.color
	
	# Underwater color adjustment
	if has_water_at(world_y):
		base_color = _get_underwater_color(biome_data.primary_biome)
		var depth: float = sea_level - world_y
		var darkness: float = clamp(depth / 20.0, 0.0, 0.7)
		base_color = base_color.darkened(darkness)
	
	# Snow overlay
	var snow_amount: float = biome_manager.get_snow_amount(world_y, biome_data)
	if snow_amount > 0.0 and not has_water_at(world_y):
		var snow_color := Color(0.95, 0.95, 1.0)
		base_color = base_color.lerp(snow_color, snow_amount)
	
	return base_color


func _get_underwater_color(biome: TerrainConstants.BiomeType) -> Color:
	match biome:
		TerrainConstants.BiomeType.DESERT, TerrainConstants.BiomeType.BEACH:
			return Color(0.85, 0.75, 0.5)
		TerrainConstants.BiomeType.OCEAN, TerrainConstants.BiomeType.DEEP_OCEAN:
			return Color(0.4, 0.35, 0.3)
		TerrainConstants.BiomeType.FROZEN_OCEAN:
			return Color(0.5, 0.5, 0.55)
		_:
			return Color(0.5, 0.4, 0.3)

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

func clear_cache() -> void:
	height_cache.clear()
