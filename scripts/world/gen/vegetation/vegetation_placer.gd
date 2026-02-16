class_name VegetationPlacer
extends RefCounted

## Queries ONE shared grid per chunk, passes it to all sub-placers
## Grid resolution follows the grass LOD level (32/16/8)
## Trees and foliage use the exact same grid

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

	_grass = GrassPlacer.new(rng)
	_tree = TreePlacer.new(rng)
	_foliage = FoliagePlacer.new(rng)


func generate_all(chunk_pos: Vector2i, grass_lod: int, foliage_lod: int) -> Dictionary:
	## One grid query shared by grass, trees, and foliage
	var lod_grid_res: Array[int] = TerrainConfig.GRASS_LOD_GRID_RES
	var grid_res: int = lod_grid_res[grass_lod] if grass_lod < lod_grid_res.size() else 8
	var grid: Dictionary = VegetationPlacerUtils.query_grid(terrain_gen, chunk_size, vertex_spacing, chunk_pos, grid_res)

	return {
		"grass": _grass.generate(grid, grass_lod),
		"trees": _tree.generate(chunk_pos, grid),
		"foliage": _foliage.generate(chunk_pos, grid, foliage_lod)
	}


func generate_grass_standalone(chunk_pos: Vector2i, grass_lod: int) -> Dictionary:
	## For grass-only LOD updates
	var lod_grid_res: Array[int] = TerrainConfig.GRASS_LOD_GRID_RES
	var grid_res: int = lod_grid_res[grass_lod] if grass_lod < lod_grid_res.size() else 8
	var grid: Dictionary = VegetationPlacerUtils.query_grid(terrain_gen, chunk_size, vertex_spacing, chunk_pos, grid_res)
	return _grass.generate(grid, grass_lod)


func generate_foliage_standalone(chunk_pos: Vector2i, foliage_lod: int) -> Dictionary:
	## For foliage-only LOD updates
	var grid: Dictionary = VegetationPlacerUtils.query_grid(terrain_gen, chunk_size, vertex_spacing, chunk_pos, 16)
	return _foliage.generate(chunk_pos, grid, foliage_lod)
