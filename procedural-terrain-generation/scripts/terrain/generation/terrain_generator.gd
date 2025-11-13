class_name TerrainGenerator
extends RefCounted

# ============================================================================
# NOISE GENERATORS
# ============================================================================

# Noise generators
var main_noise:      FastNoiseLite
var min_limit_noise: FastNoiseLite
var max_limit_noise: FastNoiseLite
var detail_noise:    FastNoiseLite
var ridge_noise:     FastNoiseLite

var biome_manager: BiomeManager
#var height_scale: float
var vertex_spacing: float
var sea_level: float = TerrainConstants.BEACH_FLOOR

# 3D grid parameters
var grid_size_xz: int = 5
var grid_size_y: int = 33
var sample_spacing: float = 8.0

var height_cache: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int = 9148748, p_height_scale: float = 10.0, p_vertex_spacing: float = 2.0):
	#height_scale   = p_height_scale
	vertex_spacing = p_vertex_spacing
	biome_manager  = BiomeManager.new(p_seed)
	setup_noise(p_seed)

func setup_noise(terrain_seed: int) -> void:
	# Main noise - determines overall terrain shape
	main_noise                    = FastNoiseLite.new()
	main_noise.seed               = terrain_seed
	main_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	main_noise.frequency          = 0.008
	main_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	main_noise.fractal_octaves    = 8
	main_noise.fractal_lacunarity = 2.0
	main_noise.fractal_gain       = 0.5
	
	# Min limit noise - lower boundary of terrain
	min_limit_noise                 = FastNoiseLite.new()
	min_limit_noise.seed            = terrain_seed + 1000
	min_limit_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	min_limit_noise.frequency       = 0.01
	min_limit_noise.fractal_type    = FastNoiseLite.FRACTAL_FBM
	min_limit_noise.fractal_octaves = 16
	
	# Max limit noise - upper boundary of terrain
	max_limit_noise                 = FastNoiseLite.new()
	max_limit_noise.seed            = terrain_seed + 2000
	max_limit_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	max_limit_noise.frequency       = 0.01
	max_limit_noise.fractal_type    = FastNoiseLite.FRACTAL_FBM
	max_limit_noise.fractal_octaves = 16
	
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
	var grid_x = floor(world_x / sample_spacing) * sample_spacing
	var grid_z = floor(world_z / sample_spacing) * sample_spacing
	
	# Get the 4 corner heights using 3D density calculation
	var h00 = _get_surface_height(grid_x, grid_z)
	var h10 = _get_surface_height(grid_x + sample_spacing, grid_z)
	var h01 = _get_surface_height(grid_x, grid_z + sample_spacing)
	var h11 = _get_surface_height(grid_x + sample_spacing, grid_z + sample_spacing)
	
	# Get interpolation factors
	var local_x = (world_x - grid_x) / sample_spacing
	var local_z = (world_z - grid_z) / sample_spacing
	
	# Apply smoothstep
	local_x = smoothstep(0.0, 1.0, local_x)
	local_z = smoothstep(0.0, 1.0, local_z)
	
	# Bilinear interpolation with smoothed factors
	var h0 = lerp(h00, h10, local_x)
	var h1 = lerp(h01, h11, local_x)
	var final_height = lerp(h0, h1, local_z)
	
	# Add small surface detail
	var detail = detail_noise.get_noise_2d(world_x, world_z) * 0.2
	final_height += detail
	
	return final_height

func _cosine_interpolate(a: float, b: float, t: float) -> float:
	# Cosine interpolation for smooth transitions
	var t_smooth = (1.0 - cos(t * PI)) / 2.0
	return a + (b - a) * t_smooth

func _get_surface_height(grid_x: float, grid_z: float) -> float:
	var key = Vector2(grid_x, grid_z)
	if key in height_cache:
		return height_cache[key]
	
	# Generate 3D density column and find surface
	var height = _calculate_surface_from_3d_density(grid_x, grid_z)
	height_cache[key] = height
	return height

# ============================================================================
# 3D DENSITY CALCULATION
# ============================================================================

func _calculate_surface_from_3d_density(world_x: float, world_z: float) -> float:
	# Get biome-blended parameters
	var biome_data = _get_biome_blended_data(world_x, world_z)
	
	# Generate a vertical column of density values (like Minecraft's 3D noise)
	# We'll sample from bottom to top to find where density crosses zero
	var min_y = TerrainConstants.MIN_HEIGHT
	var max_y = TerrainConstants.MAX_HEIGHT
	var y_step = 4
	
	var surface_y = sea_level
	
	# Scan from top to bottom to find surface
	for y in range(int(max_y), int(min_y), -int(y_step)):
		var density = _calculate_3d_density(world_x, float(y), world_z, biome_data)
		
		if density > 0.0:
			# Found solid terrain
			surface_y = float(y)
			#if surface_y>50:
				#print("surface:", surface_y)
			break
	
	return surface_y

func _calculate_3d_density(world_x: float, world_y: float, world_z: float, biome_data: Dictionary) -> float:
	# This mimics Minecraft's 3D noise combination
	# density > 0 = solid block, density <= 0 = air
	
	# Sample all three noise layers in 3D space
	var base_density = main_noise.get_noise_2d(world_x, world_z)
	#var min_limit = min_limit_noise.get_noise_3d(world_x, world_y, world_z)
	#var max_limit = max_limit_noise.get_noise_3d(world_x, world_y, world_z)
	
	#print("noise values:\n main: ", main, "\nmin_limit: ", min_limit, "\nmax_limit: ", max_limit)
	
	# Combine like Minecraft does
	#var selector = (main + 1.0) / 2.0  # Normalize to 0-1 
	#selector = clamp(selector, 0.0, 1.0)
	
	# Interpolate between min and max limits
	#var base_density = lerp(min_limit * 2.0, max_limit * 2.0, selector)
	
	# Apply height-based factor (terrain gets denser below, thins out above)
	var continental = biome_data.continental
	var erosion = biome_data.erosion
	
	# Calculate target height based on biome
	var target_height = _get_target_height_for_biome(continental, erosion, world_x, world_z)
	
	# Height falloff (makes terrain solid below target_height, air above)
	var height_factor = (world_y - target_height) * 0.15
	
	# Apply steeper falloff at extreme heights (like Minecraft does at y > 29)
	if world_y > target_height + 10.0:
		var fade = (world_y - target_height - 10.0) / 10.0
		height_factor = lerp(height_factor, height_factor * 4.0, clamp(fade, 0.0, 1.0))
	
	var final_density = base_density - height_factor
	
	return final_density

func _get_target_height_for_biome(continental: float, erosion: float, world_x: float, world_z: float) -> float:
	# Base height from continental value
	var base_height = sea_level
	
	# Continental offset (deep ocean to high mountains)
	if continental < -0.45:
		base_height += lerp(TerrainConstants.DEEP_OCEAN_FLOOR, TerrainConstants.OCEAN_FLOOR, remap(continental, -1.0, -0.45, 0.0, 1.0))
	elif continental < -0.15:
		base_height += lerp(TerrainConstants.OCEAN_FLOOR, TerrainConstants.RIVER_FLOOR, remap(continental, -0.45, -0.15, 0.0, 1.0))
	elif continental < 0.0:
		base_height += lerp(TerrainConstants.RIVER_FLOOR, TerrainConstants.BEACH_FLOOR, remap(continental, -0.15, 0.0, 0.0, 1.0))
	elif continental < 0.3:
		base_height += lerp(TerrainConstants.BEACH_FLOOR, TerrainConstants.HILL_FLOOR, remap(continental, 0.0, 0.3, 0.0, 1.0))
	elif continental < 0.6:
		base_height += lerp(TerrainConstants.HILL_FLOOR, TerrainConstants.MOUNTAINS_FLOOR, remap(continental, 0.3, 0.6, 0.0, 1.0))
	else:
		base_height += lerp(TerrainConstants.MOUNTAINS_FLOOR, TerrainConstants.MOUNTAINS_PEAK, remap(continental, 0.6, 1.0, 0.0, 1.0))
	
	# Erosion modifies height variation
	if erosion < -0.2:  # Mountains
		var ridge_val = ridge_noise.get_noise_2d(world_x, world_z)
		var ridge_factor = 1.0 - abs(ridge_val)
		ridge_factor = pow(ridge_factor, 1.5)
		base_height += ridge_factor * 20.0
	elif erosion < 0.1:  # Hills
		base_height += (0.1 - erosion) * 5.0
	
	return base_height

# ============================================================================
# BIOME BLENDING
# ============================================================================

func _get_biome_blended_data(center_x: float, center_z: float) -> Dictionary:
	# Minecraft's 5x5 biome blending approach
	var total_weight = 0.0
	var weighted_continental = 0.0
	var weighted_erosion = 0.0
	var weighted_pv = 0.0
	
	# Biome weights
	for i in range(-2, 3):
		for j in range(-2, 3):
			var offset_x = i * sample_spacing * 0.5
			var offset_z = j * sample_spacing * 0.5
			var sample_x = center_x + offset_x
			var sample_z = center_z + offset_z
			
			# Minecraft's distance-based weight formula
			var weight = 10.0 / (sqrt(i * i + j * j) + 0.2)
			
			var sample_biome = biome_manager.get_biome_data(sample_x, sample_z)
			
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
# WATER & SURFACE PROPERTIES
# ============================================================================

func has_water_at(world_y: float) -> bool:
	return world_y < sea_level

func get_surface_color(world_x: float, world_z: float, world_y: float) -> Color:
	var biome_data = get_biome_data(world_x, world_z)
	var base_color = biome_data.color
	
	if has_water_at(world_y):
		var primary_biome = biome_data.primary_biome
		match primary_biome:
			BiomeManager.BiomeType.DESERT, BiomeManager.BiomeType.BEACH:
				base_color = Color(0.85, 0.75, 0.5)
			BiomeManager.BiomeType.OCEAN, BiomeManager.BiomeType.DEEP_OCEAN:
				base_color = Color(0.4, 0.35, 0.3)
			BiomeManager.BiomeType.FROZEN_OCEAN:
				base_color = Color(0.5, 0.5, 0.55)
			BiomeManager.BiomeType.RIVER:
				base_color = Color(0.45, 0.35, 0.25)
			_:
				base_color = Color(0.5, 0.4, 0.3)
		
		var depth = sea_level - world_y
		var darkness = clamp(depth / 20.0, 0.0, 0.7)
		base_color = base_color.darkened(darkness)
	
	var snow_amount = biome_manager.get_snow_amount(world_y, biome_data)
	if snow_amount > 0.0 and not has_water_at(world_y):
		var snow_color = Color(0.95, 0.95, 1.0)
		base_color = base_color.lerp(snow_color, snow_amount)
	
	return base_color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func clear_cache():
	height_cache.clear()
