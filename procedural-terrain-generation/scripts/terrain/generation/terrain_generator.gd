class_name TerrainGenerator
extends RefCounted

var noise: FastNoiseLite
var height_scale: float
var vertex_spacing: float

func _init(
	p_seed: int = 1223334444,
	p_height_scale: float = 10.0,
	p_vertex_spacing: float = 2.0
):
	height_scale = p_height_scale
	vertex_spacing = p_vertex_spacing
	setup_noise(p_seed)

func setup_noise(terrain_seed: int) -> void:
	noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

func get_height(world_x: float, world_z: float) -> float:
	return noise.get_noise_2d(world_x, world_z) * height_scale

func get_height_layered(world_x: float, world_z: float) -> float:
	var base = noise.get_noise_2d(world_x, world_z) * height_scale
	# Add detail layers here
	# var detail = detail_noise.get_noise_2d(world_x * 5, world_z * 5) * 2.0
	return base

func get_height_for_biome(world_x: float, world_z: float, biome_id: int) -> float:
	match biome_id:
		0: # Plains
			return get_height(world_x, world_z) * 0.5
		1: # Mountains
			return get_height(world_x, world_z) * 2.0
		2: # Valleys
			return get_height(world_x, world_z) * 0.3
		_:
			return get_height(world_x, world_z)
