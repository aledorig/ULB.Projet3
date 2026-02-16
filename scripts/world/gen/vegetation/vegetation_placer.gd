class_name VegetationPlacer
extends RefCounted

## Facade that delegates to GrassPlacer, TreePlacer, FoliagePlacer
## Each chunk creates one VegetationPlacer with a shared RNG seed

var _grass:   GrassPlacer
var _tree:    TreePlacer
var _foliage: FoliagePlacer

var terrain_gen:    TerrainGenerator
var chunk_size:     int
var vertex_spacing: float


func _init(p_terrain_gen: TerrainGenerator, p_chunk_size: int, p_vertex_spacing: float, p_seed: int, p_chunk_pos: Vector2i) -> void:
	terrain_gen = p_terrain_gen
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing

	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed ^ (p_chunk_pos.x * 73856093) ^ (p_chunk_pos.y * 19349663)

	_grass = GrassPlacer.new(terrain_gen, chunk_size, vertex_spacing, rng)
	_tree = TreePlacer.new(terrain_gen, chunk_size, vertex_spacing, rng)
	_foliage = FoliagePlacer.new(terrain_gen, chunk_size, vertex_spacing, rng)


func generate_grass(chunk_pos: Vector2i, lod_level: int) -> Dictionary:
	return _grass.generate(chunk_pos, lod_level)


func generate_all_non_grass(chunk_pos: Vector2i, foliage_lod: int = 0) -> Dictionary:
	var tree_grid: Dictionary = VegetationPlacerUtils.query_grid(terrain_gen, chunk_size, vertex_spacing, chunk_pos, 8)

	var lod_grid_res: Array[int] = TerrainConfig.FOLIAGE_LOD_GRID_RES
	var foliage_grid_res: int = lod_grid_res[foliage_lod] if foliage_lod < lod_grid_res.size() else 6
	var foliage_grid: Dictionary
	if foliage_grid_res == 8:
		foliage_grid = tree_grid
	else:
		foliage_grid = VegetationPlacerUtils.query_grid(terrain_gen, chunk_size, vertex_spacing, chunk_pos, foliage_grid_res)

	return {
		"trees": _tree.generate(chunk_pos, tree_grid),
		"foliage": _foliage.generate(chunk_pos, foliage_grid, foliage_lod)
	}


func generate_foliage_standalone(chunk_pos: Vector2i, lod_level: int) -> Dictionary:
	return _foliage.generate_standalone(chunk_pos, lod_level)
