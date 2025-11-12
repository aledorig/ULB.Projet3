extends MeshInstance3D

@export var chunk_size: int = 40
@export var vertex_spacing: float = 2.0
@export var height_scale: float = 10.0
@export var terrain_seed: int = 1223334444

var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder

func _ready():
	_initialize_generators()

func _initialize_generators():
	terrain_generator = TerrainGenerator.new(terrain_seed, height_scale, vertex_spacing)
	mesh_builder = ChunkMeshBuilder.new(chunk_size, vertex_spacing, terrain_generator)

func generate_chunk(chunk_position: Vector2):
	if not terrain_generator:
		_initialize_generators()
	
	mesh = mesh_builder.build_chunk_mesh(chunk_position)

## Public API: Get height at world position (useful for object placement)
func get_height_at(world_x: float, world_z: float) -> float:
	if not terrain_generator:
		_initialize_generators()
	return terrain_generator.get_height(world_x, world_z)
