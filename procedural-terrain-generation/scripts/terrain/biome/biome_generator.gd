class_name BiomeGenerator
extends RefCounted

## Initializes and chains all GenLayer layers to create the biome pipeline
## This is the main entry point for biome generation

# ============================================================================
# STATE
# ============================================================================

var final_layer: GenLayer
var game_seed: int

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_seed: int) -> void:
	game_seed = p_seed
	final_layer = _init_layers()


func _init_layers() -> GenLayer:
	var layer: GenLayer

	# ========================================
	# Stage 1: Land/Ocean distribution
	# ========================================

	# Start with basic island generation (10% land chance)
	layer = GenLayerIsland.new(1, 10)

	# Fuzzy zoom to double resolution with random interpolation
	layer = GenLayerZoom.new(2000, layer, true)

	# Add more islands
	layer = GenLayerAddIsland.new(1, layer)

	# Normal zoom
	layer = GenLayerZoom.new(2001, layer)

	# More island passes
	layer = GenLayerAddIsland.new(2, layer)
	layer = GenLayerAddIsland.new(50, layer)
	layer = GenLayerAddIsland.new(70, layer)

	# ========================================
	# Stage 2: Climate zones
	# ========================================

	# Assign climate categories (warm/medium/cold/frozen)
	layer = GenLayerClimate.new(2, layer)

	# Prevent warm touching cold
	layer = GenLayerClimateEdge.new(2, layer, GenLayerClimateEdge.Mode.COOL_WARM)

	# Prevent warm touching frozen
	layer = GenLayerClimateEdge.new(2, layer, GenLayerClimateEdge.Mode.HEAT_ICE)

	# Zoom to increase resolution
	layer = GenLayerZoom.new(2002, layer)
	layer = GenLayerZoom.new(2003, layer)

	# ========================================
	# Stage 3: Biome selection
	# ========================================

	# Convert climate zones to actual biome IDs
	layer = GenLayerBiome.new(200, layer)

	# Zoom
	layer = GenLayerZoom.new(1000, layer)
	layer = GenLayerZoom.new(1001, layer)

	# Apply biome edge rules (insert transition biomes)
	layer = GenLayerBiomeEdge.new(1000, layer)

	# ========================================
	# Stage 4: Final refinement
	# ========================================

	# 3 zoom passes - balance between detail and performance
	var biome_size: int = 3

	for i in range(biome_size):
		layer = GenLayerZoom.new(1000 + i, layer)

		# Add shore layer after first zoom
		if i == 1:
			layer = GenLayerShore.new(1000, layer)

	# Final smooth pass
	layer = GenLayerSmooth.new(1000, layer)

	# Initialize seed chain
	layer.init_world_seed(game_seed)

	return layer

# ============================================================================
# PUBLIC API
# ============================================================================

func get_biome_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	## Generate biome IDs for a region
	## Coordinates are in biome-grid space (not world space)
	var result := final_layer.get_values(area_x, area_z, width, height)

	# Reset cache after generation to recycle arrays
	GenLayer.reset_cache()

	# Make a copy since cached arrays will be reused
	return result.duplicate()


func get_biome_at(bx: int, bz: int) -> int:
	## Get single biome at biome-grid coordinate
	var values := get_biome_values(bx, bz, 1, 1)
	return values[0]
