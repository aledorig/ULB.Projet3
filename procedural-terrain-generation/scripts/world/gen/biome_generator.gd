class_name BiomeGenerator
extends RefCounted

var final_layer: GenLayer
var game_seed: int

func _init(p_seed: int) -> void:
	game_seed = p_seed
	final_layer = _init_layers()


func _init_layers() -> GenLayer:
	var layer: GenLayer

	# Stage 1: Land/Ocean distribution
	layer = GenLayerIsland.new(1, 10)
	layer = GenLayerZoom.new(2000, layer, true)
	layer = GenLayerAddIsland.new(1, layer)
	layer = GenLayerZoom.new(2001, layer)
	layer = GenLayerAddIsland.new(2, layer)
	layer = GenLayerAddIsland.new(50, layer)
	layer = GenLayerAddIsland.new(70, layer)

	# Stage 2: Climate zones
	layer = GenLayerClimate.new(2, layer)
	layer = GenLayerClimateEdge.new(2, layer, GenLayerClimateEdge.Mode.COOL_WARM)
	layer = GenLayerClimateEdge.new(2, layer, GenLayerClimateEdge.Mode.HEAT_ICE)
	layer = GenLayerZoom.new(2002, layer)
	layer = GenLayerZoom.new(2003, layer)

	# Stage 3: Biome selection
	layer = GenLayerBiome.new(200, layer)
	layer = GenLayerZoom.new(1000, layer)
	layer = GenLayerZoom.new(1001, layer)
	layer = GenLayerBiomeEdge.new(1000, layer)

	# Stage 4: Final refinement
	var biome_size: int = 4

	for i in range(biome_size):
		layer = GenLayerZoom.new(1000 + i, layer)

		if i == 1:
			layer = GenLayerShore.new(1000, layer)

	layer = GenLayerSmooth.new(1000, layer)

	layer.init_world_seed(game_seed)

	return layer

func get_biome_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	var result := final_layer.get_values(area_x, area_z, width, height)

	GenLayer.reset_cache()

	return result.duplicate()


func get_biome_at(bx: int, bz: int) -> int:
	var values := get_biome_values(bx, bz, 1, 1)
	return values[0]
