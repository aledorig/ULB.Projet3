class_name TerrainGenerator
extends RefCounted

## Terrain generation using GenLayer-based biome system
## 1. Sample biome at (x, z) via BiomeManager (uses GenLayer pipeline)
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

## Whether to blend biome params at borders (smoother terrain)
## Uses Catmull-Rom interpolation for smooth, non-blocky terrain
var use_biome_blending: bool = true

## Blend radius for legacy single-point functions (get_height, get_surface_color)
var blend_radius: float = 16.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int = TerrainConstants.GAME_SEED) -> void:
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


# ============================================================================
# BATCHED GENERATION (optimized for chunks)
# ============================================================================

func get_vertex_data(x: float, z: float) -> Dictionary:
	## Get height AND color in one call (avoids double biome lookup)
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

	var noise_val: float = height_noise.get_noise_2d(x, z)
	var height: float = params.base + (noise_val * params.variation)
	var color: Color = params.color

	# Darken underwater
	if height < TerrainConstants.SEA_LEVEL:
		var depth: float = TerrainConstants.SEA_LEVEL - height
		var darkness: float = clampf(depth / 40.0, 0.0, 0.6)
		color = color.darkened(darkness)

	# Snow on peaks
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
	## Batch generate vertex data for an entire grid
	## Much faster than per-vertex calls due to batched biome lookups

	var total_verts: int = width * height

	# Use packed arrays for biome params (much faster than Dictionary)
	var base_heights: PackedFloat32Array = PackedFloat32Array()
	var variations: PackedFloat32Array = PackedFloat32Array()
	var biome_colors: PackedColorArray = PackedColorArray()
	base_heights.resize(total_verts)
	variations.resize(total_verts)
	biome_colors.resize(total_verts)

	# Pre-fetch biome params for the entire region using packed arrays
	if use_biome_blending:
		# Use Catmull-Rom interpolation for smooth terrain
		biome_manager.get_params_batch_catmull_rom(
			origin_x, origin_z, width, height, spacing,
			base_heights, variations, biome_colors
		)
	else:
		# Direct biome lookup (faster but blocky at biome borders)
		biome_manager.get_params_batch_packed(
			origin_x, origin_z, width, height, spacing, 0.0,
			base_heights, variations, biome_colors
		)

	var sea_level: float = TerrainConstants.SEA_LEVEL
	var snow_color := Color(0.95, 0.97, 1.0)

	var idx: int = 0
	for z in range(height):
		var world_z: float = origin_z + z * spacing
		for x in range(width):
			var world_x: float = origin_x + x * spacing

			var noise_val: float = height_noise.get_noise_2d(world_x, world_z)
			var h: float = base_heights[idx] + (noise_val * variations[idx])
			var color: Color = biome_colors[idx]

			# Darken underwater
			if h < sea_level:
				var depth: float = sea_level - h
				var darkness: float = clampf(depth / 40.0, 0.0, 0.6)
				color = color.darkened(darkness)

			# Snow on peaks
			if h > 60.0:
				var snow_amount: float = smoothstep(60.0, 80.0, h)
				color = color.lerp(snow_color, snow_amount)

			# Local coordinates for vertex position
			var local_x: float = x * spacing
			var local_z: float = z * spacing
			out_vertices[idx] = Vector3(local_x, h, local_z)
			out_colors[idx] = color
			idx += 1


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
