class_name TerrainGenerator
extends RefCounted

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var height_scale: float
var vertex_spacing: float

func _init(p_seed: int = 1223334444, p_height_scale: float = 10.0, p_vertex_spacing: float = 2.0):
	height_scale = p_height_scale
	vertex_spacing = p_vertex_spacing
	setup_noise(p_seed)

func setup_noise(terrain_seed: int) -> void:
	# Base terrain noise
	noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	# Biome noise
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = terrain_seed + 1000
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.01
	biome_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	biome_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	# Detail noise
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = terrain_seed + 2000
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.frequency = 0.2

func get_height(world_x: float, world_z: float) -> float:
	# Get biome value to determine terrain type
	var biome_value = biome_noise.get_noise_2d(world_x, world_z)
	
	# Base height
	var base_height = noise.get_noise_2d(world_x, world_z) * height_scale
	
	# Detail layer
	var detail = detail_noise.get_noise_2d(world_x, world_z) * 1.5
	
	# Apply biome-based height multipliers
	var height_multiplier = 1.0
	
	if biome_value > 0.3:
		# Mountain regions
		height_multiplier = 3.0 + (biome_value - 0.3) * 2.0
		# Add extra roughness to mountains
		var mountain_detail = noise.get_noise_2d(world_x * 2.0, world_z * 2.0) * 5.0
		base_height += mountain_detail
	elif biome_value > 0.0:
		# Hill regions
		height_multiplier = 1.5 + biome_value * 2.0
	else:
		# Plains
		height_multiplier = 0.5 + max(0, biome_value + 0.5)
	
	return (base_height * height_multiplier) + detail
